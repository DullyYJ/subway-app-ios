import SwiftUI

/// 한 번에 하나만 펼쳐지는 글(안드로이드 ScreenView 의 ok 열쇠): nil 이면 아직 안 만져서 노드의 open 값을 따른다.
@MainActor
final class PostOpen: ObservableObject {
    @Published var key: String? = nil
    func isOpen(_ k: String, initial: Bool) -> Bool { key == nil ? initial : key == k }
    func toggle(_ k: String, initial: Bool) { key = isOpen(k, initial: initial) ? "" : k }
}

private func nodeColor(_ pal: Palette, _ s: String?, _ def: String) -> Color { pal.color(s) ?? pal.color(def) ?? .primary }

// MARK: 상품 카드 격자(grid · card) — 안드로이드 ScreenCore 'grid' 배치: 칸 폭 균등 · 카드 안여백 8 · 그림 78 · 이름 11 굵게(최대 2줄) · 오른쪽 위 태그(금색)
struct CardGridNode: View {
    let node: Node; let pal: Palette
    @EnvironmentObject var host: Host
    var body: some View {
        let cols = max(1, min(4, Int(node.num("cols", 2)))), gap = CGFloat(node.num("gap", 8))
        let cards = node.items.filter { ($0["t"] as? String) == "card" && !(($0["name"] as? String) ?? "").isEmpty }
        let rows = stride(from: 0, to: cards.count, by: cols).map { Array(cards[$0..<min($0 + cols, cards.count)]) }
        VStack(spacing: gap) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                HStack(alignment: .top, spacing: gap) {
                    ForEach(Array(r.enumerated()), id: \.offset) { _, c in CardView(c: c, pal: pal).frame(maxHeight: .infinity, alignment: .top) }
                    if r.count < cols { ForEach(0..<(cols - r.count), id: \.self) { _ in Color.clear.frame(maxWidth: .infinity) } }
                }.fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct CardView: View {
    let c: [String: Any]; let pal: Palette
    @EnvironmentObject var host: Host
    var body: some View {
        let name = c["name"] as? String ?? "", tag = c["tag"] as? String ?? "", fb = c["fb"] as? String ?? ""
        let img = (c["img"] as? String).flatMap { $0.hasPrefix("http") ? URL(string: $0) : nil }
        Button { if let a = Action(c["act"] as? [String: Any]) { host.handle(a) } } label: {
            VStack(alignment: .leading, spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(nodeColor(pal, "imgbg", "card2"))
                    if let u = img {
                        AsyncImage(url: u) { ph in
                            switch ph {
                            case .success(let i): ZStack { RoundedRectangle(cornerRadius: 8).fill(nodeColor(pal, "white", "card")); i.resizable().scaledToFit() }
                            default: Text(fb).font(Typo.font(26))
                            }
                        }
                    } else { Text(fb).font(Typo.font(26)) }
                }
                .frame(height: 78).clipShape(RoundedRectangle(cornerRadius: 8))
                HStack(alignment: .top, spacing: 6) {
                    LinedText(s: name, size: 11, bold: true, lh: 1.35, color: nodeColor(pal, "text", "text"), maxLines: 2)
                    Spacer(minLength: 0)
                    if !tag.isEmpty { Text(tag).font(Typo.font(11, bold: true)).foregroundColor(nodeColor(pal, "gold", "gold")).lineLimit(1).fixedSize() }
                }
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 12).fill(nodeColor(pal, "card", "card")))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(nodeColor(pal, "border", "border"), lineWidth: 1))
        }.buttonStyle(PressStyle(radius: 12))
    }
}

