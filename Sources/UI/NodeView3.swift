import SwiftUI

private func nc3(_ pal: Palette, _ s: String?, _ def: String) -> Color { pal.color(s) ?? pal.color(def) ?? .primary }
private func ins(_ n: Node) -> EdgeInsets { let p = n.pad; return EdgeInsets(top: p.t, leading: p.l, bottom: p.b, trailing: p.r) }

// MARK: lth — 홈 '실시간 대화' 머리줄(안드로이드 K_LTH): 높이 21 · 색 점 7 · 간격 6 · 굵은 제목 12 + 작은 꼬리 글(›). live 면 점이 숨 쉬듯 번졌다 잦아든다(1.8초 주기). 줄 전체가 눌린다.
struct LthNode: View {
    let node: Node; let pal: Palette
    @EnvironmentObject var host: Host
    var body: some View {
        let dot = nc3(pal, node.str("dot"), "#ff3b30"), live = node.bool("live")
        let title = node.str("s") ?? "", tail = node.str("tail") ?? ""
        Button { if let a = node.act { host.handle(a) } } label: {
            HStack(spacing: 6) {
                ZStack {
                    if live { LiveDot(color: dot) } else { Circle().fill(dot).frame(width: 7, height: 7) }
                }.frame(width: 7, height: 7)
                HStack(spacing: 4) {
                    Text(title).font(Typo.font(12, bold: true)).foregroundColor(pal.color("text") ?? .white).lineLimit(1)
                    if !tail.isEmpty { Text(tail).font(Typo.font(12)).foregroundColor(pal.color("sub") ?? .gray).lineLimit(1).layoutPriority(1) }
                }
                Spacer(minLength: 0)
            }
            .frame(height: 21 - 4).padding(.bottom, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(radius: 6))
        .padding(ins(node))
    }
}

struct LiveDot: View {
    let color: Color
    var body: some View {
        TimelineView(.animation) { tl in
            let ms = tl.date.timeIntervalSinceReferenceDate * 1000
            let ph = ms.truncatingRemainder(dividingBy: 1800) / 1800
            let br = 0.5 - 0.5 * cos(ph * 2 * .pi)
            let dr: CGFloat = 3.5
            ZStack {
                Circle().fill(color).opacity((1 - ph) * (1 - ph) * 0.55).frame(width: dr * 2 * (1.2 + 2.6 * ph), height: dr * 2 * (1.2 + 2.6 * ph))
                Circle().fill(color).opacity(0.35 + 0.35 * br).frame(width: dr * 4.2, height: dr * 4.2).blur(radius: 1.5)
                Circle().fill(color).opacity(0.62 + 0.38 * br).frame(width: dr * 2 * (0.92 + 0.12 * br), height: dr * 2 * (0.92 + 0.12 * br))
            }
        }
        .frame(width: 7, height: 7).fixedSize()
    }
}

// MARK: ltr — '실시간 대화' 한 줄(K_LTR): 높이 20 · 닉네임 11 굵게(최대 80, 기본 금색) · 간격 7 · 글 12 한 줄 말줄임 · 오른쪽 시각 9
struct LtrNode: View {
    let node: Node; let pal: Palette
    var body: some View {
        HStack(spacing: 7) {
            if let nk = node.str("nick"), !nk.isEmpty {
                Text(nk).font(Typo.font(11, bold: true)).foregroundColor(nc3(pal, node.str("nc"), "gold")).lineLimit(1).frame(maxWidth: 80, alignment: .leading).fixedSize(horizontal: true, vertical: false)
            }
            Text(node.str("s") ?? "").font(Typo.font(12)).foregroundColor(pal.color("text") ?? .white).lineLimit(1)
            Spacer(minLength: 0)
            if let t = node.str("time"), !t.isEmpty { Text(t).font(Typo.font(9)).foregroundColor(pal.color("sub") ?? .gray).lineLimit(1).fixedSize() }
        }
        .frame(height: 20)
        .padding(ins(node))
    }
}

// MARK: pill — 작은 알약 글자(K_PILL): 글 폭 + 좌우 여백(ph 11)만 차지하고 왼쪽에 붙는다 · 높이 = 글 높이(×1.35) + 위아래 여백(pv 4) · 모서리 r 9
struct PillNode: View {
    let node: Node; let pal: Palette
    var body: some View {
        let size = CGFloat(node.num("size", 11)), ph = CGFloat(node.num("ph", 11)), pv = CGFloat(node.num("pv", 4)), r = CGFloat(node.num("r", 9))
        HStack(spacing: 0) {
            Text(node.str("s") ?? "").font(Typo.font(size, bold: node.bool("bold", true))).foregroundColor(nc3(pal, node.str("tc"), "text")).lineLimit(1)
                .frame(height: size * 1.35).padding(.horizontal, ph).padding(.vertical, pv)
                .background(RoundedRectangle(cornerRadius: r).fill(nc3(pal, node.str("fill"), "card2")))
            Spacer(minLength: 0)
        }
        .padding(ins(node))
    }
}

// MARK: tags — 눌리지 않는 알약 줄(K_TAGS): 칸이 모자라면 다음 줄로 흘러 쓴다 · 기본 높이 24 · 간격 6 · 글 11 · 좌우 여백 10 · 바탕/테두리/글자는 엔진이 정한다
struct FlowLayout: Layout {
    var gap: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 320
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(ProposedViewSize(width: w, height: nil))
            if x > 0 && x + sz.width > w + 0.5 { x = 0; y += rowH + gap; rowH = 0 }
            x += sz.width + gap; rowH = max(rowH, sz.height); maxX = max(maxX, x - gap)
        }
        return CGSize(width: maxX, height: y + rowH)
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(ProposedViewSize(width: b.width, height: nil))
            if x > 0 && x + sz.width > b.width + 0.5 { x = 0; y += rowH + gap; rowH = 0 }
            s.place(at: CGPoint(x: b.minX + x, y: b.minY + y), proposal: ProposedViewSize(width: sz.width, height: sz.height))
            x += sz.width + gap; rowH = max(rowH, sz.height)
        }
    }
}

struct TagsNode: View {
    let node: Node; let pal: Palette
    var body: some View {
        let gap = CGFloat(node.num("gap", 6)), h = CGFloat(node.num("h", 24)), size = CGFloat(node.num("size", 11)), px = CGFloat(node.num("px", 10))
        HStack(spacing: 0) {
            FlowLayout(gap: gap) {
                ForEach(Array(node.items.prefix(12).enumerated()), id: \.offset) { _, c in
                    let lab = c["s"] as? String ?? ""
                    if !lab.isEmpty {
                        Text(lab).font(Typo.font(size, bold: (c["b"] as? Bool) ?? false)).foregroundColor(nc3(pal, c["tc"] as? String, "text")).lineLimit(1)
                            .padding(.horizontal, px).frame(height: h)
                            .background(Capsule().fill(pal.color(c["c"] as? String) ?? .clear))
                            .overlay(Capsule().strokeBorder(pal.color(c["oc"] as? String) ?? .clear, lineWidth: 1))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(ins(node))
    }
}
