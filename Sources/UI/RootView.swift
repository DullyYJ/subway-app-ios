import SwiftUI

struct RootView: View {
    @StateObject private var host = Host()
    @AppStorage("theme") private var theme = ""
    @Environment(\.scenePhase) private var phase
    @State private var hdrAt = Int(Date().timeIntervalSince1970 * 1000)          // 맨 위 문구를 받은 때(켤 때 · 10분마다만 바뀐다 — 안드로이드 loadHdr/hdrTick)
    private var pal: Palette { theme == "dark" ? .dark : .light }          // 안드로이드 ShellCore.theme: dark 아니면 모두 파스텔(밝은 쪽) — 폰의 다크 모드를 따라가지 않는다

    var body: some View {
        if NodeDemo.on { NodeDemoView(pal: pal) } else { mainBody }
    }

    private var mainBody: some View {
        VStack(spacing: 0) {
            // 맨 위 흐르는 응원 문구(서버 /screen/hdr)
            RemoteScreenInline(path: "/screen/hdr?tz=\(TimeZone.current.secondsFromGMT() / 60)&now=\(hdrAt)", method: "GET", pal: pal, cacheKey: "hdr")
                .frame(height: 30)
            // 본문: 켜진 탭
            ZStack(alignment: .bottom) {
                TabContent(tab: host.tab, pal: pal)
                if let r = host.reco { DlgCard(screen: r, pal: pal) { host.recoAct($0) } }
                if let p = host.pop { DlgCard(screen: p, pal: pal) { _ in host.pop = nil } }
                if let c = host.cmPop {          // 출·퇴근 시각 고르기 팝업(바깥을 누르면 취소)
                    DlgCard(screen: c, pal: pal) { _ in host.actPublisher.send(Host.TabAction(tab: "community", a: "call", v: "tp.cancel", id: "", key: "")) }
                }
                Group {
                    if let l = host.locd {          // 위치 정보 이용 안내(바깥을 눌러도 닫히지 않는다 — 동의/거부로만). 위에서 미끄러져 내려앉고(440ms), 닫힐 땐 아래로 흐려지며 사라진다(240ms)
                        DlgCard(screen: l, pal: pal, act: { _ in }, slide: true)
                            .transition(.asymmetric(insertion: .identity, removal: .opacity.combined(with: .offset(y: 30))))
                    }
                }.animation(.timingCurve(0.4, 0, 0.8, 0.6, duration: 0.24), value: host.locd == nil)
                if let b = host.cmb { DlgCard(screen: b, pal: pal) { _ in host.cmbAct("cmb.ok") } }          // 출퇴근 브리핑 창(알림을 누르면)
                if let t = host.toast {
                    Text(t).font(Typo.font(12)).foregroundColor(.white).padding(10).background(Color.black.opacity(0.8)).cornerRadius(10).padding(.bottom, 12)
                }
            }
            // 아래 탭 막대(서버 /screen/tabs)
            RemoteScreenInline(path: "/screen/tabs", payload: "{\"cap\":\(Servers.cap),\"f\":{\"tab\":\"\(host.tab)\"}}", pal: pal, cacheKey: "tabs|" + host.tab, ttl: 600)
                .frame(height: 56)
        }
        .background(pal.color("bg") ?? Color(.systemBackground))
        .kidsHubLayer(pal: pal)            // 반드시 environmentObject(host) 보다 안쪽(먼저) — 층이 Host 를 환경에서 읽는다
        .environmentObject(host)
        .onAppear { RideLoop.shared.host = host; CommuteAlarm.attach(host); FirstRun.host = host; FirstRun.begin() }
        // 위젯 · 라이브 액티비티가 앱을 열 때: gildongmu://tab/<탭이름> 이면 그 탭으로(안드로이드 위젯: 커뮤니티 탭)
        .onOpenURL { u in
            guard u.scheme == "gildongmu", u.host == "tab", let t = u.pathComponents.dropFirst().first, Host.tabNames.contains(t) else { return }
            host.tab = t
        }
        .task { await prefetchTabBars() }
        .task { await prefetchScreens() }
        .task {          // 맨 위 문구는 10분마다(앞에 있을 때만) 새로 받는다
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 600_000_000_000)
                if UIApplication.shared.applicationState == .active { hdrAt = Int(Date().timeIntervalSince1970 * 1000) }
            }
        }
        .onChange(of: phase) { p in if p == .active { CommuteAlarm.refresh() } }          // 앱이 앞으로 올 때마다 출퇴근 알림 4주 창을 다시 민다(안드로이드 onCreate 의 rescheduleAsync)
        .preferredColorScheme(theme == "dark" ? .dark : .light)
    }

    /// 켠 뒤 잠깐 있다가 아직 안 본 탭의 화면(쇼핑 · 소식 · 게시판)을 미리 받아 `ScreenCache` 에 둔다(안드로이드 prefetchTabs) — 처음 눌러도 빈 뼈대 없이 바로 뜬다.
    @MainActor private func prefetchScreens() async {
        try? await Task.sleep(nanoseconds: 4_000_000_000)
        if host.tab != "shop" { await ShopModel().load() }
        if host.tab != "community" { await NewsModel().load(); await BoardModel().load() }
    }

    /// 아래 탭 막대를 탭마다 미리 받아 둔다(안드로이드 prefetchTabs) — 처음 옮길 때도 켜진 칸 표시가 바로 바뀐다.
    @MainActor private func prefetchTabBars() async {
        for t in Host.tabNames where t != host.tab {
            let k = "tabs|" + t
            if ScreenCache.shared.fresh(k, within: 600) { continue }
            let body = "{\"cap\":\(Servers.cap),\"f\":{\"tab\":\"\(t)\"}}"
            if let s = try? await Net.screen("/screen/tabs", body: body) { ScreenCache.shared.put(k, s) }
        }
    }
}

