import SwiftUI
import Combine

/// 홈 탭 — 안드로이드 HomeCore + ShellActivity 홈 흐름과 같은 순서(계산·문구·모양은 모두 엔진, 앱은 입력 상태를 실어 보내고 그리기만):
///  ① 입력 상태(출발·도착 글자 · 고른 장소 · 눌린 칸 · 후보 원자료)를 POST /screen/home 에 보낸다.
///  ② 지하철 후보는 엔진이 거르고(info.pk.u), 버스정류장·장소 후보는 앱이 받아(/suggest) 엔진에 실어 보낸다.
///  ③ [경로 탐색]: 고른 두 곳의 좌표로 GET /route-v2-app 을 받아 그대로 들고 있다가 POST /screen/result 에 실어, 나온 결과 화면을 홈 화면 아래에 이어 붙인다.
/// 이번 단계에 없는 것: 기준시각 고르기 · 경로 확정(탑승 안내) · 세부경로 시트 · 즐겨찾기 · 홈 카드(AI 승무원 · 혼잡도 · 대화) · 장면.
struct HLoc {
    var type = "", name = "", line = "", qname = ""
    var lat = 0.0, lng = 0.0
    var ok: Bool { lat != 0 && lng != 0 && !name.isEmpty }
}

@MainActor
final class HomeModel: ObservableObject {
    @Published var screen: Screen? = nil
    @Published var error: String? = nil
    static let START = 0, DEST = 1
    static let keys = ["start", "dest"]

    var text = ["", ""]
    var loc: [HLoc?] = [nil, nil]
    var active = -1, last = 0
    var gps = false, routing = false
    private var pkU: [HLoc] = []
    private var busRaw: [[[String: Any]]] = [[], []], placeRaw: [[[String: Any]]] = [[], []]
    private var candQ = ["", ""], fetchedQ = ["", ""]
    // 경로 결과(받은 응답을 그대로 들고 있다가 엔진에 다시 보낸다 — 앱은 가공하지 않는다)
    private var routeRaw = "", resTab = "fast", resA = "", resB = ""
    private var resRb: Int64 = 0, resBt: Int64 = -1
    private var baseMs: Int64 = -1                      // -1 = 기준시각을 안 골랐다(지금)
    @Published var showTimePick = false
    @Published var pickDate = Date()
    private var hasRoute: Bool { routeRaw.count > 2 }
    private var seq = 0, seqRoute = 0
    // 탑승 안내(경로 확정): 어느 경로로 확정했는지 기억하고, 탑승 사실(ride · lv)은 RideLoop 가 엔진 답에서 옮겨 둔 것을 쓴다
    private var rideSeq = -1, confirming = false
    private var bag = Set<AnyCancellable>()
    private var riding: Bool { RideLoop.shared.running && rideSeq == seqRoute && RideLoop.shared.rideJson.count > 2 }
    // 홈 카드 묶음(AI 승무원 · 혼잡도 · 실시간 대화): 엔진 /screen/hcards 가 정한 카드를 홈 본문 맨 아래에 붙인다
    private var aiNextAt: Int64 = 0, aiRnd = Double.random(in: 0..<1)
    private var hcKey = "", hcData: Data? = nil
    private func hcKeyNow() -> String {
        let fix = LocationStore.shared.last.map { String(format: "%.3f,%.3f", $0.coordinate.latitude, $0.coordinate.longitude) } ?? "-"
        return "\(resTab):\(hasRoute ? seqRoute : -1):\(nowMs() / 60000):\(aiNextAt):\(RideLoop.shared.sceneJson.hashValue):\(fix)"
    }
    private func hcardsBody() -> String {
        let e = env()
        var b = "{\"cap\":\(Servers.cap),\"f\":{\"now\":\(e.ms),\"tz\":\(-e.tzo),\"th\":\"dark\""
        let sc = RideLoop.shared.sceneJson
        if sc.count > 2 { b += ",\"rd\":\(sc)" }
        if let l = LocationStore.shared.last { b += ",\"gps\":[\(l.coordinate.latitude),\(l.coordinate.longitude)]" } else { b += ",\"gps\":null" }
        b += ",\"r\":\(resultFacts() ?? "null")"
        b += ",\"ai\":{\"nextAt\":\(aiNextAt),\"busy\":false,\"rnd\":\(aiRnd)},\"tk\":{\"m\":[],\"fold\":0,\"tzo\":\(e.tzo)}}}"
        return b
    }
    /// 1분마다 홈을 다시 그린다(카드 열쇠에 분이 들어 있다).
    func tick() { if hcKey != hcKeyNow() { reloadSoon() } }
    @Published var dlg: Screen? = nil
    private var pickCtx: (facts: String, ms: [Int64], no: [String], startTxt: String, seq: Int)? = nil
    private var pending: Task<Void, Never>? = nil

