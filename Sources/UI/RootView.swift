import SwiftUI

struct RootView: View {
    @StateObject private var host = Host()
    @AppStorage("theme") private var theme = ""
    @Environment(\.scenePhase) private var phase
    private var pal: Palette { theme == "dark" ? .dark : .light }          // 안드로이드 ShellCore.theme: dark 아니면 모두 파스텔(밝은 쪽) — 폰의 다크 모드를 따라가지 않는다

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
                if let r = host.reco { DlgCard(screen: r, pal: pal) { host.recoAct($0) } }
                if let p = host.pop { DlgCard(screen: p, pal: pal) { _ in host.pop = nil } }
                if let c = host.cmPop {          // 출·퇴근 시각 고르기 팝업(바깥을 누르면 취소)
                    DlgCard(screen: c, pal: pal) { _ in host.actPublisher.send(Host.TabAction(tab: "community", a: "call", v: "tp.cancel", id: "", key: "")) }
                }
                if let l = host.locd { DlgCard(screen: l, pal: pal) { _ in } }          // 위치 정보 이용 안내(바깥을 눌러도 닫히지 않는다 — 동의/거부로만)
                if let b = host.cmb { DlgCard(screen: b, pal: pal) { _ in host.cmbAct("cmb.ok") } }          // 출퇴근 브리핑 창(알림을 누르면)
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
        .onAppear { RideLoop.shared.host = host; CommuteAlarm.attach(host); FirstRun.host = host; FirstRun.begin() }
        .onChange(of: phase) { p in if p == .active { CommuteAlarm.refresh() } }          // 앱이 앞으로 올 때마다 출퇴근 알림 4주 창을 다시 민다(안드로이드 onCreate 의 rescheduleAsync)
        .preferredColorScheme(theme == "dark" ? .dark : .light)
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
