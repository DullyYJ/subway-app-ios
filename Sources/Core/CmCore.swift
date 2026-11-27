import Foundation

/// 출퇴근 브리핑 알림 설정의 "기기 쪽 상태" (안드로이드 native/shell/CmCore.java 를 옮긴 것).
///
/// ★ 원칙: "모든 계산은 엔진이 한다. 앱은 그림만 그린다."
///   설정 화면의 글·칸·요일 안내·역 후보는 모두 엔진(GET /screen/settings?p=cm 과 설정 첫 화면의 cmf)이 만든다.
///   여기는 사용자가 누른 것을 저장소(UserDefaults)에 적고(켜짐 · 출근/퇴근 시각 · 요일 · 장소 이름과 버스 좌표),
///   시각 고르기 팝업과 장소 입력칸의 "지금 어디까지 골랐나"만 기억한다.
///   알림 문구는 엔진 POST /commute-brief, 언제 울릴지는 엔진 POST /commute-alarm(op:occ) 가 정한다 — 여기는 그 요청 본문을 만들 뿐이다.
final class CmCore {
    static let shared = CmCore()

    static let kOn = "cm_on", kMorn = "cm_morn", kEve = "cm_eve", kDays = "cm_days"
    /// 장소 칸 이름(엔진 SETTINGS_PICK 의 키와 같다): 출근 출발 · 출근 도착 · 퇴근 출발 · 퇴근 도착.
    static let pk = ["from", "to", "eFrom", "eTo"]
    /// 눌림 결과(비트) — 부르는 쪽이 이 값을 보고 다시 그리기 · 알림 다시 예약 · 미리보기 · 닫기 · 버스 정류장 찾기를 한다.
    enum R {
        static let none = 0, render = 1, resched = 2, test = 4, close = 8, bus = 16
    }

    /// 시각 고르기를 가운데 팝업으로 열었다 — 엔진이 뒤로 가기 줄을 빼고 단추 묶음을 준다.
    var pop = false
    var sub = ""                                   // "" · "tp"(시각 고르기)
    var tpT = "morn", tpAp = "am"
    var tpH = 7, tpM = 30
    var pkK = "from", pkQ = ""
    /// 설정 화면 안 장소 입력칸에서 고치는 중. 켜져 있으면 pkK 가 그 칸 · pkQ 가 친 글자 — 엔진이 후보 줄을 그 칸 아래에 끼운다.
    var inl = false
    /// 설정 화면 요청(f=)에 싣는 '지금 고치는 칸 + 버스 후보' 조각(없으면 "").
    static var inlX = ""
    private var busNames: [String] = []                       // 앱이 찾아 온 버스정류장 후보(pk.b.<번호>)
    private var busGeo: [(Double, Double)] = []

    // MARK: 저장 값
    private static func get(_ k: String, _ d: String) -> String { UserDefaults.standard.string(forKey: k) ?? d }
    private static func put(_ k: String, _ v: String) { UserDefaults.standard.set(v, forKey: k) }

    static func on() -> Bool { get(kOn, "0") == "1" }
    static func morn() -> String { hm(get(kMorn, "07:30"), "07:30") }
    static func eve() -> String { hm(get(kEve, "18:30"), "18:30") }
    /// 'HH:MM' 두 자리 모양만 받는다.
    static func hm(_ s: String, _ def: String) -> String {
        let c = Array(s.utf8)
        guard c.count == 5, c[2] == 58 else { return def }
        for i in [0, 1, 3, 4] where c[i] < 48 || c[i] > 57 { return def }
        let h = Int(c[0] - 48) * 10 + Int(c[1] - 48), m = Int(c[3] - 48) * 10 + Int(c[4] - 48)
        return (h < 24 && m < 60) ? s : def
    }
    /// 보낼 요일(0=일 … 6=토). 저장 안 했으면 평일. 비어 있으면(고른 게 없음) 엔진이 매일로 본다.
    static func days() -> [Int] {
        var out: [Int] = []
        for p in get(kDays, "1,2,3,4,5").split(separator: ",") {
            let t = p.trimmingCharacters(in: .whitespaces)
            if t.count == 1, let d = Int(t), d >= 0, d <= 6, !out.contains(d) { out.append(d) }
        }
        return out.sorted()
    }
    static func daysStr(_ d: [Int]) -> String { d.map { String($0) }.joined(separator: ",") }
    static func nameKey(_ k: String) -> String { "cm_" + k.lowercased() }
    static func place(_ k: String) -> String { get(nameKey(k), "") }
    static func geoKey(_ k: String) -> String { nameKey(k) + "_g" }
    /// 장소 저장. geo 는 버스정류장일 때만("위도,경도,1") — 지하철역 · 직접 입력은 없음(역은 엔진이 이름으로 찾는다).
    static func setPlace(_ k: String, _ name: String, _ geo: (Double, Double)?) {
        put(nameKey(k), name)
        put(geoKey(k), geo.map { "\($0.0),\($0.1),1" } ?? "")
    }
    /// 엔진에 보낼 장소 {nm,lat?,lng?,bus?} — 이름이 비면 nil.
    static func placeJson(_ k: String) -> String? {
        let nm = place(k).trimmingCharacters(in: .whitespaces)
        if nm.isEmpty { return nil }
        var b = "{\"nm\":\(Json.q(nm))"
        let g = get(geoKey(k), "")
        if !g.isEmpty {
            let p = g.split(separator: ",").map { String($0) }
            if p.count == 3, let la = Double(p[0]), let lo = Double(p[1]) { b += ",\"lat\":\(la),\"lng\":\(lo),\"bus\":true" }
        }
        return b + "}"
    }

