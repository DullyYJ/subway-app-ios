import SwiftUI
import UIKit

/// 길동무 친구들 장면 — SwiftUI Canvas(비동기 렌더)에 SceneCore 가 그리고, UIKit 터치 층이 손가락을 넘긴다.
/// 앱은 그리기만 한다: 장면 값(json)은 엔진이 정해 준 그대로 SceneDriver 에 넘긴다.
struct SceneView: View {
    let json: String
    @ObservedObject private var d = SceneDriver.shared
    @Environment(\.colorScheme) private var cs
    @Environment(\.displayScale) private var scale

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                TimelineView(.animation(minimumInterval: d.hot ? nil : 1.0 / 60.0, paused: !d.ready)) { _ in
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
            .onChange(of: geo.size) { push($0) }
            .onChange(of: cs) { _ in push(geo.size) }
            .onChange(of: json) { _ in push(geo.size) }
        }
    }
    private func push(_ s: CGSize) {
        d.layout(Double(s.width), Double(s.height), Double(scale), cs == .dark)
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

    init(_ d: SceneDriver) { driver = d; super.init(frame: .zero); backgroundColor = .clear; isMultipleTouchEnabled = false; isUserInteractionEnabled = true }
    required init?(coder: NSCoder) { fatalError() }

    private func upScroll() -> UIScrollView? {
        var v: UIView? = superview
        while let x = v { if let s = x as? UIScrollView { return s }; v = x.superview }
        return nil
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)
        tracking = driver.touchDown(Double(p.x), Double(p.y))
        if tracking {
            scroll = upScroll()
            driver.onHeld = { [weak self] in self?.scroll?.panGestureRecognizer.isEnabled = false }
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard tracking, let t = touches.first else { return }
        let p = t.location(in: self)
        driver.touchMove(Double(p.x), Double(p.y))
    }
    private func finish() {
        if tracking { driver.touchUp(); tracking = false }
        scroll?.panGestureRecognizer.isEnabled = true; scroll = nil
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { finish() }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { finish() }
}
