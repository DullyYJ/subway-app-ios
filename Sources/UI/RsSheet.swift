import SwiftUI
import UIKit

/// 앱 탑승 시트(웹 rs-sheet · rs-pill · rs-undo) — 안드로이드 RsSheetView · RsCore 의 SwiftUI 판. 숫자 · 색 · 움직임은 웹 CSS 그대로:
///  · 올라온 시트(board): 하단 탭 아래 맨 아래에 붙는다(높이 83). 위 둥근 20 · 윗선 1 · 손잡이 36×4 · 탈것 칸 42 · 위 글(12 굵게 금색) · 노선 알약 + 이름(16 굵게) · 금색 [탑승] 단추(맥동 링 2초).
///    올라올 때 0.46초(0.22,1,0.36,1) + 투명도 0.3초, 하단 탭이 같이 시트 높이만큼 올라간다(레이아웃이 함께 늘어난다). 아래로 36 넘게 쓸면 닫혀 대기 알약이 된다.
///  · 떠 있는 뷰: 하단 탭 위 14. 대기 알약(높이 38 · 주황 점이 1.4초로 숨 쉼) · 기록 직후 되돌리기 캡슐(어두운 알약).
/// 어떤 모양을 보일지 · 글 · 색 · 막대는 엔진(overlay.rs)이 정한 값이다. 여기는 그리기와 누름 · 쓸기를 엔진 행동(press · undo · pill · open · close)으로 옮길 뿐이다.
enum RsCore {
    static let hBoard: CGFloat = 83, pad: CGFloat = 16, pillH: CGFloat = 38, pillR: CGFloat = 14, btnH: CGFloat = 46, rowY: CGFloat = 23, capH: CGFloat = 39, ubW: CGFloat = 64
    static func btnW(_ text: String) -> CGFloat { let n = CGFloat(text.isEmpty ? 2 : text.count); return max(92, n * 16.5 + (n > 2 ? 32 : 48)) }
    /// 올라온 시트를 아래로 쓸면 닫는다 · 알약을 위로 쓸면 연다(세로가 충분하고 가로보다 클 때만).
    static func swipe(_ st: String, _ dx: CGFloat, _ dy: CGFloat) -> String? {
        if st == "board" && dy > 36 && dy > abs(dx) * 1.2 { return "close" }
        if st == "wait" && dy < -28 && -dy > abs(dx) * 1.2 { return "open" }
        return nil
    }
    /// 하단 탭 막대를 쓸었을 때(웹 _rsInitSwipe): 위로 쓸면 도착이 멀어도 시트를 연다, 올라온 시트는 아래로 쓸면 닫는다.
    static func tabSwipe(_ st: String, _ dx: CGFloat, _ dy: CGFloat) -> String? {
        if dy < -28 && -dy > abs(dx) * 1.2 { return st == "board" ? nil : "open" }
        if dy > 36 && dy > abs(dx) * 1.2 && st == "board" { return "close" }
        return nil
    }
}

private let rsEase = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.46)

