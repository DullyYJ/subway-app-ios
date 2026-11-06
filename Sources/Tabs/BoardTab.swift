import SwiftUI

/// 커뮤니티(게시판) 탭 — 안드로이드 BoardCore 의 읽기 · 반응 · 신고/차단 부분.
/// 서버 글(/posts)과 댓글(/comments)을 받아 '글 줄'로 엮어 POST /screen/board 에 보내고, 엔진이 돌려준 화면을 그린다.
/// 글쓰기 · 댓글 쓰기는 입력 시트가 필요해 다음 단계에서 붙인다.
@MainActor
final class BoardModel: ObservableObject {
    @Published var screen: Screen? = nil
    @Published var error: String? = nil
    private var posts: [[String: Any]] = []
    private var cmts: [String: [Any]] = [:]
    private var n = 30, loading = true
    private var armK = "", armId = "", armAt = Date.distantPast
    private var pidById: [String: String] = [:]
    private var idByIdx: [String] = []
    private var cmtAt: [String: Date] = [:]
    private let ud = UserDefaults.standard

    // 보관(기기에만)
    private func dict(_ k: String) -> [String: Any] { (ud.string(forKey: k)?.data(using: .utf8)).flatMap { Json.obj($0) as? [String: Any] } ?? [:] }
    private func list(_ k: String) -> [Any] { (ud.string(forKey: k)?.data(using: .utf8)).flatMap { Json.obj($0) as? [Any] } ?? [] }
    private func put(_ k: String, _ o: Any) { ud.set(Json.text(o), forKey: k) }

    private static func idStr(_ o: Any?) -> String {
        if let s = o as? String { return s }
        if let n = o as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() { let d = n.doubleValue; return d == d.rounded() && abs(d) < 1e15 ? String(Int64(d)) : String(d) }
        return ""
    }
    private static func s(_ o: Any?, _ max: Int) -> String { let v = idStr(o); return v.count > max ? String(v.prefix(max)) : v }
    private static func d(_ o: Any?) -> Double { (o as? NSNumber)?.doubleValue ?? 0 }
    private func isBlocked(_ nick: String) -> Bool { !nick.isEmpty && nick != "익명" && list("bd_blk").contains { ($0 as? String) == nick } }

    func load(fetch: Bool = true) async {
        if fetch, let d = try? await Net.request("GET", Servers.board + "/posts?limit=50", timeout: 8),
           let o = Json.obj(d) as? [String: Any], let ps = o["posts"] as? [[String: Any]] {
            posts = ps.filter { !Self.idStr($0["id"]).isEmpty && !Self.s($0["title"], 400).isEmpty }.prefix(400).map { $0 }
            loading = false
        } else if fetch { loading = false }
        await render()
    }

    /// 엔진 글 줄: [번호, 분류, 제목, 본문, 글쓴이, 시각, 조회, 좋아요, ㅋㅋ, ㅠㅠ, 서버 댓글 수, 표시비트, 링크, 댓글들]
    private func rows() -> [Any] {
        var out: [Any] = []
        for p in posts {
            let id = Self.idStr(p["id"]), nick = Self.s(p["nick"], 40)
            if isBlocked(nick) { continue }
            let cat = Self.s(p["cat"], 12)
            let user = Self.d(p["user"]) != 0 || (p["user"] as? Bool) == true
            out.append([id, cat.isEmpty ? "잡담" : cat, Self.s(p["title"], 300), Self.s(p["body"], 3000), nick.isEmpty ? "익명" : nick,
                        Self.d(p["ts"]), Self.d(p["views"]), Self.d(p["likes"]), Self.d(p["lols"]), Self.d(p["sads"]), Self.d(p["cmts"]),
                        8 | (user ? 2 : 0), Self.s(p["link"], 400), cmts[id] ?? []] as [Any])
        }
        return out
    }

    private func render() async {
        if armK != "" && Date().timeIntervalSince(armAt) > 3.5 { armK = ""; armId = "" }
        let rs = rows()
        idByIdx = rs.map { ($0 as? [Any])?.first as? String ?? "" }
        let f: [String: Any] = ["n": n, "st": loading ? "loading" : "ready",
                                "arm": armK.isEmpty ? NSNull() : ["k": armK, "id": armId] as [String: Any],
                                "rx": dict("bd_rx"), "rep": list("bd_rep"), "bk": list("bd_blk").count]
        let body = Json.text(["cap": Servers.cap, "f": f, "p": rs] as [String: Any])
        do { let s = try await Net.screen("/screen/board", body: body); screen = s; error = nil; onScreen(s) }
        catch { self.error = error.localizedDescription }
    }

