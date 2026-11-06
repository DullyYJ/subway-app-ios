import SwiftUI

/// 홈 탭(안드로이드 HomeCore.request 와 같다): 출발·도착 입력 상태와 지금 시각을 POST /screen/home 에 보내고,
/// 엔진이 준 화면을 그대로 그린다. 이번 단계는 빈 입력 상태의 첫 화면까지이고, 검색 후보·경로 결과는 다음 단계다.
@MainActor
final class HomeModel: ObservableObject {
    @Published var screen: Screen? = nil
    @Published var error: String? = nil
    var start = "", dest = "", active = ""
    var startSet = false, destSet = false

    private func body() -> String {
        let now = Date()
        let tz = TimeZone.current
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month, .day], from: now)
        let tzo = -(tz.secondsFromGMT(for: now) / 60)                 // JS getTimezoneOffset 과 같은 부호
        let ms = Int64(now.timeIntervalSince1970 * 1000)
        let gps = LocationStore.shared.last != nil
        return "{\"cap\":\(Servers.cap),\"f\":{\"start\":\(Json.q(start)),\"dest\":\(Json.q(dest)),\"active\":\(Json.q(active)),"
            + "\"startSet\":\(startSet),\"destSet\":\(destSet),\"gps\":\(gps),\"rs\":false,"
            + "\"base\":{\"ms\":null,\"tzo\":\(tzo),\"today\":[\(c.year ?? 2026),\((c.month ?? 1) - 1),\(c.day ?? 1)],\"now\":\(ms)}},\"d\":{}}"
    }

    private var pending: Task<Void, Never>? = nil
    func reloadSoon(_ ms: UInt64 = 250) {
        pending?.cancel()
        pending = Task { try? await Task.sleep(nanoseconds: ms * 1_000_000); if !Task.isCancelled { await load() } }
    }

    /// 입력칸 글자가 바뀜(타자) — 직접 친 글자는 아직 '고른 장소'가 아니다.
    func typed(_ key: String, _ v: String) {
        if key == "start" { if v == start { return }; start = v; startSet = false }
        else if key == "dest" { if v == dest { return }; dest = v; destSet = false }
        else { return }
        active = key
        reloadSoon()
    }

    /// 화면에서 행동 v 를 가진 후보 줄(sug)의 이름
    private func sugName(_ v: String) -> String? {
        func walk(_ ns: [Node]) -> String? {
            for n in ns {
                if n.t == "sug", n.act?.v == v { return n.str("name") }
                if let r = walk(n.kids) { return r }
            }
            return nil
        }
        guard let s = screen else { return nil }
        return walk(s.body)
    }

    func call(_ v: String, host: Host) {
        if v == "rt.swap" {
            let t = start; start = dest; dest = t
            let f = startSet; startSet = destSet; destSet = f
            active = ""; reloadSoon(0)
        } else if v == "rt.gps" {
            if LocationStore.shared.last == nil { LocationStore.shared.start(); host.say("위치 권한을 허용하면 내 위치를 쓸 수 있어요"); return }
            start = "내 위치"; startSet = true; active = ""; reloadSoon(0)
        } else if v.hasPrefix("sg.") {
            guard let name = sugName(v) else { return }
            let key = v.split(separator: ".").dropFirst().first.map(String.init) ?? ""
            if key == "start" { start = name; startSet = true } else if key == "dest" { dest = name; destSet = true }
            active = ""; reloadSoon(0)
        } else if v == "rt.go" || v == "rt.enter" {
            host.say("경로 탐색은 다음 단계에서 연결돼요")
        } else if v == "bt.pick" || v == "bt.now" {
            host.say("기준시각 고르기는 다음 단계에서 연결돼요")
        }
    }

    func load() async {
        do { screen = try await Net.screen("/screen/home", body: body()); error = nil }
        catch { self.error = error.localizedDescription }
    }
}

struct HomeTab: View {
    let pal: Palette
    @StateObject private var m = HomeModel()
    @EnvironmentObject var host: Host
    var body: some View {
        ZStack {
            if let s = m.screen { ScreenBody(screen: s, pal: pal) }
            else { (pal.color("bg") ?? Color(.systemBackground)).ignoresSafeArea(); ProgressView() }
            if let e = m.error, m.screen == nil { Text(e).font(Typo.font(12)).foregroundColor(pal.color("sub") ?? .gray) }
        }
        .task { LocationStore.shared.start(); await m.load() }
        .onReceive(host.actPublisher) { x in
            guard x.tab == "home" else { return }
            if x.a == "input" { m.typed(x.key, x.v) } else if x.a == "call" { m.call(x.v, host: host) }
        }
        .onChange(of: host.reloadTick) { _ in Task { await m.load() } }
    }
}