    /// 화면 확인용 실행 인자: -homeDest 명동 → 도착지 칸에 글자를 넣고 시작 · -homeRoute 1 → 서울역→명동 경로까지 자동으로 찾는다
    var demoRoute = false
    init() {
        RideLoop.shared.$lvJson.dropFirst().sink { [weak self] _ in Task { @MainActor in self?.reloadSoon() } }.store(in: &bag)
        RideLoop.shared.$rideJson.dropFirst().sink { [weak self] _ in Task { @MainActor in self?.reloadSoon() } }.store(in: &bag)
        if let d = UserDefaults.standard.string(forKey: "homeDest"), !d.isEmpty { text[1] = d; active = 1; last = 1; candQ[1] = d }
        if UserDefaults.standard.string(forKey: "homeRoute") == "1" {
            loc[0] = HLoc(type: "subway", name: "서울역", line: "1호선", qname: "", lat: 37.5547, lng: 126.9707); text[0] = "서울역"
            loc[1] = HLoc(type: "subway", name: "명동", line: "4호선", qname: "", lat: 37.5609, lng: 126.9863); text[1] = "명동"
            demoRoute = true
        }
    }
    func startDemo(host: Host) async {
        if demoRoute { demoRoute = false; await goRoute(host: host); if UserDefaults.standard.string(forKey: "homeDetail") == "1" { openDetail() } }
    }

    // MARK: 요청
    private func nowMs() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
    private func env() -> (ms: Int64, tzo: Int, y: Int, m: Int, d: Int) {
        let now = Date(), c = Calendar.current.dateComponents([.year, .month, .day], from: now)
        return (nowMs(), -(TimeZone.current.secondsFromGMT(for: now) / 60), c.year ?? 2026, (c.month ?? 1) - 1, c.day ?? 1)
    }
    private func homeBody() -> String {
        let e = env()
        let key = active >= 0 ? HomeModel.keys[active] : ""
        var d = "{}"
        if active >= 0 {
            let b = busRaw[active].map { ["n": str($0["nodenm"]).isEmpty ? str($0["nodeName"]) : str($0["nodenm"]), "d": pf($0["dist"])] as [String: Any] }
            let p = placeRaw[active].map { ["n": str($0["place_name"]), "a": str($0["road_address_name"]).isEmpty ? str($0["address_name"]) : str($0["road_address_name"])] as [String: Any] }
            d = Json.text(["b": b, "p": p])
        }
        return "{\"cap\":\(Servers.cap),\"f\":{\"start\":\(Json.q(text[0])),\"dest\":\(Json.q(text[1])),\"active\":\(Json.q(key)),"
            + "\"startSet\":\(loc[0] != nil),\"destSet\":\(loc[1] != nil),\"gps\":\(gps),\"rs\":\(routing),"
            + "\"base\":{\"ms\":\(baseMs >= 0 ? String(baseMs) : "null"),\"tzo\":\(e.tzo),\"today\":[\(e.y),\(e.m),\(e.d)],\"now\":\(e.ms)}},\"d\":\(d)}"
    }
    private func resultFacts() -> String? {
        guard hasRoute else { return nil }
        let e = env()
        var f = "{\"data\":\(routeRaw),\"tab\":\(Json.q(resTab)),\"a\":\(Json.q(resA)),\"b\":\(Json.q(resB)),\"bt\":\(resBt >= 0 ? String(resBt) : "null"),\"rb\":\(resRb)"
        if let d = loc[1], d.ok { f += ",\"dl\":{\"la\":\(d.lat),\"lo\":\(d.lng),\"n\":\(Json.q(d.name))}" }
        if let s = loc[0], s.ok { f += ",\"me\":[\(s.lat),\(s.lng)]" }
        f += ",\"now\":\(e.ms),\"tz\":\(-e.tzo),\"th\":\"dark\",\"fav\":1"
        if riding { f += ",\"ride\":\(RideLoop.shared.rideJson)" + (RideLoop.shared.lvJson.count > 2 ? ",\"lv\":\(RideLoop.shared.lvJson)" : "") }
        return f + "}"
    }
    private func resultBody() -> String? {
        guard let f = resultFacts() else { return nil }
        return "{\"cap\":\(Servers.cap),\"r\":\(f)}"
    }
    // 세부경로 시트(안드로이드 openDetailSheet): 같은 사실에 view:detail 과 펼친 구간 번호를 실어 묻는다
    @Published var showDetail = false
    @Published var detail: Screen? = nil
    private var detOpen = Set<Int>()
    private var navKakao: [String]? = nil, navNaver: [String]? = nil
    /// 카카오맵 · 네이버지도 길찾기 앱을 열고, 앱이 없으면 웹 주소로(안드로이드 openNav). 허용된 앱 주소 모양만 연다.
    private func openNav(_ u: [String]?, host: Host) {
        guard let u = u else { return }
        let okApp = u[0].count < 1024 && !u[0].contains(" ") && (u[0].hasPrefix("kakaomap://route?") || u[0].hasPrefix("nmap://route/public?") || u[0].hasPrefix("nmap://route/walk?"))
        let web = URL(string: u[1]).flatMap { $0.scheme == "https" ? $0 : nil }
        if okApp, let app = URL(string: u[0]) {
            UIApplication.shared.open(app, options: [:]) { ok in if !ok, let w = web { UIApplication.shared.open(w) } }
        } else if let w = web { UIApplication.shared.open(w) }
    }
    func openDetail() { detOpen = []; detail = nil; showDetail = true; Task { await loadDetail() } }
    func closeDetail() { showDetail = false }
    func loadDetail() async {
        guard let f = resultFacts() else { return }
        // view · open 은 r 안에 들어간다(안드로이드 HomeCore.detailRequest 와 같다)
        let body = "{\"cap\":\(Servers.cap),\"r\":\(f.dropLast()),\"view\":\"detail\",\"open\":[\(detOpen.sorted().map(String.init).joined(separator: ","))]}}"
        if let d = try? await Net.request("POST", Servers.base + "/screen/result", body: body, timeout: 16), let s = try? Screen.parse(d) {
            detail = s
            let nav = (s.raw["info"] as? [String: Any])?["nav"] as? [String: Any]
            func pair(_ o: Any?) -> [String]? { if let a = o as? [String], a.count == 2 { return a }; return nil }
            navKakao = pair(nav?["kakao"]); navNaver = pair(nav?["naver"])
        }
    }
    private func detailAct(_ v: String, host: Host) {
        if v == "rd.close" { closeDetail() }
        else if v == "rd.confirm" { confirm(host: host) }
        else if v == "rd.kakao" { openNav(navKakao, host: host) }
        else if v == "rd.naver" { openNav(navNaver, host: host) }
        else if v.hasPrefix("rd.tg."), let i = Int(v.dropFirst(6)), i >= 0, i < 40 {
            if detOpen.contains(i) { detOpen.remove(i) } else { detOpen.insert(i) }
            Task { await loadDetail() }
        } else { host.say("이 기능은 다음 단계에서 연결돼요") }
    }