// MARK: 게시글(post) — 둥근 칸 안에 머리(분류 딱지 · 제목 · 글쓴이 · 부가 · 💬 수) · 펼치면 구분선 + 안쪽 노드들
struct PostNode: View {
    let node: Node; let pal: Palette
    @EnvironmentObject var host: Host
    @EnvironmentObject var open: PostOpen
    var body: some View {
        let key = node.str("id") ?? "", cm = Int(node.num("cm", 0))
        let isOpen = open.isOpen(key, initial: node.bool("open"))
        let badge = node.str("cat") ?? ""
        let nick = node.str("nick") ?? "", meta = node.str("meta") ?? ""
        let mp = (node.d["mp"] as? [Any])?.map { "\($0)" }
        VStack(spacing: 0) {
            Button {
                open.toggle(key, initial: node.bool("open"))
                host.handle(Action.tog(key))
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        if !badge.isEmpty {
                            Text(badge).font(Typo.font(10, bold: true)).foregroundColor(nodeColor(pal, "white", "white"))
                                .padding(.horizontal, 7).frame(height: 10 * 1.4 + 4)
                                .background(RoundedRectangle(cornerRadius: 5).fill(pal.color(node.str("catc")) ?? Color(argb: 0xFF8E8E93)))
                        }
                        LinedText(s: node.str("title") ?? "", size: 14, bold: true, lh: 1.4, color: nodeColor(pal, "text", "text"), maxLines: 4)
                    }
                    HStack(spacing: 0) {
                        if !nick.isEmpty { Text(nick).font(Typo.font(11, bold: true)).foregroundColor(nodeColor(pal, "gold", "gold")) }
                        if let mp = mp {
                            ForEach(Array(mp.enumerated()), id: \.offset) { _, t in
                                Text("·").font(Typo.font(10)).foregroundColor(nodeColor(pal, "border2", "border")).padding(.horizontal, 5)
                                Text(t).font(Typo.font(11)).foregroundColor(nodeColor(pal, "sub", "sub"))
                            }
                            if cm > 0 {
                                Text("·").font(Typo.font(10)).foregroundColor(nodeColor(pal, "border2", "border")).padding(.horizontal, 5)
                                Text("💬 \(cm)").font(Typo.font(16)).foregroundColor(nodeColor(pal, "text", "text"))
                            }
                        } else if !meta.isEmpty {
                            Text(meta).font(Typo.font(11)).foregroundColor(nodeColor(pal, "sub", "sub")).lineLimit(1).padding(.leading, nick.isEmpty ? 0 : 5)
                        }
                        Spacer(minLength: 0)
                    }.frame(height: cm > 0 && mp != nil ? 19.4 : 15.4)
                }
                .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }.buttonStyle(PressStyle(radius: 11))
            if isOpen && !node.kids.isEmpty {
                Rectangle().fill(nodeColor(pal, "border2", "border")).frame(height: 1)
                VStack(spacing: 0) { ForEach(node.kids) { NodeView(node: $0, pal: pal) } }
                    .padding(14)
            }
        }
        .padding(1)
        .background(RoundedRectangle(cornerRadius: 12).fill(nodeColor(pal, node.str("fill") ?? "card", "card")))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(nodeColor(pal, node.str("line") ?? "border", "border"), lineWidth: 1))
    }
}

// MARK: 댓글(cmt)
struct CmtNode: View {
    let node: Node; let pal: Palette
    var body: some View {
        let ind = node.bool("ind")
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text((ind ? "↳ " : "") + (node.str("nick") ?? "")).font(Typo.font(11, bold: true)).foregroundColor(pal.color(node.str("nc")) ?? Color(argb: 0xFF5E5CE6))
                if let t = node.str("time"), !t.isEmpty { Text(t).font(Typo.font(10)).foregroundColor(nodeColor(pal, "sub", "sub")) }
            }.frame(height: 11 * 1.4)
            LinedText(s: node.str("s") ?? "", size: 12, bold: false, lh: 1.5, color: nodeColor(pal, "text", "text"))
        }
        .padding(.leading, ind ? 14 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: 단추 줄(btnrow · rbtn) — 높이 30 · 간격 8 · 모서리 8 · 글 12 굵게 · 왼쪽 정렬(right 는 오른쪽 끝) · eq 면 폭을 똑같이
struct BtnRowNode: View {
    let node: Node; let pal: Palette
    @EnvironmentObject var host: Host
    var body: some View {
        let h = CGFloat(node.num("h", 30)), gap = CGFloat(node.num("gap", 8)), r = CGFloat(node.num("r", 8))
        let eq = node.bool("eq"), size = node.num("bsize", 0) > 0 ? CGFloat(node.num("bsize", 12)) : 12
        let items = node.items
        let left = items.filter { !(($0["right"] as? Bool) ?? false) }, right = items.filter { (($0["right"] as? Bool) ?? false) }
        HStack(spacing: gap) {
            ForEach(Array(left.enumerated()), id: \.offset) { _, c in btn(c, h, r, size, eq) }
            if !right.isEmpty { Spacer(minLength: 0) }
            ForEach(Array(right.enumerated()), id: \.offset) { _, c in btn(c, h, r, size, eq) }
            if right.isEmpty && !eq { Spacer(minLength: 0) }
        }
    }
    private func btn(_ c: [String: Any], _ h: CGFloat, _ r: CGFloat, _ size: CGFloat, _ eq: Bool) -> some View {
        Button { if let a = Action(c["act"] as? [String: Any]) { host.handle(a) } } label: {
            Text(c["label"] as? String ?? "").font(Typo.font(size, bold: true)).lineLimit(1)
                .foregroundColor(nodeColor(pal, c["tc"] as? String, "sub"))
                .padding(.horizontal, 12).frame(maxWidth: eq ? .infinity : nil).frame(height: h)
                .background(RoundedRectangle(cornerRadius: r).fill(nodeColor(pal, c["fill"] as? String, "card2")))
                .overlay(RoundedRectangle(cornerRadius: r).strokeBorder(nodeColor(pal, c["line"] as? String, "border2"), lineWidth: 1))
        }.buttonStyle(PressStyle(radius: r))
    }
}
