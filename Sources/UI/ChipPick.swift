import SwiftUI

/// 칩을 누르면(또는 밀어서 칸을 넘기면) 새 화면이 오기 전에 그 칩을 먼저 켜 보인다(안드로이드 ScreenView.pickChip · lightChip).
/// 서버를 기다리지 않아 바로 바뀐다. 새 화면이 오면 그 화면의 값이 맞으니 지운다.
@MainActor
final class ChipPick: ObservableObject {
    static let shared = ChipPick()
    @Published private(set) var picks: [String: String] = [:]

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
        guard a.a == "cat", let v = a.v else { return }
        for n in screen.head + screen.body where n.t == "chips" {
            let has = n.items.contains { (($0["act"] as? [String: Any])?["a"] as? String) == "cat" && (($0["act"] as? [String: Any])?["v"] as? String) == v }
            if has { pick(items: n.items, v: v); return }
        }
    }
    func clear() { if !picks.isEmpty { picks = [:] } }
}