    private func str(_ o: Any?) -> String {
        if let s = o as? String { return s }
        if let n = o as? NSNumber { let d = n.doubleValue; return d == d.rounded() && abs(d) < 1e15 ? String(Int64(d)) : String(d) }
        return ""
    }
    private func pf(_ o: Any?) -> Double {
        if let n = o as? NSNumber { return n.doubleValue }
        if let s = o as? String { return Double(s.trimmingCharacters(in: .whitespaces)) ?? 0 }
        return 0
    }

    // MARK: 화면 받기
    func load() async {
        seq += 1; let my = seq
        if aiNextAt == 0 { aiNextAt = nowMs() + 5 * 60 * 1000 }
        let hb = homeBody(), rb = resultBody()
        let ck = hcKeyNow(), cb: String? = ck == hcKey ? nil : hcardsBody()
        async let hd: Data? = try? await Net.request("POST", Servers.base + "/screen/home", body: hb, timeout: 10)
        async let rd: Data? = rb == nil ? nil : (try? await Net.request("POST", Servers.base + "/screen/result", body: rb, timeout: 16))
        async let cd: Data? = cb == nil ? nil : (try? await Net.request("POST", Servers.base + "/screen/hcards", body: cb, timeout: 15))
        let (h, r, c) = await (hd, rd, cd)
        if my != seq { return }
        if cb != nil, let c = c, Json.isObject(c) { hcKey = ck; hcData = c }
        guard let h = h else { if screen == nil { error = "홈 화면을 받지 못했어요" }; return }
        if let s = merged(h, [r, hcData]) { screen = s; error = nil; readInfo(h) }
        else { error = "홈 화면을 읽지 못했어요" }
    }

