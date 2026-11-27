import SwiftUI
import UserNotifications

/// 설정 방식(안드로이드 ShellCore.settingsFacts · routeSettings): 기기 사실을 GET /screen/settings?f= 에 실어 보내면 엔진이 화면을 만든다.
/// 스위치(set) · 테마(sel) · 아이디(saveId/clearId) · 약관 하위 화면(pol.*)을 여기서 처리한다. 안드로이드 전용 하위 화면은 pgs 에서 빼서 엔진이 감춘다.
@MainActor
final class SettingsModel: ObservableObject {
    @Published var screen: Screen? = nil
    @Published var error: String? = nil
    @Published var sub: Screen? = nil
    @Published var subOpen = false
    private let ud = UserDefaults.standard
    static let notif = ["arrive", "transfer", "arrive_reco"]

    var theme: String { ud.string(forKey: "theme") ?? "pastel" }
    func facts() -> String {
        let np = SettingsModel.notif.map { "\(Json.q($0)):\(ud.string(forKey: "np_" + $0) == "0" ? 0 : 1)" }.joined(separator: ",")
        let id = ud.string(forKey: "comm_id") ?? ""
        let rl = ud.string(forKey: "ride_log_off") == "1" ? 0 : 1
        let cm = CmCore.on() ? 1 : 0
        // cmi/cmh/cmf: 출퇴근 브리핑을 설정 화면 안에 펼친다(안드로이드 ShellCore.settingsFacts). pgs: 이 앱이 열 수 있는 하위 화면(나머지 줄은 엔진이 감춘다)
        return "{\"id\":\(Json.q(id)),\"np\":{\(np)},\"ovl\":0,\"sam\":0,\"samw\":0,\"cm\":\(cm),\"cmi\":1,\"cmh\":1,\"cmf\":\(CmCore.inlineFacts()),\"errn\":0,\"pgs\":[\"cm\",\"arr\"],\"rl\":\(rl),\"th\":\(Json.q(theme))}"
    }
    private func url(_ p: String? = nil) -> String {
        let f = facts().addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        return Servers.base + "/screen/settings?cap=\(Servers.cap)" + (p.map { "&p=\($0)" } ?? "") + "&f=" + f
    }
    private var loadSeq = 0
    func load() async {
        loadSeq += 1
        let my = loadSeq
        do {
            let d = try await Net.request("GET", url(), timeout: 9)
            let sc = try Screen.parse(d)
            if my == loadSeq { screen = sc; error = nil }          // 더 새 요청이 나갔으면 늦게 온 옛 답은 버린다(글자를 칠 때마다 다시 받는다)
        }
        catch { if screen == nil { self.error = "설정을 받지 못했어요" } }
    }

