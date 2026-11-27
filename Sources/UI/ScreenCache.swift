import SwiftUI

/// 받은 엔진 화면을 기억해 두었다가 탭을 열 때 옛 화면을 먼저 보인다(안드로이드 cachePut · showCached — 새 화면이 오면 바꾼다).
/// 메모리 + 기기 캐시 폴더(7일). 서버 지연 안내(delayed)나 오류 화면은 담지 않는다.
@MainActor
final class ScreenCache {
    static let shared = ScreenCache()
    private var mem: [String: Screen] = [:]
    private let dir: URL = {
        let d = (FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())).appendingPathComponent("screens", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()
    private var pruned = false
    private var at: [String: Date] = [:]                 // 이번 실행에서 새로 받아 담은 때(디스크에서 읽은 건 없음)

    /// 이번 실행에서 받은 지 `within` 초 안인 화면이 있으면 true(안드로이드 tabsAt — 탭 막대는 10분 안이면 다시 안 받는다).
    func fresh(_ key: String, within: TimeInterval) -> Bool {
        guard mem[key] != nil, let t = at[key] else { return false }
        return Date().timeIntervalSince(t) < within
    }

    /// 열쇠 → 파일 이름(프로세스가 바뀌어도 같아야 해서 djb2 로 만든다).
    nonisolated static func fileName(_ key: String) -> String {
        var h: UInt64 = 5381
        for b in key.utf8 { h = (h &* 33) &+ UInt64(b) }
        return String(h, radix: 16) + ".json"
    }

    /// 담은 지 몇 초 됐나(이번 실행에서 받았으면 그때부터, 아니면 파일 수정 시각부터). 없으면 nil.
    func age(_ key: String) -> TimeInterval? {
        if let t = at[key] { return Date().timeIntervalSince(t) }
        let u = dir.appendingPathComponent(ScreenCache.fileName(key))
        guard let m = (try? u.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate else { return nil }
        return Date().timeIntervalSince(m)
    }

    func get(_ key: String) -> Screen? {
        if let s = mem[key] { return s }
        let u = dir.appendingPathComponent(ScreenCache.fileName(key))
        guard let d = try? Data(contentsOf: u), let s = try? Screen.parse(d), (s.raw["_k"] as? String) == key else { return nil }          // 이름이 겹친 다른 열쇠의 파일이면 버린다
        mem[key] = s
        return s
    }

    func put(_ key: String, _ s: Screen) {
        if s.retryHint != nil || s.name == "error" || s.name == "skel" { return }
        mem[key] = s
        at[key] = Date()
        var raw = s.raw
        raw["_k"] = key
        guard let d = try? JSONSerialization.data(withJSONObject: raw), d.count < 2_000_000 else { return }
        let u = dir.appendingPathComponent(ScreenCache.fileName(key))
        Task.detached(priority: .utility) { try? d.write(to: u, options: .atomic) }
        prune()
    }

    /// 7일 넘은 파일은 지운다(앱을 켠 뒤 처음 한 번).
    private func prune() {
        if pruned { return }
        pruned = true
        let base = dir
        Task.detached(priority: .background) {
            let fm = FileManager.default
            let old = Date().addingTimeInterval(-7 * 86400)
            for u in (try? fm.contentsOfDirectory(at: base, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [] {
                if let m = (try? u.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate, m < old { try? fm.removeItem(at: u) }
            }
        }
    }
}

extension Screen {
    /// 화면을 기다리는 동안 보이는 뼈대(안드로이드 ShellCore.skeletonScreen): 홈 · 쇼핑은 cards(4) · 노선도는 map(4) · 나머지는 list(8).
    static func skeleton(_ kind: String) -> Screen? {
        let rows = kind == "list" ? 8 : 4
        let o: [String: Any] = ["ok": true, "v": 1, "screen": "skel", "head": [], "body": [["t": "skel", "kind": kind, "rows": rows, "pad": [12, 12, 12, 0]]]]
        guard let d = try? JSONSerialization.data(withJSONObject: o) else { return nil }
        return try? Screen.parse(d)
    }
}

/// 첫 화면이 오기 전에 보이는 뼈대 화면(전에는 빙글빙글 돌기만 했다).
struct SkelScreen: View {
    let kind: String
    let pal: Palette
    var body: some View {
        if let s = Screen.skeleton(kind) { ScreenBody(screen: s, pal: pal) }
        else { (pal.color("bg") ?? Color(.systemBackground)).ignoresSafeArea() }
    }
}
