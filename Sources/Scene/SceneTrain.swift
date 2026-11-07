import Foundation

/// 지하철 객실 장면(혼잡도 카드의 두 번째 쪽) — 안드로이드 SceneTrain.java 이식 자리.
/// ※ 아직 이식 전: 지금은 비어 있는 자리만 있다(SceneCore 가 부르는 이름만 맞춰 둠). 다음 단계에서 실제 그림·움직임을 채운다.
enum SceneTrain {
    final class St {}
    static func setup(_ S: SceneCore) {}
    static func refresh(_ S: SceneCore) {}
    static func feedPos(_ S: SceneCore, _ posJson: String) {}
    static func feedClock(_ S: SceneCore, _ nowMs: Int64) {}
    static func step(_ S: SceneCore, _ dt: Double) {}
    static func draw(_ S: SceneCore, _ c: SceneCv) {}
}
