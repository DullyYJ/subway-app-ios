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
        flt = chip.isEmpty ? "전체" : chip
        if let a = alts[flt], let s = screenFrom(a) { screen = s; return }
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
        screen = s; error = nil
        if let info = s.raw["info"] as? [String: Any], let c = info["ctr"] as? [Any], c.count == 2,
           let la = (c[0] as? NSNumber)?.doubleValue, let lo = (c[1] as? NSNumber)?.doubleValue { ctr = (la, lo) }
        if let a = s.raw["alts"] as? [String: Any] { alts = a.compactMapValues { $0 as? [String: Any] } }
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
        .task { LocationStore.shared.start(); await m.load() }
        .onChange(of: loc.last?.coordinate.latitude) { _ in Task { await m.gpsChanged() } }
        .onChange(of: loc.status) { _ in Task { await m.gpsChanged() } }
        .onReceive(host.actPublisher) { x in
            guard x.tab == "food" else { return }
            if x.a == "cat" { Task { await m.pick(x.v) } }
            else if x.a == "call" { host.say("가게 상세는 다음 단계에서 열려요") }
        }
        .onChange(of: host.reloadTick) { _ in Task { await m.load(force: true) } }
    }
}