    // MARK: 엔진 요청 본문
    /// POST /commute-brief 본문. gps 가 nil 이면 싣지 않는다. eta 가 true 면 엔진에 "가장 빠른 경로의 예상 소요 · 도착시각도 구해 달라".
    static func briefBody(kind: String, nowMs: Int64, gps: (Double, Double)?, eta: Bool = false) -> String {
        let k = kind == "eve" ? "eve" : (kind == "auto" ? "auto" : "morn")
        var b = "{\"kind\":\(Json.q(k)),\"nowMs\":\(nowMs)"
        for x in pk { if let p = placeJson(x) { b += ",\(Json.q(x)):\(p)" } }
        if let g = gps { b += ",\"gps\":{\"lat\":\(g.0),\"lng\":\(g.1)}" }
        if eta { b += ",\"eta\":1" }
        return b + "}"
    }
    /// POST /commute-alarm 본문(op:occ) — 앞으로 28일치 울릴 시각을 엔진이 정한다.
    static func occBody(_ nowMs: Int64) -> String {
        "{\"op\":\"occ\",\"nowMs\":\(nowMs),\"morn\":\(Json.q(morn())),\"eve\":\(Json.q(eve())),\"days\":[\(daysStr(days()))]}"
    }
    /// /commute-alarm occ 응답 → 시각 목록(ms). kind = morn | eve. 이상하면 빈 배열.
    static func parseOcc(_ d: Data, kind: String, max: Int) -> [Int64] {
        guard let o = Json.obj(d) as? [String: Any], (o["ok"] as? Bool) == true, let l = o[kind] as? [Any] else { return [] }
        var out: [Int64] = []
        for x in l.prefix(max) { if let n = x as? NSNumber { out.append(n.int64Value) } }
        return out
    }
    /// /commute-brief 응답 → (제목, 본문, 출근/퇴근). 없으면 nil.
    static func parseBrief(_ d: Data) -> (String, String, String)? {
        guard let m = Json.obj(d) as? [String: Any], (m["ok"] as? Bool) == true,
              let t = m["title"] as? String, let b = m["body"] as? String, !t.isEmpty, !b.isEmpty else { return nil }
        let k = (m["kind"] as? String) == "eve" ? "eve" : "morn"          // 엔진이 정한 출근/퇴근(미리보기 auto 도 여기서 정해진다)
        return (String(t.prefix(80)), String(b.prefix(800)), k)
    }
    struct Pt { var name = "", lat = 0.0, lng = 0.0, bus = false }
    /// /commute-brief 응답의 route → (출발, 도착). 없으면(장소를 못 찾았거나 안 정함) nil.
    static func parseRoute(_ d: Data) -> (Pt, Pt)? {
        guard let m = Json.obj(d) as? [String: Any], let r = m["route"] as? [String: Any], let a = pt(r["from"]), let b = pt(r["to"]) else { return nil }
        return (a, b)
    }
    private static func pt(_ o: Any?) -> Pt? {
        guard let m = o as? [String: Any], let nm = m["name"] as? String, let la = (m["lat"] as? NSNumber)?.doubleValue, let lo = (m["lng"] as? NSNumber)?.doubleValue,
              !nm.isEmpty, la != 0, lo != 0 else { return nil }
        return Pt(name: nm, lat: la, lng: lo, bus: (m["bus"] as? Bool) == true)
    }

