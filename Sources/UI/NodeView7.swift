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
struct TagFlowLayout: Layout {
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
            TagFlowLayout(gap: gap) {
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

// MARK: sec — 카드 위 제목줄(웹 .sec): 제목 12(자간 0.4, 보조색) · (알약 18 높이) · (가운데 작은 굵은 글 11.5) · (오른쪽 금색 테두리 단추 높이 23)
struct SecNode: View {
    let node: Node; let pal: Palette
    @EnvironmentObject var host: Host
    var body: some View {
        let size = CGFloat(node.num("size", 12)), btn = node.str("btn") ?? "", hasBtn = !btn.isEmpty
        let h: CGFloat = node.num("h", 0) > 0 ? CGFloat(node.num("h", 0)) : (hasBtn ? 23 : floor(size * 1.42))
        let sub = pal.color("sub") ?? .gray, gold = pal.color("gold") ?? .yellow
        HStack(spacing: 8) {
            Text(node.str("s") ?? "").font(Typo.font(size)).tracking(0.4).foregroundColor(sub).lineLimit(1).fixedSize()
            if let b = node.str("badge"), !b.isEmpty {
                Text(b).font(Typo.font(10, bold: true)).foregroundColor(pal.color("white") ?? .white).padding(.horizontal, 8).frame(height: 18)
                    .background(RoundedRectangle(cornerRadius: 6).fill(nc3(pal, node.str("bc"), "#1d9bf0")))
            }
            if let hint = node.str("hint"), !hint.isEmpty { Text(hint).font(Typo.font(11.5, bold: true)).foregroundColor(sub).lineLimit(1) }
            Spacer(minLength: 0)
            if hasBtn {
                Button { if let a = node.act { host.handle(a) } } label: {
                    Text(btn).font(Typo.font(11, bold: true)).foregroundColor(gold).padding(.horizontal, 14).frame(height: 23)
                        .overlay(Capsule().strokeBorder(gold, lineWidth: 1))
                }.buttonStyle(.plain)
            }
        }
        .frame(height: h)
        .padding(ins(node))
    }
}

// MARK: gauge — 혼잡도 게이지(K_GAUGE): 글 두 개(왼쪽 이름 · 오른쪽 %, 10 보조색, 높이 14) + 5 띄워 둥근 막대(높이 8, 틀 border2 · 채움 기본 #34c759) · 전체 27
struct GaugeNode: View {
    let node: Node; let pal: Palette
    var body: some View {
        let v = max(0, min(1, node.num("v", 0) / 100)), fill = nc3(pal, node.str("c"), "#34c759")
        VStack(spacing: 5) {
            HStack {
                Text(node.str("s") ?? "").font(Typo.font(10)).foregroundColor(pal.color("sub") ?? .gray)
                Spacer(minLength: 0)
                Text(node.str("txt") ?? "").font(Typo.font(10)).foregroundColor(pal.color("sub") ?? .gray)
            }.frame(height: 14)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(pal.color("border2") ?? .gray.opacity(0.3))
                    if v > 0 { Capsule().fill(fill).frame(width: max(8, g.size.width * v)) }
                }
            }.frame(height: 8)
        }
        .frame(height: 27, alignment: .top)
        .padding(ins(node))
    }
}

// MARK: cgh — 혼잡도 머리줄(K_CGH): 왼쪽 '지하철 강남'(이름 13 굵은 금색, 앞 글 보조색) + 아래 작은 글 11 · 오른쪽 혼잡 단계 17 굵게 · 높이 33
struct CghNode: View {
    let node: Node; let pal: Palette
    var body: some View {
        let sub = pal.color("sub") ?? .gray
        let lab = (node.str("lab") ?? "").isEmpty ? "" : (node.str("lab") ?? "") + " "
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    if !lab.isEmpty { Text(lab).font(Typo.font(13)).foregroundColor(sub) }
                    Text(node.str("nm") ?? "").font(Typo.font(13, bold: true)).foregroundColor(pal.color("gold") ?? .yellow).lineLimit(1)
                }.frame(height: 18)
                if let m = node.str("meta"), !m.isEmpty { Text(m).font(Typo.font(11)).foregroundColor(sub).lineLimit(1).frame(height: 15) }
            }
            Spacer(minLength: 0)
            if let st = node.str("st"), !st.isEmpty { Text(st).font(Typo.font(17, bold: true)).foregroundColor(nc3(pal, node.str("sc"), "sub")).frame(height: 33).fixedSize() }
        }
        .frame(height: 33)
        .padding(ins(node))
    }
}

