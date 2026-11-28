import SwiftUI
import UIKit

// 좌우 밀기(안드로이드 SwipeCore · ScreenView 의 mode 9 · ShellActivity.commSwipe 를 옮긴 것).
// ★ 원칙: 어디로 넘길지는 엔진이 화면에 담은 sw{l,r,lh,rh,lc,rc,k,t} 가 정한다. 앱은 몸짓을 알아보고, 그 행동을 그대로 실행하고, 그림(따라 움직이기 · 나가고 · 들어오기)만 그린다.

/// 판정값 · 그림 계산(순수 — 시험에서 바로 부른다). 값은 안드로이드 ScreenView 와 같다.
enum SwipeMath {
    static let minPt: CGFloat = 32          // 이만큼 밀면 넘긴다
    static let flingV: CGFloat = 520        // 빠르게 쓸기(pt/초) — 10pt 만 밀어도 넘긴다
    static let flingMin: CGFloat = 10
    static let drag: CGFloat = 88           // 고무줄 한계
    static let slide: CGFloat = 56          // 나가고 들어오는 거리
    static let lock: CGFloat = 1.0          // 가로가 세로의 이 배수 넘으면 가로로 잠근다

    /// 손가락이 dx 만큼 갔을 때 본문이 따라 움직이는 거리: 처음엔 1:1, 갈수록 고무줄처럼 느려진다.
    static func shift(_ dx: CGFloat) -> CGFloat {
        if dx == 0 { return 0 }
        return (dx < 0 ? -1 : 1) * drag * (1 - exp(-abs(dx) / drag))
    }
    /// 밀수록 살짝 옅어진다(최대 30%).
    static func alpha(_ shift: CGFloat) -> Double { 1 - 0.3 * Double(min(1, abs(shift) / drag)) }
    /// 놓았을 때 넘길지: 32pt 넘게 밀었거나, 빠르게 쓸었고(520pt/초) 10pt 이상 같은 쪽으로 갔다.
    static func fires(dx: CGFloat, vx: CGFloat) -> Bool {
        abs(dx) >= minPt || (abs(vx) >= flingV && abs(dx) >= flingMin && vx * dx > 0)
    }
    /// 가로로 잠글지(밀기 시작): 가로가 세로 이상이다.
    static func horizontal(dx: CGFloat, dy: CGFloat) -> Bool { abs(dx) > abs(dy) * lock }
}

struct SwipePair { var l: Action? = nil; var r: Action? = nil }

/// 화면 JSON 의 sw — 엔진이 정한 밀기 행동.
struct SwipeInfo {
    var l: Action? = nil, r: Action? = nil
    var lh = false, rh = false          // 그 행동이 머리(탭 칩) 쪽 것인가
    var lc = "", rc = ""                // (뉴스로 넘어갈 때) 먼저 켤 카테고리
    var k = ""                          // 이 화면이 서 있는 칸
    var t: [String: SwipePair] = [:]    // 칸마다 {왼쪽으로 밀면, 오른쪽으로 밀면}
    var has: Bool { l != nil || r != nil || !t.isEmpty }

    init?(_ raw: [String: Any]) {
        guard let w = raw["sw"] as? [String: Any] else { return nil }
        l = Action(w["l"] as? [String: Any]); r = Action(w["r"] as? [String: Any])
        lh = (w["lh"] as? NSNumber)?.boolValue ?? false; rh = (w["rh"] as? NSNumber)?.boolValue ?? false
        lc = String(((w["lc"] as? String) ?? "").prefix(20)); rc = String(((w["rc"] as? String) ?? "").prefix(20))
        k = String(((w["k"] as? String) ?? "").prefix(60))
        if let tm = w["t"] as? [String: Any], tm.count <= 40 {
            for (key, v) in tm {
                guard !key.isEmpty, key.count <= 60, let e = v as? [String: Any] else { continue }
                t[key] = SwipePair(l: Action(e["l"] as? [String: Any]), r: Action(e["r"] as? [String: Any]))
            }
        }
    }
}

/// 밀기를 이어 넘기는 기억(안드로이드 SwipeCore). 다음 칸 화면이 아직 오지 않았을 때 옛 화면의 sw 는 옛 칸 기준이라 그대로 쓰면 같은 칸을 또 요청한다.
/// 그래서 밀거나 칩을 누를 때마다 '고른 칸'을 적어 두고, 엔진이 준 표(sw.t)에서 그 칸의 다음 행동을 쓴다. 계산 없이 표를 찾아보기만 한다.
struct SwipeCore {
    private(set) var tbl: [String: SwipePair]? = nil
    private var tblTab = ""
    private(set) var cur = ""
    var hasTable: Bool { tbl != nil }

