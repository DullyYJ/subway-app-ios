import SwiftUI
import CoreLocation

/// 맛집 탭 — 안드로이드 FoodCore + ShellActivity 맛집 흐름과 같은 순서:
///  ① 위치만 알리고 엔진에 첫 화면을 묻는다(엔진이 중심 좌표를 info.ctr 로 정해 준다)
///  ② 그 중심으로 서버 가게(/food)와 공공데이터(공유 저장소 /food-pub → 없으면 공공 서버 3쪽)를 동시에 받는다
///  ③ 받은 원자료를 실어 엔진에 다시 묻고, 엔진이 칩(분류)마다 계산해 둔 화면(alts)을 눌렀을 때 바로 올린다.
/// 무엇을 어떻게 보일지(순서 · 문구 · 거리 · 중복 정리)는 모두 엔진이 정한다. 가게 상세 시트 · 지도 펼침은 다음 단계.
@MainActor
final class FoodModel: ObservableObject {
    @Published var screen: Screen? = nil
    @Published var error: String? = nil
    private var flt = "전체"
    private var loaded = false, failed = false
    private var srv: [Any] = [], pub: [Any] = []
    private var ctr: (Double, Double)? = nil
    private var alts: [String: [String: Any]] = [:]
    private var loadedAt = Date.distantPast
    private var gen = 0
    // 가게 지도 펼침(안드로이드 FoodCore.panel*): 무엇을 그릴지는 엔진이 정하고, 앱은 그 노드를 목록의 그 카드 뒤에 끼우기만 한다.
    private var cur: [String: Any]? = nil                  // 지금 보이는 목록 화면(펼침 없는 원본)
    private var go: [String: [Any]] = [:]                   // 눌림 번호표(info.go) — 옛 엔진 대비
    private var altGo: [String: [String: [Any]]] = [:]
    private var stnName = ""
    private var openKey = "", panelAfter = ""
    private var panelNodes: [[String: Any]]? = nil
    private var panelRes: [String: String] = [:]
    private var pendingSel: [String: Any] = [:]
    private var selName = "", selLa = 0.0, selLo = 0.0
    private var nvApp: [String: String] = [:], nvWeb: [String: String] = [:]
    private var seqPanel = 0
    @Published var revealKey: String? = nil
    private static let ttl: TimeInterval = 600

    private var gps: CLLocation? { LocationStore.shared.last }
    private var needData: Bool { ctr != nil && (!loaded || Date().timeIntervalSince(loadedAt) > Self.ttl) }
    private var state: String {
        if gps == nil {
            switch LocationStore.shared.status {
            case .denied, .restricted: return "noperm"
            case .notDetermined: return "idle"
            default: return "locating"
            }
        }
        return loaded ? "done" : "loading"
    }

    func invalidate() { loaded = false; failed = false; alts = [:]; srv = []; pub = []; ctr = nil }

    func load(force: Bool = false) async {
        if force { invalidate() }
        gen += 1; let my = gen
        guard let r1 = await post() else { if my == gen && screen == nil { error = "맛집 화면을 받지 못했어요" }; return }
        guard my == gen else { return }
        apply(r1)
        if needData { await fetchData(my) }
    }

    /// 위치가 처음 잡혔거나 크게 바뀌었을 때 다시 묻는다.
    func gpsChanged() async { if screen == nil || ctr == nil || state == "locating" { await load() } }

    func pick(_ chip: String) async {
        closePanel()
        flt = chip.isEmpty ? "전체" : chip
        if let g = altGo[flt] { go = g }
        if let a = alts[flt] { cur = a; redraw(); return }
        if let r = await post() { apply(r) }
    }

    // ── 요청 ──
    private func ll(_ l: CLLocation?) -> Any { l == nil ? NSNull() : [l!.coordinate.latitude, l!.coordinate.longitude] }
    private func post() async -> Screen? {
        var f: [String: Any] = ["stn": "", "st": loaded ? "done" : state, "flt": flt, "fail": failed ? 1 : 0, "gps": ll(gps), "dl": NSNull()]
        f["stn"] = ""
        var body: [String: Any] = ["cap": Servers.cap, "f": f]
        if loaded { body["s"] = srv; body["u"] = pub }
        body["alts"] = "chips"
        do { return try await Net.screen("/screen/food", body: Json.text(body)) } catch { return nil }
    }

