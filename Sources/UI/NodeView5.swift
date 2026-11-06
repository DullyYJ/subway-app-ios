import SwiftUI

private func c5(_ pal: Palette, _ s: String?, _ def: String) -> Color {
    if let s = s, !s.isEmpty, let c = pal.color(s) { return c }
    return pal.color(def) ?? .primary
}

// MARK: 시트 머리(shd): 위 8 · 손잡이 40x5(아래 8) · 제목 15 굵게(최대 2줄, 줄 높이 ×1.3) + 오른쪽 ×(28 동그라미) · 아래 8 · 좌우 18
struct ShdNode: View {
    let node: Node; let pal: Palette
    @EnvironmentObject var host: Host
    var body: some View {
        let text = c5(pal, "text", "text")
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3).fill(c5(pal, "border2", "border2")).frame(width: 40, height: 5).padding(.top, 8).padding(.bottom, 8)
            HStack(alignment: .center, spacing: 8) {
                LinedText(s: node.str("title") ?? "", size: 15, bold: true, lh: 1.3, color: text, maxLines: 2)
                Button { if let a = node.act { host.handle(a) } } label: {
                    ZStack {
                        Circle().fill(Color(red: 120 / 255, green: 120 / 255, blue: 128 / 255).opacity(0.16)).frame(width: 28, height: 28)
                        Path { p in p.move(to: CGPoint(x: -4.2, y: -4.2)); p.addLine(to: CGPoint(x: 4.2, y: 4.2)); p.move(to: CGPoint(x: 4.2, y: -4.2)); p.addLine(to: CGPoint(x: -4.2, y: 4.2)) }
                            .stroke(text, style: StrokeStyle(lineWidth: 1.7, lineCap: .round)).frame(width: 0, height: 0)
                    }.frame(width: 28, height: 28)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 18).padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: 세부경로 줄(tdrow): 진행 레일(34) · 아이콘 동그라미 · 뱃지(24) · 경유 글 · 오른쪽 시간 · 펼침 정거장(27 간격)
struct TdrowNode: View {
    let node: Node; let pal: Palette
    @EnvironmentObject var host: Host
    @State private var open: Bool
    init(node: Node, pal: Palette) { self.node = node; self.pal = pal; _open = State(initialValue: node.bool("op")) }

    private var stops: [[Any]] { (node.d["stops"] as? [[Any]]) ?? [] }
    var body: some View {
        let sub = c5(pal, "sub", "sub"), border = c5(pal, "border", "border"), card = c5(pal, "card", "card")
        let col = c5(pal, node.str("col"), "sub")
        let pos = node.str("pos") ?? "m", ic = node.str("ic") ?? "w"
        let ex = node.bool("ex"), idx = Int(node.num("i", -1))
        let lab = node.str("lab") ?? "", path = node.str("path") ?? "", cnt = node.str("cnt") ?? ""
        let time = node.str("time") ?? "", rng = node.str("rng") ?? ""
        let dep = node.num("dep", 0), arr = node.num("arr", 0)
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                // 진행 레일: 바탕 선 + (지나온 만큼 채움은 TimelineView) — 첫 줄은 가운데부터, 마지막 줄은 가운데까지
                TimelineView(.periodic(from: .now, by: 1)) { tl in
                    let now = tl.date.timeIntervalSince1970 * 1000
                    let act = arr > dep && now >= dep && now < arr
                    let ratio: Double = arr <= dep ? 0 : now >= arr ? 1 : now <= dep ? 0 : (now - dep) / (arr - dep)
                    GeometryReader { g in
                        let hh = g.size.height
                        let t0: CGFloat = (pos == "f" || pos == "o") ? hh / 2 : 0, t1: CGFloat = (pos == "l" || pos == "o") ? hh / 2 : hh
                        let sx: CGFloat = 16 + 17
                        ZStack(alignment: .topLeading) {
                            if act { Rectangle().fill(c5(pal, "card2", "card2")) }
                            Rectangle().fill(c5(pal, node.str("trk"), "border")).frame(width: 3, height: max(0, t1 - t0)).offset(x: sx - 1.5, y: t0)
                            if ratio > 0 { Rectangle().fill(col).frame(width: 3, height: max(0, (t1 - t0) * ratio)).offset(x: sx - 1.5, y: t0) }
                            ZStack {
                                Circle().fill(card).frame(width: 34, height: 34)
                                Circle().fill(c5(pal, node.str("ibg"), "card2")).frame(width: 30, height: 30)
                                ZStack { TdIcon(kind: ic).stroke(col, style: StrokeStyle(lineWidth: 1.8, lineCap: .round)); TdIcon(kind: ic, fills: true).fill(col) }.frame(width: 16, height: 16)
                            }.frame(width: 34, height: 34).position(x: sx, y: hh / 2 - 0.5)
                            if act {
                                let my = t0 + (t1 - t0) * ratio
                                Circle().fill(Color(hex: 0xFF3B30).opacity(0.3)).frame(width: 17, height: 17).position(x: sx, y: my)
                                Circle().fill(Color.white).frame(width: 13, height: 13).position(x: sx, y: my)
                                Circle().fill(Color(hex: 0xFF3B30)).frame(width: 8, height: 8).position(x: sx, y: my)
                            }
                        }
                    }
                }
                // 글 영역
                HStack(alignment: .center, spacing: 12) {
                    Color.clear.frame(width: 34, height: 1)
                    VStack(alignment: .leading, spacing: 0) {
                        if !lab.isEmpty {
                            HStack(spacing: 8) {
                                Text(lab).font(Typo.font(13, bold: true)).foregroundColor(c5(pal, node.str("bfg"), "sub")).lineLimit(1).truncationMode(.tail)
                                    .padding(.horizontal, 11).frame(height: 24)
                                    .background(Capsule().fill(c5(pal, node.str("bbg"), "card2")))
                                if ex {
                                    ZStack {
                                        Circle().fill(c5(pal, "card2", "card2")).frame(width: 19, height: 19)
                                        Circle().strokeBorder(border, lineWidth: 1).frame(width: 19, height: 19)
                                        Path { p in p.move(to: CGPoint(x: -3.6, y: -1.6)); p.addLine(to: CGPoint(x: 3.6, y: -1.6)); p.addLine(to: CGPoint(x: 0, y: 2.2)); p.closeSubpath() }
                                            .fill(sub).frame(width: 0, height: 0)
                                    }.rotationEffect(.degrees(open ? 180 : 0)).animation(.easeOut(duration: 0.2), value: open)
                                }
                            }
                        }
                        if !path.isEmpty { LinedText(s: path, size: 12, lh: 16.0 / 12.0, color: sub, maxLines: 2).padding(.top, 5) }
                        if !cnt.isEmpty { Text(cnt).font(Typo.font(11)).foregroundColor(sub).frame(height: 15, alignment: .leading).padding(.top, 2) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 2) {
                        if !time.isEmpty { Text(time).font(Typo.font(14, bold: true)).foregroundColor(c5(pal, node.str("tcol"), "sub")).frame(height: 18) }
                        if !rng.isEmpty { Text(rng).font(Typo.font(10)).foregroundColor(sub).frame(height: 13) }
                    }.fixedSize()
                }
                .padding(.horizontal, 16).padding(.vertical, 13).frame(minHeight: 34 + 26)
            }
            .overlay(alignment: .bottom) { Rectangle().fill(border).frame(height: 1) }
            .contentShape(Rectangle())
            .onTapGesture {
                guard ex else { return }
                if idx >= 0 { open.toggle() } else if let a = node.act { host.handle(a) }
            }
            if (open || node.bool("op")) && !stops.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(stops.enumerated()), id: \.offset) { _, s in
                        let name = s.count > 0 ? (s[0] as? String ?? "") : "", lb = s.count > 1 ? (s[1] as? String ?? "") : ""
                        let end = s.count > 2 ? ((s[2] as? NSNumber)?.doubleValue ?? 0) != 0 : false
                        HStack(spacing: 0) {
                            ZStack {
                                Circle().fill(col).frame(width: 9, height: 9)
                                if !end { Circle().fill(card).frame(width: 5, height: 5) }
                            }.frame(width: 9, height: 9).padding(.leading, 60)
                            Text(name).font(Typo.font(12, bold: end)).foregroundColor(end ? c5(pal, "text", "text") : sub).lineLimit(1).padding(.leading, 10)
                            Spacer(minLength: 8)
                            Text(lb).font(Typo.font(11)).foregroundColor(sub).lineLimit(1).padding(.trailing, 16)
                        }.frame(height: 27)
                    }
                }.padding(.top, 4).padding(.bottom, 8)
            }
        }
    }
}

