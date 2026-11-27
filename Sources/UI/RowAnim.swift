import SwiftUI

/// 경로 카드 버튼 줄의 전환 연출 수식(웹 _rowFrame · _rowEase 와 같은 식) — 안드로이드 ActRowCore.java.
/// 어떤 칸이 되는지·전환 종류·시간·곡선은 엔진이 정하고, 여기서는 받은 값으로 한 순간의 네 조각 자리만 구한다.
enum ActRowCore {
    struct Piece: Equatable { var show = false; var x: CGFloat = 0, y: CGFloat = 0, w: CGFloat = 0, h: CGFloat = 0 }
    static let slotA = 0, slotB = 1, slotC = 2, slotO = 3

    /// CSS cubic-bezier(x1,y1,x2,y2) 와 같은 곡선: 시간 t(0~1) → 진행 0~1.
    nonisolated static func ease(_ t: Double, _ z: [Double]) -> Double {
        if t <= 0 { return 0 }
        if t >= 1 { return 1 }
        var lo = 0.0, hi = 1.0, u = t
        for _ in 0..<24 { u = (lo + hi) / 2; if bz(u, z[0], z[2]) < t { lo = u } else { hi = u } }
        return bz(u, z[1], z[3])
    }
    nonisolated private static func bz(_ u: Double, _ p1: Double, _ p2: Double) -> Double {
        let v = 1 - u
        return 3 * v * v * u * p1 + 3 * v * u * u * p2 + u * u * u
    }

    /// 진행 p(0~1)에서 네 조각의 [보임, x, y, w, h]. 조각: A 왼쪽 · B 가운데 · C 오른쪽(새 칸) · O 밀려나는 옛 칸.
    /// kind: push_in(왼쪽 두 칸이 줄고 오른쪽에서 밀고 들어옴) · push_out(그 반대) · slide_down(새 칸이 위에서 내려오며 옛 칸을 아래로) · slide_up(새 칸이 아래에서 올라오며 옛 칸을 위로).
    nonisolated static func frame(_ kind: String, _ p0: Double, W: CGFloat, H: CGFloat, g: CGFloat) -> [Piece] {
        var out = [Piece](repeating: Piece(), count: 4)
        let p = CGFloat(max(0, min(1, p0)))
        let w2 = (W - g) / 2, w3 = (W - 2 * g) / 3, x3 = 2 * (w3 + g)
        func set(_ k: Int, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) { out[k] = Piece(show: true, x: x, y: y, w: w, h: h) }
        if kind == "push_in" || kind == "push_out" {
            let q = kind == "push_out" ? 1 - p : p
            let wa = w2 + (w3 - w2) * q
            set(slotA, 0, 0, wa, H); set(slotB, wa + g, 0, wa, H); set(slotC, 2 * (wa + g), 0, w3, H)
            return out
        }
        set(slotA, 0, 0, w3, H); set(slotB, w3 + g, 0, w3, H)
        if kind == "slide_down" { set(slotC, x3, -H * (1 - p), w3, H); set(slotO, x3, H * p, w3, H) }
        else if kind == "slide_up" { set(slotC, x3, H * (1 - p), w3, H); set(slotO, x3, -H * p, w3, H) }
        else { set(slotC, x3, 0, w3, H) }
        return out
    }

    /// 연출을 지금 그려야 하나: 전환이 일어난 시각(sq, 엔진 시계)이 방금(2.5초 안)일 때만. 오래된 값은 최종 모양만 보인다.
    nonisolated static func fresh(_ sq: Int64, _ wallMs: Int64) -> Bool { let d = wallMs - sq; return sq > 0 && d > -2000 && d < 2500 }
}

/// row 노드의 `an` — 칸이 셋(모두 단추)일 때만(탑승 · 환승 · 도착 칸). 안드로이드 ScreenCore row.an.
struct RowAnimSpec {
    let kind: String
    let ms: Int
    let sq: Int64
    let bg: String
    let ez: [Double]
    let oS: String
    let oFill: String?
    let oTc: String?

    static func parse(_ n: Node) -> RowAnimSpec? {
        guard let a = n.d["an"] as? [String: Any] else { return nil }
        let k = a["k"] as? String ?? ""
        guard ["push_in", "push_out", "slide_down", "slide_up"].contains(k) else { return nil }
        let kids = n.kids
        guard kids.count == 3, kids.allSatisfy({ $0.t == "button" }) else { return nil }
        let ms = Int(max(0, min(1500, (a["ms"] as? NSNumber)?.doubleValue ?? 0)))
        let sq = (a["sq"] as? NSNumber)?.int64Value ?? 0
        if ms <= 0 || sq <= 0 { return nil }
        var ez: [Double] = [0.2, 0, 0, 1]
        if let e = a["e"] as? [Any], e.count == 4 {
            for i in 0..<4 { if let v = (e[i] as? NSNumber)?.doubleValue { ez[i] = max(-1, min(2, v)) } }
        }
        let o = a["o"] as? [String: Any]
        let bgRaw = a["bg"] as? String ?? ""
        return RowAnimSpec(kind: k, ms: ms, sq: sq, bg: bgRaw.isEmpty ? "card" : bgRaw, ez: ez,
                           oS: o?["s"] as? String ?? "", oFill: o?["fill"] as? String, oTc: o?["tc"] as? String)
    }
}

