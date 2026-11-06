import SwiftUI

/// 노선도 탭(안드로이드 MapCore + ShellActivity.loadMapBody): 머리줄(/screen/map part h) + 본문(part b).
/// 버스 모드는 엔진이 서버에서 받아 줄 수 있으면(sv:1) 한 번에 오고, 못 받았으면 엔진이 info.bus.need 로 받아 올 주소를 알려 준다 —
/// 앱은 그 주소를 받아 res 에 담아 다시 보내기만 한다(최대 8바퀴). 무엇을 어떻게 그릴지는 모두 엔진이 정한다.
@MainActor
final class MapModel: ObservableObject {
    @Published var head: Screen? = nil
    @Published var body: Screen? = nil
    @Published var error: String? = nil
    @Published var view = ""                       // 엔진 info.view: metro | list | bus
    @Published var loading = false

    private let ud = UserDefaults.standard
    var mode: String { ud.string(forKey: "map_mode") == "subway" ? "subway" : "bus" }
    var reg: String { let r = ud.string(forKey: "map_reg") ?? "seoul"; return ["seoul", "busan", "daegu", "gwangju", "daejeon"].contains(r) ? r : "seoul" }
    var flt: String { let f = ud.string(forKey: "map_flt") ?? "ALL"; return !f.isEmpty && f.count < 12 ? f : "ALL" }
    private var busView: String { ud.string(forKey: "map_busvw") == "fav" ? "fav" : "near" }

    // 지하철 노선도 그림(앱에 들어 있는 데이터) · 역 팝업(엔진이 그린다)
    @Published var metro: MetroData? = nil
    @Published var stnScreen: Screen? = nil
    @Published var showStn = false
    func loadMetro() async {
        if metro != nil { return }
        guard let url = Bundle.main.url(forResource: "metro_native", withExtension: "bin") else { return }
        let m = await Task.detached(priority: .userInitiated) { () -> MetroData? in
            guard let d = try? Data(contentsOf: url) else { return nil }
            return MetroData.load(gz: d)
        }.value
        metro = m
    }
    func tapStation(_ name: String) {
        let n = name.filter { !$0.isWhitespace }
        guard !n.isEmpty else { return }
        showStn = true; stnScreen = nil
        let body = "{\"cap\":\(Servers.cap),\"f\":{\"part\":\"stn\",\"stn\":\(Json.q(n)),\"sl\":\"\",\"reg\":\(Json.q(reg)),\"th\":\"dark\"}}"
        Task {
            if let d = try? await Net.request("POST", Servers.base + "/screen/map", body: body, timeout: 10), let s = try? Screen.parse(d) { stnScreen = s }
            else { showStn = false }
        }
    }

    private var busRes: [String: String] = [:]
    private var busSel = -1
    private var seq = 0
    var gps: (Double, Double)? { LocationStore.shared.last.map { ($0.coordinate.latitude, $0.coordinate.longitude) } }

    // MARK: 요청
    private func facts(_ part: String) -> String {
        var f = "{\"part\":\(Json.q(part)),\"mode\":\(Json.q(mode)),\"reg\":\(Json.q(reg)),\"flt\":\(Json.q(flt)),\"th\":\"dark\""
        if let g = gps { f += ",\"gps\":[\(g.0),\(g.1)]" }
        return f + "}"
    }
    private func headBody() -> String { "{\"cap\":\(Servers.cap),\"f\":\(facts("h"))}" }
    private func bodyBody() -> String {
        var f = facts("b")
        if mode == "bus" {
            f.removeLast()
            f += ",\"bus\":{\"vw\":\(Json.q(busView)),\"sel\":\(busSel),\"sv\":1,\"svb\":300,\"fav\":[],\"nx\":{},\"al\":{},\"ord\":[]"
            if let g = gps { f += ",\"lat\":\(g.0),\"lng\":\(g.1)" }
            f += ",\"res\":{" + busRes.map { "\(Json.q($0.key)):\(Json.q($0.value))" }.joined(separator: ",") + "}}}"
        }
        return "{\"cap\":\(Servers.cap),\"f\":\(f)}"
    }

    // MARK: 받기
    func load() async {
        seq += 1; let my = seq
        loading = true; defer { if my == seq { loading = false } }
        async let h: Data? = try? await Net.request("POST", Servers.base + "/screen/map", body: headBody(), timeout: 8)
        let hd = await h
        if my != seq { return }
        if let hd = hd, let s = try? Screen.parse(hd) { head = s }
        var last: Data? = nil
        for round in 0..<8 {
            guard let d = try? await Net.request("POST", Servers.base + "/screen/map", body: bodyBody(), timeout: 10) else { break }
            if my != seq { return }
            last = d
            let need = readNeed(d)
            if need.isEmpty || round == 7 { break }
            // 엔진이 받아 오라고 한 주소를 동시에 받아 res 에 담는다
            let got = await withTaskGroup(of: (String, String).self) { g -> [(String, String)] in
                for n in need { g.addTask { (n.0, await MapModel.busGet(n.1)) } }
                var out: [(String, String)] = []
                for await x in g { out.append(x) }
                return out
            }
            for (k, v) in got { busRes[k] = v }
        }
        if my != seq { return }
        guard let d = last, let s = try? Screen.parse(d) else { if body == nil { error = "노선도를 받지 못했어요" }; return }
        body = s; error = nil
        view = ((((try? JSONSerialization.jsonObject(with: d)) as? [String: Any])?["info"] as? [String: Any])?["view"] as? String) ?? ""
    }