    /// 홈 화면 아래에 결과 화면의 본문을 이어 붙인다(안드로이드 ShellCore.mergeBodies).
    private func merged(_ h: Data, _ rs: [Data?]) -> Screen? {
        guard var ho = (try? JSONSerialization.jsonObject(with: h)) as? [String: Any], var body = ho["body"] as? [[String: Any]] else { return try? Screen.parse(h) }
        for r in rs {
            guard let r = r, let ro = (try? JSONSerialization.jsonObject(with: r)) as? [String: Any], (ro["ok"] as? Bool) != false,
                  let rbody = ro["body"] as? [[String: Any]] else { continue }
            body += rbody
            if ho["sw"] == nil, let sw = ro["sw"] { ho["sw"] = sw }
        }
        ho["body"] = body
        guard let d = try? JSONSerialization.data(withJSONObject: ho) else { return try? Screen.parse(h) }
        return try? Screen.parse(d)
    }

    private func readInfo(_ h: Data) {
        pkU = []
        guard let o = (try? JSONSerialization.jsonObject(with: h)) as? [String: Any], let info = o["info"] as? [String: Any],
              let pk = info["pk"] as? [String: Any], let u = pk["u"] as? [[String: Any]] else { return }
        pkU = u.map { HLoc(type: "subway", name: str($0["name"]), line: str($0["line"]), qname: "", lat: pf($0["lat"]), lng: pf($0["lng"])) }
    }

    func reloadSoon(_ ms: UInt64 = 0) {
        pending?.cancel()
        pending = Task { if ms > 0 { try? await Task.sleep(nanoseconds: ms * 1_000_000) }; if !Task.isCancelled { await load() } }
    }

