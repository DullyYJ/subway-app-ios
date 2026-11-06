import SwiftUI

/// 소통방(안드로이드 ChatCore): 전체 방(/talks)과 노선 방(/lroom)의 대화를 받아 엔진(/screen/chat)이 그린 화면으로 보인다.
/// 어느 방을 어떤 모양으로 보일지는 엔진이 정하고, 앱은 대화 모으기 · 보낸 글(전송 중) · 신고/차단/숨김 · 롱폴만 맡는다.
@MainActor
final class ChatModel: ObservableObject {
    @Published var screen: Screen? = nil
    @Published var askUgc = false
    @Published var askId = false
    @Published var reportId: String? = nil
    @Published var screenTick = 0
    private let ud = UserDefaults.standard
    private var talk: [(id: String, row: [Any])] = []           // 전체 방: [nick,text,ts,mine,line,id]
    private var room: [String: [(id: String, row: [Any])]] = [:] // 노선 방: [id,ts,nick,text,kind]
    private var sinceG: Int64 = 0, nowG: Int64 = 0
    private var sinceR: [String: Int64] = [:], nowR: [String: Int64] = [:]
    private var alerts: [String: Any] = [:]
    private var notices: Any? = nil, noticesAt: Int64 = 0
    private var pends: [(sel: String, text: String, ts: Date)] = []
    private var postLine = ""
    private var ridsR: [String] = []
    private var failed = false, loaded = false
    private var afterUgc: (() -> Void)? = nil

    var sel: String { let s = ud.string(forKey: "chat_sel") ?? "all"; return !s.isEmpty && s.count < 30 ? s : "all" }
    var me: String { ud.string(forKey: "comm_id") ?? "" }
    private var theme: String { ud.string(forKey: "theme") == "dark" ? "dark" : "pastel" }

    static func s(_ o: Any?, _ n: Int) -> String { let t = (o as? String) ?? ""; return t.count > n ? String(t.prefix(n)) : t }
    static func d(_ o: Any?) -> Double { (o as? NSNumber)?.doubleValue ?? 0 }
    static func idStr(_ o: Any?) -> String {
        if let s = o as? String { return s }
        if let n = o as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() { let d = n.doubleValue; return d == d.rounded() && abs(d) < 1e15 ? String(Int64(d)) : String(d) }
        return ""
    }
    private func jarr(_ k: String) -> [Any] { (ud.string(forKey: k)?.data(using: .utf8)).flatMap { Json.obj($0) as? [Any] } ?? [] }
    private func blocked() -> [String] { jarr("bd_blk").compactMap { $0 as? String }.filter { !$0.isEmpty } }

    // MARK: 받은 대화 합치기
    private func addTalks(_ d: Data) -> Bool {
        guard let o = Json.obj(d) as? [String: Any], (o["ok"] as? Bool) == true, let ts = o["talks"] as? [[String: Any]] else { failed = true; return false }
        let sn = ChatModel.d(o["now"]); if sn > 0 { nowG = Int64(sn) }
        for m in ts {
            let id = ChatModel.idStr(m["id"]); if id.isEmpty || talk.contains(where: { $0.id == id }) { continue }
            let t = ChatModel.d(m["ts"]); if Int64(t) > sinceG { sinceG = Int64(t) }
            let nick = ChatModel.s(m["nick"], 40)
            talk.append((id, [nick, ChatModel.s(m["text"], 400), t, (!me.isEmpty && me == nick) ? 1 : 0, ChatModel.s(m["line"], 20), id]))
        }
        if talk.count > 300 { talk.removeFirst(talk.count - 300) }
        loaded = true; failed = false; return true
    }
    private func addRoom(_ line: String, _ d: Data) -> Bool {
        guard let o = Json.obj(d) as? [String: Any], (o["ok"] as? Bool) == true else { failed = true; return false }
        let sn = ChatModel.d(o["now"]); if sn > 0 { nowR[line] = Int64(sn) }
        var rm = room[line] ?? []; var since = sinceR[line] ?? 0
        for m in (o["msgs"] as? [[String: Any]] ?? []) {
            let id = ChatModel.idStr(m["id"]); if id.isEmpty || rm.contains(where: { $0.id == id }) { continue }
            let t = ChatModel.d(m["ts"]); if Int64(t) > since { since = Int64(t) }
            rm.append((id, [id, t, ChatModel.s(m["nick"], 40), ChatModel.s(m["text"], 400), ChatModel.s(m["kind"], 10)]))
        }
        if rm.count > 200 { rm.removeFirst(rm.count - 200) }
        room[line] = rm; sinceR[line] = since
        if let a = o["alert"] as? [String: Any] { alerts[line] = a } else { alerts.removeValue(forKey: line) }
        loaded = true; failed = false; return true
    }

