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
    var onPull: (() -> Void)? = nil          // 아래로 당겨 새로고침(안드로이드: 노선도 버스 · 맛집만)
    @StateObject private var open = PostOpen()
    @ViewBuilder private func pullable<C: View>(_ c: C) -> some View {
        if let f = onPull { c.refreshable { f(); try? await Task.sleep(nanoseconds: 700_000_000) } } else { c }
    }
    var body: some View {
        VStack(spacing: 0) {
            if !screen.head.isEmpty {
                VStack(spacing: 0) { ForEach(screen.head) { NodeView(node: $0, pal: pal).environment(\.inHead, true) } }
            }
            SwipeArea(screen: screen, cfg: swipe) {
                pullable(ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(screen.body) { NodeView(node: $0, pal: pal) }
                    }.padding(.bottom, 24)
                })
            }
            .overlay(alignment: .bottom) { if let f = Fab(screen.raw["fab"] as? [String: Any]) { FabButton(fab: f, pal: pal) } }          // 떠 있는 단추(게시판 '제보 글쓰기')
            if !screen.foot.isEmpty {
                VStack(spacing: 0) { ForEach(screen.foot) { NodeView(node: $0, pal: pal) } }
            }
        }
        .background(pal.color(screen.bg) ?? pal.color("bg") ?? Color(.systemBackground))
        .environmentObject(open)
        .environment(\.curScreen, screen)
        .onChange(of: "\(screen.name)|\(screen.raw["rev"] as? String ?? "")|\(screen.body.count)|\(ChipPick.sig(screen))") { _ in ChipPick.shared.clear() }          // 새 화면이 오면 먼저 켠 칩을 거두고 그 화면 값을 따른다
    }
}

/// 화면이 준 떠 있는 단추 {s, icon(SVG path), act}: 본문 아래 가운데 · 높이 40 · 금색 알약 · 아래 여백 16(안드로이드 ScreenView.drawFab).
struct Fab {
    let s: String, icon: String, act: Action
    init?(_ m: [String: Any]?) {
        guard let m = m, let s = m["s"] as? String, !s.isEmpty, let a = Action(m["act"] as? [String: Any]) else { return nil }
        self.s = String(s.prefix(24)); icon = String(((m["icon"] as? String) ?? "").prefix(900)); act = a
    }
}
struct FabButton: View {
    let fab: Fab
    let pal: Palette
    @EnvironmentObject var host: Host
    var body: some View {
        let gold = pal.color("gold") ?? .orange, on = pal.color("ongold") ?? .white
        Button { host.handle(fab.act) } label: {
            HStack(spacing: 6) {
                if !fab.icon.isEmpty { SVGIcon(d: fab.icon).fill(on).frame(width: 14, height: 14) }
                Text(fab.s).font(Typo.font(13, bold: true)).foregroundColor(on).lineLimit(1)
            }
            .padding(.horizontal, 24).frame(height: 40)
            .background(Capsule().fill(gold))
            .shadow(color: gold.opacity(0.35), radius: 7, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 16)
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
