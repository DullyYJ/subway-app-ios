import SwiftUI

/// 단추 노드. 경로 방식 탭(rh.tab.*)을 누르면 새 화면이 오기 전에 그 자리에서 먼저 켜 보인다 — 바탕 · 테두리 · 글 색을 0.15초 동안 섞는다(웹 transition .15s · 안드로이드 pickRtab).
struct ButtonNode: View {
    let node: Node
    let pal: Palette
    @EnvironmentObject var host: Host
    @Environment(\.curScreen) private var curScreen
    @ObservedObject private var pick = ChipPick.shared

    var body: some View {
        let r = CGFloat(node.num("r", 12)), left = node.str("al") == "left"
        let st = pick.restyle[ChipPick.bkey(node.d)] ?? BtnStyle(node.d)
        func c(_ v: String?, _ def: String) -> Color { pal.color(v) ?? pal.color(def) ?? .primary }
        return Button {
            if let a = node.act {
                if ChipPick.isRtab(node.d) { pick.pickBtn(node.d, in: curScreen) }
                host.handle(a)
            }
        } label: {
            Text(node.str("s") ?? "")
                .font(Typo.font(CGFloat(node.num("size", 12)), bold: node.bool("bold")))
                .foregroundColor(c(st.tc, "sub"))
                .lineLimit(1).truncationMode(.tail)
                .padding(.horizontal, left ? 11 : 8)
                .frame(maxWidth: .infinity, alignment: left ? .leading : .center)
                .frame(height: CGFloat(node.num("h", 40)))
                .background(RoundedRectangle(cornerRadius: r).fill(c(st.fill, "card")))
                .overlay(RoundedRectangle(cornerRadius: r).strokeBorder(c(st.line, "border"), lineWidth: 1))
                .animation(.easeOut(duration: 0.15), value: st)
        }.buttonStyle(PressStyle(radius: r))
    }
}