    /// 엔진 답의 info.bus.need: [{k, url}] — 받아 올 주소(최대 64).
    private func readNeed(_ d: Data) -> [(String, String)] {
        guard mode == "bus", let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any], let i = o["info"] as? [String: Any],
              let b = i["bus"] as? [String: Any], let n = b["need"] as? [[String: Any]] else { return [] }
        return n.prefix(64).compactMap { x in
            guard let k = x["k"] as? String, let u = x["url"] as? String else { return nil }
            return (String(k.prefix(4)), String(u.prefix(600)))
        }
    }

    /// 공공 API 주소를 버스 전용 프록시(/tago)로 받는다. 안 되면 route-v2 의 /bus-tago 로 한 번 더. 허용 호스트가 아니면 빈 글.
    nonisolated static func busGet(_ raw: String) async -> String {
        guard raw.range(of: "^https?://(apis\\.data\\.go\\.kr|ws\\.bus\\.go\\.kr)/", options: .regularExpression) != nil,
              let enc = raw.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))) else { return "" }
        for base in [Servers.bus + "/tago?url=", Servers.base + "/bus-tago?url="] {
            if let d = try? await Net.request("GET", base + enc, timeout: 8), let s = String(data: d, encoding: .utf8), s.count > 2 { return s }
        }
        return ""
    }

    // MARK: 눌림
    func cat(_ v: String) {
        if v.hasPrefix("m:") { ud.set(v.dropFirst(2) == "subway" ? "subway" : "bus", forKey: "map_mode"); busRes = [:]; body = nil }
        else if v.hasPrefix("r:") { ud.set(String(v.dropFirst(2)), forKey: "map_reg"); ud.set("ALL", forKey: "map_flt") }
        else if v.hasPrefix("f:") { ud.set(String(v.dropFirst(2)), forKey: "map_flt") }
        else { return }
        Task { await load() }
    }
    func call(_ v: String, host: Host) {
        if v == "mp.vw.near" || v == "mp.vw.fav" {
            let nv = String(v.dropFirst(6)); if nv == busView { return }
            ud.set(nv, forKey: "map_busvw"); busSel = -1; Task { await load() }
        } else if v == "mp.rf" || v == "mp.loc" || v == "mp.rt" {
            LocationStore.shared.start(); busRes = [:]; busSel = -1; Task { await load() }
        } else if v.hasPrefix("mp.pc.") || v.hasPrefix("mp.pm."), let i = Int(v.dropFirst(6)) {
            busSel = i; Task { await load() }
        } else if v == "mp.close" { showStn = false }
        else { host.say("이 기능은 다음 단계에서 연결돼요") }
    }
}

struct MapTab: View {
    let pal: Palette
    @StateObject private var m = MapModel()
    @EnvironmentObject var host: Host
    var body: some View {
        VStack(spacing: 0) {
            if let h = m.head { VStack(spacing: 0) { ForEach(h.head + h.body) { NodeView(node: $0, pal: pal) } } }
            ZStack {
                if let s = m.body { ScreenBody(screen: s, pal: pal) }
                else { (pal.color("bg") ?? Color(.systemBackground)).ignoresSafeArea(); ProgressView() }
                if m.view == "metro", let md = m.metro {
                    MetroMapView(data: md, filter: md.filterIndex(m.flt)) { m.tapStation($0) }
                }
                if m.showStn {
                    ZStack(alignment: .bottom) {
                        Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { m.showStn = false }
                        Group {
                            if let s = m.stnScreen { ScreenBody(screen: s, pal: pal) } else { ProgressView().frame(height: 120) }
                        }
                        .frame(maxWidth: 520).frame(maxHeight: 520).fixedSize(horizontal: false, vertical: true)
                        .background(pal.color("card") ?? .black)
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
                    }
                }
                if let e = m.error, m.body == nil { Text(e).font(Typo.font(12)).foregroundColor(pal.color("sub") ?? .gray) }
            }
        }
        .background(pal.color("bg") ?? Color(.systemBackground))
        .task { LocationStore.shared.start(); await m.loadMetro(); await m.load() }
        .onReceive(host.actPublisher) { x in
            guard x.tab == "map" else { return }
            if x.a == "cat" { m.cat(x.v) } else if x.a == "call" { m.call(x.v, host: host) }
        }
        .onChange(of: host.reloadTick) { _ in Task { await m.load() } }
    }
}