/// 가로 줄: 같은 폭 칸으로 나란히(간격 기본 8). 버튼 세 칸이 바뀌는 줄이면 그 전환을 엔진이 정한 대로 보인다.
struct RowNode: View {
    let node: Node
    let pal: Palette
    var body: some View {
        let gap = CGFloat(node.num("gap", 8))
        let base = HStack(alignment: .top, spacing: gap) {
            ForEach(node.kids) { NodeView(node: $0, pal: pal).frame(maxWidth: .infinity, alignment: .topLeading) }
        }
        if let sp = RowAnimSpec.parse(node) { base.overlay(RowAnimOverlay(node: node, spec: sp, gap: gap, pal: pal)) }
        else { base }
    }
}

/// 최종 모양 위에 카드색 덮개를 얹고 네 조각을 엔진이 정한 종류·시간·곡선대로 움직인다(웹 RowNative). 방금 일어난 전환만 그리고, 아니면 아무것도 안 그린다. 눌림은 아래 단추가 받는다.
struct RowAnimOverlay: View {
    let node: Node
    let spec: RowAnimSpec
    let gap: CGFloat
    let pal: Palette
    @State private var t0: Date? = nil

    var body: some View {
        GeometryReader { g in
            TimelineView(.animation(paused: t0 == nil)) { tl in
                if let t = t0, tl.date.timeIntervalSince(t) * 1000 < Double(spec.ms), g.size.width > 1, g.size.height > 1 {
                    cover(g.size, el: tl.date.timeIntervalSince(t) * 1000)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { start() }
        .onChange(of: spec.sq) { _ in start() }
    }

    private func start() {
        let wall = Int64(Date().timeIntervalSince1970 * 1000)
        guard ActRowCore.fresh(spec.sq, wall) else { t0 = nil; return }
        let ago = Double(max(0, wall - spec.sq))
        t0 = Date().addingTimeInterval(-ago / 1000)
        let left = max(0, Double(spec.ms) - ago) / 1000 + 0.05
        let sq = spec.sq
        Task { @MainActor in try? await Task.sleep(nanoseconds: UInt64(left * 1_000_000_000)); if spec.sq == sq { t0 = nil } }
    }

    @ViewBuilder private func cover(_ s: CGSize, el: Double) -> some View {
        let pcs = ActRowCore.frame(spec.kind, ActRowCore.ease(max(0, el) / Double(spec.ms), spec.ez), W: s.width, H: s.height, g: gap)
        ZStack(alignment: .topLeading) {
            (pal.color(spec.bg) ?? pal.color("card") ?? Color.white).frame(width: s.width, height: s.height)
            ForEach([3, 2, 1, 0], id: \.self) { sl in          // 옛 칸 → 새 칸 → 가운데 → 왼쪽 순(웹과 같다)
                if pcs[sl].show { piece(sl).frame(width: max(0, pcs[sl].w), height: max(0, pcs[sl].h)).offset(x: pcs[sl].x, y: pcs[sl].y) }
            }
        }
        .frame(width: s.width, height: s.height, alignment: .topLeading).clipped()
    }

    @ViewBuilder private func piece(_ sl: Int) -> some View {
        if sl < 3 { NodeView(node: node.kids[sl], pal: pal) }
        else if !spec.oS.isEmpty { oldSlot }
    }

    /// 밀려나는 옛 칸: 셋째 단추의 모양에 글 · 바탕 · 글색만 엔진이 준 것으로(안드로이드 btnCopy + aoS · aoF · aoT).
    private var oldSlot: some View {
        let k = node.kids[2]
        let r = CGFloat(k.num("r", 12))
        let left = k.str("al") == "left"
        func c(_ v: String?, _ def: String) -> Color { pal.color(v) ?? pal.color(def) ?? Color.primary }
        return Text(spec.oS)
            .font(Typo.font(CGFloat(k.num("size", 12)), bold: k.bool("bold")))
            .foregroundColor(c(spec.oTc ?? k.str("tc"), "sub"))
            .lineLimit(1)
            .padding(.horizontal, left ? 11 : 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: left ? .leading : .center)
            .background(RoundedRectangle(cornerRadius: r).fill(c(spec.oFill ?? k.str("fill"), "card")))
            .overlay(RoundedRectangle(cornerRadius: r).strokeBorder(c(k.str("line"), "border"), lineWidth: 1))
    }
}