    private func apply(_ s: Screen) {
        error = nil
        cur = s.raw
        if let info = s.raw["info"] as? [String: Any] {
            if let c = info["ctr"] as? [Any], c.count == 2, let la = (c[0] as? NSNumber)?.doubleValue, let lo = (c[1] as? NSNumber)?.doubleValue { ctr = (la, lo) }
            if let g = info["go"] as? [String: Any] { go = g.compactMapValues { $0 as? [Any] } }
            if let st = info["stn"] as? String { stnName = String(st.prefix(30)) }
        }
        if let a = s.raw["alts"] as? [String: Any] {
            alts = a.compactMapValues { $0 as? [String: Any] }
            altGo = alts.mapValues { (($0["info"] as? [String: Any])?["go"] as? [String: Any])?.compactMapValues { $0 as? [Any] } ?? [:] }
        }
        redraw()
    }
    private var autoDone = false
    /// 확인용(-foodOpen): 목록의 첫 가게를 자동으로 펼친다.
    func autoOpen(host: Host) {
        guard !autoDone, CommandLine.arguments.contains("-foodOpen"), let body = cur?["body"] as? [[String: Any]],
              let v = body.compactMap({ ($0["act"] as? [String: Any])?["v"] as? String }).first(where: { $0.hasPrefix("fm.c.") || $0.hasPrefix("fm.p.") }) else { return }
        autoDone = true
        act(Host.TabAction(tab: "food", a: "call", v: v, id: "", key: ""), host: host)
    }
    /// 목록 화면에 펼침을 끼워 올린다(그 카드가 목록에 없으면 펼침 없이).
    private func redraw() {
        guard var d = cur else { return }
        if !openKey.isEmpty, let pn = panelNodes, var body = d["body"] as? [[String: Any]],
           let at = body.firstIndex(where: { (($0["act"] as? [String: Any])?["v"] as? String) == panelAfter }) {
            body.insert(contentsOf: pn, at: at + 1); d["body"] = body
            d["rev"] = ((d["rev"] as? String) ?? "") + "+" + openKey + ":" + String(pn.count)
        }
        if let sc = screenFrom(d) { screen = sc }
    }

    // ── 눌림 ──
    func act(_ x: Host.TabAction, host: Host) {
        if x.a == "refresh" { closePanel(); Task { await load(force: true) }; return }
        guard x.a == "call", x.v.hasPrefix("fm.") else { return }
        let k = String(x.v.dropFirst(3))
        if k == "close" { closePanel(); redraw(); return }
        if ["nr", "kr", "ni", "ki"].contains(k), !openKey.isEmpty { link(k, host: host); return }
        var l: [Any]? = nil
        if x.id.count >= 8, x.id.hasPrefix("["), let a = Json.obj(Data(x.id.utf8)) as? [Any], a.count >= 5, a[0] is String, a[3] is NSNumber, a[4] is NSNumber { l = a }
        if l == nil, let g = go[k], g.count >= 5 { l = g }
        guard let sel = l else { return }
        if k == openKey { if panelNodes == nil || panelSkel { return }; closePanel(); redraw(); return }       // 열려 있는 카드를 또 누르면 접는다
        pendingSel = ["n": sel[0], "c": sel[1], "a": sel[2], "la": sel[3], "lo": sel[4]]
        selName = sel[0] as? String ?? ""; selLa = (sel[3] as? NSNumber)?.doubleValue ?? 0; selLo = (sel[4] as? NSNumber)?.doubleValue ?? 0
        openKey = k; panelAfter = "fm." + k; panelNodes = nil; panelRes = [:]; nvApp = [:]; nvWeb = [:]
        panelNodes = [["t": "skel", "kind": "map", "rows": 2, "pad": [12, 6, 12, 10]]]; panelSkel = true
        redraw(); revealKey = openKey
        Task { await panelRound(host: host) }
    }
    private var panelSkel = false
    private func closePanel() { seqPanel += 1; panelSkel = false; openKey = ""; panelAfter = ""; panelNodes = nil; panelRes = [:]; nvApp = [:]; nvWeb = [:] }