    /// 화면이 바뀌었다. 표가 있으면 그 화면의 표 · 칸으로 맞추고, 표 없는 sw 화면이면 표를 버린다. sw 없는 화면(뼈대 · 오류)은 앞의 표를 둔다.
    mutating func onScreen(_ i: SwipeInfo?, tab: String) {
        guard let i = i else { return }
        if !i.t.isEmpty { tbl = i.t; tblTab = tab; cur = i.k; return }
        if i.l != nil || i.r != nil { tbl = nil; cur = "" }
    }
    /// 밀려는 쪽(dir -1 = 왼쪽으로 밀기 · +1 = 오른쪽으로 밀기)의 행동. 표를 쓸 수 없으면 nil(그 화면 자체의 sw 를 쓴다).
    func pick(dir: Int, tab: String) -> Action? {
        guard let t = tbl, !cur.isEmpty, tab == tblTab, let e = t[cur] else { return nil }
        return dir == -1 ? e.l : e.r
    }
    /// 행동을 실행했다(밀기 · 칩 누르기): 그 행동의 칸이 표에 있으면 지금 고른 칸으로 적는다.
    mutating func note(_ a: Action) {
        guard let t = tbl, let v = a.v else { return }
        if a.a == "cat", t[v] != nil { cur = v }
        else if a.a == "call", v.hasPrefix("rh.tab."), t[String(v.dropFirst(7))] != nil { cur = String(v.dropFirst(7)) }       // 경로 결과 카드: 탭 이름이 칸 이름
    }
}

/// 한 밀기 자리의 기억(화면이 바뀌어도 이어진다).
@MainActor
final class SwipeState: ObservableObject {
    var core = SwipeCore()
    var seen = ""
}

/// 이 화면이 좌우 밀기를 쓰는 자리인가 + 행동을 어떻게 실행하나.
struct SwipeCfg {
    let tab: String
    let handle: (Action) -> Void
    let ok: () -> Bool                  // 지금 밀어도 되는가(팝업이 떠 있으면 안 된다 · 홈은 경로가 있고 탑승 중이 아닐 때만)
    @MainActor init(tab: String, host: Host, ok: @escaping () -> Bool = { true }) {
        self.tab = tab
        self.handle = { [weak host] a in host?.handle(a) }
        self.ok = { [weak host] in
            guard let h = host else { return false }
            return h.reco == nil && h.pop == nil && h.cmPop == nil && h.menuPop == nil && h.locd == nil && h.cmb == nil && ok()
        }
    }
}

/// 밀기 그림(안드로이드 ScreenView swOx · swAl): 손가락을 따라 움직이다 → 놓으면 나가고(0.11초) → 새 화면이 오면 반대쪽에서 들어온다(0.34초). 안 넘기면 스프링으로 제자리.
@MainActor
final class SwipeFX: ObservableObject {
    static let shared = SwipeFX()
    @Published var ox: CGFloat = 0
    @Published var al: Double = 1
    private(set) var pendDir = 0
    private var pendAt = Date.distantPast
    private var gen = 0

    func dragTo(_ dx: CGFloat) {
        gen += 1; pendDir = 0
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { let s = SwipeMath.shift(dx); ox = s; al = SwipeMath.alpha(s) }
    }
    /// 안 넘기고 놓았다: 스프링으로 제자리.
    func settle() {
        gen += 1
        withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) { ox = 0; al = 1 }
    }
    /// 넘기기로 했다: 가던 쪽으로 계속 미끄러지며 사라지고(0.11초) → action(새 화면을 부른다) → 새 화면이 오면 arrived() 가 들여보낸다. 끝내 안 오면(0.45초) 제자리에서 다시 나타난다.
    func fire(dir: Int, from shift: CGFloat, action: @escaping () -> Bool) {
        gen += 1; let g = gen
        let tg: CGFloat = shift < 0 ? -SwipeMath.slide : SwipeMath.slide
        withAnimation(.easeOut(duration: 0.11)) { ox = tg; al = 0 }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 110_000_000)
            guard g == gen else { return }
            pendDir = dir; pendAt = Date()
            if !action() { pendDir = 0; reappear(from: tg); return }
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard g == gen, pendDir != 0 else { return }
            pendDir = 0; reappear(from: tg)
        }
    }
    private func reappear(from tg: CGFloat) {
        withAnimation(.easeOut(duration: 0.42)) { ox = 0; al = 1 }
    }
    /// 새 화면이 왔다: 넘기는 중이었으면 반대쪽(손가락이 간 반대)에서 미끄러져 들어온다. 투명이 아니라 0.25 에서 시작한다(빈 틈이 안 보이게).
    func arrived() {
        guard pendDir != 0, Date().timeIntervalSince(pendAt) < 0.6 else { return }
        let d = pendDir; pendDir = 0; gen += 1; let g = gen
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { ox = -CGFloat(d) * SwipeMath.slide; al = 0.25 }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 24_000_000)
            guard g == gen else { return }
            withAnimation(.timingCurve(0.22, 0.8, 0.3, 1, duration: 0.34)) { ox = 0; al = 1 }
        }
    }
}

