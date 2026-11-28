import Foundation

/// 캐릭터 시계 위젯의 자리 잡기 — 안드로이드 WidgetGeo.java 의 포팅(pt 단위, 값 · 식 그대로).
/// 시계 숫자 상자(clk*), 글자 크기(textDp), 캐릭터 키(charH), 바닥(ground), 출퇴근 때의 말풍선·버튼 자리를 위젯 크기에서 정한다.
final class GwGeo {
    let vertical: Bool
    let W: Double, H: Double
    var clkL = 0.0, clkT = 0.0, clkW = 0.0, clkH = 0.0
    var textDp = 0.0, lineH = 0.0
    var charH = 0.0, ground = 0.0, stageY = 0.0
    var stageL = 0.0, stageW = 0.0
    var bubL = 0.0, bubT = 0.0, bubW = 0.0, bubH = 0.0, btnL = 0.0, btnT = 0.0, btnW = 0.0, btnH = 0.0
    var bubTs = 0.0, btnTs = 0.0
    var bubLines = 2
    var bubPad = 8.0
    var dateL = 0.0, dateT = 0.0, dateSp = 0.0
    var commute = false

    static let DIGIT_W = 0.56, COLON_W = 0.26, DIGIT_H = 0.72
    static let LINE_K = 1.3, GAP = 6.0, MARGIN_B = 8.0, BTN_K = 2.5, BTN_RATIO = 0.88, BTN_MIN_H = 30.0
    static let STAGE_PER_CHAR = 0.82

    private init(_ v: Bool, _ w: Double, _ h: Double) { vertical = v; W = w; H = h }
    private static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { v < lo ? lo : (v > hi ? hi : v) }

    static func of(vertical: Bool, W: Double, H: Double) -> GwGeo {
        let g = GwGeo(vertical, max(60, W), max(60, H)); g.build(); return g
    }

    func setCommute(_ c: Bool, lines: Int? = nil) {
        let l = max(1, min(6, lines ?? bubLines))
        if c == commute && l == bubLines { return }
        commute = c; bubLines = l; build()
    }
    func bubbleHeight() -> Double { Double(bubLines) * bubTs * Self.LINE_K + 2 * bubPad }
    static func buttonHeight(_ btnTs: Double) -> Double { max(BTN_MIN_H, btnTs * BTN_K) }
    private static func btnHeightFor(_ vertical: Bool, _ btnTs: Double) -> Double { vertical ? buttonHeight(btnTs) : max(24, btnTs * BTN_K) }

    private func sizeText(_ boxW: Double, _ T: Double) {
        var ts = vertical ? Self.clamp(boxW / 12.5, 13, 18) : Self.clamp(H * 0.11, 12, 18)
        if !vertical {
            bubPad = Self.clamp(H * 0.07, 4, 8)
            let avail = H - 4 - 6
            while ts > 8 && Double(bubLines) * ts * Self.LINE_K + 2 * bubPad + Self.GAP + Self.btnHeightFor(false, ts * Self.BTN_RATIO) > avail { ts -= 0.5 }
        }
        ts = min(ts, max(8, T - 1))
        bubTs = ts; btnTs = ts * Self.BTN_RATIO
    }

    private func build() {
        ground = H - 4
        let headroom: Double
        var T: Double
        if !vertical {
            charH = Self.clamp(H * 0.30, 22, 40)
            headroom = charH + 4
            let tH = (H - headroom - 8) / Self.DIGIT_H, tW = (W - 16) / (4 * Self.DIGIT_W + Self.COLON_W)
            T = Self.clamp(min(tH, tW), 16, 120)
            if commute {
                T = max(14, min(T, (W - 136) / (4 * Self.DIGIT_W + Self.COLON_W)))
                let sw = max((4 * Self.DIGIT_W + Self.COLON_W) * T, Self.STAGE_PER_CHAR * charH * 3)
                sizeText(max(60, W - 8 - sw - 12 - 8), T)
            }
            textDp = T
            clkW = (4 * Self.DIGIT_W + Self.COLON_W) * T; clkH = Self.DIGIT_H * T; lineH = clkH
        } else {
            charH = Self.clamp(min(W * 0.36, H * 0.14), 22, 40)
            headroom = charH + 4
            let tH = (H - headroom - 8) / (Self.DIGIT_H * 2 + 0.30), tW = (W - 12) / (2 * Self.DIGIT_W)
            T = Self.clamp(min(tH, tW), 16, 120)
            if commute {
                sizeText(W - 16, T)
                let below = 0.25 * charH + 8 + bubbleHeight() + Self.GAP + Self.btnHeightFor(true, btnTs) + Self.MARGIN_B
                let fit = (H - headroom - below) / (Self.DIGIT_H * 2 + 0.30)
                T = max(14, min(T, fit))
                bubTs = min(bubTs, max(8, T - 1)); btnTs = bubTs * Self.BTN_RATIO
            }
            textDp = T
            lineH = Self.DIGIT_H * T
            clkW = 2 * Self.DIGIT_W * T; clkH = lineH * 2 + T * 0.30
        }
        derive()
    }

    /// 실제 글꼴로 잰 숫자 상자를 받아 나머지 자리를 다시 계산한다.
    func measured(digitsW: Double, digitsH: Double, oneLineH: Double) {
        if digitsW > 4 && digitsH > 4 {
            if !vertical { clkW = digitsW; clkH = digitsH; lineH = digitsH }
            else { lineH = oneLineH > 2 ? oneLineH : digitsH; clkW = digitsW; clkH = lineH * 2 + textDp * 0.30 }
        }
        derive()
    }

    func derive() {
        let headroom = charH + 4
        stageW = clkW
        if commute { stageW = max(clkW, Self.STAGE_PER_CHAR * charH * 3) }
        btnH = commute ? Self.btnHeightFor(vertical, btnTs) : Self.BTN_MIN_H
        if !vertical {
            if !commute {
                stageL = (W - clkW) / 2
                clkL = stageL
                clkT = Self.clamp(H - 8 - clkH, headroom, H)
            } else {
                stageL = 8
                clkL = stageL + (stageW - clkW) / 2
                clkT = max(headroom, Self.clamp(H * 0.30, 16, H - clkH - 40))
            }
            dateL = stageL; dateSp = 11; dateT = 3
            let rl = stageL + stageW + 12, rr = W - 8
            bubL = rl; bubW = max(60, rr - rl)
            btnW = bubW; btnL = bubL
            btnT = H - btnH - (commute ? 6 : Self.MARGIN_B)
            bubH = commute ? bubbleHeight() : 26
            bubT = max(2, btnT - Self.GAP - bubH)
        } else {
            stageL = (W - stageW) / 2
            clkL = (W - clkW) / 2
            if !commute { clkT = Self.clamp(H - 8 - clkH, headroom, H) } else { clkT = headroom }
            dateL = 0; dateSp = 11; dateT = 3
            btnW = W - 16; btnL = 8
            btnT = H - btnH - Self.MARGIN_B
            bubL = 8; bubW = W - 16
            bubH = commute ? bubbleHeight() : 30
            bubT = btnT - Self.GAP - bubH
        }
        stageY = min(ground, clkT + clkH + charH * 0.25)
    }

    var clkR: Double { clkL + clkW }
    var clkB: Double { clkT + clkH }
    var clkCx: Double { clkL + clkW / 2 }
}
