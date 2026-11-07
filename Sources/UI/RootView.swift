import SwiftUI

struct RootView: View {
    @StateObject private var host = Host()
    @Environment(\.colorScheme) private var scheme
    @AppStorage("theme") private var theme = ""
    private var pal: Palette { theme == "dark" ? .dark : theme == "pastel" ? .light : (scheme == .dark ? .dark : .light) }

    var body: some View {
        if NodeDemo.on { NodeDemoView(pal: pal) } else { mainBody }
    }

    private var mainBody: some View {
        VStack(spacing: 0) {
            // 맨 위 흐르는 응원 문구(서버 /screen/hdr)
            RemoteScreenInline(path: "/screen/hdr?tz=\(TimeZone.current.secondsFromGMT() / 60)&now=\(Int(Date().timeIntervalSince1970 * 1000))", method: "GET", pal: pal)
                .frame(height: 30)
            // 본문: 켜진 탭
            ZStack(alignment: .bottom) {
                TabContent(tab: host.tab, pal: pal)
                if let t = host.toast {
                    Text(t).font(Typo.font(12)).foregroundColor(.white).padding(10).background(Color.black.opacity(0.8)).cornerRadius(10).padding(.bottom, 12)
                }
            }
            // 아래 탭 막대(서버 /screen/tabs)
            RemoteScreenInline(path: "/screen/tabs", payload: "{\"cap\":\(Servers.cap),\"f\":{\"tab\":\"\(host.tab)\"}}", pal: pal)
                .frame(height: 56)
        }
        .background(pal.color("bg") ?? Color(.systemBackground))
        .kidsHubLayer(pal: pal)            // 반드시 environmentObject(host) 보다 안쪽(먼저) — 층이 Host 를 환경에서 읽는다
        .environmentObject(host)
        .preferredColorScheme(theme == "dark" ? .dark : theme == "pastel" ? .light : nil)
    }
}

/// 머리글 · 탭 막대처럼 스크롤 없이 노드만 쌓는 작은 서버 화면.
struct RemoteScreenInline: View {
    let path: String
    var method: String = "POST"
    var payload: String? = nil
    let pal: Palette
    @StateObject private var loader = ScreenLoader()
    private var key: String { "\(path)|\(payload ?? "")" }
    var body: some View {
        Group {
            if let s = loader.screen { VStack(spacing: 0) { ForEach(s.body) { NodeView(node: $0, pal: pal) } } }
            else { Color.clear }
        }
        .task(id: key) { await loader.load(path: path, method: method, body: payload) }
    }
}

/// 켜진 탭의 본문. 연결된 탭: 커뮤니티 · 쇼핑. 홈 · 노선도 · 맛집은 다음 단계(그동안 개발용 화면 탐색기).
struct TabContent: View {
    let tab: String
    let pal: Palette
    var body: some View {
        switch tab {
        case "community": CommunityTab(pal: pal)
        case "shop": ShopTab(pal: pal)
        case "food": FoodTab(pal: pal)
        case "home": HomeTab(pal: pal)
        case "map": MapTab(pal: pal)
        default: DevExplorer(pal: pal, title: tab + " (다음 단계에서 연결)", start: "/screen/settings?cap=8")
        }
    }
}