// MARK: cars — 칸별 혼잡(K_CARS): 제목 11(높이 15 · 아래 6) + 칸 가로줄(칸 높이 58 · 간격 4 · 테두리 1.5 색 · 글 세 줄 11 굵게/10/10) / 칸이 없으면 안내 글 11
struct CarsNode: View {
    let node: Node; let pal: Palette
    var body: some View {
        let sub = pal.color("sub") ?? .gray
        let cells = node.items.prefix(12)
        VStack(alignment: .leading, spacing: 0) {
            if let t = node.str("ttl"), !t.isEmpty { Text(t).font(Typo.font(11)).foregroundColor(sub).lineLimit(1).frame(height: 15).padding(.bottom, 6) }
            if cells.isEmpty {
                Text(node.str("msg") ?? "").font(Typo.font(11)).foregroundColor(sub).frame(height: 26, alignment: .center)
            } else {
                HStack(spacing: 4) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { _, c in
                        let col = nc3(pal, c["c"] as? String, "#34c759")
                        VStack(spacing: 0) {
                            Text(c["n"] as? String ?? "").font(Typo.font(11, bold: true)).foregroundColor(col).lineLimit(1).frame(height: 14).padding(.top, 7.5)
                            Text(c["l"] as? String ?? "").font(Typo.font(10)).foregroundColor(sub).lineLimit(1).frame(height: 12.5).padding(.top, 2)
                            Text(c["p"] as? String ?? "").font(Typo.font(10)).foregroundColor(col).lineLimit(1).frame(height: 12.5).padding(.top, 2)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity).frame(height: 58)
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(col, lineWidth: 1.5))
                    }
                }
            }
        }
        .padding(ins(node))
    }
}

// MARK: lpills — 줄 바꿈 노선 알약들(웹 _linePillHtml): 글 13 굵게 흰색 · 높이 27(숫자 있으면 34, 동그라미 22 반투명 흰색) · 좌우 14(숫자면 왼쪽 6) · 간격 7
struct LpillsNode: View {
    let node: Node; let pal: Palette
    var body: some View {
        let gap = CGFloat(node.num("gap", 7)), items = node.items
        let anyNum = items.contains { !(($0["num"] as? String) ?? "").isEmpty }
        HStack(spacing: 0) {
            TagFlowLayout(gap: gap) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, c in
                    let num = (c["num"] as? String) ?? ""
                    HStack(spacing: 6) {
                        if !num.isEmpty {
                            Text(num).font(Typo.font(12, bold: true)).foregroundColor(.white).frame(width: 22, height: 22).background(Circle().fill(Color.white.opacity(0.28)))
                        }
                        Text(c["s"] as? String ?? "").font(Typo.font(13, bold: true)).foregroundColor(.white).lineLimit(1)
                    }
                    .padding(.leading, num.isEmpty ? 14 : 6).padding(.trailing, 14)
                    .frame(height: anyNum ? 34 : 27)
                    .background(Capsule().fill(nc3(pal, c["c"] as? String, "#8e8e93")))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(ins(node))
    }
}

// MARK: skel — 스켈레톤(뼈대): 카드 모양 자리표시가 숨 쉬듯 옅어졌다 짙어진다(1.3초). list 줄 68 · cards 132 · map 200 · 간격 10 · 모서리 14
struct SkelNode: View {
    let node: Node; let pal: Palette
    var body: some View {
        let kind = node.str("kind") ?? "list", rows = max(1, min(14, Int(node.num("rows", 6))))
        TimelineView(.animation) { tl in
            let ph = (tl.date.timeIntervalSinceReferenceDate * 1000).truncatingRemainder(dividingBy: 1300) / 1300
            let pulse = 0.5 + 0.5 * sin(ph * 2 * .pi)
            let bar = (pal.color("border") ?? .gray).opacity((110 + 100 * pulse) / 255)
            VStack(spacing: 10) {
                if kind == "map" { RoundedRectangle(cornerRadius: 14).fill(bar).frame(height: 200) }
                ForEach(0..<rows, id: \.self) { _ in
                    let cards = kind == "cards"
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 14).fill(pal.color("card") ?? .black)
                        RoundedRectangle(cornerRadius: 14).strokeBorder(pal.color("border") ?? .gray, lineWidth: 1)
                        GeometryReader { g in
                            let w = g.size.width
                            if cards {
                                RoundedRectangle(cornerRadius: 6).fill(bar).frame(width: w * 0.55 - 14, height: 14).offset(x: 14, y: 14)
                                RoundedRectangle(cornerRadius: 6).fill(bar).frame(width: w - 28, height: 14).offset(x: 14, y: 44)
                                RoundedRectangle(cornerRadius: 6).fill(bar).frame(width: w * 0.8 - 14, height: 14).offset(x: 14, y: 68)
                                RoundedRectangle(cornerRadius: 10).fill(bar).frame(width: 82, height: 20).offset(x: 14, y: 98)
                            } else {
                                Circle().fill(bar).frame(width: 36, height: 36).offset(x: 14, y: 16)
                                RoundedRectangle(cornerRadius: 6).fill(bar).frame(width: (w - 90) * 0.62, height: 14).offset(x: 62, y: 16)
                                RoundedRectangle(cornerRadius: 6).fill(bar).frame(width: (w - 90) * 0.9, height: 12).offset(x: 62, y: 40)
                            }
                        }
                    }.frame(height: cards ? 132 : 68)
                }
            }
        }
        .padding(ins(node))
    }
}