/// 머리글 · 탭 막대처럼 스크롤 없이 노드만 쌓는 작은 서버 화면.
struct RemoteScreenInline: View {
    let path: String
    var method: String = "POST"
    var payload: String? = nil
    let pal: Palette
    var cacheKey: String? = nil          // 있으면 그 열쇠의 옛 화면을 먼저 보이고 새로 받으면 바꾼다(안드로이드 hdr · tabs|탭)
    var ttl: TimeInterval = 0            // 받은 지 이 초 안이면 다시 받지 않는다(탭 막대 10분)
    @StateObject private var loader = ScreenLoader()
    private var key: String { "\(path)|\(payload ?? "")" }
    var body: some View {
        Group {
            if let s = loader.screen { VStack(spacing: 0) { ForEach(s.body) { NodeView(node: $0, pal: pal) } } }
            else { Color.clear }
        }
        .task(id: key) {
            if let k = cacheKey {
                if let c = ScreenCache.shared.get(k) { loader.screen = c }
                if ttl > 0 && ScreenCache.shared.fresh(k, within: ttl) { return }
            }
            await loader.load(path: path, method: method, body: payload)
            if let k = cacheKey, loader.error == nil, let s = loader.screen { ScreenCache.shared.put(k, s) }
        }
    }
}

/// 켜진 탭의 본문. 연결된 탭: 커뮤니티 · 쇼핑. 홈 · 노선도 · 맛집은 다음 단계(그동안 개발용 화면 탐색기).
struct TabContent: View {
    let tab: String
    let pal: Palette
    var body: some View {
        Group {
            switch tab {
            case "community": CommunityTab(pal: pal)
            case "shop": ShopTab(pal: pal)
            case "food": FoodTab(pal: pal)
            case "home": HomeTab(pal: pal)
            case "map": MapTab(pal: pal)
            default: DevExplorer(pal: pal, title: tab + " (다음 단계에서 연결)", start: "/screen/settings?cap=8")
            }
        }
        .modifier(TabFadeIn())
        .id(tab)
    }
}

/// 탭을 옮기면(켜진 탭을 다시 눌러도) 새 화면이 살짝 떠올라 자리잡는다: 흐림 0.85 → 1, 아래 4pt → 제자리, 180ms,
/// 곡선 (0.32, 0.72, 0, 1) — 안드로이드 ShellActivity.tabSettle. 소통방도 같다.
struct TabFadeIn: ViewModifier {
    @EnvironmentObject private var host: Host
    @State private var a = 0.85
    @State private var y: CGFloat = 4
    func body(content: Content) -> some View {
        content.opacity(a).offset(y: y)
            .onAppear { settle() }
            .onChange(of: host.settleTick) { _ in
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { a = 0.85; y = 4 }
                DispatchQueue.main.async { settle() }
            }
    }
    private func settle() { withAnimation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.18)) { a = 1; y = 0 } }
}
