import SwiftUI

/// 시트가 올라오는 움직임(안드로이드 ShellActivity.slideIn — 웹 slideUp): 아래 56pt 에서 흐림 0 → 1 로 340ms,
/// 곡선 (0.32, 0.72, 0, 1)(아이폰 시트처럼 빠르게 시작해 부드럽게 멈춘다). 닫을 때는 안드로이드처럼 바로 사라진다.
/// 시트 판(panel)에만 붙인다 — 어두운 바탕은 처음부터 깔린다.
struct SheetIn: ViewModifier {
    @State private var on = false
    @Environment(\.accessibilityReduceMotion) private var reduce
    func body(content: Content) -> some View {
        content
            .opacity(on || reduce ? 1 : 0)
            .offset(y: on || reduce ? 0 : 56)
            .onAppear { withAnimation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.34)) { on = true } }
    }
}

extension View {
    func sheetIn() -> some View { modifier(SheetIn()) }
}