// MARK: lbar — 불러오는 중 막대(K_LBAR): 높이 84 · 제목 14 굵게(가운데) · 막대 폭 min(칸-56, 260) 높이 8 · 퍼센트 12 금색 · 안내 11.5 · 진행은 앱이 시간으로 그린다(1-e^(-t/1.8s), 최대 99%)
struct LbarNode: View {
    let node: Node; let pal: Palette
    @State private var t0 = Date()
    var body: some View {
        TimelineView(.animation) { tl in
            let pr = min(0.99, 1 - exp(-tl.date.timeIntervalSince(t0) / 1.8))
            VStack(spacing: 0) {
                Text(node.str("ttl") ?? "").font(Typo.font(14, bold: true)).foregroundColor(pal.color("text") ?? .white).frame(height: 22).padding(.top, 8)
                GeometryReader { g in
                    let bw = min(g.size.width - 56, 260)
                    ZStack(alignment: .leading) {
                        Capsule().fill(pal.color("border") ?? .gray)
                        Capsule().fill(pal.color("gold") ?? .yellow).frame(width: max(8, bw * pr))
                    }.frame(width: bw, height: 8).frame(maxWidth: .infinity)
                }.frame(height: 8).padding(.top, 8)
                Text("\(Int((pr * 100).rounded()))%").font(Typo.font(12, bold: true)).foregroundColor(pal.color("gold") ?? .yellow).frame(height: 18).padding(.top, 6)
                if let s = node.str("sub"), !s.isEmpty { Text(s).font(Typo.font(11.5)).foregroundColor(pal.color("sub") ?? .gray).frame(height: 16).padding(.top, -0) }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 84)
        .padding(ins(node))
    }
}

// MARK: aih — AI 승무원 카드 머리줄(K_AIH): 높이 28 · 제목 13.5 굵게 · 다음 갱신 카운트다운 알약(11 굵게, 높이 19, 좌우 8, 모서리 8) · 오른쪽 새로고침 단추 30×28(모서리 9, card2 + border)
struct AihNode: View {
    let node: Node; let pal: Palette
    @EnvironmentObject var host: Host
    var body: some View {
        let until = node.num("to", 0), done = node.str("done") ?? "", busy = node.bool("bd")
        let pc = nc3(pal, node.str("pc"), "#2f7cf6"), pf = pal.color(node.str("pf")) ?? Color(red: 47/255, green: 124/255, blue: 246/255).opacity(0.12)
        HStack(spacing: 8) {
            Text(node.str("s") ?? "").font(Typo.font(13.5, bold: true)).foregroundColor(pal.color("text") ?? .white).lineLimit(1)
            Spacer(minLength: 0)
            if until > 0 {
                TimelineView(.periodic(from: .now, by: 1)) { tl in
                    let rem = max(0, Int(((until - tl.date.timeIntervalSince1970 * 1000) / 1000).rounded()))
                    Text(rem > 0 ? String(format: "%d:%02d", rem / 60, rem % 60) : done).font(Typo.font(11, bold: true)).foregroundColor(pc)
                        .padding(.horizontal, 8).frame(height: 19).background(RoundedRectangle(cornerRadius: 8).fill(pf))
                }
            }
            Button { if !busy, let a = node.act { host.handle(a) } } label: {
                SVGIcon(d: node.str("icon") ?? "").fill((pal.color("text") ?? .white).opacity(busy ? 0.4 : 1)).frame(width: 16, height: 16)
                    .frame(width: 30, height: 28)
                    .background(RoundedRectangle(cornerRadius: 9).fill(pal.color("card2") ?? .gray.opacity(0.2)))
                    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(pal.color("border") ?? .gray, lineWidth: 1))
            }.buttonStyle(.plain)
        }
        .frame(height: 28)
        .padding(ins(node))
    }
}