    // MARK: 입력 · 후보
    /// 입력칸 글자가 바뀜 — 직접 친 글자는 아직 '고른 장소'가 아니다(글을 고치면 고른 장소가 풀린다).
    func typed(_ key: String, _ v: String) {
        guard let f = HomeModel.keys.firstIndex(of: key) else { return }
        if v == text[f] && active == f { return }
        if v != text[f] { text[f] = v; loc[f] = nil }
        active = f; last = f
        let q = norm(text[f])
        if q != candQ[f] { candQ[f] = q; busRaw[f] = []; placeRaw[f] = [] }
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            await load()                                   // 지하철 후보는 엔진이 바로 거른다
            await fetchCands(f)                            // 버스 · 장소 후보는 받아 와서 한 번 더
        }
    }

    private func norm(_ s: String) -> String { let t = s.trimmingCharacters(in: .whitespacesAndNewlines); return String(t.prefix(60)) }
    private func enc(_ s: String) -> String {
        var cs = CharacterSet.alphanumerics; cs.insert(charactersIn: "-_.!~*'()")
        return s.addingPercentEncoding(withAllowedCharacters: cs) ?? s
    }
    private func suggest(_ kind: String, _ q: String, direct: String) async -> Data? {
        if let d = try? await Net.request("GET", Servers.base + "/suggest?k=\(kind)&q=\(enc(q))", timeout: 5), !d.isEmpty { return d }
        return try? await Net.request("GET", direct, timeout: 6)
    }
    private func fetchCands(_ f: Int) async {
        let q = norm(text[f])
        guard q.count >= 2, q != fetchedQ[f] else { return }
        fetchedQ[f] = q
        let busDirect = Servers.bus + "/tago?url=" + enc("https://apis.data.go.kr/1613000/BusSttnInfoInqireService/getSttnNoList?serviceKey=&nodeNm=\(enc(q))&_type=json")
        let placeDirect = Servers.news + "/kakao-local?path=" + enc("search/keyword.json") + "&qs=" + enc("query=\(enc(q))&size=5")
        async let bd = suggest("b", q, direct: busDirect)
        async let pd = suggest("p", q, direct: placeDirect)
        let (b, p) = await (bd, pd)
        guard norm(text[f]) == q else { return }          // 그 사이 글이 바뀌었으면 버린다
        busRaw[f] = parseBus(b); placeRaw[f] = parsePlaces(p)
        if !busRaw[f].isEmpty || !placeRaw[f].isEmpty { await load() }
    }
    private func parseBus(_ d: Data?) -> [[String: Any]] {
        guard let d = d, let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
              let items = (((o["response"] as? [String: Any])?["body"] as? [String: Any])?["items"]) as? [String: Any] else { return [] }
        let it = items["item"]
        let l: [[String: Any]] = (it as? [[String: Any]]) ?? ((it as? [String: Any]).map { [$0] } ?? [])
        return Array(l.prefix(5))
    }
    private func parsePlaces(_ d: Data?) -> [[String: Any]] {
        guard let d = d, let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any], let docs = o["documents"] as? [[String: Any]] else { return [] }
        return Array(docs.filter { pf($0["x"]) != 0 && pf($0["y"]) != 0 }.prefix(5))
    }

    /// 후보 고르기(kind u 지하철 · b 버스정류장 · p 장소) — 안드로이드 HomeCore.choose.
    private func choose(_ kind: Character, _ idx: Int) -> Bool {
        let f = active >= 0 ? active : last
        var l = HLoc()
        if kind == "u" {
            guard idx >= 0, idx < pkU.count, !pkU[idx].name.isEmpty else { return false }
            l = pkU[idx]
        } else if kind == "b" {
            guard idx >= 0, idx < busRaw[f].count else { return false }
            let s = busRaw[f][idx]
            l.type = "bus"; l.name = str(s["nodenm"]).isEmpty ? str(s["nodeName"]) : str(s["nodenm"])
            l.lat = pf(s["gpslati"] ?? s["gpsLati"]); l.lng = pf(s["gpslong"] ?? s["gpsLong"])
        } else if kind == "p" {
            guard idx >= 0, idx < placeRaw[f].count else { return false }
            let s = placeRaw[f][idx]
            l.type = "address"; l.name = str(s["place_name"]); l.lat = pf(s["y"]); l.lng = pf(s["x"])
        } else { return false }
        if l.name.isEmpty { return false }
        text[f] = l.name; loc[f] = l
        candQ[f] = l.name; fetchedQ[f] = l.name; busRaw[f] = []; placeRaw[f] = []
        pkU = []; active = -1
        return true
    }

    // MARK: 눌림
    func call(_ v: String, host: Host) {
        if v == "ai.refresh" { aiNextAt = nowMs() + 5 * 60 * 1000; aiRnd = Double.random(in: 0..<1); hcKey = ""; reloadSoon(); return }
        if v == "tk.open" { host.tab = "community"; return }
        if v == "tk.send" || v == "share.loc" { host.say("이 기능은 다음 단계에서 연결돼요"); return }
        if v.hasPrefix("rh.") { result(v, host: host); return }
        if v.hasPrefix("rd.") { detailAct(v, host: host); return }
        if v.hasPrefix("sg."), v.count > 5 {
            let a = Array(v)
            guard a[4] == ".", let idx = Int(String(a[5...])) else { return }
            if choose(a[3], idx) {
                reloadSoon()
                if loc[0]?.ok == true && loc[1]?.ok == true { Task { await goRoute(host: host) } }      // 두 곳이 다 정해지면 [경로 탐색]을 안 눌러도 바로 찾는다
            }
            return
        }
        switch v {
        case "rt.swap":
            text.swapAt(0, 1); loc.swapAt(0, 1)
            busRaw = [[], []]; placeRaw = [[], []]; candQ = [norm(text[0]), norm(text[1])]; fetchedQ = candQ; pkU = []; active = -1
            reloadSoon()
        case "rt.gps":
            if gps { return }
            Task { await detectGps(host: host) }
        case "rt.go", "rt.enter":
            if text[0].trimmingCharacters(in: .whitespaces).isEmpty || text[1].trimmingCharacters(in: .whitespaces).isEmpty {
                if v == "rt.go" { host.say("출발지와 도착지를 입력해 주세요") }
                return
            }
            active = -1
            Task { await goRoute(host: host) }
        case "bt.pick":
            if riding { host.say("탑승 안내 중에는 바꿀 수 없어요"); return }
            pickDate = baseMs >= 0 ? Date(timeIntervalSince1970: Double(baseMs) / 1000) : Date()
            showTimePick = true
        case "bt.now":
            baseMs = -1
            reloadSoon()
        default: break
        }
    }

    private func detectGps(host: Host) async {
        let store = LocationStore.shared
        if store.last == nil {
            store.start(); gps = true; await load()
            for _ in 0..<16 { if store.last != nil { break }; try? await Task.sleep(nanoseconds: 500_000_000) }
            gps = false
            if store.last == nil { host.say("위치를 알아내지 못했어요. 위치 권한을 확인해 주세요"); await load(); return }
        }
        guard let l = store.last else { return }
        var p = HLoc(type: "gps", name: "내 위치", line: "", qname: "내 위치", lat: l.coordinate.latitude, lng: l.coordinate.longitude)
        p.qname = "내 위치"
        loc[0] = p; text[0] = "내 위치"; candQ[0] = "내 위치"; fetchedQ[0] = "내 위치"; pkU = []
        if active == 0 { active = -1 }
        await load()
        if loc[1]?.ok == true { await goRoute(host: host) }
    }

    // MARK: 경로 찾기
    private func num(_ v: Double) -> String { v == v.rounded() && abs(v) < 1e15 ? String(Int64(v)) : String(v) }
    private func goRoute(host: Host) async {
        guard let s = loc[0], let d = loc[1], s.ok, d.ok else { host.say("출발지와 도착지를 목록에서 골라 주세요"); return }
        let picked = baseMs >= 0
        let base = picked ? baseMs : nowMs()
        let qs = "SX=\(num(s.lng))&SY=\(num(s.lat))&EX=\(num(d.lng))&EY=\(num(d.lat))&baseMs=\(base)" + (picked ? "&bf=1" : "")
            + "&SN=\(enc(String((s.qname.isEmpty ? s.name : s.qname).prefix(60))))&EN=\(enc(String((d.qname.isEmpty ? d.name : d.qname).prefix(60))))"
        seqRoute += 1; let my = seqRoute
        routing = true; await load()
        let data = try? await Net.request("GET", Servers.base + "/route-v2-app?" + qs, timeout: 30)
        guard my == seqRoute else { return }
        routing = false
        guard let data = data, let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              raw.count > 2, raw.hasPrefix("{"), raw.hasSuffix("}") else {
            host.say("경로를 찾지 못했어요. 잠시 뒤에 다시 해 주세요"); await load(); return
        }
        routeRaw = raw; resTab = "fast"; resA = s.qname.isEmpty ? text[0] : s.qname; resB = text[1]; resRb = base; resBt = picked ? baseMs : -1
        await load()
    }

    /// 결과 화면의 눌림(rh.*): 탭 바꾸기 · 닫기만 이번 단계. 확정 · 세부경로 · 즐겨찾기 · 안내 종료는 다음 단계.
    private func result(_ v: String, host: Host) {
        if v.hasPrefix("rh.tab.") { resTab = String(v.dropFirst(7)); reloadSoon() }
        else if v == "rh.close" { routeRaw = ""; reloadSoon() }
        else if v == "rh.detail" { openDetail() }
        else if v == "rh.confirm" { confirm(host: host) }
        else if v == "rh.stop" { stopRide(host: host) }
        else if v == "rh.slot" { slot(host: host) }
        else { host.say("이 기능은 다음 단계에서 연결돼요") }
    }

    /// 시각 시트의 [확인]: 고른 시각(초는 0)으로 두고, 결과를 보는 중이면 그 시각으로 다시 찾는다.
    func commitBase(host: Host) {
        let t = floor(pickDate.timeIntervalSince1970 / 60) * 60
        baseMs = Int64(t * 1000); showTimePick = false
        if hasRoute, loc[0]?.ok == true, loc[1]?.ok == true { Task { await goRoute(host: host) } } else { reloadSoon() }
    }

    // MARK: 경로 확정 · 탑승 안내 (안드로이드 ShellActivity.startRide / rideCommit)
    private func startBody(_ facts: String, pickMs: Int64 = 0, pickNo: String = "") -> String {
        var f = facts
        if pickMs > 0 { f = String(f.dropLast()) + ",\"pick\":{\"ms\":\(pickMs)" + (pickNo.isEmpty ? "" : ",\"no\":\(Json.q(pickNo))") + "}}" }
        return "{\"cap\":\(Servers.cap),\"r\":\(f)}"
    }
    func confirm(host: Host) {
        guard hasRoute, !riding, !confirming, let facts = resultFacts() else { return }
        confirming = true
        let my = seqRoute
        LocationStore.shared.start()
        host.say("탑승 안내를 준비하고 있어요")
        Task {
            let body = startBody(facts)
            // 첫 구간이 버스면 고를 차가 있는지(/ride/buspick)를 시작 요청과 동시에 묻는다 — 기다림을 늘리지 않는다
            async let st = try? Net.request("POST", Servers.base + "/ride/start", body: body, timeout: 12)
            async let pk = try? Net.request("POST", Servers.base + "/ride/buspick", body: body, timeout: 6)
            let (sd, pd) = await (st, pk)
            confirming = false
            guard my == seqRoute, hasRoute else { return }
            let txt = sd.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            if !txt.isEmpty, let pd = pd, let o = Json.obj(pd) as? [String: Any] {
                var ms: [Int64] = [], no: [String] = []
                if let items = (o["info"] as? [String: Any])?["items"] as? [[String: Any]] {
                    for x in items { if let m = (x["ms"] as? NSNumber)?.int64Value { ms.append(m); no.append(x["no"].map { "\($0)" } ?? "") } }
                }
                if (o["ask"] as? Bool) != true, let a = o["auto"] as? [String: Any], let am = (a["ms"] as? NSNumber)?.int64Value, am > 0 {
                    await startPicked(startBody(facts, pickMs: am, pickNo: a["no"].map { "\($0)" } ?? ""), seq: my, host: host); return      // 오는 버스가 하나뿐 — 묻지 않고 그 버스로
                }
                if (o["ask"] as? Bool) == true, !ms.isEmpty, (o["dlg"] as? [String: Any]) != nil, let sc = try? Screen.parse(pd) {
                    pickCtx = (facts, ms, no, txt, my); dlg = sc; return                // 탈 버스 고르기 카드
                }
            }
            commit(txt, seq: my, host: host)
        }
    }
    /// 카드의 눌림: dl.bp.N → N 번째 버스로 다시 시작 · dl.ok → 경로 시각대로 시작 · 그 밖(dl.close · 바깥)은 취소.
    func dlgAct(_ v: String, host: Host) {
        guard let c = pickCtx else { dlg = nil; return }
        dlg = nil; pickCtx = nil
        if v.hasPrefix("dl.bp."), let i = Int(v.dropFirst(6)), i >= 0, i < c.ms.count {
            Task { await startPicked(startBody(c.facts, pickMs: c.ms[i], pickNo: c.no[i]), seq: c.seq, host: host) }
        } else if v == "dl.ok" { commit(c.startTxt, seq: c.seq, host: host) }
        else { host.say("탑승 안내를 시작하지 않았어요") }
    }
    private func startPicked(_ body: String, seq my: Int, host: Host) async {
        host.say("고른 버스로 탑승 안내를 준비하고 있어요")
        let d = try? await Net.request("POST", Servers.base + "/ride/start", body: body, timeout: 12)
        commit(d.flatMap { String(data: $0, encoding: .utf8) } ?? "", seq: my, host: host)
    }
    /// 엔진이 만든 탑승 state(/ride/start 응답 {ok, state, text})를 받아 안내 루프를 켠다.
    private func commit(_ txt: String, seq my: Int, host: Host) {
        guard my == seqRoute, hasRoute, !riding else { return }
        guard !txt.isEmpty, let o = Json.obj(Data(txt.utf8)) as? [String: Any], (o["ok"] as? Bool) == true, let st = o["state"] as? [String: Any] else {
            let msg = ((Json.obj(Data(txt.utf8)) as? [String: Any])?["msg"] as? String) ?? ""
            host.say(msg.isEmpty ? "탑승 안내를 시작하지 못했어요" : msg); return
        }
        rideSeq = my
        RideLoop.shared.start(stateJson: Json.text(st), text: (o["text"] as? String) ?? "")
        host.say("\(optName(resTab)) 경로로 확정했어요")
        if showDetail { closeDetail() }
        reloadSoon()
    }
    private func optName(_ t: String) -> String { ["fast": "최단시간", "less": "최소환승", "cheap": "최저요금", "walk": "최소도보", "comfort": "편한"][t] ?? "선택한" }
    /// 안내 종료 = 여정 종료 — 도착지를 넣기 전 첫 홈 화면으로(안드로이드 stopRide / endJourney).
    private func stopRide(host: Host) {
        RideLoop.shared.stop()
        rideSeq = -1; routeRaw = ""; text = ["", ""]; loc = [nil, nil]; active = -1
        busRaw = [[], []]; placeRaw = [[], []]; candQ = ["", ""]; fetchedQ = ["", ""]; pkU = []
        reloadSoon()
        host.say("여정을 끝냈어요. 새 도착지를 넣어 주세요")
    }
    /// 버튼 줄 오른쪽 칸: 도착 = 안내 종료 · 탑승/환승 = 엔진에 눌렀다고 알린다(누를 수 있을 때만).
    private func slot(host: Host) {
        guard riding else { return }
        let r = RideLoop.shared
        if r.rowSlot == "arrive" { stopRide(host: host) }
        else if r.rowSlot == "board" || r.rowSlot == "transfer" {
            if r.rowCan { r.press() } else { host.say("앞 구간을 내린 뒤에 눌러 주세요") }
        }
    }
}

