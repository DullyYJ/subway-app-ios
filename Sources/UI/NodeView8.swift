import SwiftUI

private func nc8(_ pal: Palette, _ s: String?, _ def: String) -> Color { pal.color(s) ?? pal.color(def) ?? .primary }
private func ins8(_ n: Node) -> EdgeInsets { let p = n.pad; return EdgeInsets(top: p.t, leading: p.l, bottom: p.b, trailing: p.r) }

// 노선 상세 색(안드로이드 C_UP/C_DOWN/C_NA/C_ME)
private let brUp = Color(red: 0, green: 0xB3 / 255, blue: 0x41 / 255)
private let brDown = Color(red: 1, green: 0x9F / 255, blue: 0x0A / 255)
private let brNa = Color(red: 0x2F / 255, green: 0x7C / 255, blue: 0xF6 / 255)
private let brMe = Color(red: 1, green: 0x3B / 255, blue: 0x30 / 255)
private func brCls(_ k: String?) -> Color { k == "up" ? brUp : k == "down" ? brDown : brNa }

private struct BrPill: View {
    let text: String; let h: CGFloat; let fill: Color; let stroke: Color?; let tc: Color; let size: CGFloat; let px: CGFloat
    var body: some View {
        Text(text).font(Typo.font(size, bold: true)).foregroundColor(tc).lineLimit(1).fixedSize()
            .padding(.horizontal, px).frame(height: h)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(stroke ?? .clear, lineWidth: stroke == nil ? 0 : 1))
    }
}
private struct BrBottomLine: View {
    let pal: Palette; var inset: CGFloat = 0
    var body: some View { Rectangle().fill(pal.color("border") ?? .gray).frame(height: 1).padding(.leading, inset) }
}

// MARK: brh — 노선 상세 머리: 높이 52 · 번호 배지(높이 28 · 모서리 8 · 글 15 굵게 흰색 · 좌우 11) · 종류 글 12 · 오른쪽 ↻(18) ✕(17) 36 칸
struct BrhNode: View {
    let node: Node; let pal: Palette
    @EnvironmentObject var host: Host
    var body: some View {
        let sub = pal.color("sub") ?? .gray
        HStack(spacing: 0) {
            Text(node.str("no") ?? "").font(Typo.font(15, bold: true)).foregroundColor(.white).lineLimit(1).fixedSize()
                .padding(.horizontal, 11).frame(minWidth: 46, minHeight: 28, maxHeight: 28)
                .background(RoundedRectangle(cornerRadius: 8).fill(nc8(pal, node.str("c"), "#7f8c8d")))
            if let tp = node.str("tp"), !tp.isEmpty { Text(tp).font(Typo.font(12)).foregroundColor(sub).lineLimit(1).padding(.leading, 8) }
            Spacer(minLength: 0)
            Button { if let a = Action(node.d["bact"] as? [String: Any]) { host.handle(a) } } label: {
                Text("\u{21BB}").font(Typo.font(18)).foregroundColor(sub).frame(width: 36, height: 36)
            }.buttonStyle(.plain)
            Button { if let a = node.act { host.handle(a) } } label: {
                Text("\u{2715}").font(Typo.font(17)).foregroundColor(sub).frame(width: 36, height: 36)
            }.buttonStyle(.plain)
            Color.clear.frame(width: 0)
        }
        .padding(.leading, 16).padding(.trailing, 12)
        .frame(height: 52)
        .background(pal.color("card") ?? .black)
        .overlay(alignment: .bottom) { BrBottomLine(pal: pal) }
        .padding(ins8(node))
    }
}

