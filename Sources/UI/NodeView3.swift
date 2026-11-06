import SwiftUI

private func nc(_ pal: Palette, _ s: String?, _ def: String) -> Color {
    if let s = s, !s.isEmpty, let c = pal.color(s) { return c }
    return pal.color(def) ?? .primary
}

// MARK: 홈 입력줄(inbar) — 안드로이드 ScreenCore 'inbar' · ScreenView.drawInbar 와 같다.
// 왼쪽 점(지름 10) → 글자 칸(바탕 띠 ifill) → 오른쪽 단추(너비 = 글자 + bpx*2, 높이 bh, 모서리 9). dim 이면 단추가 흐리고 눌러도 아무 일 없다.
struct InbarNode: View {
    let node: Node; let pal: Palette
    @EnvironmentObject var host: Host
    @State private var text: String
    @FocusState private var focused: Bool
    init(node: Node, pal: Palette) { self.node = node; self.pal = pal; _text = State(initialValue: node.str("value") ?? "") }

    var body: some View {
        let h = CGFloat(node.num("h", 40)), size = CGFloat(node.num("size", 13))
        let bsz = node.num("bsize", 0) > 0 ? CGFloat(node.num("bsize", 0)) : size
        let bh = node.num("bh", 0) > 0 ? min(CGFloat(node.num("bh", 0)), h) : h
        let bpx = node.num("bpx", 0) > 0 ? CGFloat(node.num("bpx", 0)) : 14
        let dim = node.bool("dim"), spin = node.bool("spin") && dim
        let ac = nc(pal, node.str("onc"), "gold"), ck = nc(pal, node.str("ckf"), "#121214")
        let tc = nc(pal, node.str("tc"), "text"), sc = nc(pal, node.str("sc"), "sub")
        let ifh = node.num("ifh", 0) > 0 ? CGFloat(node.num("ifh", 0)) : size + 2
        let key = node.str("key") ?? ""
        let hasDot = !(node.str("dot") ?? "").isEmpty
        return HStack(spacing: 0) {
            if hasDot {
                Circle().fill(nc(pal, node.str("dot"), "gold")).frame(width: 10, height: 10).padding(.leading, 14 + 0).padding(.trailing, 10)
            } else { Color.clear.frame(width: 14, height: 1) }
            TextField("", text: $text, prompt: Text(node.str("hint") ?? "").foregroundColor(sc.opacity(0.8)))
                .font(Typo.font(size, bold: node.bool("bold")))
                .foregroundColor(tc)
                .focused($focused)
                .submitLabel(.search)
                .onSubmit { if let a = Action(node.d["eact"] as? [String: Any]) { host.handle(a) } }
                .frame(height: ifh)
                .background(node.str("ifill") != nil && !(node.str("ifill") ?? "").isEmpty ? RoundedRectangle(cornerRadius: CGFloat(node.num("ifr", 0))).fill(nc(pal, node.str("ifill"), "card2")) : nil)
                .padding(.trailing, 10)
            Button { if !dim, let a = node.act { focused = false; host.handle(a) } } label: {
                HStack(spacing: 6) {
                    if spin { ProgressView().scaleEffect(0.6).tint(ck.opacity(0.75)).frame(width: 10, height: 10) }
                    Text(node.str("btn") ?? "").font(Typo.font(bsz, bold: true)).foregroundColor(ck.opacity(dim ? 0.6 : 1)).lineLimit(1)
                }
                .padding(.horizontal, bpx).frame(height: bh)
                .background(RoundedRectangle(cornerRadius: 9).fill(ac.opacity(dim ? 0.5 : 1)))
            }.buttonStyle(.plain).fixedSize()
        }
        .frame(height: h)
        .onChange(of: text) { v in host.actPublisher.send(Host.TabAction(tab: host.tab, a: "input", v: v, id: "", key: key)) }
        .onChange(of: node.str("value") ?? "") { v in if !focused && v != text { text = v } }
        .onChange(of: host.reloadTick) { _ in }
    }
}

// MARK: 출발↔도착 바꾸기(swap) — 두 줄 경계에 얹히는 동그란 단추(높이를 차지하지 않는다)
struct SwapNode: View {
    let node: Node; let pal: Palette
    @EnvironmentObject var host: Host
    var body: some View {
        let d = CGFloat(node.num("size", 34))
        Color.clear.frame(height: 0).overlay {
            Button { if let a = node.act { host.handle(a) } } label: {
                ZStack {
                    Circle().fill(nc(pal, node.str("line"), "bg")).frame(width: d, height: d)
                    Circle().fill(nc(pal, node.str("fill"), "#0a84ff")).frame(width: d - 5, height: d - 5)
                    SVGIcon(d: node.str("icon") ?? "").fill(nc(pal, node.str("tc"), "white")).frame(width: d * 16 / 34, height: d * 16 / 34)
                }.frame(width: d, height: d)
            }.buttonStyle(.plain)
        }.zIndex(5)
    }
}

// MARK: 기준시각 줄(trow): 🕐 기준시각 · 시각 글 · 작은 안내 · 요일 알약 · 현재 단추
struct TrowNode: View {
    let node: Node; let pal: Palette
    @EnvironmentObject var host: Host
    var body: some View {
        let sub = nc(pal, "sub", "sub")
        let cur = node.bool("cur", true)
        let pill = nc(pal, node.str("dc"), "#30d158")
        return Button { if let a = node.act { host.handle(a) } } label: {
            HStack(spacing: 8) {
                if let lb = node.str("lb"), !lb.isEmpty { Text(lb).font(Typo.font(10)).foregroundColor(sub).lineLimit(1) }
                Text(node.str("s") ?? "").font(Typo.font(12)).foregroundColor(cur ? sub : nc(pal, "text", "text")).lineLimit(1)
                if let h = node.str("hint"), !h.isEmpty { Text(h).font(Typo.font(10)).foregroundColor(sub).lineLimit(1).padding(.leading, -4) }
                Spacer(minLength: 0)
                if let dy = node.str("day"), !dy.isEmpty {
                    Text(dy).font(Typo.font(10, bold: true)).foregroundColor(pill).padding(.horizontal, 7).frame(height: 18)
                        .background(RoundedRectangle(cornerRadius: 8).fill(pill.opacity(0.15)))
                }
                if let b = node.str("btn"), !b.isEmpty {
                    Button { if let a = Action(node.d["bact"] as? [String: Any]) { host.handle(a) } } label: {
                        Text(b).font(Typo.font(10)).foregroundColor(sub).frame(minHeight: 34)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14).frame(height: CGFloat(node.num("h", 34))).contentShape(Rectangle())
        }.buttonStyle(PressStyle(radius: 0))
    }
}