struct HomeTab: View {
    let pal: Palette
    @StateObject private var m = HomeModel()
    @EnvironmentObject var host: Host
    var body: some View {
        ZStack {
            if let s = m.screen { ScreenBody(screen: s, pal: pal) }
            else { (pal.color("bg") ?? Color(.systemBackground)).ignoresSafeArea(); ProgressView() }
            if let e = m.error, m.screen == nil { Text(e).font(Typo.font(12)).foregroundColor(pal.color("sub") ?? .gray) }
            if m.showDetail { DetailSheet(m: m, pal: pal) }
            if m.showTimePick { TimePickCard(m: m, pal: pal) { m.commitBase(host: host) } }
            if let d = m.dlg { DlgCard(screen: d, pal: pal) { m.dlgAct($0, host: host) } }
        }
        .task { LocationStore.shared.start(); await m.load(); await m.startDemo(host: host) }
        .task { while !Task.isCancelled { try? await Task.sleep(nanoseconds: 30_000_000_000); m.tick() } }
        .onReceive(host.actPublisher) { x in
            guard x.tab == "home" else { return }
            if x.a == "input" { m.typed(x.key, x.v) } else if x.a == "call" { if x.v.hasPrefix("dl.") { m.dlgAct(x.v, host: host) } else { m.call(x.v, host: host) } }
        }
        .onChange(of: host.reloadTick) { _ in Task { await m.load() } }
    }
}

