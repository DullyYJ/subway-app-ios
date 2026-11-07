import Foundation
import UIKit
import CoreGraphics
import QuartzCore

/// 네이티브 장면의 운전석 — 그림(SceneCore)·도화지(CGCv)·스프라이트·진동·손가락을 한데 묶는다. 안드로이드 SceneDriver.java 의 iOS 판.
///
///   엔진(워커 /scene) ──JSON──▶ SceneView ──apply──▶ SceneDriver ──▶ SceneCore(그림·움직임)
///                                                   │                └─▶ SceneCv ─▶ CGCv ─▶ SwiftUI Canvas(비동기 렌더)
///                                                   └─▶ 진동(SceneHaptics 무늬 → Core Haptics)
/// 이 클래스는 아무것도 '판단'하지 않는다. 엔진이 정한 장면(mode·look·cast·traits)을 SceneCore 에 넘기고, 화면 박자가 알려 주는 시각마다 update → render 를 부를 뿐이다.
/// ★ 렌더는 Canvas(rendersAsynchronously)에서 메인이 아닌 쪽으로 돌 수 있으므로, SceneCore 에 닿는 모든 입구를 한 자물쇠로 감싼다(손가락은 메인에서 온다).
final class SceneDriver: ObservableObject, SceneHost {
    static let shared = SceneDriver()

    @Published private(set) var isReady = false
    @Published private(set) var tag = ""
    @Published private(set) var hot = false
    /// 캐릭터를 꾹 눌러 잡았다 → 아래 목록의 스크롤을 막아야 한다.
    var onHeld: (() -> Void)?
    var haptics = true

    private let lock = NSRecursiveLock()
    private let cv = CGCv(nil)
    private var core: SceneCore!
    private var sheets: [String: SceneImg] = [:]
    private var introImg: SceneImg?
    private var loaded = false, loading = false
    private var density = 1.0
    private var lastT = 0.0
    private var tagNow = "", hotNow = false
    private var json = ""

    private static let IDS = SceneModel.ORDER
    private static let ACT_IDS = ["juksun", "bbosong", "dolsom", "ppopu", "lovel", "dudung", "sul", "chaeng"]      // 전용 동작 시트(<id>_act)가 있는 친구

    init() { core = SceneCore(host: self, factory: cv, rng: SysRng()) }