    // MARK: 엔진 화면 요청에 싣는 기기 사실
    /// 시각 고르기 팝업 화면(GET /screen/settings?p=cm)의 기기 사실.
    func pageFacts() -> String {
        var b = "{\"pf\":{\"nat\":true,\"nv\":true,\"on\":\(CmCore.on())"
        b += ",\"morn\":\(Json.q(CmCore.morn())),\"eve\":\(Json.q(CmCore.eve()))"
        b += ",\"days\":[\(CmCore.daysStr(CmCore.days()))]"
        for k in CmCore.pk { b += ",\(Json.q(k)):\(Json.q(CmCore.place(k)))" }
        if sub == "tp" && pop { b += ",\"pop\":true" }
        if sub == "tp" { b += ",\"sub\":\"tp\",\"tp\":{\"t\":\(Json.q(tpT)),\"ap\":\(Json.q(tpAp)),\"h\":\(tpH),\"m\":\(tpM)}" }
        return b + "}}"
    }
    /// 설정 첫 화면 요청에 싣는 출퇴근 패널의 기기 사실(엔진 settingsPageFacts 와 같은 모양 · cmf).
    static func inlineFacts() -> String {
        var b = "{\"nat\":true,\"nv\":true,\"on\":\(on())"
        b += ",\"morn\":\(Json.q(morn())),\"eve\":\(Json.q(eve()))"
        b += ",\"days\":[\(daysStr(days()))]"
        for k in pk { b += ",\(Json.q(k)):\(Json.q(place(k)))" }
        return b + inlX + "}"
    }
    private func syncX() {
        if !inl { CmCore.inlX = ""; return }
        var b = ",\"pick\":{\"k\":\(Json.q(pkK)),\"q\":\(Json.q(pkQ))},\"bus\":["
        b += busNames.map { Json.q($0) }.joined(separator: ",")
        CmCore.inlX = b + "]"
    }
    static func isPk(_ k: String) -> Bool { pk.contains(k) }

    // MARK: 장소 입력칸
    /// 입력칸에 손가락이 들어옴: 어느 칸인지만 적는다(그려 다시 받지 않는다).
    func focusInline(_ k: String, _ q: String) {
        guard CmCore.isPk(k) else { return }
        inl = true; pkK = k; pkQ = q; clearBus(); syncX()
    }
    /// 입력칸에서 글자가 바뀜.
    func onInline(_ k: String, _ q: String) -> Int {
        guard CmCore.isPk(k) else { return R.none }
        let same = inl && k == pkK
        inl = true; pkK = k; pkQ = q
        if !same { clearBus() }
        if pkQ.trimmingCharacters(in: .whitespaces).count < 2 { clearBus(); syncX(); return R.render }
        syncX()
        return R.render | R.bus                    // 지하철역 후보는 엔진이 바로 그린다 · 버스정류장은 찾아 오는 대로 한 번 더 그린다
    }
    /// 입력칸을 벗어남 — 친 글자가 있고 저장된 것과 다르면 자동 저장한다.
    func blurInline(_ k: String, _ typed: String) -> Int {
        guard inl, k == pkK else { return R.none }
        let t = typed.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty, t.count <= 60, t != CmCore.place(k).trimmingCharacters(in: .whitespaces) {      // 글자를 모두 지운 채 벗어나면 저장된 것을 그대로 둔다 — 비우기는 Enter 로만
            CmCore.setPlace(k, t, nil); _ = endInline()
            return R.render | R.resched
        }
        _ = endInline()
        return R.render
    }
    /// 고치기를 끝낸다(저장하지 않은 글자는 버린다). 켜져 있었으면 true.
    @discardableResult func endInline() -> Bool { let was = inl; inl = false; clearBus(); syncX(); return was }
    /// 앱이 찾아 온 버스정류장 후보(이름 · 위도 · 경도).
    func setBus(_ names: [String], _ geo: [(Double, Double)]) {
        busNames = []; busGeo = []
        for i in 0..<min(names.count, geo.count) { busNames.append(names[i]); busGeo.append(geo[i]) }
        syncX()
    }
    func clearBus() { busNames = []; busGeo = []; if inl { syncX() } }