/// 세부경로 시트: 바깥은 0.82 어둡게(누르면 닫힘) · 카드색 바탕 · 위쪽 모서리 20 · 위에서 10 띄움 · 폭 최대 520. (웹 transitDetail)
struct DetailSheet: View {
    @ObservedObject var m: HomeModel
    let pal: Palette
    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.82).ignoresSafeArea().onTapGesture { m.closeDetail() }
            Group {
                if let s = m.detail { ScreenBody(screen: s, pal: pal) }
                else { ZStack { (pal.color("card") ?? .black); Text("경로를 불러오는 중...").font(Typo.font(13)).foregroundColor(pal.color("sub") ?? .gray) } }
            }
            .frame(maxWidth: 520).frame(maxHeight: .infinity)
            .background(pal.color("card") ?? .black)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
            .padding(.top, 10)
        }
        .transition(.move(edge: .bottom))
    }
}


/// 엔진이 만든 안내창(screen.dlg): 흐린 바탕 + 가운데 카드. 너비 w(최대 화면-2·mx) · 높이 최대 maxh · 모서리 r · 흐림 dim. 바깥을 누르면 dl.close.
struct DlgCard: View {
    let screen: Screen
    let pal: Palette
    let act: (String) -> Void
    @StateObject private var open = PostOpen()
    private var d: [String: Any] { screen.raw["dlg"] as? [String: Any] ?? [:] }
    private func n(_ k: String, _ def: Double, _ lo: Double, _ hi: Double) -> Double { min(hi, max(lo, (d[k] as? NSNumber)?.doubleValue ?? def)) }
    var body: some View {
        GeometryReader { g in
            let w = min(n("w", 320, 120, 480), g.size.width - 2 * n("mx", 16, 0, 80))
            ZStack {
                Color.black.opacity(n("dim", 0.5, 0, 0.85)).ignoresSafeArea().onTapGesture { act("dl.close") }
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(screen.head) { NodeView(node: $0, pal: pal) }
                        ForEach(screen.body) { NodeView(node: $0, pal: pal) }
                        ForEach(screen.foot) { NodeView(node: $0, pal: pal) }
                    }
                }
                .environmentObject(open)
                .frame(width: w).frame(maxHeight: g.size.height * n("maxh", 0.85, 0.3, 0.95))
                .fixedSize(horizontal: false, vertical: true)
                    .background(pal.color((d["fill"] as? String) ?? "") ?? pal.color("card") ?? .black)
                    .clipShape(RoundedRectangle(cornerRadius: n("r", 16, 0, 40)))
                    .position(x: g.size.width / 2, y: g.size.height * n("top", 0.5, 0.1, 0.9))
            }
        }
    }
}