    // MARK: 엔진 요청
    private func requestBody() -> String {
        let s = sel
        pends.removeAll { Date().timeIntervalSince($0.ts) > 45 }
        let have = s == "all" ? !talk.isEmpty : room[s] != nil
        let tzo = -TimeZone.current.secondsFromGMT() / 60
        var f: [String: Any] = ["sel": s, "sec": HomeModel.shared.routeSec, "my": jarr("my_lines"), "th": theme, "st": have ? "ready" : (failed ? "fail" : "loading"),
                                "tzo": tzo, "me": me, "hid": jarr("lrHidden")]
        if RideLoop.shared.running, !HomeModel.shared.routeSec.isEmpty, let sc = Json.obj(Data(RideLoop.shared.sceneJson.utf8)) { f["ride"] = sc }
        let ps = pends.filter { $0.sel == s }.map { [$0.text, Int64($0.ts.timeIntervalSince1970 * 1000)] as [Any] }
        if !ps.isEmpty { f["pend"] = ps }
        let bl = blocked()
        let g: [Any] = talk.map { $0.row }.filter { r in
            if bl.isEmpty { return true }
            if (r[3] as? Int) == 1 { return true }
            return !bl.contains((r[0] as? String) ?? "")
        }
        var r: [Any] = []; var rids: [String] = []
        if s != "all", let rm = room[s] { for e in rm { if !bl.isEmpty, bl.contains((e.row[2] as? String) ?? "") { continue }; r.append(e.row); rids.append(e.id) } }
        ridsR = rids
        let off: Any = (s != "all" ? ((notices as? [String: Any])?["lines"] as? [String: Any])?[s] : nil) ?? NSNull()
        let d: [String: Any] = ["g": g, "r": r, "off": off, "offOk": notices != nil ? 1 : 0, "offAt": noticesAt, "al": alerts[s] ?? NSNull()]
        return Json.text(["cap": Servers.cap, "f": f, "d": d] as [String: Any])
    }
    func render() async {
        let s = sel
        guard let d = try? await Net.request("POST", Servers.base + "/screen/chat", body: requestBody(), timeout: 10), let sc = try? Screen.parse(d), s == sel else { return }
        screen = sc; screenTick += 1
        postLine = ((sc.raw["info"] as? [String: Any])?["pl"] as? String) ?? ""
    }

    // MARK: 받기
    func fetch() async {
        let s = sel
        await noticesMaybe()
        if s == "all" {
            let u = Servers.board + "/talks" + (sinceG > 0 ? "?since=\(sinceG)&limit=40" : "?limit=30")
            if let d = try? await Net.request("GET", u, timeout: 8) { _ = addTalks(d) } else if !loaded { failed = true }
        } else {
            let u = Servers.board + "/lroom?line=\(s.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? s)&since=\(sinceR[s] ?? 0)"
            if let d = try? await Net.request("GET", u, timeout: 12) { _ = addRoom(s, d) } else if !loaded { failed = true }
        }
        await render()
    }
    private func noticesMaybe() async {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        guard now - noticesAt > 60000 else { return }
        if let d = try? await Net.request("GET", Servers.base + "/line-notices", timeout: 8), let o = Json.obj(d) as? [String: Any], (o["ok"] as? Bool) == true { notices = o; noticesAt = now }
    }
    /// 롱폴: 이 방의 마지막 시각 이후 새 글이 생길 때까지 서버가 붙들었다가 돌려준다. 못 받은 방이면 먼저 보통 요청.
    func liveLoop() async {
        await fetch()
        var fails = 0
        while !Task.isCancelled {
            let s = sel
            let all = s == "all"
            let since = all ? sinceG : (sinceR[s] ?? 0)
            let base = since > 0 ? since : (all ? nowG : (nowR[s] ?? 0))
            if base <= 0 { try? await Task.sleep(nanoseconds: 700_000_000); if base <= 0 && !loaded { await fetch() }; continue }
            let u = all ? Servers.board + "/talks?since=\(base)&limit=40&wait=15" : Servers.board + "/lroom?line=\(s.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? s)&since=\(base)&wait=15"
            let t0 = Date()
            if let d = try? await Net.request("GET", u, timeout: 25) {
                fails = 0
                if Task.isCancelled || s != sel { continue }
                let head = String(data: d.prefix(90), encoding: .utf8) ?? ""
                let changed = head.contains("\"changed\":false") ? false : true
                let got = all ? addTalks(d) : addRoom(s, d)
                if got && changed { await render() }
                await noticesMaybe()
                let dt = Date().timeIntervalSince(t0)
                if dt < 1.5 { try? await Task.sleep(nanoseconds: UInt64((1.5 - dt) * 1e9)) }
            } else {
                fails += 1
                try? await Task.sleep(nanoseconds: UInt64(min(30, 2 * fails)) * 1_000_000_000)
            }
        }
    }