    // MARK: 출퇴근 브리핑(안드로이드 ShellActivity.cmInlineAct · cmText · cmReload) — 저장은 CmCore, 글 · 시각은 엔진
    private var typed: [String: String] = [:]
    private var editTask: Task<Void, Never>? = nil
    private func cmAct(_ a: String, _ v: String?, _ key: String?, on: Bool, q: String?, host: Host) {
        let r = CmCore.shared.act(a, v: v, key: key, on: on, q: q)
        cmApply(r, host: host)
    }
    private func cmApply(_ r: Int, host: Host) {
        let c = CmCore.shared
        if r & CmCore.R.resched != 0 { Task { await CommuteAlarm.reschedule() } }
        if r & CmCore.R.test != 0 { host.say("브리핑을 만드는 중이에요"); Task { await CommuteAlarm.sendPreview(host: host) }; return }
        if c.sub == "tp" { loadTp(host: host); return }                 // 시각 고르기는 가운데 팝업
        if host.cmPop != nil { host.cmPop = nil }
        if r & CmCore.R.bus != 0 {
            let q = c.pkQ
            Task { await load(); if await CommuteAlarm.busSearch(q) { await load() } }          // 지하철 후보는 엔진이 바로 · 버스정류장은 찾아 오는 대로 한 번 더
            return
        }
        if r & CmCore.R.render != 0 { Task { await load() } }
    }
    private func loadTp(host: Host) {
        let c = CmCore.shared
        c.pop = true
        Task {
            if let d = try? await Net.request("GET", CommuteAlarm.pageUrl("cm", c.pageFacts()), timeout: 9), let sc = try? Screen.parse(d) { host.cmPop = sc }
        }
    }
    private func cmText(_ k: String, _ value: String, _ kind: String, host: Host) {
        typed["cmp." + k] = value
        let c = CmCore.shared
        if kind == "focus" { c.focusInline(k, value); return }
        if kind == "input" {
            guard c.inl, c.pkK == k else { return }                     // 손가락이 들어온 칸의 글자만(화면이 칸 값을 다시 넣을 때는 무시)
            editTask?.cancel()
            editTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 120_000_000)
                if Task.isCancelled { return }
                guard let self = self else { return }
                let r = CmCore.shared.onInline(k, value)
                self.cmApply(r, host: host)
            }
            return
        }
        if kind == "blur" {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 350_000_000)         // 후보 줄을 누른 게 아니면(그러면 이미 저장돼 있다) 친 글자를 그대로 자동 저장
                guard let self = self else { return }
                let r = CmCore.shared.blurInline(k, self.typed["cmp." + k] ?? value)
                self.cmApply(r, host: host)
            }
        }
    }
    // MARK: 하차 7분 전 추천 시험(안드로이드 ShellActivity.testReco · pageUrlArr) — 글은 엔진이 만들고, 앱은 그 시간대의 실제 알림과 같은 내용을 알림으로 띄워 줄 뿐
    private func arrFacts(stat: Bool, policy: Bool) -> String {
        var b = "{\"pf\":{\"nat\":true,\"nv\":true"
        if stat {
            let rl = RideLoop.shared
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            b += ",\"st\":{\"timer\":\(rl.running),\"route\":\(rl.recoInfo != nil),\"pre\":7,\"tzo\":-540,\"policy\":\(policy)"
            if let r = rl.recoInfo { b += ",\"dest\":\(Json.q(r.dest)),\"rem\":\(max(0, min(86400, Int((r.arr - now) / 1000))))" }
            if RecoFlow.sentAt > 0 { b += ",\"alertAt\":\(RecoFlow.sentAt)" }
            if !RecoFlow.stage.isEmpty { b += ",\"dg\":{\"stage\":\(Json.q(RecoFlow.stage))" + (RecoFlow.stageAt > 0 ? ",\"at\":\(RecoFlow.stageAt)" : "") + "}" }
            b += "}"
        }
        return b + "}}"
    }
    private func openArr(stat: Bool) {
        subOpen = true; if !stat { sub = nil }
        Task {
            let st = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            let policy = st == .authorized || st == .provisional || st == .ephemeral
            let f = arrFacts(stat: stat, policy: policy).addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
            if let d = try? await Net.request("GET", Servers.base + "/screen/settings?cap=\(Servers.cap)&p=arr&f=" + f, timeout: 9), let s = try? Screen.parse(d) { sub = s }
        }
        arrStat = stat
    }
    private var arrStat = false
    private func testReco(_ kind: String, host: Host) {
        host.say("추천 알림을 만드는 중이에요")
        Task {
            let r = await RecoFlow.send(body: RecoFlow.testBody(kind: kind, nowMs: Int64(Date().timeIntervalSince1970 * 1000)), host: host, loc: nil, notifyOnly: true)
            if !r.sent { host.say("추천을 받지 못했어요") }
            if subOpen { openArr(stat: arrStat) }          // 상태 확인을 켜 둔 채면 새 발송 단계로 다시 그린다
        }
    }
    private func openSub(_ p: String) {
        subOpen = true; sub = nil
        Task { if let d = try? await Net.request("GET", url(p), timeout: 9), let s = try? Screen.parse(d) { sub = s } }
    }
    func handle(_ x: Host.TabAction, host: Host) {
        switch x.a {
        case "input", "focus", "blur":
            if x.key.hasPrefix("cmp.") { cmText(String(x.key.dropFirst(4)), x.v, x.a, host: host) }
        case "set":
            if x.key == "cm" { cmAct("set", nil, "cm", on: x.on, q: nil, host: host); return }
            if x.key.hasPrefix("n.") {
                let k = String(x.key.dropFirst(2))
                if SettingsModel.notif.contains(k) { ud.set(x.on ? "1" : "0", forKey: "np_" + k); Task { await load() } }
            } else if x.key == "rl" { ud.set(x.on ? "0" : "1", forKey: "ride_log_off"); Task { await load() } }
        case "sel":
            if x.v == "dark" || x.v == "pastel" { ud.set(x.v, forKey: "theme"); Task { await load() } }
        case "call":
            if x.v.hasPrefix("cm.") || x.v.hasPrefix("pk.") || x.v.hasPrefix("tp.") {
                var q: String? = nil
                if x.v.hasPrefix("pk.save.") { q = typed["cmp." + String(x.v.dropFirst(8))] ?? "" }
                else if x.v == "pk.n" { q = x.id }
                cmAct("call", x.v, nil, on: false, q: q, host: host)
                return
            }
            switch x.v {
            case "saveId":
                let raw = ud.string(forKey: "field.cid") ?? ""
                let e = BoardModel.idError(raw)
                if !e.isEmpty { host.say(e); return }
                let id = raw.trimmingCharacters(in: .whitespaces)
                ud.set(id, forKey: "comm_id"); host.say("아이디가 저장되었어요: " + id); Task { await load() }
            case "clearId":
                ud.set("", forKey: "comm_id"); host.clearField("cid"); host.say("아이디가 삭제되었어요"); Task { await load() }
            case "pg.back": subOpen = false
            case "pg.arr": openArr(stat: false)
            case "arr.stat": openArr(stat: true)
            case "pol.privacy": openSub("polp")
            case "pol.location": openSub("poll")
            case "pol.opensource": openSub("polo")
            default:
                if let k = RecoFlow.testKind(x.v) { testReco(k, host: host) }
                else if x.v.hasPrefix("tab.") { host.call(x.v) } else { host.say("아직 옮기는 중이에요") }
            }
        case "web": host.say("아직 옮기는 중이에요")
        default: break
        }
    }
}

