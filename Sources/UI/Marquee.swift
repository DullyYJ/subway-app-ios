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
    /// 이름 오른쪽 빈 칸에서 동물들이 노는 놀이터(안드로이드 PlayView). nil 이면 칸만 비워 둔다. 팝업은 이름 줄 아래에 맞춰 위로 솟고, 시간표는 제목 줄 위로 솟는다.
    var play: PlayKind? = nil
    var padTop: CGFloat = 0
    var padBottom: CGFloat = 0
    @AppStorage("theme") private var theme = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 놀이터 칸(이 뷰 좌표). 이름이 길어 최소 칸도 못 내면 nil(웹과 같다).
    private func playRect(width: CGFloat, nameW: CGFloat) -> CGRect? {
        guard let k = play, reserve > 0 else { return nil }
        var r: CGRect?
        if k == .popup { r = PlayCore.popupHost(sheetW: width, padX: 0, nameX: 0, nameW: nameW, nameY: 0, nameH: height) }
        else { r = PlayCore.ttHost(barY: -padTop, barH: padTop + height + padBottom, titleX: 0, titleW: nameW, rightEdge: width) }
        guard var h = r else { return nil }
        if h.minY < -padTop { h.origin.y = -padTop }          // 시트 맨 위보다 위로는 못 나간다(안드로이드 max(0, y))
        return h
    }

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
            let host = playRect(width: g.size.width, nameW: min(full, vis))
            ZStack(alignment: .topLeading) {
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
                if let h = host, let k = play {
                    PlayField(w: h.width, h: h.height, dark: theme == "dark", reduce: reduceMotion, kind: k)
                        .id("\(Int(h.width))x\(Int(h.height))\(theme == "dark")")
                        .frame(width: h.width, height: h.height)
                        .offset(x: h.minX, y: h.minY)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(height: height)
    }
}