/// 본문에 밀기 그림만 입힌다(머리 · 꼬리는 그대로).
@MainActor
struct SwipeShift<C: View>: View {
    @ObservedObject private var fx = SwipeFX.shared
    let on: Bool
    let content: C
    var body: some View { content.offset(x: on ? fx.ox : 0).opacity(on ? fx.al : 1) }
}

/// 밀기 몸짓 자리: 본문 영역 안에서 시작한 가로 밀기를 알아본다. 안드로이드와 같이 입력칸 · 가로로 밀리는 줄에서 시작한 몸짓은 무시한다.
@MainActor
struct SwipeArea<Content: View>: View {
    let screen: Screen
    let cfg: SwipeCfg?
    let content: () -> Content
    @StateObject private var st = SwipeState()

    init(screen: Screen, cfg: SwipeCfg?, @ViewBuilder content: @escaping () -> Content) {
        self.screen = screen; self.cfg = cfg; self.content = content
    }

    private var sig: String { "\(screen.name)|\(screen.raw["rev"] as? String ?? "")|\(screen.body.count)" }
    private func sync() {
        let s = sig
        if st.seen == s { return }
        st.seen = s
        st.core.onScreen(SwipeInfo(screen.raw), tab: cfg?.tab ?? "")
    }
    private func can() -> Bool {
        guard let cfg = cfg, cfg.ok() else { return false }
        sync()
        return (SwipeInfo(screen.raw)?.has ?? false) || st.core.hasTable
    }
    /// 안드로이드 commSwipe: 표에서 이어 넘길 행동이 있으면 그것을, 없으면 화면 자체의 sw 를 쓴다. 넘길 곳이 없으면(끝) false.
    private func step(_ dir: Int) -> Bool {
        guard let cfg = cfg else { return false }
        sync()
        let info = SwipeInfo(screen.raw)
        var a = dir == -1 ? info?.l : info?.r
        var cat = dir == -1 ? (info?.lc ?? "") : (info?.rc ?? "")
        if let c = st.core.pick(dir: dir, tab: cfg.tab) { a = c; cat = "" }
        guard let act = a else { return false }
        if !cat.isEmpty { UserDefaults.standard.set(cat, forKey: "news_cat") }       // 뉴스로 넘어갈 때 먼저 켤 카테고리(엔진이 정함)
        st.core.note(act)
        ChipPick.shared.light(act, in: screen)                                    // 위 칩 줄도 새 화면을 기다리지 않고 그 칸을 켠다(칩을 눌렀을 때와 같다)
        cfg.handle(act)
        return true
    }
    private func finish(_ dx: CGFloat, _ vx: CGFloat) {
        let fx = SwipeFX.shared
        if SwipeMath.fires(dx: dx, vx: vx) {
            let dir = dx < 0 ? -1 : 1
            fx.fire(dir: dir, from: SwipeMath.shift(dx)) { step(dir) }
        } else { fx.settle() }
    }

    var body: some View {
        Color.clear
            .overlay(SwipeShift(on: cfg != nil, content: content()))
            .background(SwipeSurface(enabled: cfg != nil, begin: { can() }, drag: { SwipeFX.shared.dragTo($0) }, end: { finish($0, $1) }, cancel: { SwipeFX.shared.settle() }))
            .onAppear { sync(); SwipeFX.shared.arrived() }
            .onChange(of: sig) { _ in sync(); SwipeFX.shared.arrived() }
    }
}

/// 창 전체에 가로 팬 인식기를 하나 붙이고, 이 자리(본문) 안에서 시작한 것만 받는다. 세로 스크롤과 함께 인식하되 가로가 더 크면 세로 스크롤을 끊어 목록이 흔들리지 않게 한다.
struct SwipeSurface: UIViewRepresentable {
    var enabled: Bool
    var begin: () -> Bool
    var drag: (CGFloat) -> Void
    var end: (CGFloat, CGFloat) -> Void
    var cancel: () -> Void

