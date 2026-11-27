import SwiftUI

/// 서버가 늦거나 화면을 못 받았을 때의 안내 + 자동 다시 받기(안드로이드 ShellCore.retryHint · errorScreen · ShellActivity.scheduleRetry 와 같다).
/// 문구 · 간격은 엔진이 줄 때는 엔진의 것(top-level delayed:true · retry:[초…]), 통신 자체가 안 될 때만 앱 안의 같은 화면을 쓴다.
extension Screen {
    /// 엔진 안내 화면조차 못 받을 때의 재시도 간격(초) — 짧게 몇 번만.
    static let defaultRetry = [4, 8, 16, 30]

    /// 엔진이 "서버가 늦다"며 준 안내 화면의 재시도 간격(초). 아니면 nil.
    static func retryHint(_ raw: [String: Any]) -> [Int]? {
        guard (raw["delayed"] as? Bool) == true else { return nil }
        guard let r = raw["retry"] as? [Any], !r.isEmpty else { return defaultRetry }
        return r.prefix(6).map { x in
            if let n = x as? NSNumber { return Int(max(1, min(120, n.doubleValue))) }
            return 5
        }
    }
    var retryHint: [Int]? { Screen.retryHint(raw) }

    /// 화면을 못 받았을 때 빈 화면 대신 보이는 안내와 [다시 시도](행동 이름 gdm_retry). diag: 왜 못 받았는지 짧은 글.
    static func errorScreen(_ diag: String) -> Screen? {
        var body: [[String: Any]] = [
            ["t": "text", "s": "서버 연결이 지연되고 있습니다.\n자동으로 다시 시도하고 있어요.", "size": 15, "color": "sub", "lh": 1.5, "align": "center", "pad": [24, 96, 24, 12]]
        ]
        if !diag.isEmpty {
            body.append(["t": "text", "s": String(diag.prefix(90)), "size": 11, "color": "sub", "alpha": 0.7, "lh": 1.4, "align": "center", "pad": [24, 0, 24, 12]])
        }
        body.append(["t": "button", "s": "다시 시도", "size": 14, "h": 44, "r": 12, "bold": true, "fill": "gold", "tc": "white", "act": ["a": "call", "v": "gdm_retry"]])
        let o: [String: Any] = ["ok": true, "v": 1, "screen": "error", "head": [], "body": body]
        guard let d = try? JSONSerialization.data(withJSONObject: o) else { return nil }
        return try? Screen.parse(d)
    }
}

/// 안내 화면이 떠 있는 동안 정해진 간격(초)마다 뒤에서 다시 받는다. 정해진 횟수가 끝나면 [다시 시도] 단추로만.
/// 앱이 가려졌으면(백그라운드) 하지 않는다. 안내가 사라지면(받았다) 횟수를 처음으로.
@MainActor
struct AutoRetry: ViewModifier {
    let delays: [Int]?
    @EnvironmentObject var host: Host
    @Environment(\.scenePhase) private var phase
    @State private var n = 0

    func body(content: Content) -> some View {
        content
            .task(id: "\(n)|\(delays != nil)|\(phase == .active)") { await step() }
            .onChange(of: delays == nil) { gone in if gone { n = 0 } }
    }

    private func step() async {
        guard phase == .active, let d = delays, n < d.count else { return }
        try? await Task.sleep(nanoseconds: UInt64(d[n]) * 1_000_000_000)
        if Task.isCancelled { return }
        n += 1
        host.reloadTick += 1
    }
}

/// 탭이 화면을 못 받아 비어 있을 때 그리는 안내 카드(엔진 화면 그리기를 그대로 쓴다) + 자동 다시 받기.
struct RetryCard: View {
    let msg: String
    let pal: Palette
    var body: some View {
        Group {
            if let s = Screen.errorScreen(msg) { ScreenBody(screen: s, pal: pal) }
            else { Text(msg).font(Typo.font(12)).foregroundColor(pal.color("sub") ?? .gray) }
        }
        .modifier(AutoRetry(delays: Screen.defaultRetry))
    }
}
