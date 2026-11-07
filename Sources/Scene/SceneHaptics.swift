import Foundation
import CoreHaptics
import UIKit

/// 장면 진동 무늬표 — 안드로이드 SceneHaptics.java 와 같은 값. SceneCore 는 '무슨 일이 일어났는지'만 이름으로 알리고, 어떤 느낌으로 울릴지는 여기서만 정한다.
/// 무늬 = [쉬는 ms, 울리는 ms, 쉬는 ms, 울리는 ms …] + 세기(0~255). 첫 칸은 늘 쉬는 칸(0).
enum SceneHaptics {
    struct Pat { let timings: [Int]; let amps: [Int]; var total: Int { timings.reduce(0, +) } }
    static let TABLE: [String: Pat] = [
        // 손가락 동작
        "grab": Pat(timings: [0, 14], amps: [0, 110]),
        "tap": Pat(timings: [0, 12], amps: [0, 100]),
        "release": Pat(timings: [0, 10], amps: [0, 70]),
        // 착륙(캐릭터마다 다르게)
        "land": Pat(timings: [0, 22], amps: [0, 170]),
        "land_cotton": Pat(timings: [0, 18, 34, 36], amps: [0, 95, 0, 45]),
        "land_pose": Pat(timings: [0, 12, 52, 10], amps: [0, 200, 0, 110]),
        "land_dig": Pat(timings: [0, 20, 36, 20, 36, 26], amps: [0, 200, 0, 170, 0, 225]),
        "land_flip": Pat(timings: [0, 10, 14, 14, 14, 18, 16, 30], amps: [0, 50, 0, 85, 0, 120, 0, 235]),
        "land_fly": Pat(timings: [0, 20, 70, 20, 60, 14], amps: [0, 110, 0, 90, 0, 60]),
        "land_puddle": Pat(timings: [0, 30, 44, 18, 44, 12], amps: [0, 235, 0, 120, 0, 60]),
        "land_tumble": Pat(timings: [0, 12, 20, 14, 20, 30], amps: [0, 70, 0, 110, 0, 210]),
        "land_hose": Pat(timings: [0, 16, 30, 16, 30, 40], amps: [0, 120, 0, 90, 0, 60]),
        "squirt": Pat(timings: [0, 18, 22, 18, 22, 18], amps: [0, 90, 0, 120, 0, 90]),
        // 연출
        "flap": Pat(timings: [0, 16, 60, 16], amps: [0, 100, 0, 80]),
        "hearts": Pat(timings: [0, 22, 70, 30], amps: [0, 130, 0, 100]),
        "thud": Pat(timings: [0, 34], amps: [0, 230]),
        "angry": Pat(timings: [0, 28, 40, 28, 40, 40], amps: [0, 210, 0, 230, 0, 255]),
        "splash": Pat(timings: [0, 26, 38, 16, 38, 10], amps: [0, 220, 0, 110, 0, 50]),
        "grin": Pat(timings: [0, 10, 50, 10], amps: [0, 90, 0, 140]),
    ]
    static func get(_ name: String) -> Pat? { TABLE[name] }
}

/// 무늬를 Core Haptics 로 그대로 재생한다(울리는 칸마다 날카로운 톡 + 길이만큼 이어지는 진동). 지원하지 않는 기기는 UIKit 충격 진동으로 대신한다.
final class SceneHapticPlayer {
    static let shared = SceneHapticPlayer()
    private let q = DispatchQueue(label: "scene.haptic")
    private var engine: CHHapticEngine?
    private let supported = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var light: UIImpactFeedbackGenerator?, medium: UIImpactFeedbackGenerator?, heavy: UIImpactFeedbackGenerator?

    func play(_ name: String) {
        guard let p = SceneHaptics.get(name) else { return }
        q.async { [self] in
            if supported, playCore(p) { return }
            fallback(p)
        }
    }
    private func ensureEngine() -> CHHapticEngine? {
        if let e = engine { return e }
        guard let e = try? CHHapticEngine() else { return nil }
        e.isAutoShutdownEnabled = true
        e.resetHandler = { [weak self] in self?.q.async { try? self?.engine?.start() } }
        e.stoppedHandler = { _ in }
        do { try e.start() } catch { return nil }
        engine = e; return e
    }
    private func playCore(_ p: SceneHaptics.Pat) -> Bool {
        guard let e = ensureEngine() else { return false }
        var ev: [CHHapticEvent] = []; var t = 0.0
        for i in 0..<p.timings.count {
            t += Double(p.timings[i]) / 1000.0
            if i % 2 == 1 {
                let inten = Float(min(255, max(1, p.amps[i]))) / 255
                let par = [CHHapticEventParameter(parameterID: .hapticIntensity, value: inten), CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.55)]
                ev.append(CHHapticEvent(eventType: .hapticTransient, parameters: par, relativeTime: t))
                let dur = Double(p.timings[i]) / 1000.0
                if dur > 0.02 { ev.append(CHHapticEvent(eventType: .hapticContinuous, parameters: par, relativeTime: t, duration: dur)) }
            }
        }
        do {
            let pat = try CHHapticPattern(events: ev, parameters: [])
            let pl = try e.makePlayer(with: pat); try e.start(); try pl.start(atTime: CHHapticTimeImmediate); return true
        } catch { return false }
    }
    private func fallback(_ p: SceneHaptics.Pat) {
        let peak = p.amps.max() ?? 0
        DispatchQueue.main.async { [self] in
            if peak < 110 { if light == nil { light = UIImpactFeedbackGenerator(style: .light) }; light?.impactOccurred() }
            else if peak < 190 { if medium == nil { medium = UIImpactFeedbackGenerator(style: .medium) }; medium?.impactOccurred() }
            else { if heavy == nil { heavy = UIImpactFeedbackGenerator(style: .heavy) }; heavy?.impactOccurred() }
        }
    }
}
