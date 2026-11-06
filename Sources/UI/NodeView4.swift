import SwiftUI

private func rc(_ pal: Palette, _ s: Any?, _ def: String) -> Color {
    if let s = s as? String, !s.isEmpty, let c = pal.color(s) { return c }
    return pal.color(def) ?? .primary
}
private func rcOpt(_ pal: Palette, _ s: Any?) -> Color? {
    if let s = s as? String, !s.isEmpty { return pal.color(s) }
    return nil
}
private func dn(_ d: [String: Any], _ k: String, _ def: Double) -> CGFloat {
    if let n = d[k] as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() { return CGFloat(n.doubleValue) }
    return CGFloat(def)
}
private func db(_ d: [String: Any], _ k: String) -> Bool { (d[k] as? NSNumber)?.boolValue ?? false }

// MARK: 경로 결과 머리줄(rhd): 큰 분 숫자(28 굵게) + 단위(14) + 구간명(12) + (즐겨찾기 알약) + (닫기 ×) — 글자 밑선을 맞춘다
struct RhdNode: View {
    let node: Node; let pal: Palette
    @EnvironmentObject var host: Host
    var body: some View {
        let msg = node.str("msg") ?? "", num = node.str("num") ?? ""
        let isMsg = !msg.isEmpty && num.isEmpty
        let sub = rc(pal, "sub", "sub"), txt = rc(pal, "text", "text"), gold = rc(pal, "gold", "gold")
        let btn = node.str("btn") ?? ""
        let xact = Action(node.d["xact"] as? [String: Any])
        return HStack(alignment: .lastTextBaseline, spacing: 0) {
            if isMsg {
                Text(msg).font(Typo.font(14, bold: true)).foregroundColor(txt).lineLimit(1)
            } else {
                Text(num).font(Typo.font(28, bold: true)).foregroundColor(txt).lineLimit(1).fixedSize()
                if let u = node.str("unit"), !u.isEmpty { Text(u).font(Typo.font(14)).foregroundColor(sub).padding(.leading, 5).fixedSize() }
                if let s = node.str("s"), !s.isEmpty { Text(s).font(Typo.font(12)).foregroundColor(sub).lineLimit(1).padding(.leading, 13) }
            }
            Spacer(minLength: 8)
            if !btn.isEmpty {
                Button { if let a = node.act { host.handle(a) } } label: {
                    Text(btn).font(Typo.font(11, bold: true)).foregroundColor(gold).padding(.horizontal, 8).frame(height: 22)
                        .overlay(Capsule().strokeBorder(gold, lineWidth: 1))
                }.buttonStyle(.plain).padding(.trailing, xact != nil ? 4 : 0).alignmentGuide(.lastTextBaseline) { $0[VerticalAlignment.center] + 5 }
            }
            if let xa = xact {
                Button { host.handle(xa) } label: { Text("\u{00D7}").font(Typo.font(22)).foregroundColor(sub).frame(width: 28, height: 28) }
                    .buttonStyle(.plain).alignmentGuide(.lastTextBaseline) { $0[VerticalAlignment.center] + 8 }
            }
        }
        .frame(height: 34)
    }
}

// MARK: 구간 타임라인(trk): 칸(역·도보) 가로 줄. 칸 = 이름(30) · 배지(18) · 선+점(26) · 시각(3 간격 + 16) = 93. 시각·색·글은 전부 엔진이 정한다.
struct TrkNode: View {
    let node: Node; let pal: Palette
    var body: some View {
        let cells = node.d["cells"] as? [[String: Any]] ?? []
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, c in TrkCell(c: c, pal: pal) }
            }
        }
        .frame(height: 93)
    }
}

private struct TrkCell: View {
    let c: [String: Any]; let pal: Palette
    var body: some View {
        let w = dn(c, "w", 64)
        let past = db(c, "ps")
        let dim: Double = past ? 0.35 : 1
        let name = (c["n"] as? String ?? "").replacingOccurrences(of: "\n", with: " ")
        let g = c["g"] as? String ?? ""
        let gk = c["gk"] as? String ?? "p"
        let gc = rcOpt(pal, c["gc"]) ?? (pal.color("sub") ?? .gray)
        let dk = c["dk"] as? String ?? ""
        let dc = rcOpt(pal, c["dc"]) ?? .gray
        let dc2 = rcOpt(pal, c["dc2"]) ?? dc
        let time = c["t"] as? String ?? ""
        VStack(spacing: 0) {
            Text(name).font(Typo.font(dn(c, "ns", 10), bold: db(c, "nb"))).foregroundColor(rc(pal, c["nc"], "text").opacity(dim))
                .lineLimit(1).truncationMode(.tail).frame(width: w - 4, height: 30 - dn(c, "np", 0), alignment: .bottom)
                .padding(.bottom, dn(c, "np", 0)).frame(height: 30, alignment: .bottom)
            Group {
                if g.isEmpty { Color.clear }
                else if gk == "p" {
                    Text(g).font(Typo.font(dn(c, "gs", 7), bold: true)).foregroundColor(.white).padding(.horizontal, dn(c, "gx", 4))
                        .frame(height: dn(c, "gs", 7) * 1.25 + 2).background(RoundedRectangle(cornerRadius: 4).fill(gc))
                } else { Text(g).font(Typo.font(dn(c, "gs", 7), bold: true)).foregroundColor(gc) }
            }.frame(width: w, height: 18)
            ZStack(alignment: .top) {
                HStack(spacing: 0) {
                    Rectangle().fill((rcOpt(pal, c["lc"]) ?? .clear).opacity(dim)).frame(height: 3)
                    Rectangle().fill((rcOpt(pal, c["rc"]) ?? .clear).opacity(dim)).frame(height: 3)
                }.frame(width: w).padding(.top, 12)
                dot(dk: dk, dc: dc, dc2: dc2, past: past).frame(width: 14, height: 14).padding(.top, 6)
            }.frame(width: w, height: 26, alignment: .top)
            Text(time).font(Typo.font(dn(c, "ts", 9), bold: db(c, "tb"))).foregroundColor(rc(pal, c["tc"], "sub").opacity(dim))
                .lineLimit(1).frame(width: w, height: 16).padding(.top, 3)
        }
        .frame(width: w, height: 93, alignment: .top)
    }

    @ViewBuilder private func dot(dk: String, dc: Color, dc2: Color, past: Bool) -> some View {
        let card = pal.color("card") ?? .black
        if past {
            let r: CGFloat = dk == "e" ? 7 : dk == "m" ? 3 : 6
            ZStack { Circle().fill(Color(red: 0x55 / 255, green: 0x55 / 255, blue: 0x55 / 255).opacity(0.3)).frame(width: r * 2, height: r * 2)
                if dk == "r" { Circle().fill(card).frame(width: 6, height: 6) } }
        } else if dk == "e" { Circle().fill(dc).frame(width: 14, height: 14) }
        else if dk == "r" { ZStack { Circle().fill(dc).frame(width: 12, height: 12); Circle().fill(card).frame(width: 6, height: 6) } }
        else if dk == "m" {
            HStack(spacing: 0) { Rectangle().fill(dc).frame(width: 3, height: 6); Rectangle().fill(dc2).frame(width: 3, height: 6) }.clipShape(Circle())
        } else { Color.clear.frame(width: 1, height: 1) }
    }
}
