import SwiftUI
import UIKit

/// 길동무 친구들 장면 — SwiftUI Canvas(비동기 렌더)에 SceneCore 가 그리고, UIKit 터치 층이 손가락을 넘긴다.
/// 앱은 그리기만 한다: 장면 값(json)은 엔진이 정해 준 그대로 SceneDriver 에 넘긴다.
struct SceneView: View {
    let json: String
    /// 평소 칸 높이(pt). 인사로 카드가 늘어나면 전체 높이는 이보다 커지고, 장면은 이 높이로 만들어 둔 채 늘어난 만큼 인도만 늘려 그린다.
    var baseH: CGFloat? = nil
    @ObservedObject private var d = SceneDriver.shared
    @Environment(\.colorScheme) private var cs
    @Environment(\.displayScale) private var scale

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                TimelineView(.animation(minimumInterval: d.hot ? nil : 1.0 / 60.0, paused: !d.isReady)) { _ in
                    Canvas(opaque: false, rendersAsynchronously: true) { gc, _ in
                        gc.withCGContext { cg in d.drawFrame(cg) }
                    }
                }
                SceneTouchLayer(driver: d)
                if !d.tag.isEmpty {
                    Text(d.tag).font(.system(size: 10.5, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 9).padding(.vertical, 3)
                        .background(Capsule().fill(Color(red: 12 / 255, green: 18 / 255, blue: 34 / 255).opacity(0.55)))
                        .padding(.leading, 8).padding(.top, 7).allowsHitTesting(false)
                }
            }
            .onAppear { d.load(); d.resume(); push(geo.size) }
            .onChange(of: geo.size) { push($0); if let b = baseH { d.helloStretch(Double(max(0, geo.size.height - b))) } }
            .onChange(of: cs) { _ in push(geo.size) }
            .onChange(of: json) { _ in push(geo.size) }
        }
    }
    private func push(_ s: CGSize) {
        d.layout(Double(s.width), Double(baseH ?? s.height), Double(scale), cs == .dark)
        if !json.isEmpty { d.apply(json) }
    }
}

/// 손가락을 SceneDriver 로 넘기는 투명한 UIKit 층. 캐릭터를 잡으면(꾹 누르기) 위쪽 스크롤을 잠시 막고, 놓으면 푼다.
struct SceneTouchLayer: UIViewRepresentable {
    let driver: SceneDriver
    func makeUIView(context: Context) -> SceneTouchUIView { SceneTouchUIView(driver) }
    func updateUIView(_ v: SceneTouchUIView, context: Context) {}
}

final class SceneTouchUIView: UIView {
    private let driver: SceneDriver
    private var tracking = false
    private weak var scroll: UIScrollView?
    private var downPt = CGPoint.zero
    private var tickTimer: Timer?, lpTimer: Timer?
    private var ignoreUp = false
    private static let tickSec = 1.0, lpSec = 3.0, slop: CGFloat = 12

    init(_ d: SceneDriver) { driver = d; super.init(frame: .zero); backgroundColor = .clear; isMultipleTouchEnabled = false; isUserInteractionEnabled = true }
    required init?(coder: NSCoder) { fatalError() }

    private func upScroll() -> UIScrollView? {
        var v: UIView? = superview
        while let x = v { if let s = x as? UIScrollView { return s }; v = x.superview }
        return nil
    }
    private func cancelTimers() { tickTimer?.invalidate(); lpTimer?.invalidate(); tickTimer = nil; lpTimer = nil }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)
        downPt = p
        scroll = upScroll()
        if driver.helloActive() {                                  // 인사 중: 손가락은 이 카드가 받는다(스크롤 · 눌림 없음) — 한 번 톡 치면 일찍 끝낸다
            scroll?.panGestureRecognizer.isEnabled = false
            tracking = false; ignoreUp = false
            return
        }
        tracking = driver.touchDown(Double(p.x), Double(p.y))
        if tracking {
            driver.onHeld = { [weak self] in self?.scroll?.panGestureRecognizer.isEnabled = false }
        }
        cancelTimers()
        tickTimer = Timer.scheduledTimer(withTimeInterval: Self.tickSec, repeats: false) { [weak self] _ in self?.tick() }
        lpTimer = Timer.scheduledTimer(withTimeInterval: Self.lpSec, repeats: false) { [weak self] _ in self?.longPress() }
    }
    /// 1초: 배경에 손이 올라가 있다 → 짧게 '톡'(진행 중이라는 알림). 인사 대본이 있고 장면이 준비됐을 때만.
    private func tick() {
        guard driver.helloReady(), SceneOpen.helloNow() != nil else { return }
        let g = UIImpactFeedbackGenerator(style: .light); g.impactOccurred(intensity: 0.8)
    }
    /// 3초: 카드가 늘어나 친구들이 인사한다.
    private func longPress() {
        guard driver.helloReady(), let plan = SceneOpen.helloNow() else { return }
        if tracking { driver.touchUp(); tracking = false }         // 잡고 있던 캐릭터는 놓는다
        let seed = Int64(truncatingIfNeeded: DispatchTime.now().uptimeNanoseconds)
        guard driver.helloStart(plan, seed) else { return }
        ignoreUp = true                                            // 이 누름은 여기서 끝(놓을 때 '일찍 끝내기'로 안 친다)
        scroll?.panGestureRecognizer.isEnabled = false
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        driver.onHelloEnd = { [weak self] in self?.scroll?.panGestureRecognizer.isEnabled = true; self?.scroll = nil }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)
        if hypot(p.x - downPt.x, p.y - downPt.y) > Self.slop { cancelTimers() }
        guard tracking else { return }
        driver.touchMove(Double(p.x), Double(p.y))
    }
    private func finish(ended: Bool) {
        cancelTimers()
        if tracking { driver.touchUp(); tracking = false }
        if driver.helloActive() {
            if ended { if ignoreUp { ignoreUp = false } else { driver.helloSkip() } }
            return                                                 // 스크롤은 인사가 끝날 때(onHelloEnd) 푼다
        }
        scroll?.panGestureRecognizer.isEnabled = true; scroll = nil
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { finish(ended: true) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { finish(ended: false) }
}