    // MARK: 눌림
    func select(_ line: String) {
        ud.set(line.isEmpty || line.count > 29 ? "all" : line, forKey: "chat_sel"); failed = false
        Task { await render(); await fetch() }
    }
    func act(_ x: Host.TabAction, host: Host) {
        if x.a == "cat" { select(x.v); return }
        guard x.a == "call" else { return }
        if x.v == "ch.send" { send(host: host) }
        else if x.v.hasPrefix("ch.x.") {
            if !x.id.isEmpty { reportId = x.id }
            else if let i = Int(x.v.dropFirst(5)), i >= 0, i < ridsR.count { reportId = ridsR[i] }
        }
    }
    private func send(host: Host) {
        let key = sel == "all" ? "chat.all" : "chat.room"
        let raw = (ud.string(forKey: "field." + key) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return }
        if me.isEmpty { askId = true; host.say("설정에서 커뮤니티 아이디를 등록하면 글과 제보를 남길 수 있어요"); return }
        if ud.string(forKey: "ugc_ok") != "1" { afterUgc = { [weak self] in self?.send(host: host) }; askUgc = true; return }
        let text = raw.count > 200 ? String(raw.prefix(200)) : raw
        let vsel = sel
        let line = vsel == "all" ? postLine : vsel
        pends.append((vsel, text, Date()))
        host.clearField(key)
        Task {
            await render()
            let bad = await Rules.check("chat", "", [text])
            if !bad.isEmpty {
                pends.removeAll { $0.text == text }
                ud.set(text, forKey: "field." + key); host.say(bad); await render(); return
            }
            let body = Json.text(["nick": me, "text": text, "line": line] as [String: Any])
            let (st, data) = await Net.post(Servers.board + "/react", body, timeout: 9)
            let resp = String(data: data, encoding: .utf8) ?? ""
            if !(st == 200 && resp.contains("\"stored\"")) {
                pends.removeAll { $0.text == text }
                ud.set(text, forKey: "field." + key)
                host.say(st == 0 ? "네트워크가 불안정해요" : resp.contains("filtered") ? "부적절한 표현이 있어 올리지 못했어요" : "잠시 후 다시 시도해 주세요")
            }
            await fetch()
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await fetch()
        }
    }
    func agreeUgc(host: Host) { ud.set("1", forKey: "ugc_ok"); askUgc = false; if let f = afterUgc { afterUgc = nil; f() } }

