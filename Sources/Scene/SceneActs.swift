import Foundation

/// 친구들의 동작 모음(안드로이드 SceneActs.java 1,234줄) 이식 자리.
/// ※ 아직 이식 전: 지금은 걷기·뛰기·쉬기 같은 기본 동작(SceneCore)만 돈다. 다음 단계에서 고유 동작(register)을 채운다.
enum SceneActs {
    static func register(_ S: SceneCore) {}
    /// 머리 위치(몸 기준: 바라보는 쪽으로 dx, 발 기준 위로 dy)
    static func headOf(_ a: SceneCore.Actor, _ hh: Double) -> [Double] { [0, -hh * 0.82] }
}