    // MARK: 눌림
    /// a = 행동 종류(call · set) · v = call 이름 · key = 스위치 키(cm) · on = 스위치 값 · q = 입력칸 글자(pk.save/pk.n 일 때). 눌림 결과(R.*)를 돌려준다.
    func act(_ a: String, v: String?, key: String?, on: Bool, q: String?) -> Int {
        if a == "set" {
            if key != "cm" { return R.none }
            CmCore.put(CmCore.kOn, on ? "1" : "0")
            return R.render | R.resched
        }
        guard a == "call", let v = v else { return R.none }
        if v == "pg.back" { if !sub.isEmpty { sub = ""; clearBus(); return R.render }; return R.close }
        if v.hasPrefix("cm.day.") {
            let d = CmCore.digit(v, 7)
            if d < 0 || d > 6 { return R.none }
            var l = CmCore.days()
            if let i = l.firstIndex(of: d) { l.remove(at: i) } else { l.append(d) }
            CmCore.put(CmCore.kDays, CmCore.daysStr(l.sorted()))
            return R.render | R.resched
        }
        if v.hasPrefix("cm.preset.") {
            let p = String(v.dropFirst(10))
            let cur = CmCore.get(CmCore.kDays, "1,2,3,4,5")
            CmCore.put(CmCore.kDays, p == "weekday" ? "1,2,3,4,5" : p == "weekend" ? "0,6" : p == "all" ? "0,1,2,3,4,5,6" : cur)
            return R.render | R.resched
        }
        if v == "cm.tp.morn" || v == "cm.tp.eve" {
            tpT = v.hasSuffix("eve") ? "eve" : "morn"
            let s = Array((tpT == "eve" ? CmCore.eve() : CmCore.morn()).utf8)
            let h24 = Int(s[0] - 48) * 10 + Int(s[1] - 48), m = Int(s[3] - 48) * 10 + Int(s[4] - 48)
            tpAp = h24 >= 12 ? "pm" : "am"; tpH = h24 % 12 == 0 ? 12 : h24 % 12; tpM = m - (m % 5)
            sub = "tp"
            return R.render
        }
        if v == "tp.ap.am" || v == "tp.ap.pm" { tpAp = v.hasSuffix("pm") ? "pm" : "am"; return R.render }
        if v.hasPrefix("tp.h.") { let h = CmCore.num(v, 5); if h < 1 || h > 12 { return R.none }; tpH = h; return R.render }
        if v.hasPrefix("tp.m.") { let m = CmCore.num(v, 5); if m < 0 || m > 55 || m % 5 != 0 { return R.none }; tpM = m; return R.render }
        if v == "tp.cancel" { sub = ""; pop = false; return R.render }
        if v == "tp.ok" {
            let h24 = (tpH % 12) + (tpAp == "pm" ? 12 : 0)
            let s = (h24 < 10 ? "0" : "") + String(h24) + ":" + (tpM < 10 ? "0" : "") + String(tpM)
            CmCore.put(tpT == "eve" ? CmCore.kEve : CmCore.kMorn, s)
            sub = ""; pop = false
            return R.render | R.resched
        }
        if v == "cm.test" { return R.test }
        if v.hasPrefix("pk.save.") {                                              // 설정 화면 안 입력칸의 Enter: 그 칸 글자를 저장(비면 지움)
            let k = String(v.dropFirst(8))
            if !CmCore.isPk(k) { return R.none }
            CmCore.setPlace(k, (q ?? "").trimmingCharacters(in: .whitespaces), nil); endInline()
            return R.render | R.resched
        }
        if v == "pk.n" {                                                          // 설정 화면 안 지하철 후보 줄(이름은 엔진이 줬다)
            let t = (q ?? "").trimmingCharacters(in: .whitespaces)
            if !inl || t.isEmpty || (q ?? "").count > 60 { return R.none }
            CmCore.setPlace(pkK, t, nil); endInline()
            return R.render | R.resched
        }
        if !inl { return R.none }
        if v == "pk.cancel" { endInline(); return R.render }
        if v == "pk.clear" { CmCore.setPlace(pkK, "", nil); endInline(); return R.render | R.resched }
        if v.hasPrefix("pk.b.") {
            let i = CmCore.num(v, 5)
            if i < 0 || i >= busNames.count || i >= busGeo.count { return R.none }
            CmCore.setPlace(pkK, busNames[i], busGeo[i]); endInline()
            return R.render | R.resched
        }
        return R.none
    }
    private static func digit(_ v: String, _ at: Int) -> Int {
        let a = Array(v.utf8)
        return (a.count == at + 1 && a[at] >= 48 && a[at] <= 57) ? Int(a[at] - 48) : -1
    }
    private static func num(_ v: String, _ at: Int) -> Int {
        let a = Array(v.utf8)
        if a.count <= at || a.count > at + 3 { return -1 }
        var n = 0
        for i in at..<a.count { let c = a[i]; if c < 48 || c > 57 { return -1 }; n = n * 10 + Int(c - 48) }
        return n
    }
}