    /// 신고: 글을 숨기고 글쓴이를 차단하며(익명 제외) 서버에 올린다(숫자 id 만).
    func confirmReport(host: Host) {
        guard let id = reportId else { return }
        reportId = nil
        var h = jarr("lrHidden"); if !h.contains(where: { ($0 as? String) == id }) { h.append(id) }
        ud.set(Json.text(Array(h.suffix(300))), forKey: "lrHidden")
        var nick = ""
        for (_, rows) in room { if let e = rows.first(where: { $0.id == id }) { nick = ChatModel.s(e.row[2], 40); break } }
        if nick.isEmpty, let e = talk.first(where: { $0.id == id }) { nick = ChatModel.s(e.row[0], 40) }
        var blk = false
        if !nick.isEmpty && nick != "익명" {
            var b = blocked(); if !b.contains(nick) { b.append(nick); ud.set(Json.text(Array(b.suffix(200))), forKey: "bd_blk") }
            blk = true
        }
        host.say(blk ? "신고했어요. 이 글과 글쓴이의 글은 더 이상 보이지 않아요" : "신고했어요. 이 글은 더 이상 보이지 않아요")
        Task { await render() }
        let n = id.hasPrefix("L") ? String(id.dropFirst()) : id
        if !n.isEmpty, n.count <= 18, n.allSatisfy({ $0.isNumber }) {
            Task { _ = try? await Net.request("POST", Servers.board + "/lreport", body: Json.text(["id": n] as [String: Any]), timeout: 9) }
        }
    }
}

struct ChatView: View {
    let pal: Palette
    @StateObject private var m = ChatModel()
    @EnvironmentObject var host: Host
    var body: some View {
        ZStack {
            (pal.color("bg") ?? Color(.systemBackground)).ignoresSafeArea()
            if let s = m.screen {
                VStack(spacing: 0) {
                    ForEach(s.head) { NodeView(node: $0, pal: pal).environment(\.inHead, true) }
                    ScrollViewReader { sp in
                        ScrollView {
                            LazyVStack(spacing: 0) { ForEach(s.body) { NodeView(node: $0, pal: pal) }; Color.clear.frame(height: 1).id("end") }
                        }
                        .onAppear { sp.scrollTo("end", anchor: .bottom) }
                        .onChange(of: s.body.count) { _ in withAnimation(.none) { sp.scrollTo("end", anchor: .bottom) } }
                    }
                    ForEach(s.foot) { NodeView(node: $0, pal: pal) }
                }
            } else { ProgressView() }
            if m.askUgc { UgcCard(pal: pal, onAgree: { m.agreeUgc(host: host) }, onClose: { m.askUgc = false }) }
            if m.reportId != nil { ReportCard(pal: pal, onYes: { m.confirmReport(host: host) }, onNo: { m.reportId = nil }) }
        }
        .task { await m.liveLoop() }
        .onReceive(HomeModel.shared.$routeSec.dropFirst()) { _ in Task { await m.render() } }
        .onReceive(host.actPublisher) { x in if x.tab == "community" { m.act(x, host: host) } }
    }
}

/// 신고 확인 카드(안드로이드 report 대화상자와 같은 글).
struct ReportCard: View {
    let pal: Palette
    var onYes: () -> Void; var onNo: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { onNo() }
            VStack(spacing: 0) {
                Text("이 글을 신고할까요?").font(Typo.font(16, bold: true)).foregroundColor(pal.color("text") ?? .white).padding(.bottom, 8)
                Text("신고하면 이 글을 숨기고 글쓴이를 차단해요. 신고가 여러 명 모이면 자동으로 숨겨져요.").font(Typo.font(13)).foregroundColor(pal.color("sub") ?? .gray).lineSpacing(3).padding(.bottom, 16)
                HStack(spacing: 10) {
                    Button { onNo() } label: { Text("취소").font(Typo.font(14, bold: true)).foregroundColor(pal.color("sub") ?? .gray).frame(maxWidth: .infinity).frame(height: 44).background(RoundedRectangle(cornerRadius: 12).fill(pal.color("card2") ?? .gray.opacity(0.2))) }.buttonStyle(.plain)
                    Button { onYes() } label: { Text("신고").font(Typo.font(14, bold: true)).foregroundColor(pal.color("ongold") ?? .black).frame(maxWidth: .infinity).frame(height: 44).background(RoundedRectangle(cornerRadius: 12).fill(pal.color("gold") ?? .yellow)) }.buttonStyle(.plain)
                }
            }
            .padding(20).frame(maxWidth: 340).background(RoundedRectangle(cornerRadius: 16).fill(pal.color("card") ?? .black)).padding(.horizontal, 24)
        }
    }
}
