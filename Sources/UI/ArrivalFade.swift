import SwiftUI

/// 뼈대(또는 빈 화면) 자리에 진짜 화면이 처음 올라올 때 살짝 떠오른다: 흐림 0.35 → 1, 240ms 감속(안드로이드 ShellActivity.fadeIn —
/// alpha 0.35 → 1, DecelerateInterpolator(1.4)). 옛 화면을 먼저 보였다가 새로 받아 바꿀 때(갱신)는 쓰지 않는다.
/// 쓰는 법: 화면 쪽에 `.transition(.arrival)`, 뼈대 쪽에 `.transition(.identity)`, 둘을 감싼 곳에 `.arrivalFade(화면이 있나)`.
struct ArrivalAlpha: ViewModifier {
    let a: Double
    func body(content: Content) -> some View { content.opacity(a) }
}

extension AnyTransition {
    static var arrival: AnyTransition {
        .asymmetric(insertion: .modifier(active: ArrivalAlpha(a: 0.35), identity: ArrivalAlpha(a: 1)), removal: .identity)
    }
}

extension View {
    /// 안드로이드 DecelerateInterpolator(1.4) 는 1 − (1 − x)^2.8 — 이에 가까운 베지어.
    func arrivalFade(_ shown: Bool) -> some View {
        self.animation(.timingCurve(0.18, 0.62, 0.34, 1, duration: 0.24), value: shown)
    }
}