// MARK: brt — 노선 상세 제목: 기점 → 종점(14 굵게, 위 12 · 높이 20) · 방향 알약(높이 18 · 글 11) · 요약 칩들(글 11.5 · 좌우 9 · 위아래 4 · 간격 6)
struct BrtNode: View {
    let node: Node; let pal: Palette
    var body: some View {
        let text = pal.color("text") ?? .white, sub = pal.color("sub") ?? .gray
        let tag = node.str("tag") ?? "", cls = brCls(node.str("tk"))
        let chips = Array(node.list("chips").prefix(6))
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(node.str("a") ?? "").font(Typo.font(14, bold: true)).foregroundColor(text).lineLimit(1)
                Text("\u{2192}").font(Typo.font(14, bold: true)).foregroundColor(sub).fixedSize()
                Text(node.str("b") ?? "").font(Typo.font(14, bold: true)).foregroundColor(text).lineLimit(1)
                Spacer(minLength: 0)
                if !tag.isEmpty { BrPill(text: tag, h: 18, fill: cls.opacity(0.14), stroke: nil, tc: cls, size: 11, px: 8) }
            }.frame(height: 20)
            if !chips.isEmpty {
                TagFlowLayout(gap: 6) {
                    ForEach(Array(chips.enumerated()), id: \.offset) { _, c in
                        let k = c["k"] as? String ?? ""
                        let tc: Color = k == "on" ? brNa : k == "me" ? brMe : sub
                        let fl: Color = k == "on" ? brNa.opacity(0.12) : k == "me" ? brMe.opacity(0.12) : (pal.color("bg") ?? .black)
                        let st: Color = k == "on" ? brNa.opacity(0.25) : k == "me" ? brMe.opacity(0.25) : (pal.color("border") ?? .gray)
                        Text(c["s"] as? String ?? "").font(Typo.font(11.5, bold: true)).foregroundColor(tc).lineLimit(1)
                            .padding(.horizontal, 9).frame(height: 11.5 * 1.3 + 8)
                            .background(Capsule().fill(fl)).overlay(Capsule().strokeBorder(st, lineWidth: 1))
                    }
                }
            }
        }
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(pal.color("card") ?? .black)
        .overlay(alignment: .bottom) { BrBottomLine(pal: pal) }
        .padding(ins8(node))
    }
}

// MARK: brsec — 상행/하행 구간 머리: 높이 34 · ▼ 13 굵게(구간색) · 이름 12.5 굵게 + ' 방면' 12.5 보조색 · 오른쪽 알약
struct BrsecNode: View {
    let node: Node; let pal: Palette
    var body: some View {
        let cls = brCls(node.str("k")), tag = node.str("tag") ?? ""
        HStack(spacing: 0) {
            Text("\u{25BC}").font(Typo.font(13, bold: true)).foregroundColor(cls).frame(width: 18, alignment: .leading)
            Text(node.str("s") ?? "").font(Typo.font(12.5, bold: true)).foregroundColor(pal.color("text") ?? .white).lineLimit(1)
            Text(" \u{BC29}\u{BA74}").font(Typo.font(12.5)).foregroundColor(pal.color("sub") ?? .gray).fixedSize()
            Spacer(minLength: 8)
            if !tag.isEmpty { BrPill(text: tag, h: 18, fill: cls.opacity(0.14), stroke: nil, tc: cls, size: 11, px: 8) }
        }
        .padding(.horizontal, 16).frame(height: 34)
        .background(pal.color("bg") ?? .black)
        .overlay(alignment: .bottom) { BrBottomLine(pal: pal) }
        .padding(ins8(node))
    }
}

// MARK: brturn — 회차 알약: 높이 34 안에 높이 22 가운데 알약(주황 14% 바탕 · 30% 테두리 · 글 11.5 굵게)
struct BrturnNode: View {
    let node: Node; let pal: Palette
    var body: some View {
        HStack {
            Spacer(minLength: 0)
            BrPill(text: node.str("s") ?? "회차 \u{21BB}", h: 22, fill: brDown.opacity(0.14), stroke: brDown.opacity(0.30), tc: brDown, size: 11.5, px: 13)
            Spacer(minLength: 0)
        }
        .frame(height: 34)
        .padding(ins8(node))
    }
}

