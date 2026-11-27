import SwiftUI

/// 서버 화면 하나를 받아(POST/GET) 그린다. 받는 동안 이전 화면을 유지하고, 실패하면 이유를 보여 준다.
@MainActor
final class ScreenLoader: ObservableObject {
    @Published var screen: Screen? = nil
    @Published var error: String? = nil
    @Published var loading = false
    func load(path: String, method: String = "POST", body: String? = nil) async {
        loading = true; defer { loading = false }
        do { screen = try await Net.screen(path, method: method, body: body); error = nil }
        catch { self.error = error.localizedDescription }
    }
}

/// 서버 화면 하나: 머리(head)는 위에 고정 · 꼬리(foot)는 아래에 고정 · 본문(body)만 스크롤(안드로이드 ScreenView 와 같다).
/// swipe 를 주면 본문을 좌우로 밀어 엔진이 정한 칸으로 넘긴다(EngineSwipe.swift).
struct ScreenBody: View {
    let screen: Screen
    let pal: Palette
    var swipe: SwipeCfg? = nil
    @StateObject private var open = PostOpen()
    var body: some View {
        VStack(spacing: 0) {
            if !screen.head.isEmpty {
                VStack(spacing: 0) { ForEach(screen.head) { NodeView(node: $0, pal: pal).environment(\.inHead, true) } }
            }
            SwipeArea(screen: screen, cfg: swipe) {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(screen.body) { NodeView(node: $0, pal: pal) }
                    }.padding(.bottom, 24)
                }
            }
            if !screen.foot.isEmpty {
                VStack(spacing: 0) { ForEach(screen.foot) { NodeView(node: $0, pal: pal) } }
            }
        }
        .background(pal.color(screen.bg) ?? pal.color("bg") ?? Color(.systemBackground))
        .environmentObject(open)
        .onChange(of: "\(screen.name)|\(screen.raw["rev"] as? String ?? "")|\(screen.body.count)") { _ in ChipPick.shared.clear() }          // 새 화면이 오면 먼저 켠 칩을 거두고 그 화면 값을 따른다
    }
}

struct RemoteScreen: View {
    let path: String
    var method: String = "POST"
    var payload: String? = nil
    let pal: Palette
    @StateObject private var loader = ScreenLoader()
    @EnvironmentObject var host: Host
    private var key: String { "\(path)|\(method)|\(payload ?? "")|\(host.reloadTick)" }

    var body: some View {
        ZStack {
            if let s = loader.screen { ScreenBody(screen: s, pal: pal) }
            else { (pal.color("bg") ?? Color(.systemBackground)).ignoresSafeArea() }
            if loader.loading && loader.screen == nil { ProgressView() }
            if let e = loader.error {
                VStack { Spacer(); Text(e).font(Typo.font(12)).foregroundColor(.white).padding(10).background(Color.red.opacity(0.85)).cornerRadius(8).padding() }
            }
        }
        .task(id: key) { await loader.load(path: path, method: method, body: payload) }
    }
}
