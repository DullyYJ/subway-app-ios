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

    // 글쓰기 · 아이디 · 규칙 동의
    @Published var writeOpen = false
    @Published var writeScreen: Screen? = nil
    @Published var askUgc = false
    @Published var askId = false
    private var writeErr = "", writeBusy = false
    private var afterUgc: (() -> Void)? = nil
    var commId: String { ud.string(forKey: "comm_id") ?? "" }
    private var owner: String {
        if let k = ud.string(forKey: "bd_owner"), k.count >= 16 { return k }
        let k = (0..<16).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
        ud.set(k, forKey: "bd_owner"); return k
    }
    var ugcOk: Bool { ud.string(forKey: "ugc_ok") == "1" }
    static func idError(_ v: String) -> String {
        let t = v.trimmingCharacters(in: .whitespaces)
        if t.count < 2 || t.count > 12 { return "아이디는 2~12자로 입력해주세요" }
        for c in t.unicodeScalars {
            let ok = (c.value >= 0xAC00 && c.value <= 0xD7A3) || (c.value >= 97 && c.value <= 122) || (c.value >= 65 && c.value <= 90) || (c.value >= 48 && c.value <= 57) || c == "_"
            if !ok { return "한글·영문·숫자만 사용할 수 있어요" }
        }
        return ""
    }
    func saveId(_ v: String, say: @escaping (String) -> Void) {
        let e = Self.idError(v); if !e.isEmpty { say(e); return }
        let id = v.trimmingCharacters(in: .whitespaces); ud.set(id, forKey: "comm_id"); askId = false; say("아이디가 저장되었어요: " + id)
        if let f = afterId { afterId = nil; f() }
    }
    private var afterId: (() -> Void)? = nil
    func agreeUgc(say: @escaping (String) -> Void) { ud.set("1", forKey: "ugc_ok"); askUgc = false; if let f = afterUgc { afterUgc = nil; f() } else { say("동의했어요. 한 번 더 눌러 주세요") } }

    /// 올려도 되는지 엔진에 묻는다: 안 되면 문구, 되면 "". 엔진이 안 닿으면 막지 않는다.
    private func rulesCheck(_ kind: String, _ cat: String, _ texts: [String]) async -> String {
        let body = Json.text(["op": "check", "kind": kind, "cat": cat, "texts": texts] as [String: Any])
        guard let d = try? await Net.request("POST", Servers.base + "/rules", body: body, timeout: 6), let o = Json.obj(d) as? [String: Any] else { return "" }
        if (o["ok"] as? Bool) == false { let m = o["msg"] as? String ?? ""; return m.isEmpty ? "등록할 수 없어요" : m }
        return ""
    }

    // MARK: 글쓰기 시트(엔진 /screen/write)
    func openWrite(say: @escaping (String) -> Void) {
        if !ugcOk { afterUgc = { [weak self] in self?.openWrite(say: say) }; askUgc = true; return }
        if commId.isEmpty { afterId = { [weak self] in self?.openWrite(say: say) }; askId = true; return }
        for k in ["wt", "wb"] { ud.removeObject(forKey: "field." + k) }
        writeErr = ""; writeBusy = false; writeScreen = nil; writeOpen = true
        Task { await loadWrite() }
    }
    func closeWrite() { writeOpen = false }
    private func loadWrite() async {
        let t = ud.string(forKey: "field.wt") ?? "", b = ud.string(forKey: "field.wb") ?? ""
        let body = "{\"cap\":\(Servers.cap),\"f\":{\"rc\":0,\"err\":\(Json.q(writeErr)),\"busy\":\(writeBusy ? 1 : 0),\"t\":\(Json.q(t)),\"b\":\(Json.q(b))}}"
        if let d = try? await Net.request("POST", Servers.base + "/screen/write", body: body, timeout: 8), let sc = try? Screen.parse(d), writeOpen { writeScreen = sc }
    }
    func writeAct(_ v: String, host: Host) {
        if v == "wr.close" { closeWrite(); return }
        guard v == "wr.submit", !writeBusy else { return }
        let t = (ud.string(forKey: "field.wt") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let b = (ud.string(forKey: "field.wb") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { writeErr = "제목을 입력해주세요"; Task { await loadWrite() }; return }
        if b.isEmpty { writeErr = "내용을 입력해주세요"; Task { await loadWrite() }; return }
        writeBusy = true; writeErr = ""
        Task {
            await loadWrite()
            let bad = await rulesCheck("post", "잡담", [t, b])
            if !bad.isEmpty { writeBusy = false; writeErr = bad; await loadWrite(); return }
            let nick = commId
            let json = Json.text(["nick": nick, "title": t, "body": b, "cat": "잡담", "owner_key": owner] as [String: Any])
            let (st, data) = await Net.post(Servers.board + "/post", json, timeout: 9)
            writeBusy = false
            let rejected = st >= 400 && st < 500
            if rejected {
                let why = (Json.obj(data) as? [String: Any])?["error"] as? String ?? ""
                writeErr = why.isEmpty ? "등록할 수 없어요" : why; await loadWrite(); return
            }
            let sid = st == 200 ? Self.idStr((Json.obj(data) as? [String: Any])?["id"]) : ""
            let ok = !sid.isEmpty
            let now = Date().timeIntervalSince1970 * 1000
            var my = list("bd_my")
            my.insert(["id": ok ? sid : "L\(Int64(now))", "cat": "잡담", "title": t, "body": b, "nick": nick, "ts": now, "pending": !ok, "srv": ok] as [String: Any], at: 0)
            put("bd_my", Array(my.prefix(50)))
            host.say(ok ? "글이 등록되었어요" : "글을 저장했어요. 연결되면 모두에게 보여요")
            closeWrite()
            await load()
        }
    }

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
        for m in list("bd_my").compactMap({ $0 as? [String: Any] }) {            // 내 글은 서버 목록 위에 얹는다
            let id = Self.idStr(m["id"])
            if posts.contains(where: { Self.idStr($0["id"]) == id }) { continue }
            let srv = (m["srv"] as? Bool) == true, pending = (m["pending"] as? Bool) == true
            out.append([id, Self.s(m["cat"], 12), Self.s(m["title"], 300), Self.s(m["body"], 3000), Self.s(m["nick"], 40), Self.d(m["ts"]), 0, 0, 0, 0, 0,
                        1 | (pending ? 4 : 0) | (srv ? 8 : 0), "", cmts[id] ?? []] as [Any])
        }
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

    func handle(_ x: Host.TabAction, say: @escaping (String) -> Void) {
        if x.a == "tog" { Task { await openComments(pid: x.v) }; return }
        guard x.a == "call", x.v.hasPrefix("bd.") else { return }
        let v = x.v
        if v == "bd.more" { n = min(300, n + 30); Task { await render() }; return }
        if v == "bd.write" { writeHost = hostRef; openWrite(say: say); return }
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
                else { deletePost(id); say("글을 삭제했어요") }
            } else { armK = p[1]; armId = id; armAt = Date() }
        case "cm": comment(id, key: x.key, say: say); return
        default: return
        }
        Task { await render() }
    }

    var hostRef: Host? = nil
    private var writeHost: Host? = nil

    private func deletePost(_ id: String) {
        let my = list("bd_my").compactMap { $0 as? [String: Any] }
        let mine = my.first { Self.idStr($0["id"]) == id }
        let srv = (mine?["srv"] as? Bool) == true || posts.contains { Self.idStr($0["id"]) == id }
        put("bd_my", my.filter { Self.idStr($0["id"]) != id })
        if srv { Task { _ = await Net.post(Servers.board + "/post/mine-delete", Json.text(["post_id": id, "owner_key": owner]), timeout: 9) } }
    }

    /// 댓글 쓰기: 아이디 · 규칙 동의 · 글 검사를 거쳐 바로 내 말풍선을 붙이고 서버에 보낸다(결과는 기다리지 않는다).
    private func comment(_ id: String, key: String, say: @escaping (String) -> Void) {
        let ck = key.isEmpty ? "" : key
        guard !ck.isEmpty else { return }
        let t = (ud.string(forKey: "field." + ck) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return }
        let text = String(t.prefix(200))
        if commId.isEmpty { afterId = { [weak self] in self?.comment(id, key: key, say: say) }; askId = true; return }
        if !ugcOk { afterUgc = nil; askUgc = true; return }
        let nick = commId
        Task {
            let bad = await rulesCheck("chat", "", [text])
            if !bad.isEmpty { say(bad); return }
            let now = Date().timeIntervalSince1970 * 1000
            var l = cmts[id] ?? []
            l.append(["loc\(Int64(now))", nick, text, now, [Any]()] as [Any])
            cmts[id] = l
            _ = Task { await Net.post(Servers.board + "/comment", Json.text(["post_id": id, "nick": nick, "body": text]), timeout: 9) }
            hostRef?.clearField(ck)
            await render()
        }
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
            if m.writeOpen { WriteSheet(m: m, pal: pal) }
            if m.askId { IdCard(pal: pal, initial: m.commId, onSave: { m.saveId($0) { host.say($0) } }, onClose: { m.askId = false }) }
            if m.askUgc { UgcCard(pal: pal, onAgree: { m.agreeUgc { host.say($0) } }, onClose: { m.askUgc = false }) }
            if let e = m.error, m.screen == nil { Text(e).font(Typo.font(12)).foregroundColor(pal.color("sub") ?? .gray) }
        }
        .task { m.hostRef = host; await m.load() }
        .onReceive(host.actPublisher) { x in
            guard x.tab == "community" else { return }
            if x.v.hasPrefix("wr.") { m.writeAct(x.v, host: host) } else { m.hostRef = host; m.handle(x) { host.say($0) } }
        }
        .onChange(of: host.reloadTick) { _ in Task { await m.load() } }
    }
}