// MARK: brs — 노선 상세 정류장 줄: 왼쪽 레일(x 26, 폭 5) + 점(바깥 6.5 · 안 4.5 흰색) / 버스(맥박 파랑 원 10.5) / 내 위치(빨강 맥박) · 이름 15 굵게 · 번호 11.5 · 알림 12 굵게(줄당 17) · 오른쪽 라벨 알약
struct BrsNode: View {
    let node: Node; let pal: Palette
    @EnvironmentObject var host: Host
    var body: some View {
        let cls = brCls(node.str("k")), tag = node.str("ps") ?? "", lab = node.str("lab") ?? ""
        let badge = node.str("mk") ?? "", here = node.bool("here") || node.num("here", 0) > 0, mine = node.bool("mine") || node.num("mine", 0) > 0
        let go = node.str("fl") ?? "", big = node.bool("ar") || node.num("ar", 0) > 0
        let notes = Array(node.list("notes").prefix(3))
        let id = node.str("id") ?? ""
        let nc = notes.count
        let bodyH: CGFloat = 20 + (id.isEmpty ? 0 : 3 + 15) + CGFloat(nc) * 17
        let rowH = max(56, 20 + bodyH)
        let bg: Color = tag == "s" ? brDown.opacity(0.14) : tag == "p" ? brNa.opacity(0.14) : mine ? brMe.opacity(0.09) : here ? brNa.opacity(0.08) : .clear
        let nameC: Color = mine ? brMe : here ? brNa : (pal.color("text") ?? .white)
        Button { if let a = node.act { host.handle(a) } } label: {
            ZStack(alignment: .topLeading) {
                bg
                // 레일
                GeometryReader { g in
                    let cy = rowH / 2
                    let lt: CGFloat = go.contains("f") ? cy : 0, lb: CGFloat = go.contains("l") ? cy : rowH
                    Rectangle().fill(cls).frame(width: 5, height: max(0, lb - lt)).offset(x: 26 - 2.5, y: lt)
                    BrsMarker(kind: badge, cls: cls, big: big).frame(width: 60, height: 60).offset(x: 26 - 30, y: cy - 30)
                }
                // 본문
                VStack(alignment: .leading, spacing: 0) {
                    Text(node.str("nm") ?? "").font(Typo.font(15, bold: true)).foregroundColor(nameC).lineLimit(1).frame(height: 20, alignment: .leading)
                    if !id.isEmpty { Text(id).font(Typo.font(11.5)).foregroundColor(pal.color("sub") ?? .gray).frame(height: 15, alignment: .leading).padding(.top, 3) }
                    ForEach(Array(notes.enumerated()), id: \.offset) { _, n in
                        Text(n["s"] as? String ?? "").font(Typo.font(12, bold: true)).foregroundColor((n["k"] as? String) == "me" ? brMe : brNa).lineLimit(1).frame(height: 17, alignment: .leading)
                    }
                }
                .padding(.leading, 48).padding(.top, 10).padding(.trailing, lab.isEmpty ? 16 : 80)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                if !lab.isEmpty {
                    HStack { Spacer(minLength: 0)
                        if tag == "s" { BrPill(text: lab, h: 18, fill: brDown.opacity(0.22), stroke: nil, tc: Color(red: 0xC7 / 255, green: 0x77 / 255, blue: 0), size: 11, px: 8) }
                        else { Text(lab).font(Typo.font(11, bold: true)).foregroundColor(brNa.opacity(0.9)).padding(.horizontal, 8) }
                    }.frame(height: 18).padding(.trailing, 16).padding(.top, rowH / 2 - 9)
                }
            }
            .frame(height: rowH + 1, alignment: .top)
            .overlay(alignment: .bottom) { Rectangle().fill(pal.color("border") ?? .gray).frame(height: 1).padding(.leading, 48).padding(.trailing, 16) }
        }
        .buttonStyle(.plain)
        .padding(ins8(node))
    }
}

private struct BrsMarker: View {
    let kind: String; let cls: Color; let big: Bool
    var body: some View {
        ZStack {
            if kind == "bus" {
                TimelineView(.animation) { tl in
                    let ph = (tl.date.timeIntervalSinceReferenceDate * 1000).truncatingRemainder(dividingBy: 1100) / 1100
                    ZStack {
                        Circle().fill(brNa.opacity(0.45 * (1 - ph))).frame(width: 21 * (1 + 1.4 * ph), height: 21 * (1 + 1.4 * ph))
                        Circle().fill(brNa).frame(width: 21, height: 21).scaleEffect(1 + 0.15 * sin(ph * .pi))
                        // 버스 몸통
                        RoundedRectangle(cornerRadius: 2).fill(.white).frame(width: 9, height: 9).offset(y: -0.5)
                        Rectangle().fill(brNa).frame(width: 6.4, height: 2.8).offset(y: -3)
                        Circle().fill(.white).frame(width: 2.4, height: 2.4).offset(x: -2.4, y: 4.6)
                        Circle().fill(.white).frame(width: 2.4, height: 2.4).offset(x: 2.4, y: 4.6)
                    }
                }
            } else if kind == "me" {
                TimelineView(.animation) { tl in
                    let ph = (tl.date.timeIntervalSinceReferenceDate * 1000).truncatingRemainder(dividingBy: 1600) / 1600
                    ZStack {
                        Circle().fill(brMe.opacity(0.5 * (1 - ph))).frame(width: 17 * (1 + 1.7 * ph), height: 17 * (1 + 1.7 * ph))
                        Circle().fill(.white).frame(width: 18, height: 18)
                        Circle().fill(brMe).frame(width: 13, height: 13)
                        Circle().fill(.white).frame(width: 5, height: 5)
                    }
                }
            } else {
                Circle().fill(cls).frame(width: 13, height: 13)
                Circle().fill(.white).frame(width: 9, height: 9)
                if big { Text("\u{25BC}").font(Typo.font(7, bold: true)).foregroundColor(.white).offset(y: 12) }
            }
        }
    }
}

