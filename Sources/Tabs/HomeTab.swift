import SwiftUI

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
    private var resRb: Int64 = 0
    private var hasRoute: Bool { routeRaw.count > 2 }
    private var seq = 0, seqRoute = 0
    private var pending: Task<Void, Never>? = nil

    /// 화면 확인용 실행 인자: -homeDest 명동 → 도착지 칸에 글자를 넣고 시작 · -homeRoute 1 → 서울역→명동 경로까지 자동으로 찾는다
    var demoRoute = false
    init() {
        if let d = UserDefaults.standard.string(forKey: "homeDest"), !d.isEmpty { text[1] = d; active = 1; last = 1; candQ[1] = d }
        if UserDefaults.standard.string(forKey: "homeRoute") == "1" {
            loc[0] = HLoc(type: "subway", name: "서울역", line: "1호선", qname: "", lat: 37.5547, lng: 126.9707); text[0] = "서울역"
            loc[1] = HLoc(type: "subway", name: "명동", line: "4호선", qname: "", lat: 37.5609, lng: 126.9863); text[1] = "명동"
            demoRoute = true
        }
    }
    func startDemo(host: Host) async { if demoRoute { demoRoute = false; await goRoute(host: host) } }

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
            + "\"base\":{\"ms\":null,\"tzo\":\(e.tzo),\"today\":[\(e.y),\(e.m),\(e.d)],\"now\":\(e.ms)}},\"d\":\(d)}"
    }
    private func resultBody() -> String? {
        guard hasRoute else { return nil }
        let e = env()
        var f = "{\"data\":\(routeRaw),\"tab\":\(Json.q(resTab)),\"a\":\(Json.q(resA)),\"b\":\(Json.q(resB)),\"bt\":null,\"rb\":\(resRb)"
        if let d = loc[1], d.ok { f += ",\"dl\":{\"la\":\(d.lat),\"lo\":\(d.lng),\"n\":\(Json.q(d.name))}" }
        if let s = loc[0], s.ok { f += ",\"me\":[\(s.lat),\(s.lng)]" }
        f += ",\"now\":\(e.ms),\"tz\":\(-e.tzo),\"th\":\"dark\",\"fav\":1}"
        return "{\"cap\":\(Servers.cap),\"r\":\(f)}"
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
        let hb = homeBody(), rb = resultBody()
        async let hd: Data? = try? await Net.request("POST", Servers.base + "/screen/home", body: hb, timeout: 10)
        async let rd: Data? = rb == nil ? nil : (try? await Net.request("POST", Servers.base + "/screen/result", body: rb, timeout: 16))
        let (h, r) = await (hd, rd)
        if my != seq { return }
        guard let h = h else { if screen == nil { error = "홈 화면을 받지 못했어요" }; return }
        if let s = merged(h, r) { screen = s; error = nil; readInfo(h) }
        else { error = "홈 화면을 읽지 못했어요" }
    }

    /// 홈 화면 아래에 결과 화면의 본문을 이어 붙인다(안드로이드 ShellCore.mergeBodies).
    private func merged(_ h: Data, _ r: Data?) -> Screen? {
        guard let r = r, var ho = (try? JSONSerialization.jsonObject(with: h)) as? [String: Any],
              let ro = (try? JSONSerialization.jsonObject(with: r)) as? [String: Any],
              (ro["ok"] as? Bool) != false,
              let hbody = ho["body"] as? [[String: Any]], let rbody = ro["body"] as? [[String: Any]] else { return try? Screen.parse(h) }
        ho["body"] = hbody + rbody
        if ho["sw"] == nil, let sw = ro["sw"] { ho["sw"] = sw }
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
        if v.hasPrefix("rh.") { result(v, host: host); return }
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
        case "bt.pick", "bt.now":
            host.say("기준시각 고르기는 다음 단계에서 연결돼요")
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
        let base = nowMs()
        let qs = "SX=\(num(s.lng))&SY=\(num(s.lat))&EX=\(num(d.lng))&EY=\(num(d.lat))&baseMs=\(base)"
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
        routeRaw = raw; resTab = "fast"; resA = s.qname.isEmpty ? text[0] : s.qname; resB = text[1]; resRb = base
        await load()
    }

    /// 결과 화면의 눌림(rh.*): 탭 바꾸기 · 닫기만 이번 단계. 확정 · 세부경로 · 즐겨찾기 · 안내 종료는 다음 단계.
    private func result(_ v: String, host: Host) {
        if v.hasPrefix("rh.tab.") { resTab = String(v.dropFirst(7)); reloadSoon() }
        else if v == "rh.close" { routeRaw = ""; reloadSoon() }
        else { host.say("이 기능은 다음 단계에서 연결돼요") }
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
        }
        .task { LocationStore.shared.start(); await m.load(); await m.startDemo(host: host) }
        .onReceive(host.actPublisher) { x in
            guard x.tab == "home" else { return }
            if x.a == "input" { m.typed(x.key, x.v) } else if x.a == "call" { m.call(x.v, host: host) }
        }
        .onChange(of: host.reloadTick) { _ in Task { await m.load() } }
    }
}