/// 글쓰기 시트: 엔진(/screen/write)이 그린 화면. 위로 10 띄운 가득 찬 판.
struct WriteSheet: View {
    @ObservedObject var m: BoardModel
    let pal: Palette
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { m.closeWrite() }
            Group {
                if let s = m.writeScreen { ScreenBody(screen: s, pal: pal) }
                else { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
            }
            .frame(maxWidth: 520).frame(maxHeight: .infinity)
            .background(pal.color("card") ?? .black)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
            .padding(.top, 44)
        }
        .transition(.move(edge: .bottom))
    }
}

/// 커뮤니티 아이디 정하기(안드로이드 설정 > 커뮤니티 아이디 · 2~12자 한글·영문·숫자·_)
struct IdCard: View {
    let pal: Palette; let initial: String
    var onSave: (String) -> Void; var onClose: () -> Void
    @State private var text = ""
    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { onClose() }
            VStack(alignment: .leading, spacing: 0) {
                Text("커뮤니티 아이디").font(Typo.font(15, bold: true)).foregroundColor(pal.color("text") ?? .white)
                Text("글과 댓글에 함께 보여요. 2~12자, 한글·영문·숫자만 쓸 수 있어요").font(Typo.font(12)).foregroundColor(pal.color("sub") ?? .gray).padding(.top, 4).padding(.bottom, 12)
                TextField("아이디", text: $text).font(Typo.font(14)).foregroundColor(pal.color("text") ?? .white).padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(pal.color("bg") ?? .black))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(pal.color("border2") ?? .gray, lineWidth: 1))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                HStack(spacing: 8) {
                    Button { onClose() } label: { Text("취소").font(Typo.font(14, bold: true)).foregroundColor(pal.color("sub") ?? .gray).frame(maxWidth: .infinity).frame(height: 42)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(pal.color("border2") ?? .gray, lineWidth: 1)) }.buttonStyle(.plain)
                    Button { onSave(text) } label: { Text("저장").font(Typo.font(14, bold: true)).foregroundColor(Color(red: 0x12 / 255.0, green: 0x12 / 255.0, blue: 0x14 / 255.0)).frame(maxWidth: .infinity).frame(height: 42)
                        .background(RoundedRectangle(cornerRadius: 10).fill(pal.color("gold") ?? .yellow)) }.buttonStyle(.plain).layoutPriority(1)
                }.padding(.top, 14)
            }
            .padding(EdgeInsets(top: 20, leading: 18, bottom: 18, trailing: 18))
            .background(RoundedRectangle(cornerRadius: 16).fill(pal.color("card") ?? .black))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(pal.color("border") ?? .gray, lineWidth: 1))
            .padding(.horizontal, 28).frame(maxWidth: 420)
        }
        .onAppear { text = initial }
    }
}

