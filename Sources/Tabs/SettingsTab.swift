import SwiftUI

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
        return "{\"id\":\(Json.q(id)),\"np\":{\(np)},\"ovl\":0,\"sam\":0,\"samw\":0,\"cm\":0,\"errn\":0,\"pgs\":[],\"rl\":\(rl),\"th\":\(Json.q(theme))}"
    }
    private func url(_ p: String? = nil) -> String {
        let f = facts().addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        return Servers.base + "/screen/settings?cap=\(Servers.cap)" + (p.map { "&p=\($0)" } ?? "") + "&f=" + f
    }
    func load() async {
        do { let d = try await Net.request("GET", url(), timeout: 9); screen = try Screen.parse(d); error = nil }
        catch { if screen == nil { self.error = "설정을 받지 못했어요" } }
    }
    private func openSub(_ p: String) {
        subOpen = true; sub = nil
        Task { if let d = try? await Net.request("GET", url(p), timeout: 9), let s = try? Screen.parse(d) { sub = s } }
    }
    func handle(_ x: Host.TabAction, host: Host) {
        switch x.a {
        case "set":
            if x.key.hasPrefix("n.") {
                let k = String(x.key.dropFirst(2))
                if SettingsModel.notif.contains(k) { ud.set(x.on ? "1" : "0", forKey: "np_" + k); Task { await load() } }
            } else if x.key == "rl" { ud.set(x.on ? "0" : "1", forKey: "ride_log_off"); Task { await load() } }
        case "sel":
            if x.v == "dark" || x.v == "pastel" { ud.set(x.v, forKey: "theme"); Task { await load() } }
        case "call":
            switch x.v {
            case "saveId":
                let raw = ud.string(forKey: "field.cid") ?? ""
                let e = BoardModel.idError(raw)
                if !e.isEmpty { host.say(e); return }
                let id = raw.trimmingCharacters(in: .whitespaces)
                ud.set(id, forKey: "comm_id"); host.say("아이디가 저장되었어요: " + id); Task { await load() }
            case "clearId":
                ud.set("", forKey: "comm_id"); host.clearField("cid"); host.say("아이디가 삭제되었어요"); Task { await load() }
            case "pol.privacy": openSub("polp")
            case "pol.location": openSub("poll")
            case "pol.opensource": openSub("polo")
            default:
                if x.v.hasPrefix("tab.") { host.call(x.v) } else { host.say("아직 옮기는 중이에요") }
            }
        case "web": host.say("아직 옮기는 중이에요")
        default: break
        }
    }
}

struct SettingsView: View {
    let pal: Palette
    @StateObject private var m = SettingsModel()
    @EnvironmentObject var host: Host
    var body: some View {
        ZStack {
            if let s = m.screen { ScreenBody(screen: s, pal: pal) }
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
        .task { await m.load() }
        .onReceive(host.actPublisher) { x in if x.tab == "community" { m.handle(x, host: host) } }
        .onChange(of: host.reloadTick) { _ in Task { await m.load() } }
    }
}