    private func panelBody() -> String {
        var f: [String: Any] = ["pn": 1, "sel": pendingSel, "me": ll(gps), "ctr": ctr.map { [$0.0, $0.1] as [Double] } ?? NSNull(), "stn": stnName, "dst": 0]
        if !panelRes.isEmpty { f["res"] = panelRes }
        return Json.text(["cap": Servers.cap, "f": f] as [String: Any])
    }
    /// 펼침 요청 → 엔진이 더 받아 오라는 경로 주소(info.need)가 있으면 받아 와서 다시 묻는다(끝은 엔진이 정한다).
    private func panelRound(host: Host) async {
        seqPanel += 1; let my = seqPanel; let key = openKey
        let d = try? await Net.request("POST", Servers.base + "/screen/food", body: panelBody(), timeout: 8)
        guard my == seqPanel, key == openKey else { return }
        guard let d = d, let o = Json.obj(d) as? [String: Any], (o["ok"] as? Bool) == true, let body = o["body"] as? [[String: Any]], !body.isEmpty else {
            if panelNodes == nil || panelSkel { closePanel(); redraw(); host.say("가게 지도를 열지 못했어요") }
            return
        }
        panelNodes = body; panelSkel = false
        var need: [(String, String)] = []
        if let info = o["info"] as? [String: Any] {
            if let nv = info["nv"] as? [String: Any] {
                nvApp = [:]; nvWeb = [:]
                for (k, v) in nv { if let u = v as? [String: Any] { nvApp[k] = String((u["app"] as? String ?? "").prefix(1500)); nvWeb[k] = String((u["web"] as? String ?? "").prefix(1500)) } }
            }
            for x in (info["need"] as? [[String: Any]] ?? []) {
                let k = String((x["k"] as? String ?? "").prefix(8)), u = String((x["url"] as? String ?? "").prefix(1500))
                if !k.isEmpty, u.hasPrefix("https://"), panelRes[k] == nil { need.append((k, u)) }
            }
        }
        redraw()
        if need.isEmpty { return }
        for (k, u) in need {
            Task {
                let got = (try? await Net.request("GET", u, timeout: 9)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
                guard key == openKey else { return }
                panelRes[k] = got
                await panelRound(host: host)
            }
        }
    }

    // ── 외부 지도 앱 ──
    private func link(_ k: String, host: Host) {
        let key = ["nr": "nroute", "kr": "kroute", "ni": "ninfo", "ki": "kinfo"][k] ?? ""
        guard let app = nvApp[key], let web = nvWeb[key] else { return }
        if k == "ki" { Task { await openKakaoPlace(app: app, web: web, host: host) } } else { openExternal(app, web) }
    }
    /// 카카오맵 가게 정보: 엔진이 이름+좌표로 장소 ID 를 찾으면 그 가게 페이지를, 못 찾으면 이름 검색 주소를 연다.
    private func openKakaoPlace(app: String, web: String, host: Host) async {
        guard !selName.isEmpty, selLa != 0 || selLo != 0 else { openExternal(app, web); return }
        host.say("카카오맵에서 가게 정보를 여는 중...")
        let body = Json.text(["op": "kakaoId", "name": selName, "la": selLa, "lo": selLo] as [String: Any])
        if let d = try? await Net.request("POST", Servers.base + "/screen/food", body: body, timeout: 6), let o = Json.obj(d) as? [String: Any],
           (o["ok"] as? Bool) == true, let a = o["app"] as? String, let w = o["web"] as? String,
           a.hasPrefix("kakaomap://place?id="), w.hasPrefix("https://place.map.kakao.com/") { openExternal(a, w); return }
        openExternal(app, web)
    }
    private func openExternal(_ app: String, _ web: String) {
        if let u = URL(string: app), !app.isEmpty, !app.hasPrefix("http") {
            UIApplication.shared.open(u, options: [:]) { ok in if !ok, let w = URL(string: web) { UIApplication.shared.open(w) } }
        } else if let w = URL(string: web.isEmpty ? app : web) { UIApplication.shared.open(w) }
    }
    private func screenFrom(_ d: [String: Any]) -> Screen? {
        guard let data = try? JSONSerialization.data(withJSONObject: d) else { return nil }
        return try? Screen.parse(data)
    }

    // ── 원자료 ──
    private func fetchData(_ my: Int) async {
        guard let c = ctr else { return }
        let la = String(format: "%.6f", c.0), lo = String(format: "%.6f", c.1)
        async let s = try? Net.request("GET", "\(Servers.food)/food?lat=\(la)&lng=\(lo)&r=1500&limit=400", timeout: 8)
        async let p = pubPages(la, lo)
        let (sd, pages) = await (s, p)
        guard my == gen else { return }
        var srvOk = false
        if let sd = sd, let o = Json.obj(sd) as? [String: Any], let items = o["items"] as? [Any] { srv = items; srvOk = true } else { srv = [] }
        var rows: [Any] = [], pubOk = false
        for pg in pages { if let r = Self.rows(pg) { rows += r; pubOk = true } }
        pub = rows
        failed = !srvOk || (pub.isEmpty && !pubOk)
        loaded = true; loadedAt = Date()
        if let r = await post(), my == gen { apply(r) } else if my == gen { error = "맛집 화면을 받지 못했어요" }
    }

    /// 공공데이터: 먼저 공유 저장소 한 번, 비었으면 공공 서버에서 3쪽(200곳씩)을 동시에 받는다.
    private func pubPages(_ la: String, _ lo: String) async -> [Data] {
        if let d = try? await Net.request("GET", "\(Servers.base)/food-pub?lat=\(la)&lng=\(lo)", timeout: 9), (Self.rows(d)?.count ?? 0) > 0 { return [d] }
        let base = "https://apis.data.go.kr/B553077/api/open/sdsc2/storeListInRadius?serviceKey=&radius=1500&cx=\(lo)&cy=\(la)&indsLclsCd=I2&type=json&numOfRows=200&pageNo="
        var out: [Data] = []
        await withTaskGroup(of: (Int, Data?).self) { g in
            for i in 1...3 {
                let inner = base + String(i)
                let url = Servers.news + "/tago?url=" + (inner.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? inner)
                g.addTask { (i, try? await Net.request("GET", url, timeout: 10)) }
            }
            var got: [(Int, Data?)] = []
            for await r in g { got.append(r) }
            for (_, d) in got.sorted(by: { $0.0 < $1.0 }) {
                out.append(d ?? Data())
                if (d.flatMap { Self.rows($0)?.count } ?? 0) < 200 { break }
            }
        }
        return out
    }

    /// 공공데이터 한 쪽 → 행 [상호, 중분류, 소분류, 도로명, 지번, 위도, 경도] (못 읽으면 nil).
    static func rows(_ d: Data) -> [Any]? {
        guard !d.isEmpty, let o = Json.obj(d) as? [String: Any] else { return nil }
        var body = o["body"]
        if body == nil, let r = o["response"] as? [String: Any] { body = r["body"] }
        let items = (body as? [String: Any])?["items"]
        var l: [[String: Any]] = []
        if let a = items as? [[String: Any]] { l = a } else if let m = items as? [String: Any] { l = [m] }
        return l.map { r in [r["bizesNm"] ?? NSNull(), r["indsMclsNm"] ?? NSNull(), r["indsSclsNm"] ?? NSNull(), r["rdnmAdr"] ?? NSNull(), r["lnoAdr"] ?? NSNull(), r["lat"] ?? NSNull(), r["lon"] ?? NSNull()] as [Any] }
    }
}

struct FoodTab: View {
    let pal: Palette
    @StateObject private var m = FoodModel()
    @EnvironmentObject var host: Host
    @ObservedObject private var loc = LocationStore.shared
    var body: some View {
        ZStack {
            if let s = m.screen { ScreenBody(screen: s, pal: pal) }
            else { (pal.color("bg") ?? Color(.systemBackground)).ignoresSafeArea(); ProgressView() }
            if let e = m.error, m.screen == nil { Text(e).font(Typo.font(12)).foregroundColor(pal.color("sub") ?? .gray) }
        }
        .task { LocationStore.shared.start(); await m.load(); try? await Task.sleep(nanoseconds: 1_500_000_000); m.autoOpen(host: host) }
        .onChange(of: loc.last?.coordinate.latitude) { _ in Task { await m.gpsChanged() } }
        .onChange(of: loc.status) { _ in Task { await m.gpsChanged() } }
        .onReceive(host.actPublisher) { x in
            guard x.tab == "food" else { return }
            if x.a == "cat" { Task { await m.pick(x.v) } }
            else { m.act(x, host: host) }
        }
        .onChange(of: host.reloadTick) { _ in Task { await m.load(force: true) } }
    }
}
