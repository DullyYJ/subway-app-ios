import SwiftUI

/// 커뮤니티 탭(안드로이드 ShellCore.slotsOf): 맨 위 방식 칩 줄(/screen/cchips) + 고른 방식의 본문.
/// 방식: chat 소통방 · board 게시판 · news 소식 · set 설정. 기본은 소식.
@MainActor
final class CommunityModel: ObservableObject {
    static let modes = ["chat", "board", "news", "set"]
    @Published var mode: String
    @Published var head: Screen? = nil
    init() {
        let m = UserDefaults.standard.string(forKey: "cc_mode") ?? "news"
        mode = CommunityModel.modes.contains(m) ? m : "news"
        let a = CommandLine.arguments
        if let i = a.firstIndex(of: "-ccMode"), i + 1 < a.count, CommunityModel.modes.contains(a[i + 1]) { mode = a[i + 1] }
    }
    func setMode(_ m: String) {
        guard CommunityModel.modes.contains(m), m != mode else { return }
        mode = m; UserDefaults.standard.set(m, forKey: "cc_mode")
        Task { await loadHead() }
    }
    func loadHead() async {
        let body = "{\"cap\":\(Servers.cap),\"f\":{\"mode\":\(Json.q(mode))}}"
        if let d = try? await Net.request("POST", Servers.base + "/screen/cchips", body: body, timeout: 8), let s = try? Screen.parse(d) { head = s }
    }
}

struct CommunityTab: View {
    let pal: Palette
    @StateObject private var m = CommunityModel()
    @EnvironmentObject var host: Host
    var body: some View {
        VStack(spacing: 0) {
            if let h = m.head { VStack(spacing: 0) { ForEach(h.head) { NodeView(node: $0, pal: pal).environment(\.inHead, true) }; ForEach(h.body) { NodeView(node: $0, pal: pal) } } }
            Group {
                switch m.mode {
                case "board": BoardTab(pal: pal)
                case "set": SettingsView(pal: pal)
                case "chat": ChatPending(pal: pal)
                default: NewsView(pal: pal)
                }
            }
        }
        .background(pal.color("bg") ?? Color(.systemBackground))
        .task { await m.loadHead() }
        .onReceive(host.actPublisher) { x in
            guard x.tab == "community", x.a == "call", x.v.hasPrefix("cc.") else { return }
            m.setMode(String(x.v.dropFirst(3)))
        }
    }
}

/// 소통방은 다음 단계 — 그 사이 안내만.
struct ChatPending: View {
    let pal: Palette
    var body: some View {
        ZStack {
            (pal.color("bg") ?? Color(.systemBackground)).ignoresSafeArea()
            Text("소통방은 곧 열려요").font(Typo.font(14)).foregroundColor(pal.color("sub") ?? .gray)
        }
    }
}