// MARK: chart — 24시간 막대 차트: 틀(card2 · 모서리 11 · 테두리 1) 안에 머리줄(제목 11 · 출처 9 · 피크 11 굵게 오른쪽) + 가로로 미는 막대줄
// 막대 칸 폭 28 · 막대 폭 16(위 모서리 3) · 아래 시간 글 8(현재는 굵게) · 지금 막대는 바깥 테두리 2 · 운행 없는 시간(o)은 흐린 낮은 막대
struct ChartNode: View {
    let node: Node; let pal: Palette
    var body: some View {
        let bh = CGFloat(node.num("bh", 112)), ci = Int(node.num("ci", -1))
        let sub = pal.color("sub") ?? .gray, pc = nc8(pal, node.str("pc"), "gold"), co = nc8(pal, node.str("co"), "#ffffff")
        let bars = node.list("bars")
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Text(node.str("ttl") ?? "").font(Typo.font(11)).foregroundColor(sub).lineLimit(1).fixedSize()
                if let s = node.str("src"), !s.isEmpty { Text(s).font(Typo.font(9)).foregroundColor(sub).lineLimit(1) }
                Spacer(minLength: 0)
                if let pk = node.str("pk"), !pk.isEmpty { Text(pk).font(Typo.font(11, bold: true)).foregroundColor(pc).lineLimit(1).fixedSize() }
            }
            .frame(height: 15).padding(.leading, 11).padding(.trailing, 11)
            GeometryReader { g in
                let side = max(0, (g.size.width - 22) / 2 - 14) + 11   // 안드로이드: 안쪽 왼쪽 11 + 첫 막대 앞 빈 칸(안쪽폭/2 - 14)
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(Array(bars.enumerated()), id: \.offset) { i, b in
                                ChartBar(b: b, cur: b["u"] as? Bool ?? false, bh: bh, pal: pal, co: co).id(i)
                            }
                        }
                        .padding(.horizontal, side)
                    }
                    .task { if ci >= 0 { try? await Task.sleep(nanoseconds: 250_000_000); proxy.scrollTo(ci, anchor: .center) } }
                }
            }
            .frame(height: bh + 4)
            .padding(.top, 9)
            Color.clear.frame(height: 7)
        }
        .padding(.top, 11)
        .background(RoundedRectangle(cornerRadius: 11).fill(pal.color("card2") ?? .gray.opacity(0.2)))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(pal.color("border") ?? .gray, lineWidth: 1))
        .padding(ins8(node))
    }
}
private struct ChartBar: View {
    let b: [String: Any]; let cur: Bool; let bh: CGFloat; let pal: Palette; let co: Color
    var body: some View {
        let off = b["o"] as? Bool ?? false
        let v = CGFloat((b["v"] as? NSNumber)?.doubleValue ?? 0), a = (b["a"] as? NSNumber)?.doubleValue ?? 1
        let fc = pal.color(b["c"] as? String) ?? Color(red: 0x34 / 255, green: 0xC7 / 255, blue: 0x59 / 255)
        let sub = pal.color("sub") ?? .gray
        let lc: Color = cur ? (pal.color("text") ?? .white) : sub
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                if off {
                    RoundedRectangle(cornerRadius: 2).fill((pal.color("border2") ?? .gray).opacity(0.35)).frame(width: 16, height: 4)
                } else {
                    let h = max(4, v)
                    UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 3).fill(fc.opacity(a)).frame(width: 16, height: h)
                        .overlay { if cur { UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 4).strokeBorder(co, lineWidth: 2).frame(width: 20, height: h + 2).offset(y: -1) } }
                }
            }.frame(height: bh - 13, alignment: .bottom)
            Text(b["h"] as? String ?? "").font(Typo.font(8, bold: cur)).foregroundColor(off ? lc.opacity(0.35) : lc).frame(height: 13)
        }
        .frame(width: 28, height: bh)
    }
}