/// 구간 아이콘(손으로 그린 선 모양: w 도보 · s 지하철 · b 버스). 중심 기준 16 안에 그린다(안드로이드 tdIcon 좌표 그대로).
struct TdIcon: Shape {
    let kind: String
    var fills = false          // true: 채운 작은 동그라미만 · false: 선만
    func path(in r: CGRect) -> Path {
        let cx = r.midX, cy = r.midY
        func L(_ p: inout Path, _ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) { p.move(to: CGPoint(x: cx + x0, y: cy + y0)); p.addLine(to: CGPoint(x: cx + x1, y: cy + y1)) }
        var p = Path()
        func dot(_ x: CGFloat, _ y: CGFloat, _ rad: CGFloat) { p.addEllipse(in: CGRect(x: cx + x - rad, y: cy + y - rad, width: rad * 2, height: rad * 2)) }
        if kind == "w" {
            if fills { dot(1, -6, 2) } else { L(&p, 1, -3.2, -1, 1.8); L(&p, -1, 1.8, -4, 6.5); L(&p, -1, 1.8, 2.5, 6.5); L(&p, 0.6, -2, 4.2, 0.2); L(&p, 0.6, -2, -3, -0.8) }
        } else if kind == "s" {
            if fills { dot(-2.4, 1.5, 1.1); dot(2.4, 1.5, 1.1) }
            else { p.addRoundedRect(in: CGRect(x: cx - 5, y: cy - 7, width: 10, height: 11.5), cornerSize: CGSize(width: 3, height: 3)); L(&p, -5, -1.5, 5, -1.5); L(&p, -3.5, 4.5, -5.2, 7.5); L(&p, 3.5, 4.5, 5.2, 7.5) }
        } else {
            if fills { dot(-3, 2, 1.1); dot(3, 2, 1.1) }
            else { p.addRoundedRect(in: CGRect(x: cx - 6, y: cy - 7, width: 12, height: 12.5), cornerSize: CGSize(width: 2.5, height: 2.5)); L(&p, -6, -1.5, 6, -1.5); L(&p, -3.5, 5.5, -3.5, 7.5); L(&p, 3.5, 5.5, 3.5, 7.5) }
        }
        return p
    }
}
