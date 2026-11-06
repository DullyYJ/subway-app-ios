import SwiftUI

/// 말풍선 한 줄(msg) — 안드로이드 ScreenCore K_MSG: 폭은 칸의 74% 까지 · 안쪽 가로 11 · 세로 8 · 글 13(줄 높이 1.45) · 모서리 13 ·
/// 남의 글은 위에 닉네임(11, 아래 3) · 말풍선 아래 3 띄워 시각(9) · 내 글은 오른쪽 · 안 읽음 '1'(금색) · go 글(밑줄)을 누르면 행동.
struct FracWidth: Layout {
    var frac: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let s = subviews.first else { return .zero }
        let w = (proposal.width ?? 320) * frac
        return s.sizeThatFits(ProposedViewSize(width: w, height: nil))
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let s = subviews.first else { return }
        let sz = s.sizeThatFits(ProposedViewSize(width: b.width * frac, height: nil))
        s.place(at: b.origin, proposal: ProposedViewSize(width: sz.width, height: sz.height))
    }
}

struct MsgNode: View {
    let node: Node; let pal: Palette
    @EnvironmentObject var host: Host
    var body: some View {
        let mine = node.bool("mine")
        let p = node.pad
        let fill = pal.color(node.str("fill")) ?? (mine ? pal.color("gold") : pal.color("card2")) ?? .gray
        let tc = pal.color(node.str("tc")) ?? (mine ? Color(hex: 0x121214) : pal.color("text")) ?? .white
        let sub = pal.color("sub") ?? .gray
        let nick = ((node.str("pre") ?? "").isEmpty ? "" : (node.str("pre") ?? "") + " ") + (node.str("nick") ?? "")
        let badge = node.str("badge") ?? "", time = node.str("time") ?? "", go = node.str("go") ?? ""
        let act = node.act
        VStack(alignment: mine ? .trailing : .leading, spacing: 0) {
            if !mine && !nick.isEmpty {
                Text(nick).font(Typo.font(11)).foregroundColor(sub).lineLimit(1).padding(.bottom, 3)
            }
            FracWidth(frac: 0.74) {
                VStack(alignment: .leading, spacing: 0) {
                    if !badge.isEmpty {
                        Text(badge).font(Typo.font(10, bold: true)).foregroundColor(pal.color(node.str("bc")) ?? Color(hex: 0xFF453A)).frame(height: 14)
                    }
                    Text(node.str("s") ?? "").font(Typo.font(13)).foregroundColor(tc).lineSpacing(13 * 1.45 - 15.5).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 11).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 13).fill(fill))
            }
            .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
            .frame(height: nil)
            HStack(spacing: 0) {
                if node.bool("un") { Text("1").font(Typo.font(9, bold: true)).foregroundColor(pal.color("gold") ?? .yellow).padding(.trailing, 5) }
                if !time.isEmpty { Text(time).font(Typo.font(9)).foregroundColor(sub) }
                if !go.isEmpty, let a = act {
                    Text(" · ").font(Typo.font(9)).foregroundColor(sub.opacity(0.75))
                    Button { host.handle(a) } label: { Text(go).font(Typo.font(9)).underline().foregroundColor(sub.opacity(0.75)) }.buttonStyle(.plain)
                }
            }
            .padding(.top, 3).frame(height: 13, alignment: .leading)
        }
        .padding(EdgeInsets(top: p.t, leading: p.l, bottom: p.b, trailing: p.r))
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
    }
}