struct SettingsView: View {
    let pal: Palette
    @StateObject private var m = SettingsModel()
    @ObservedObject private var kids = KidsHub.shared
    @EnvironmentObject var host: Host
    /// 길동무 키즈 줄(연결 전엔 '연결' 한 줄 · 연결 뒤엔 키즈 서버가 준 줄들)을 '개발자 도구' 카드 위에(없으면 '약관 및 정책' 위) 끼운다 — 안드로이드 ScreenCore.settingsExtra 와 같은 자리.
    private func withKids(_ s: Screen) -> Screen {
        var body = s.body
        var at = 0, dev = -1
        for (i, n) in body.enumerated() where n.t == "panel" {
            let first = n.kids.first?.str("s")
            if first == "개발자 도구", dev < 0 { dev = i }
            if first == "약관 및 정책" { at = i; break }
        }
        if dev >= 0 { at = dev }
        let extra = kids.extraNodes.enumerated().map { Node(d: $1, id: "kids\($0)") }
        body.insert(contentsOf: extra, at: min(at, body.count))
        return Screen(name: s.name, head: s.head, body: body, foot: s.foot, bg: s.bg, raw: s.raw)
    }
    var body: some View {
        ZStack {
            if let s = m.screen { ScreenBody(screen: withKids(s), pal: pal) }
            else { (pal.color("bg") ?? Color(.systemBackground)).ignoresSafeArea(); ProgressView() }
            if let e = m.error, m.screen == nil { Text(e).font(Typo.font(12)).foregroundColor(pal.color("sub") ?? .gray) }
            if m.subOpen {
                ZStack(alignment: .bottom) {
                    Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { m.subOpen = false }
                    VStack(spacing: 0) {
                        Group {
                            if let s = m.sub { ScreenBody(screen: s, pal: pal) } else { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
                        }
                        Button { m.subOpen = false } label: {
                            Text("닫기").font(Typo.font(14, bold: true)).foregroundColor(pal.color("sub") ?? .gray).frame(maxWidth: .infinity).frame(height: 44)
                        }.buttonStyle(.plain)
                    }
                    .frame(maxWidth: 520).frame(maxHeight: .infinity)
                    .background(pal.color("card") ?? .black)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
                    .padding(.top, 44)
                }.transition(.move(edge: .bottom))
            }
        }
        .task { await m.load(); kids.refreshLink() }
        .onReceive(host.actPublisher) { x in if x.tab == "community" { m.handle(x, host: host) } }
        .onChange(of: host.reloadTick) { _ in Task { await m.load() } }
    }
}