/// 하단 탭 아래에 올라오는 시트. RootView 의 맨 아래 칸에 놓으면 탭 막대와 본문이 시트 높이만큼 함께 밀려 올라간다.
struct RsBoardSheet: View {
    let ov: OvState; let pal: Palette
    let act: (String) -> Void
    @State private var drag: CGFloat = 0
    @State private var dragging = false
    private var gold: Color { pal.color("gold") ?? .yellow }
    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let bw = RsCore.btnW(ov.rsBt), btnX = w - RsCore.pad - bw, tx = RsCore.pad + 42 + 12, right = btnX - 12
            ZStack(alignment: .topLeading) {
                // 카드: 위 둥근 20 + 윗선 1(아래 모서리는 화면 밖으로 밀어 낸다)
                RoundedRectangle(cornerRadius: 20).fill(pal.color("card") ?? .black).frame(width: w, height: RsCore.hBoard + 24)
                RoundedRectangle(cornerRadius: 20).strokeBorder(pal.color("border2") ?? .gray, lineWidth: 1).frame(width: w, height: RsCore.hBoard + 24)
                RoundedRectangle(cornerRadius: 2).fill(pal.color("border2") ?? .gray).frame(width: 36, height: 4).offset(x: w / 2 - 18, y: 9)
                ZStack { RoundedRectangle(cornerRadius: 13).fill(pal.color("card2") ?? .gray); RsGlyph(bus: ov.rsMode == "bus", fg: gold, bg: pal.color("card2") ?? .gray) }
                    .frame(width: 42, height: 42).offset(x: RsCore.pad, y: 25)
                Text(ov.rsKick.isEmpty ? ov.rsK : ov.rsKick).font(Typo.font(12, bold: true)).foregroundColor(gold).lineLimit(1)
                    .frame(width: max(0, right - tx), alignment: .leading).offset(x: tx, y: 38 - 14)
                HStack(spacing: 7) {
                    if !ov.rsChip.isEmpty {
                        Text(ov.rsChip).font(Typo.font(11, bold: true)).foregroundColor(Color(argb: ov.rsCfg)).lineLimit(1)
                            .padding(.horizontal, 8).frame(height: 20).background(Color(argb: ov.rsCbg)).cornerRadius(10)
                    }
                    Text(ov.rsNm).font(Typo.font(16, bold: true)).foregroundColor(pal.color("text") ?? .white).lineLimit(1)
                }
                .frame(width: max(0, right - tx), alignment: .leading).offset(x: tx, y: 61.3 - 20)
                RsBigButton(label: ov.rsBt, pal: pal, w: bw) { act("press") }.offset(x: btnX, y: RsCore.rowY)
                if ov.rsBar >= 0 {                                                      // 출발 뒤 줄어드는 막대(웹 .rs-bar: 좌우 16 · 아래 5 · 높이 3)
                    RoundedRectangle(cornerRadius: 1.5).fill(pal.color("border") ?? .gray).frame(width: w - 2 * RsCore.pad, height: 3).offset(x: RsCore.pad, y: RsCore.hBoard - 8)
                    RoundedRectangle(cornerRadius: 1.5).fill(gold).frame(width: (w - 2 * RsCore.pad) * CGFloat(ov.rsBar), height: 3).offset(x: RsCore.pad, y: RsCore.hBoard - 8)
                }
            }
            .frame(width: w, height: RsCore.hBoard, alignment: .topLeading)
            .contentShape(Rectangle())
            .offset(y: drag)                                                            // 손가락을 따라 내려온다
            .simultaneousGesture(DragGesture(minimumDistance: 6).onChanged { v in
                if v.translation.height > 0 && v.translation.height > abs(v.translation.width) { dragging = true; drag = v.translation.height }
                else if dragging { dragging = false; drag = 0 }
            }.onEnded { v in
                let sw = RsCore.swipe(ov.rsSt, v.translation.width, v.translation.height)
                let was = dragging; dragging = false
                if was && sw == nil { withAnimation(.easeOut(duration: 0.2)) { drag = 0 } }
                if let sw = sw { act(sw); DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { withAnimation(.easeOut(duration: 0.2)) { drag = 0 } } }
            })
        }
        .frame(height: RsCore.hBoard)
    }
}

/// 금색 단추(웹 .rs-btn): 135° 금색 → 진금색 · 둥근 15 · 16 굵은 글 + 자간 .5 · 맥동 링(2초 주기, 0~70% 동안 12 까지 번지며 사라짐).
private struct RsBigButton: View {
    let label: String; let pal: Palette; let w: CGFloat; let tap: () -> Void
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2), u = t / 1.4
            let e = u < 1 ? 1 - (1 - u) * (1 - u) : 1, s = CGFloat(12 * e)
            let g1 = pal.color("gold") ?? .yellow, g2 = pal.color("gold2") ?? .orange
            ZStack {
                if u < 1 {
                    RoundedRectangle(cornerRadius: 15 + s / 2).strokeBorder(g1.opacity(0.5 * (1 - e)), lineWidth: max(0.5, s))
                        .frame(width: w + s, height: RsCore.btnH + s)
                }
                RoundedRectangle(cornerRadius: 15).fill(LinearGradient(colors: [g1, g2], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: w, height: RsCore.btnH)
                Text(label).font(Typo.font(16, bold: true)).tracking(0.5).foregroundColor(pal.color("ongold") ?? .black)
            }
            .frame(width: w, height: RsCore.btnH)
        }
        .contentShape(Rectangle())
        .onTapGesture { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); tap() }
        .accessibilityAddTraits(.isButton)
    }
}