// MARK: pickl — 밀어 고르는 목록: 줄 높이 h(38) · 보이는 줄 vis(5) · 줄 = 모서리 9 · 고른 줄 gold 바탕 흰 글 / 아닌 줄 card2 + border2 · 왼쪽 라벨 13 굵게(12) · 가운데 보조 글(12) · 오른쪽 값 13 굵게
// plain: 활동 기록 — 바탕 없이 한 줄 글(size 12.5 · 고른 줄 굵고 text색) · fold: 접힌 채로는 고른 줄만, 눌러 펼친다(▾/▴)
struct PicklNode: View {
    let node: Node; let pal: Palette
    @EnvironmentObject var host: Host
    @State private var open: Bool
    init(node: Node, pal: Palette) { self.node = node; self.pal = pal; _open = State(initialValue: node.bool("open")) }
    var body: some View {
        let plain = node.bool("plain"), fold = node.bool("fold") && node.list("rows").count > 1
        let h = CGFloat(node.num("h", 38)), vis = max(1, min(8, Int(node.num("vis", 5))))
        let rows = node.list("rows")
        let onIdx = rows.firstIndex { ($0["on"] as? Bool) == true } ?? 0
        let shown = Swift.min(rows.count, vis)
        let tail: CGFloat = plain ? 0 : 4
        let fullH = CGFloat(shown) * h - tail
        let collH = h - 4
        Group {
            if fold && !open {
                row(rows[onIdx], idx: onIdx, plain: plain, fold: true, h: h)
                    .frame(height: collH)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: rows.count > shown) {
                        VStack(spacing: 0) {
                            ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                                row(r, idx: i, plain: plain, fold: fold, h: h).frame(height: plain ? h : h - 4).padding(.bottom, plain ? 0 : 4).id(i)
                            }
                        }
                    }
                    .frame(height: fullH)
                    .onAppear { DispatchQueue.main.async { proxy.scrollTo(plain ? rows.count - 1 : onIdx, anchor: plain ? .bottom : .center) } }
                }
            }
        }
        .padding(ins8(node))
    }
    @ViewBuilder private func row(_ r: [String: Any], idx: Int, plain: Bool, fold: Bool, h: CGFloat) -> some View {
        let on = (r["on"] as? Bool) == true
        let size = CGFloat(node.num("size", 12.5))
        let sub = pal.color("sub") ?? .gray, text = pal.color("text") ?? .white
        Button {
            if fold && !open { withAnimation(.easeOut(duration: 0.18)) { open = true }; return }
            if fold && open { withAnimation(.easeOut(duration: 0.18)) { open = false } }
            if let a = Action(r["act"] as? [String: Any]) { host.handle(a) }
        } label: {
            if plain {
                Text(r["a"] as? String ?? "").font(Typo.font(size, bold: on)).foregroundColor(on ? text : sub).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                let tc: Color = on ? .white : text, sc: Color = on ? Color.white.opacity(0.9) : sub
                ZStack {
                    HStack(spacing: 0) {
                        Text(r["a"] as? String ?? "").font(Typo.font(13, bold: true)).foregroundColor(tc).lineLimit(1)
                        Spacer(minLength: 0)
                    }.padding(.leading, 12)
                    GeometryReader { g in
                        Text(r["b"] as? String ?? "").font(Typo.font(12)).foregroundColor(sc).lineLimit(1)
                            .offset(x: g.size.width * 0.5 - (fold && on ? 8 : 0), y: (g.size.height - 16) / 2)
                    }
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Text(r["c"] as? String ?? "").font(Typo.font(13, bold: true)).foregroundColor(tc).lineLimit(1)
                            .padding(.trailing, fold && on ? 30 : 12)
                    }
                    if fold && on {
                        Image(systemName: open ? "chevron.up" : "chevron.down").font(.system(size: 9, weight: .bold)).foregroundColor(tc)
                            .frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 12)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 9).fill(on ? (pal.color("gold") ?? .yellow) : (pal.color("card2") ?? .gray.opacity(0.2))))
                .overlay { if !on { RoundedRectangle(cornerRadius: 9).strokeBorder(pal.color("border2") ?? .gray, lineWidth: 1) } }
            }
        }.buttonStyle(.plain)
    }
}