    func makeCoordinator() -> Coord { Coord() }
    func makeUIView(context: Context) -> SwipeAnchor {
        let v = SwipeAnchor()
        v.isUserInteractionEnabled = false
        v.backgroundColor = .clear
        v.coord = context.coordinator
        context.coordinator.anchor = v
        context.coordinator.p = self
        return v
    }
    func updateUIView(_ v: SwipeAnchor, context: Context) {
        context.coordinator.p = self
        context.coordinator.pan?.isEnabled = enabled
    }
    static func dismantleUIView(_ v: SwipeAnchor, coordinator: Coord) { coordinator.detach() }

    @MainActor
    final class Coord: NSObject, UIGestureRecognizerDelegate {
        var p: SwipeSurface?
        weak var anchor: SwipeAnchor?
        var pan: UIPanGestureRecognizer?
        private weak var win: UIWindow?
        private var live = false

        func attach(to w: UIWindow?) {
            guard let w = w, win !== w else { return }
            detach()
            let g = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
            g.delegate = self
            g.cancelsTouchesInView = false
            g.delaysTouchesBegan = false
            g.delaysTouchesEnded = false
            g.isEnabled = p?.enabled ?? false
            w.addGestureRecognizer(g)
            pan = g; win = w
        }
        func detach() {
            if let g = pan { win?.removeGestureRecognizer(g) }
            pan = nil; win = nil
        }

        /// 시작한 자리가 이 본문 안이고, 입력칸 · 가로로 밀리는 줄이 아닌가.
        private func startOK(_ g: UIPanGestureRecognizer) -> Bool {
            guard let a = anchor, let w = a.window, w === win, a.superview != nil, !a.isHidden else { return false }
            let t = g.translation(in: w), cur = g.location(in: w)
            let start = CGPoint(x: cur.x - t.x, y: cur.y - t.y)
            guard a.convert(a.bounds, to: w).contains(start) else { return false }
            let hit = w.hitTest(start, with: nil)
            if let hv = hostView(a), let h = hit, !h.isDescendant(of: hv) { return false }          // 위에 시트 · 다른 화면이 덮고 있다
            var v: UIView? = hit
            while let x = v {
                if x is UITextField || x is UITextView { return false }
                if let sv = x as? UIScrollView, sv.isScrollEnabled, sv.contentSize.width > sv.bounds.width + 24 { return false }       // 가로로 밀리는 줄(칩 · 타임라인)
                v = x.superview
            }
            return true
        }

        /// 이 자리를 품은 SwiftUI 호스팅 뷰(시트는 따로 호스팅 뷰를 가진다).
        private func hostView(_ v: UIView?) -> UIView? {
            var x = v
            while let y = x { if String(describing: type(of: y)).contains("HostingView") { return y }; x = y.superview }
            return nil
        }

        func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
            guard let pg = g as? UIPanGestureRecognizer, p?.enabled == true else { return false }
            let t = pg.translation(in: pg.view)
            guard SwipeMath.horizontal(dx: t.x, dy: t.y), startOK(pg) else { return false }
            return p?.begin() ?? false
        }
        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith o: UIGestureRecognizer) -> Bool { true }

        @objc func onPan(_ g: UIPanGestureRecognizer) {
            let dx = g.translation(in: g.view).x
            switch g.state {
            case .began:
                live = true
                cutScroll(g)
                p?.drag(dx)
            case .changed:
                if live { p?.drag(dx) }
            case .ended:
                if live { p?.end(dx, g.velocity(in: g.view).x) }
                live = false
            case .cancelled, .failed:
                if live { p?.cancel() }
                live = false
            default: break
            }
        }
        /// 가로로 밀기 시작 — 바닥의 세로 스크롤을 끊는다(비스듬히 밀어도 목록이 흔들리지 않게).
        private func cutScroll(_ g: UIPanGestureRecognizer) {
            guard let w = win else { return }
            let t = g.translation(in: w), cur = g.location(in: w)
            var v: UIView? = w.hitTest(CGPoint(x: cur.x - t.x, y: cur.y - t.y), with: nil)
            while let x = v {
                if let sv = x as? UIScrollView { sv.panGestureRecognizer.isEnabled = false; sv.panGestureRecognizer.isEnabled = true; break }
                v = x.superview
            }
        }
    }
}

final class SwipeAnchor: UIView {
    weak var coord: SwipeSurface.Coord?
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let w = window { coord?.attach(to: w) } else { coord?.detach() }
    }
}