/// 탈것 그림(웹 _RS_ICON 을 단순화): 금색 몸 + 카드 색 창 · 불빛 · 다리.
private struct RsGlyph: View {
    let bus: Bool; let fg: Color; let bg: Color
    var body: some View {
        Canvas { c, size in
            let cx = size.width / 2, cy = size.height / 2 + 0.0
            func rr(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ r: Double, _ col: Color) {
                c.fill(Path(roundedRect: CGRect(x: cx + x0, y: cy + y0, width: x1 - x0, height: y1 - y0), cornerRadius: r), with: .color(col))
            }
            func dot(_ x: Double, _ y: Double, _ r: Double, _ col: Color) { c.fill(Path(ellipseIn: CGRect(x: cx + x - r, y: cy + y - r, width: 2 * r, height: 2 * r)), with: .color(col)) }
            if bus {
                rr(-8, -10, 8, 7, 3, fg); rr(-7, 7, -4.5, 10, 0, fg); rr(4.5, 7, 7, 10, 0, fg)
                rr(-6, -7.5, 6, -1, 1.5, bg); dot(-4.8, 3.6, 1.5, bg); dot(4.8, 3.6, 1.5, bg)
            } else {
                rr(-7, -10, 7, 6.5, 3.5, fg)
                var l = Path(); l.move(to: CGPoint(x: cx - 4.5, y: cy + 6)); l.addLine(to: CGPoint(x: cx - 7, y: cy + 10.5))
                l.move(to: CGPoint(x: cx + 4.5, y: cy + 6)); l.addLine(to: CGPoint(x: cx + 7, y: cy + 10.5))
                c.stroke(l, with: .color(fg), lineWidth: 1.7)
                rr(-5, -7.5, 5, -0.5, 1.5, bg); dot(-3.4, 3, 1.4, bg); dot(3.4, 3, 1.4, bg)
            }
        }.frame(width: 42, height: 42)
    }
}

/// 하단 탭 위에 떠 있는 대기 알약 · 되돌리기 캡슐(탭 위 14). 다른 곳의 터치는 뒤 화면으로 간다.
struct RsFloat: View {
    let ov: OvState; let pal: Palette
    let act: (String) -> Void
    var body: some View {
        Group {
            if ov.rsSt == "wait" { pill.transition(.scale(scale: 0.6, anchor: .bottomTrailing).combined(with: .opacity).combined(with: .offset(y: 16))) }
            else if ov.rsSt == "undo" { undo.transition(.opacity.combined(with: .offset(y: 24))) }
        }
        .padding(.bottom, 14)
    }
    private var pill: some View {
        let chip = ov.rsChip.isEmpty ? ov.rsNm : ov.rsChip
        return HStack(spacing: 0) {
            TimelineView(.animation) { tl in
                let ph = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.4) / 1.4, s = 0.5 - 0.5 * cos(ph * 2 * .pi)          // 숨쉬는 점(웹 rsDot 1.4초: 투명도 1→.35 · 크기 1→.7)
                Circle().fill((pal.color("orange") ?? .orange).opacity(1 - 0.65 * s)).frame(width: 8 * (1 - 0.3 * s), height: 8 * (1 - 0.3 * s)).frame(width: 8, height: 8)
            }.padding(.leading, 13).padding(.trailing, 8)
            Text("대기").font(Typo.font(14, bold: true)).foregroundColor(pal.color("text") ?? .white)
            if !chip.isEmpty { Text(chip).font(Typo.font(11, bold: true)).foregroundColor(pal.color("sub") ?? .gray).lineLimit(1).frame(maxWidth: 90).padding(.leading, 8) }
        }
        .padding(.trailing, 15).frame(height: RsCore.pillH)
        .background(Capsule().fill(pal.color("card") ?? .black))
        .overlay(Capsule().strokeBorder(pal.color("border2") ?? .gray, lineWidth: 1))
        .frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, RsCore.pillR)
        .contentShape(Capsule())
        .onTapGesture { UIImpactFeedbackGenerator(style: .light).impactOccurred(); act("pill") }
        .gesture(DragGesture(minimumDistance: 10).onEnded { v in if let sw = RsCore.swipe("wait", v.translation.width, v.translation.height) { act(sw) } })
    }
    private var undo: some View {
        HStack(spacing: 12) {
            Text(ov.rsK).font(Typo.font(13, bold: true)).foregroundColor(pal.color("bg") ?? .black).lineLimit(1).frame(maxWidth: 220, alignment: .leading)
            Text(ov.rsBt.isEmpty ? "되돌리기" : ov.rsBt).font(Typo.font(13, bold: true)).foregroundColor(Color(argb: 0xFF0A84FF)).frame(width: RsCore.ubW)
                .contentShape(Rectangle()).onTapGesture { UIImpactFeedbackGenerator(style: .light).impactOccurred(); act("undo") }
        }
        .padding(.leading, 16).padding(.trailing, 12).frame(height: RsCore.capH)
        .background(Capsule().fill(pal.color("text") ?? .black))
    }
}
