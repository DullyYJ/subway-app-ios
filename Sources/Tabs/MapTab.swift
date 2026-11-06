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
    func tapStation(_ name: String, line: String = "") {
        let n = name.filter { !$0.isWhitespace }
        guard !n.isEmpty else { return }
        showStn = true; stnScreen = nil; stnLine = line; pickName = ""; stnName = n; ttMode = false
        let body = "{\"cap\":\(Servers.cap),\"f\":{\"part\":\"stn\",\"stn\":\(Json.q(n)),\"sl\":\(Json.q(line)),\"reg\":\(Json.q(reg)),\"th\":\"dark\"}}"
        Task {
            if let d = try? await Net.request("POST", Servers.base + "/screen/map", body: body, timeout: 10), let s = try? Screen.parse(d) {
                readStn(d); stnScreen = s
            } else { showStn = false }
        }
    }
    private func readStn(_ d: Data) {
        pickName = ""; pickLine = ""; pickLa = 0; pickLo = 0
        guard let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any], let i = o["info"] as? [String: Any] else { return }
        ttLines = (i["lines"] as? [Any] ?? []).map { String(describing: $0) }
        if let m = i["msg"] as? [String: Any] { msgS = m["s"] as? String ?? ""; msgE = m["e"] as? String ?? ""; msgE2 = m["e2"] as? String ?? "" }
        if let p = i["pick"] as? [String: Any] {
            pickName = p["name"] as? String ?? ""; pickLine = p["line"] as? String ?? ""
            pickLa = (p["la"] as? NSNumber)?.doubleValue ?? 0; pickLo = (p["lo"] as? NSNumber)?.doubleValue ?? 0
        }
    }
    static func fill(_ t: String, _ n: String) -> String { t.replacingOccurrences(of: "{n}", with: n) }
    /// 역 팝업 단추(출발 · 도착 · 시간표)
    func sheetAct(_ v: String, host: Host) {
        let home = HomeModel.shared
        if v == "mp.close" { showStn = false; ttMode = false; return }
        if v == "mp.tt" { openTimetable(); return }
        if v.hasPrefix("mt.") { ttAct(v); return }
        if v == "mp.start" || v == "mp.dest" {
            guard !pickName.isEmpty else { return }
            showStn = false
            if home.isRiding { host.say("탑승 안내 중에는 바꿀 수 없어요"); return }
            if v == "mp.start" {
                home.setPlace(HomeModel.START, type: "subway", name: pickName, line: pickLine, lat: pickLa, lng: pickLo)
                let t = MapModel.fill(msgS, pickName); if !t.isEmpty { host.say(t) }
            } else {
                home.setPlace(HomeModel.DEST, type: "subway", name: pickName, line: pickLine, lat: pickLa, lng: pickLo)
                if home.bothSet {
                    let t = MapModel.fill(msgE, pickName); if !t.isEmpty { host.say(t) }
                    host.tab = "home"
                    Task { try? await Task.sleep(nanoseconds: 400_000_000); home.searchRoute(host: host) }
                } else { let t = MapModel.fill(msgE2, pickName); if !t.isEmpty { host.say(t) } }
            }
            return
        }
    }

    private var busRes: [String: String] = [:]
    private var busSel = -1

    // 화면에서 읽은 것(info): 정류장 · 노선 · 즐겨찾기 규칙 · 지방 노선 목록
    var stops: [[String: Any]] = []
    var rts: [Int: [[String]]] = [:]
    var favMax = 12, aliasMax = 10
    var favTxAdd = "", favTxRm = "", favTxFull = ""
    var regionStns: [(String, String)] = []
    var msgS = "", msgE = "", msgE2 = ""
    var pickName = "", pickLine = "", pickLa = 0.0, pickLo = 0.0
    var stnLine = ""
    @Published var aliasEdit: AliasEdit? = nil
    @Published var routeOpen = false
    @Published var ttMode = false
    var stnName = ""
    var ttLines: [String] = [], ttDks: [String] = [], ttDays: [String] = []
    var ttLine = "", ttDay = "", ttDk = "", ttState = "loading", needLine = "", needDay = "", ttAsked = ""
    var ttRes: [String: String] = [:]
    var ttSeq = 0, ttNeed = false
    let route = BusRoute()
    var pkBusName = "", pkBusId = ""
    struct AliasEdit: Identifiable { let id = UUID(); let key: String; let name: String; let cur: String }

    var favRaw: String { let s = ud.string(forKey: "map_busfav") ?? "[]"; return s.hasPrefix("[") ? s : "[]" }
    var alRaw: String { let s = ud.string(forKey: "map_busal") ?? "{}"; return s.hasPrefix("{") ? s : "{}" }
    private var favList: [[String: Any]] { ((try? JSONSerialization.jsonObject(with: Data(favRaw.utf8))) as? [[String: Any]]) ?? [] }
    private var aliasMap: [String: String] { ((try? JSONSerialization.jsonObject(with: Data(alRaw.utf8))) as? [String: String]) ?? [:] }

    func readInfo(_ d: Data) {
        guard let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any], let i = o["info"] as? [String: Any] else { return }
        if let rs = i["rs"] as? [[Any]] { regionStns = rs.compactMap { $0.count == 2 ? (String(describing: $0[0]), String(describing: $0[1])) : nil } } else { regionStns = [] }
        stops = Array((i["stops"] as? [[String: Any]] ?? []).prefix(40))
        if let fp = i["favp"] as? [String: Any] {
            favMax = (fp["max"] as? NSNumber)?.intValue ?? favMax; aliasMax = (fp["al"] as? NSNumber)?.intValue ?? aliasMax
            favTxAdd = fp["add"] as? String ?? ""; favTxRm = fp["rm"] as? String ?? ""; favTxFull = fp["full"] as? String ?? ""
        }
        rts = [:]
        if let r = i["rts"] as? [String: Any] {
            for (k, v) in r { if let ik = Int(k), let arr = v as? [[Any]] { rts[ik] = arr.prefix(40).compactMap { $0.count >= 3 ? $0.prefix(3).map { String(describing: $0) } : nil } } }
        }
    }
    private func toggleFav(_ i: Int, host: Host) -> Bool {
        guard i >= 0, i < stops.count, let id = stops[i]["id"] as? String, !id.isEmpty else { return false }
        var fl = favList
        if let at = fl.firstIndex(where: { ($0["id"] as? String) == id }) { fl.remove(at: at); if !favTxRm.isEmpty { host.say(favTxRm) } }
        else {
            if fl.count >= favMax { if !favTxFull.isEmpty { host.say(favTxFull) }; return false }
            fl.append(stops[i]); if !favTxAdd.isEmpty { host.say(favTxAdd) }
        }
        if let d = try? JSONSerialization.data(withJSONObject: fl), let s = String(data: d, encoding: .utf8) { ud.set(s, forKey: "map_busfav") }
        return true
    }
    func setAlias(_ key: String, _ text: String) {
        guard !key.isEmpty else { return }
        var m = aliasMap
        let t = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(aliasMax))
        if t.isEmpty { m.removeValue(forKey: key) } else { m[key] = t }
        if let d = try? JSONSerialization.data(withJSONObject: m), let s = String(data: d, encoding: .utf8) { ud.set(s, forKey: "map_busal") }
        Task { await load() }
    }
    func aliasFor(_ i: Int) -> AliasEdit? {
        guard i >= 0, i < stops.count, let id = stops[i]["id"] as? String, !id.isEmpty else { return nil }
        return AliasEdit(key: id, name: stops[i]["nm"] as? String ?? "", cur: aliasMap[id] ?? "")
    }
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
            f += ",\"bus\":{\"vw\":\(Json.q(busView)),\"sel\":\(busSel),\"sv\":1,\"svb\":300,\"fav\":\(favRaw),\"nx\":{},\"al\":\(alRaw),\"ord\":[]"
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
        readInfo(d)
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
        if raw.hasPrefix(Servers.news + "/bus-stops?"), raw.count < 200, raw.range(of: "^[A-Za-z0-9:/._?=&%-]+$", options: .regularExpression) != nil {
            if let d = try? await Net.request("GET", raw, timeout: 9), let s = String(data: d, encoding: .utf8), s.count > 2 { return s }
            return ""
        }
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
        } else if v.hasPrefix("mp.fv."), let i = Int(v.dropFirst(6)) {
            if toggleFav(i, host: host) { Task { await load() } }
        } else if v.hasPrefix("mp.al."), let i = Int(v.dropFirst(6)) {
            aliasEdit = aliasFor(i)
        } else if v.hasPrefix("br.") {
            if routeOpen { brAct(v, host: host) } else { openRoute(v) }
        } else if v.hasPrefix("mr."), let i = Int(v.dropFirst(3)), i >= 0, i < regionStns.count {
            tapStation(regionStns[i].0, line: regionStns[i].1)
        } else if v == "mp.close" || v == "mp.start" || v == "mp.dest" || v == "mp.tt" || v.hasPrefix("mt.") {
            sheetAct(v, host: host)
        } else { host.say("이 기능은 다음 단계에서 연결돼요") }
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
                        .frame(height: m.ttMode ? UIScreen.main.bounds.height * 0.62 : nil, alignment: .top)
                        .background(pal.color("card") ?? .black)
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
                    }
                }
                if m.routeOpen { RouteSheet(route: m.route, pal: pal) { m.closeRoute() } }
                if let ae = m.aliasEdit {
                    AliasCard(edit: ae, pal: pal, maxLen: m.aliasMax, onSave: { m.setAlias(ae.key, $0); m.aliasEdit = nil }, onClose: { m.aliasEdit = nil })
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