    /// 엔진이 돌려준 info(ids · sid / idx)로 글번호 ↔ 화면 열쇠를 맞춘다.
    private func onScreen(_ s: Screen) {
        pidById = [:]
        guard let info = s.raw["info"] as? [String: Any], let ids = info["ids"] as? [Any] else { return }
        if let sid = info["sid"] as? [Any], sid.count == ids.count {
            for k in 0..<ids.count { let real = Self.s(sid[k], 60); if !real.isEmpty { pidById[real] = Self.s(ids[k], 60) } }
        } else if let idx = info["idx"] as? [Any] {
            for k in 0..<min(ids.count, idx.count) { let i = Int(Self.d(idx[k])); if i >= 0 && i < idByIdx.count { pidById[idByIdx[i]] = Self.s(ids[k], 60) } }
        }
    }
    private func idOfPid(_ pid: String) -> String { pidById.first { $0.value == pid }?.key ?? "" }

    func handle(_ x: Host.TabAction, say: (String) -> Void) {
        if x.a == "tog" { Task { await openComments(pid: x.v) }; return }
        guard x.a == "call", x.v.hasPrefix("bd.") else { return }
        let v = x.v
        if v == "bd.more" { n = min(300, n + 30); Task { await render() }; return }
        if v == "bd.write" { say("글쓰기는 다음 단계에서 열려요"); return }
        if v == "bd.ub.all" { put("bd_blk", [Any]()); Task { await render() }; return }
        let p = v.components(separatedBy: ".")
        guard p.count == 3 else { return }
        var id = x.id
        if id.isEmpty, let i = Int(p[2]), i >= 0, i < idByIdx.count { id = idByIdx[i] }
        guard !id.isEmpty else { return }
        switch p[1] {
        case "lk": toggleRx(id, "like")
        case "lo": toggleRx(id, "lol")
        case "sd": toggleRx(id, "sad")
        case "bk", "rp", "dl":
            if armK == p[1] && armId == id && Date().timeIntervalSince(armAt) <= 3.5 {      // 두 번 눌러 확정
                armK = ""; armId = ""
                if p[1] == "bk" { block(id) }
                else if p[1] == "rp" { report(id); say("신고가 접수됐어요. 이 글은 더 이상 보이지 않아요") }
                else { say("내 글만 지울 수 있어요") }
            } else { armK = p[1]; armId = id; armAt = Date() }
        case "cm": say("댓글 쓰기는 다음 단계에서 열려요")
        default: return
        }
        Task { await render() }
    }

    private func toggleRx(_ id: String, _ type: String) {
        var rx = dict("bd_rx"); var m = (rx[id] as? [String: Any]) ?? [:]
        if m[type] != nil { m.removeValue(forKey: type) } else { m[type] = 1 }
        if m.isEmpty { rx.removeValue(forKey: id) } else { rx[id] = m }
        put("bd_rx", rx)
    }
    private func block(_ id: String) {
        let nick = Self.s(posts.first { Self.idStr($0["id"]) == id }?["nick"], 40)
        var b = list("bd_blk"); guard !nick.isEmpty, !b.contains(where: { ($0 as? String) == nick }) else { return }
        b.append(nick); put("bd_blk", Array(b.suffix(200)))
    }
    private func report(_ id: String) {
        var r = list("bd_rep"); if !r.contains(where: { ($0 as? String) == id }) { r.append(id) }
        put("bd_rep", Array(r.suffix(200)))
        Task { _ = try? await Net.request("POST", Servers.board + "/report", body: Json.text(["post_id": id]), timeout: 9) }
    }

    /// 글을 펼치면 서버 댓글을 받아 붙인다(15초 안에는 다시 받지 않는다).
    private func openComments(pid: String) async {
        let id = idOfPid(pid)
        guard !id.isEmpty, posts.contains(where: { Self.idStr($0["id"]) == id }) else { return }
        if let t = cmtAt[id], Date().timeIntervalSince(t) < (cmts[id] != nil ? 15 : 3) { return }
        cmtAt[id] = Date()
        let q = id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? id
        guard let d = try? await Net.request("GET", Servers.board + "/comments?post_id=\(q)&limit=50", timeout: 8),
              let o = Json.obj(d) as? [String: Any], let cs = o["comments"] as? [[String: Any]], !cs.isEmpty else { return }
        cmts[id] = cs.map { c in ["srv" + Self.idStr(c["id"]), Self.s(c["nick"], 40), Self.s(c["body"], 400), Self.d(c["ts"]), [Any]()] as [Any] }
        await render()
    }
}

struct BoardTab: View {
    let pal: Palette
    @StateObject private var m = BoardModel()
    @EnvironmentObject var host: Host
    var body: some View {
        ZStack {
            if let s = m.screen { ScreenBody(screen: s, pal: pal) }
            else { (pal.color("bg") ?? Color(.systemBackground)).ignoresSafeArea(); ProgressView() }
            if let e = m.error, m.screen == nil { Text(e).font(Typo.font(12)).foregroundColor(pal.color("sub") ?? .gray) }
        }
        .task { await m.load() }
        .onReceive(host.actPublisher) { x in if x.tab == "community" { m.handle(x) { host.say($0) } } }
        .onChange(of: host.reloadTick) { _ in Task { await m.load() } }
    }
}