    // ───────────── 스프라이트(webp 시트) 읽기: 백그라운드, 끝나면 장면을 이어서 만든다 ─────────────
    func load() {
        lock.lock(); if loaded || loading { lock.unlock(); return }; loading = true; lock.unlock()
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            var got: [String: SceneImg] = [:]; var intro: SceneImg?
            for id in Self.IDS { if let i = Self.decode(Chars.file(id)) { got[id] = i } }                         // 뽀송은 지금 신은 신발 시트
            intro = Self.decode("dudung_intro")
            for id in Self.IDS { if let i = Self.decode(Chars.file(id + "_pose")) { got[id + "_pose"] = i } }     // 자세 시트는 없어도 된다 — 걷기 시트로 대신 그린다
            for id in Self.ACT_IDS { if let i = Self.decode(Chars.file(id + "_act")) { got[id + "_act"] = i } }   // 전용 동작 시트도 없어도 된다 — 자세 시트로 대신 그린다
            if let i = Self.decode("juksun_nb") { got["juksun_nb"] = i }                                          // 대나무 없는 걷기 시트
            lock.lock()
            loading = false
            if intro == nil || got.isEmpty { lock.unlock(); return }
            sheets = got; introImg = intro; loaded = true
            core.apply(core.last())
            lock.unlock()
            DispatchQueue.main.async { [self] in isReady = true }
        }
    }
    private static func decode(_ name: String) -> SceneImg? {
        guard let u = Bundle.main.url(forResource: name, withExtension: "webp", subdirectory: "chars3d"), let d = try? Data(contentsOf: u), let ui = UIImage(data: d), let cg = ui.cgImage else { return nil }
        return CGImg(cg)
    }

    // ───────────── 엔진 답 · 크기 · 테마 ─────────────
    /// 칸 크기(pt)·화면 배율·테마. 바뀌었으면 같은 장면을 새 크기로 다시 만든다.
    func layout(_ w: Double, _ h: Double, _ scale: Double, _ dark: Bool) {
        lock.lock(); defer { lock.unlock() }
        density = scale > 0 ? scale : 1
        core.layout(w, h, density, dark)
    }
    /// 엔진이 보낸 /scene 답(JSON 글자 그대로). 같은 글자면 다시 만들지 않는다.
    @discardableResult func apply(_ js: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if js == json && core.isRunning() { return true }
        json = js
        return core.apply(SceneModel.parse(js))
    }
    func stop() { lock.lock(); core.stop(); lastT = 0; lock.unlock() }
    /// 화면에 다시 나타났을 때: 시간 점프 없이 새로 시작한다.
    func resume() { lock.lock(); lastT = 0; lock.unlock() }
    func isRunning() -> Bool { lock.lock(); defer { lock.unlock() }; return core.isRunning() }

    // ───────────── 프레임: 움직임 계산 + 그리기(Canvas 의 CGContext, 점 단위 · 맨 왼쪽 위가 장면 왼쪽 위) ─────────────
    func drawFrame(_ cg: CGContext) {
        lock.lock(); defer { lock.unlock() }
        guard loaded, core.isRunning() else { lastT = 0; return }
        let now = CACurrentMediaTime()
        let h = core.interactive() || core.helloActive()
        if h != hotNow { hotNow = h; DispatchQueue.main.async { [self] in hot = h } }
        if lastT > 0 { let dt = min(now - lastT, 0.1); if dt > 0 { core.update(dt) } }
        lastT = now
        cg.saveGState(); cg.scaleBy(x: CGFloat(1 / density), y: CGFloat(1 / density))      // 장면은 '화면 픽셀'로 그린다(렌더가 dpr 배로 확대)
        cv.begin(cg); core.render(cv)
        cg.restoreGState()
        let tg = core.tag()
        if tg != tagNow { tagNow = tg; DispatchQueue.main.async { [self] in tag = tg } }
    }

    // ───────────── 카드 확장 인사(s340) ─────────────
    func helloReady() -> Bool { lock.lock(); defer { lock.unlock() }; return loaded && core.isRunning() && core.mode == "idle" }
    func helloStart(_ plan: SceneHello.Plan, _ seed: Int64) -> Bool { lock.lock(); defer { lock.unlock() }; return core.startHello(plan, seed) }
    func helloActive() -> Bool { lock.lock(); defer { lock.unlock() }; return core.helloActive() }
    func helloMs() -> Double { lock.lock(); defer { lock.unlock() }; return core.helloMs() }
    func helloSkip() { lock.lock(); core.helloSkip(); lock.unlock() }
    func helloStop() { lock.lock(); core.helloStop(); lock.unlock() }
    /// 카드가 늘어난 높이(pt) — 장면 안에서는 디자인 좌표(÷배율)로 바꿔 인도를 그만큼 늘린다.
    func helloStretch(_ ext: Double) { lock.lock(); core.setStretch(core.k > 0 ? ext / core.k : 0); lock.unlock() }

    // ───────────── 손가락(점 단위, 장면 왼쪽 위 기준) ─────────────
    func touchDown(_ x: Double, _ y: Double) -> Bool { lock.lock(); defer { lock.unlock() }; return core.isRunning() && core.down(x, y) }
    func touchMove(_ x: Double, _ y: Double) { lock.lock(); core.move(x, y); lock.unlock() }
    func touchUp() { lock.lock(); core.up(); lock.unlock() }
    func isHeld() -> Bool { lock.lock(); defer { lock.unlock() }; return core.isHeld() }

    // ───────────── SceneHost ─────────────
    func sheet(_ id: String) -> SceneImg? { sheets[id] }
    func intro() -> SceneImg? { introImg }
    func ready() -> Bool { loaded }
    func held() { DispatchQueue.main.async { [self] in onHeld?() } }
    func haptic(_ name: String) { if haptics { SceneHapticPlayer.shared.play(name) } }
}