/// 커뮤니티 이용 규칙 동의(Play 사용자 생성 콘텐츠 정책 · App Store 가이드라인 1.2: 글을 올리기 전에 규칙에 동의)
struct UgcCard: View {
    let pal: Palette
    var onAgree: () -> Void; var onClose: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { onClose() }
            VStack(alignment: .leading, spacing: 0) {
                Text("커뮤니티 이용 규칙").font(Typo.font(15, bold: true)).foregroundColor(pal.color("text") ?? .white)
                ScrollView {
                    Text("게시판·실시간 대화·노선 방에 올리는 글은 다른 이용자에게 닉네임과 함께 공개돼요.\n\n다음 글은 올릴 수 없고, 신고가 모이면 자동으로 숨겨지거나 운영자가 지워요.\n· 욕설·비방·혐오·차별\n· 성적이거나 폭력적인 내용, 아동·청소년을 해치는 내용\n· 이름·연락처·주소·위치 같은 개인정보 노출, 광고·도배·사칭\n\n불쾌한 글은 '신고'(글쓴이도 이 기기에서 차단돼요)나 '차단'으로 바로 가릴 수 있어요.\n\n일부 답글은 AI가 만든 것이고, 입력한 말은 AI 답글을 만들려고 Google Gemini로 전달돼요. 개인정보는 입력하지 마세요.\n\n동의하지 않으면 글을 쓸 수 없어요.")
                    .font(Typo.font(13)).foregroundColor(pal.color("sub") ?? .gray).padding(.top, 8)
                }.frame(maxHeight: 360)
                HStack(spacing: 8) {
                    Button { onClose() } label: { Text("취소").font(Typo.font(14, bold: true)).foregroundColor(pal.color("sub") ?? .gray).frame(maxWidth: .infinity).frame(height: 42)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(pal.color("border2") ?? .gray, lineWidth: 1)) }.buttonStyle(.plain)
                    Button { onAgree() } label: { Text("동의하고 계속").font(Typo.font(14, bold: true)).foregroundColor(Color(red: 0x12 / 255.0, green: 0x12 / 255.0, blue: 0x14 / 255.0)).frame(maxWidth: .infinity).frame(height: 42)
                        .background(RoundedRectangle(cornerRadius: 10).fill(pal.color("gold") ?? .yellow)) }.buttonStyle(.plain).layoutPriority(1)
                }.padding(.top, 14)
            }
            .padding(EdgeInsets(top: 20, leading: 18, bottom: 18, trailing: 18))
            .background(RoundedRectangle(cornerRadius: 16).fill(pal.color("card") ?? .black))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(pal.color("border") ?? .gray, lineWidth: 1))
            .padding(.horizontal, 28).frame(maxWidth: 420)
        }
    }
}