/// 기준시각 고르기: 날짜 + 시각 한 장(안드로이드는 날짜 → 시각 두 번). 바깥을 누르면 닫는다.
struct TimePickCard: View {
    @ObservedObject var m: HomeModel
    let pal: Palette
    let ok: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { m.showTimePick = false }
            VStack(spacing: 8) {
                Text("기준시각").font(Typo.font(15, bold: true)).foregroundColor(pal.color("text") ?? .white).padding(.top, 14)
                DatePicker("", selection: $m.pickDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical).labelsHidden().environment(\.locale, Locale(identifier: "ko_KR"))
                    .tint(pal.color("gold") ?? .yellow).padding(.horizontal, 8)
                HStack(spacing: 10) {
                    Button { m.showTimePick = false } label: {
                        Text("취소").font(Typo.font(14, bold: true)).foregroundColor(pal.color("sub") ?? .gray).frame(maxWidth: .infinity).frame(height: 42)
                            .background(RoundedRectangle(cornerRadius: 12).fill(pal.color("card2") ?? .gray.opacity(0.3)))
                    }.buttonStyle(.plain)
                    Button(action: ok) {
                        Text("확인").font(Typo.font(14, bold: true)).foregroundColor(Color(hex: 0x121214)).frame(maxWidth: .infinity).frame(height: 42)
                            .background(RoundedRectangle(cornerRadius: 12).fill(pal.color("gold") ?? .yellow))
                    }.buttonStyle(.plain)
                }.padding(.horizontal, 16).padding(.bottom, 14)
            }
            .frame(maxWidth: 340)
            .background(RoundedRectangle(cornerRadius: 20).fill(pal.color("card") ?? .black))
            .padding(.horizontal, 16)
        }
    }
}
