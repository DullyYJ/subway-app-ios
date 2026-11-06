import WidgetKit
import SwiftUI
import ActivityKit

@main
struct GildongmuLiveBundle: WidgetBundle {
    var body: some Widget { RideLiveActivity() }
}

/// 안드로이드 '알약' 오버레이의 iOS 판: 알약 상태에서는 다이내믹 아일랜드 안으로 들어가 [도착 · 이동중 · 대기]를 보인다.
/// 값은 모두 엔진이 정해 보낸 것(RideActivityAttributes.ContentState) — 여기는 그리기만 한다.
struct RideLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RideActivityAttributes.self) { ctx in
            LockBanner(s: ctx.state, dest: ctx.attributes.dest)
                .activityBackgroundTint(Color(argb: ctx.state.bg))
                .activitySystemActionForegroundColor(Color(argb: ctx.state.fg))
        } dynamicIsland: { ctx in
            let s = ctx.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { StateChip(s: s) }
                DynamicIslandExpandedRegion(.trailing) {
                    if !s.banner.isEmpty { Text(s.banner).font(Typo.font(12, bold: true)).foregroundColor(alertColor(s.alert)).lineLimit(1) }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(s.line1).font(Typo.font(14, bold: true)).foregroundColor(.white).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        if !s.cells.isEmpty { CellStrip(s: s, onDark: true) }
                        if !s.pillText.isEmpty { Text(s.pillText).font(Typo.font(12)).foregroundColor(Color(argb: 0xFFB0B0B8)).lineLimit(1) }
                    }
                }
            } compactLeading: {
                Dot(rgb: s.stateRgb, pulse: s.alert > 0)
            } compactTrailing: {
                Text(s.alert > 0 && !s.banner.isEmpty ? s.banner : s.label)
                    .font(Typo.font(12, bold: true)).foregroundColor(s.alert > 0 ? alertColor(s.alert) : .white).lineLimit(1)
            } minimal: {
                Dot(rgb: s.stateRgb, pulse: s.alert > 0)
            }
            .keylineTint(Color(argb: s.stateRgb))
        }
    }
}

/// 경고 색: 1정거장 전 빨강 · 2정거장 전 주황(안드로이드 오버레이와 같다).
private func alertColor(_ a: Int) -> Color { a == 1 ? Color(argb: 0xFFFF453A) : a == 2 ? Color(argb: 0xFFFF9F0A) : .white }

private struct Dot: View {
    let rgb: Int; var pulse = false
    @State private var on = false
    var body: some View {
        Circle().fill(Color(argb: rgb)).frame(width: 10, height: 10)
            .opacity(pulse ? (on ? 0.28 : 1) : 1)
            .onAppear { if pulse { withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) { on = true } } }
    }
}

private struct StateChip: View {
    let s: RideActivityAttributes.ContentState
    var body: some View {
        HStack(spacing: 6) {
            Dot(rgb: s.stateRgb, pulse: s.alert > 0)
            Text(s.label).font(Typo.font(13, bold: true)).foregroundColor(.white)
        }
    }
}

/// 현위치가 가운데 오는 5칸(역 이름 · 시각 · 점) — 안드로이드 오버레이 칸 줄의 단순판.
private struct CellStrip: View {
    let s: RideActivityAttributes.ContentState
    var onDark = false
    var body: some View {
        let fg = onDark ? Color.white : Color(argb: s.fg), sub = onDark ? Color(argb: 0xFF8E8E93) : Color(argb: s.sub)
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(s.cells.enumerated()), id: \.offset) { i, c in
                VStack(spacing: 3) {
                    Text(c.t).font(Typo.font(10)).foregroundColor(sub).lineLimit(1)
                    ZStack {
                        Rectangle().fill(sub.opacity(0.4)).frame(height: 2)
                        Circle().fill(Color(argb: i == s.cur ? s.stateRgb : c.dc)).frame(width: i == s.cur ? 12 : 8, height: i == s.cur ? 12 : 8)
                    }.frame(height: 12)
                    Text(c.n).font(Typo.font(11, bold: i == s.cur)).foregroundColor(i == s.cur ? fg : sub).lineLimit(1).minimumScaleFactor(0.8)
                }.frame(maxWidth: .infinity)
            }
        }
    }
}

private struct LockBanner: View {
    let s: RideActivityAttributes.ContentState; let dest: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Dot(rgb: s.stateRgb, pulse: s.alert > 0)
                Text(s.label).font(Typo.font(13, bold: true)).foregroundColor(Color(argb: s.fg))
                Spacer()
                if !s.banner.isEmpty { Text(s.banner).font(Typo.font(12, bold: true)).foregroundColor(alertColor(s.alert)) }
            }
            Text(s.line1).font(Typo.font(16, bold: true)).foregroundColor(Color(argb: s.fg)).lineLimit(1)
            if !s.line2.isEmpty { Text(s.line2).font(Typo.font(13)).foregroundColor(Color(argb: s.sub)).lineLimit(1) }
            if !s.cells.isEmpty { CellStrip(s: s) }
        }
        .padding(14)
    }
}
