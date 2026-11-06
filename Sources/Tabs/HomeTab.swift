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
        .onChange(of: host.reloadTick) { _ in Task { await m.load() } }
    }
}