// MARK: search — 알약 검색창: 높이 44 · 폭 min(max, 칸) 가운데 · card 바탕 + border 1 · 왼쪽 배지 원 20(accent · 글 12 굵게 흰색, 왼쪽 14) · 입력(8 띄움) · 오른쪽 돋보기 단추 원 30(accent, 오른쪽 8)
struct SearchNode: View {
    let node: Node; let pal: Palette
    @EnvironmentObject var host: Host
    @Environment(\.openURL) private var openURL
    @State private var text = ""
    @FocusState private var focus: Bool
    var body: some View {
        let accent = nc8(pal, node.str("accent"), "#e63329"), maxW = CGFloat(node.num("max", 340))
        let maxlen = Int(node.num("maxlen", 60)), badge = node.str("badge") ?? ""
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                ZStack { Circle().fill(accent); if !badge.isEmpty { Text(badge).font(Typo.font(12, bold: true)).foregroundColor(.white) } }.frame(width: 20, height: 20)
                TextField("", text: $text, prompt: Text(node.str("hint") ?? "").foregroundColor((pal.color("sub") ?? .gray).opacity(0.8)))
                    .font(Typo.font(13)).foregroundColor(pal.color("text") ?? .white)
                    .focused($focus).submitLabel(.search).onSubmit(go)
                    .onChange(of: text) { v in if v.count > maxlen { text = String(v.prefix(maxlen)) } }
                Button(action: go) {
                    Image(systemName: "magnifyingglass").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                        .frame(width: 30, height: 30).background(Circle().fill(accent))
                }.buttonStyle(.plain)
            }
            .padding(.leading, 14).padding(.trailing, 8).frame(height: 44)
            .background(Capsule().fill(pal.color("card") ?? .black))
            .overlay(Capsule().strokeBorder(pal.color("border") ?? .gray, lineWidth: 1))
            .frame(maxWidth: maxW)
            Spacer(minLength: 0)
        }
        .padding(ins8(node))
    }
    /// act.tpl 의 {q} 에 입력을 끼워 연다. 비었으면 act.empty.
    private func go() {
        focus = false
        guard let a = node.d["act"] as? [String: Any] else { return }
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw: String
        if q.isEmpty { raw = a["empty"] as? String ?? "" }
        else { raw = (a["tpl"] as? String ?? "").replacingOccurrences(of: "{q}", with: q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&=+#?"))) ?? q) }
        if let u = URL(string: raw), u.scheme == "http" || u.scheme == "https" { openURL(u) }
    }
}

// MARK: runner — 경로 탐색 로딩(웹 #transitLoading): 달리는 칸 98 · 제목 14 굵게(위 8 · 높이 19) 뒤 점 3개 · 안내 11(위 4 · 높이 14) = 총 143
// 캐릭터는 방금 나온 것이 아닌 하나를 뽑아(시각으로 정해지는 값) 화면을 한 번 가로지르면 다음 캐릭터로 넘어간다. 시트(256px 칸 4×4)에서 칸을 잘라 안드로이드와 같은 자리·크기로 그린다.
final class RunnerState {
    var id = "", prev = "", t0: Int64 = 0, born: Int64 = 0, last: Int64 = 0
}
struct RunnerNode: View {
    let node: Node; let pal: Palette
    @State private var st = RunnerState()
    private func nowMs(_ d: Date) -> Int64 { Int64(d.timeIntervalSince1970 * 1000) }
    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.animation) { tl in
                let now = nowMs(tl.date)
                let _ = step(now)
                let t = now - st.born
                Canvas { ctx, size in draw(ctx, size, now: now, t: t) }
                    .frame(height: RunnerCore.trackH)
            }.frame(height: RunnerCore.trackH)
            TimelineView(.animation) { tl in
                let t = nowMs(tl.date) - st.born
                HStack(spacing: 0) {
                    Text(node.str("ttl") ?? "").font(Typo.font(14, bold: true)).foregroundColor(pal.color("text") ?? .white)
                    ForEach(0..<3, id: \.self) { i in
                        Text(".").font(Typo.font(14, bold: true)).foregroundColor((pal.color("text") ?? .white).opacity(RunnerCore.dotAlpha(t, i)))
                    }
                }.frame(height: RunnerCore.ttlH)
            }.padding(.top, RunnerCore.ttlGap)
            Group {
                if let s = node.str("sub"), !s.isEmpty { Text(s).font(Typo.font(11)).foregroundColor(pal.color("sub") ?? .gray) }
                else { Color.clear }
            }.frame(height: RunnerCore.subH).padding(.top, RunnerCore.subGap)
        }
        .frame(maxWidth: .infinity)
        .padding(ins8(node))
    }
    /// 새로 보이기 시작(0.4초 넘게 안 그려졌다) → 캐릭터를 하나 뽑는다
    private func step(_ now: Int64) {
        if st.id.isEmpty || now - st.last > 400 {
            st.id = RunnerCore.pick(st.prev, RunnerCore.unit(now)); st.prev = st.id; st.t0 = now; st.born = now
            RunnerArt.warm(first: st.id)
        }
        st.last = now
    }
    private func draw(_ ctx: GraphicsContext, _ size: CGSize, now: Int64, t: Int64) {
        let w = size.width, hc = RunnerCore.trackH
        let line = pal.color("border2") ?? .gray
        var f = RunnerCore.at(st.id, now - st.t0, w)
        if f.done { st.id = RunnerCore.pick(st.id, RunnerCore.unit(now)); st.prev = st.id; st.t0 = now; f = RunnerCore.at(st.id, 0, w); RunnerArt.warm(first: st.id) }
        let file = f.intro ? "dudung_intro" : RunnerCore.file(st.id, now)
        func dash(_ c: GraphicsContext, _ x0: CGFloat, _ x1: CGFloat, _ y: CGFloat, _ off: CGFloat) {
            var x = x0 - 16 + off
            while x < x1 {
                let a = max(x0, x), b = min(x1, x + 8)
                if b > a { var p = Path(); p.move(to: CGPoint(x: a, y: y)); p.addLine(to: CGPoint(x: b, y: y)); c.stroke(p, with: .color(line), lineWidth: 2) }
                x += 16
            }
        }
        if let img = RunnerArt.get(file), let d = RunnerCore.spec(st.id) {
            let sc = CGFloat(d.cell / 256), gy = hc - 12
            var c = ctx
            c.clip(to: Path(CGRect(x: 0, y: 0, width: w, height: hc)))
            dash(c, 0, w, gy + 3, CGFloat((Double(t) / 1000 * 40).truncatingRemainder(dividingBy: 16)))   // 바닥 점선: 초당 40 으로 흐른다
            let sw = CGFloat(d.cell * d.sh)                                                              // 그림자
            c.fill(Path(ellipseIn: CGRect(x: f.shadowX - sw / 2, y: gy + 3 - 3, width: sw, height: 6)), with: .color(Color.black.opacity(0.2)))
            let col = f.idx % 4, row = f.idx / 4
            let left = f.x - CGFloat(d.ox) * sc, top = gy + 3 - CGFloat(d.lift) - CGFloat(d.base) * sc, cell = CGFloat(d.cell)
            var cc = c
            cc.clip(to: Path(CGRect(x: left, y: top, width: cell, height: cell)))
            cc.draw(Image(uiImage: img), in: CGRect(x: left - CGFloat(col) * cell, y: top - CGFloat(row) * cell, width: cell * 4, height: cell * 4))
        } else {                                                                                          // 시트를 아직 못 읽었다 → 굴러가는 바퀴
            let tw = RunnerCore.wheelTrackW, th = RunnerCore.wheelTrackH
            let tx = (w - tw) / 2, ty = (hc - th) / 2, cy = ty + th / 2 + 1
            var c = ctx
            var base = Path(); base.move(to: CGPoint(x: tx, y: ty + th)); base.addLine(to: CGPoint(x: tx + tw, y: ty + th))
            c.stroke(base, with: .color(line), style: StrokeStyle(lineWidth: 2, dash: [8, 8]))
            c.clip(to: Path(CGRect(x: tx, y: ty - 4, width: tw, height: th + 8)))
            let wx = tx + RunnerCore.wheelX(t, tw) + 12, gold = pal.color("gold") ?? .yellow
            c.stroke(Path(ellipseIn: CGRect(x: wx - 10, y: cy - 2 - 10, width: 20, height: 20)), with: .color(gold), lineWidth: 3)
            var r = c
            r.translateBy(x: wx, y: cy - 2); r.rotate(by: .degrees(Double(RunnerCore.wheelRot(t))))
            var ln = Path(); ln.move(to: CGPoint(x: -10, y: 0)); ln.addLine(to: CGPoint(x: 10, y: 0))
            r.stroke(ln, with: .color(gold), lineWidth: 2)
        }
    }
}
