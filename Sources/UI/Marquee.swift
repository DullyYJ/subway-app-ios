import SwiftUI

/// 오른쪽에 놀이터 칸(reserve)을 남기고 한 줄로 흐르는 이름(안드로이드 ScreenCore mq · rw / ScreenView.mqOff).
/// 이름이 보이는 칸(너비 − reserve, 최소 40)보다 길면 1.2초 멈췄다가 초당 30pt 로 끝까지 흐르고, 1.2초 멈췄다가 되돌아온다. 짧으면 그냥 왼쪽에 둔다.
struct MarqueeLabel: View {
    let text: String
    let size: CGFloat
    let bold: Bool
    let color: Color
    let height: CGFloat
    let reserve: CGFloat

    /// 흐른 거리(pt). over = 넘치는 길이.
    nonisolated static func offset(over: CGFloat, t: Double) -> CGFloat {
        if over <= 0 { return 0 }
        let run = Double(over) / 30.0 * 1000.0, pause = 1200.0, cyc = pause + run + pause + run
        var x = (t * 1000.0).truncatingRemainder(dividingBy: cyc)
        if x < pause { return 0 }
        x -= pause; if x < run { return over * CGFloat(x / run) }
        x -= run; if x < pause { return over }
        x -= pause; return over * CGFloat(1 - x / run)
    }

    var body: some View {
        GeometryReader { g in
            let vis = max(40, g.size.width - reserve)
            let full = Typo.width(text, size, bold)
            Group {
                if full > vis + 0.5 {
                    TimelineView(.animation) { tl in
                        Text(text).font(Typo.font(size, bold: bold)).foregroundColor(color).lineLimit(1).fixedSize()
                            .offset(x: -MarqueeLabel.offset(over: full - vis, t: tl.date.timeIntervalSinceReferenceDate))
                    }
                } else {
                    Text(text).font(Typo.font(size, bold: bold)).foregroundColor(color).lineLimit(1)
                }
            }
            .frame(width: vis, height: height, alignment: .leading).clipped()
        }
        .frame(height: height)
    }
}
