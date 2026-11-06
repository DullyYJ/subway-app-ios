import SwiftUI
import Combine

/// 화면에서 눌린 행동(Action)을 받아 처리하는 곳. 안드로이드의 ShellActivity 가 하던 일을 단계별로 옮긴다.
/// 1단계: open(https) · tab.* 전환 · set(스위치 저장) · refresh · 나머지는 '아직 연결 안 됨' 안내로 기록한다.
@MainActor
final class Host: ObservableObject {
    @Published var tab: String = UserDefaults.standard.string(forKey: "tab") ?? "home" { didSet { UserDefaults.standard.set(tab, forKey: "tab") } }
    @Published var toast: String? = nil
    @Published var reloadTick = 0
    @Published var sheet: SheetRoute? = nil
    /// 분류 칩(cat) · 글 펼침(tog) 같은 탭 안의 행동: 켜진 탭이 받아 자기 화면을 다시 그린다.
    struct TabAction { let tab: String; let a: String; let v: String; let id: String; let key: String }
    let actPublisher = PassthroughSubject<TabAction, Never>()

    struct SheetRoute: Identifiable { let id = UUID(); let path: String; let body: String?; let title: String }

    /// 안드로이드 ShellCore.TABS 순서가 아니라 서버가 tabs 화면에서 정한다. 여기서는 이름만 안다.
    static let tabNames = ["community", "map", "home", "shop", "food"]

    func handle(_ a: Action) {
        switch a.a {
        case "open":
            if let u = a.url, let url = URL(string: u), url.scheme == "https" { UIApplication.shared.open(url) }
        case "refresh":
            reloadTick += 1
        case "cat", "tog":
            actPublisher.send(TabAction(tab: tab, a: a.a, v: a.v ?? "", id: a.id ?? "", key: a.key ?? ""))
        case "set":
            if let k = a.key { UserDefaults.standard.set(a.on ?? false, forKey: "set." + k) }
        case "call":
            if let v = a.v, v.hasPrefix("bd.") { actPublisher.send(TabAction(tab: "community", a: "call", v: v, id: a.id ?? "", key: a.key ?? "")) }
            else { call(a.v ?? "") }
        default:
            say("‘\(a.a)’ 행동은 아직 연결되지 않았어요 (v=\(a.v ?? "-"))")
        }
    }

    func call(_ v: String) {
        if v.hasPrefix("tab.") {
            let t = String(v.dropFirst(4))
            if Host.tabNames.contains(t) { tab = t }
            return
        }
        if v.hasPrefix("bd.") { actPublisher.send(TabAction(tab: "community", a: "call", v: v, id: "", key: "")); return }
        say("call ‘\(v)’ 는 아직 연결되지 않았어요")
    }

    func say(_ m: String) {
        toast = m
        Task { try? await Task.sleep(nanoseconds: 2_500_000_000); if self.toast == m { self.toast = nil } }
    }
}
