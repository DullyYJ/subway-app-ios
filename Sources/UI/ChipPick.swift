import SwiftUI

/// 칩 · 경로 방식 탭(rh.tab.*) · 두 칸 단추(btog)를 누르면(또는 밀어서 칸을 넘기면) 새 화면이 오기 전에 먼저 켜 보인다(안드로이드 ScreenView.pickChip · pickRtab · pickBtog · lightChip).
/// 서버를 기다리지 않아 바로 바뀐다. 새 화면이 오면 그 화면의 값이 맞으니 지운다.

/// 단추 한 개의 모양(바탕 · 테두리 · 글 색 이름) — 켜진 단추와 눌린 단추가 서로 맞바꾼다.
struct BtnStyle: Equatable {
    var fill: String?, line: String?, tc: String?
    init(_ d: [String: Any]) { fill = d["fill"] as? String; line = d["line"] as? String; tc = d["tc"] as? String }
}

@MainActor
final class ChipPick: ObservableObject {
    static let shared = ChipPick()
    @Published private(set) var picks: [String: String] = [:]
    /// 단추 열쇠 → 먼저 보일 모양(경로 방식 탭: 눌린 단추는 켜진 모양으로, 켜져 있던 단추는 눌린 단추의 모양으로).
    @Published private(set) var restyle: [String: BtnStyle] = [:]

    /// 한 칩 줄을 가리키는 열쇠: 줄 안 칩들의 행동 값을 이은 것.
    nonisolated static func rowKey(_ items: [[String: Any]]) -> String {
        items.compactMap { ($0["act"] as? [String: Any])?["v"] as? String }.joined(separator: "|")
    }
    func pick(items: [[String: Any]], v: String) {
        let k = ChipPick.rowKey(items)
        if !k.isEmpty { picks[k] = v }
    }
    /// 밀어서 넘긴 행동(cat v)이 이 화면의 어느 칩 줄에 있으면 그 칩을 켠다.
    func light(_ a: Action, in screen: Screen) {
        if a.a == "call", let v = a.v, v.hasPrefix("rh.tab.") {          // 결과 카드를 밀어 탭을 넘길 때도 위 탭 단추를 먼저 켜 보인다
            for list in [screen.head.map(\.d), screen.body.map(\.d)] {
                if let row = ChipPick.findRow(list, key: v), let p = row.first(where: { ChipPick.bkey($0) == v }) { pickBtn(p, in: screen); return }
            }
            return
        }
        guard a.a == "cat", let v = a.v else { return }
        for n in screen.head + screen.body where n.t == "chips" {
            let has = n.items.contains { (($0["act"] as? [String: Any])?["a"] as? String) == "cat" && (($0["act"] as? [String: Any])?["v"] as? String) == v }
            if has { pick(items: n.items, v: v); return }
        }
    }
    func clear() { if !picks.isEmpty { picks = [:] }; if !restyle.isEmpty { restyle = [:] } }

    // MARK: 경로 방식 탭 단추(안드로이드 ScreenView.pickRtab)
    /// 단추의 열쇠: 행동 값(없으면 글).
    nonisolated static func bkey(_ d: [String: Any]) -> String {
        if let v = (d["act"] as? [String: Any])?["v"] as? String, !v.isEmpty { return v }
        return d["s"] as? String ?? ""
    }
    nonisolated static func isRtab(_ d: [String: Any]) -> Bool { (d["t"] as? String) == "button" && bkey(d).hasPrefix("rh.tab.") }
    /// key 단추가 들어 있는 줄(같은 부모의 자식들) 안의 경로 탭 단추들.
    nonisolated static func findRow(_ nodes: [[String: Any]], key: String, depth: Int = 0) -> [[String: Any]]? {
        if nodes.contains(where: { isRtab($0) && bkey($0) == key }) { return nodes.filter(isRtab) }
        guard depth < 4 else { return nil }
        for n in nodes { if let k = n["kids"] as? [[String: Any]], let r = findRow(k, key: key, depth: depth + 1) { return r } }
        return nil
    }
    /// 눌린 경로 탭 단추를 새 화면 전에 먼저 켠다: 켜져 있던 단추(바탕 gold)와 모양을 맞바꾼다. 이미 켜져 있거나 켜진 단추가 없으면 아무것도 안 한다.
    func pickBtn(_ pressed: [String: Any], in screen: Screen?) {
        guard let screen = screen, ChipPick.isRtab(pressed) else { return }
        let pk = ChipPick.bkey(pressed)
        var group: [[String: Any]] = []
        for list in [screen.head.map(\.d), screen.body.map(\.d)] { if let r = ChipPick.findRow(list, key: pk) { group = r; break } }
        func eff(_ d: [String: Any]) -> BtnStyle { restyle[ChipPick.bkey(d)] ?? BtnStyle(d) }
        let pe = eff(pressed)
        if pe.fill == "gold" { return }
        guard let on = group.first(where: { ChipPick.bkey($0) != pk && eff($0).fill == "gold" }) else { return }
        let ok = ChipPick.bkey(on)
        restyle[pk] = eff(on); restyle[ok] = pe
    }
    /// 새 화면이 왔는지 가리는 표: 단추 · 칩 줄의 켜짐 모양을 이어 붙인 글 — 달라지면 먼저 켠 것을 거둔다.
    nonisolated static func sig(_ s: Screen) -> String {
        var out = ""
        func scan(_ nodes: [[String: Any]], _ depth: Int) {
            for n in nodes {
                switch n["t"] as? String {
                case "button": if isRtab(n) { out += bkey(n) + "=" + ((n["fill"] as? String) ?? "") + ";" }
                case "chips", "btog": out += ((n["items"] as? [[String: Any]]) ?? []).map { ($0["on"] as? Bool) == true ? "1" : "0" }.joined() + ";"
                default: break
                }
                if depth < 3, let k = n["kids"] as? [[String: Any]] { scan(k, depth + 1) }
            }
        }
        scan(s.head.map(\.d), 0); scan(s.body.prefix(60).map(\.d), 0)
        return out
    }
}
