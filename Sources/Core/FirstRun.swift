import Foundation
import UserNotifications

/// 처음 설치 승인 순서(안드로이드 ShellActivity.setupNext · locGate): ① 알림 허용(기기 창) → ② 위치 정보 이용 안내(엔진 p=locd — 동의/거부) → ③ 위치 허용(기기 창).
/// 안내 글은 엔진이 만들고, 여기는 차례와 기기 창 열기만 한다. 동의는 평생 한 번(loc_disc) · 거부하면 이번 실행엔 더 묻지 않는다.
@MainActor
enum FirstRun {
    static weak var host: Host?
    private static var asking = false
    private static var declined = false
    private static var waiting: [(Bool) -> Void] = []
    static let kLocDisc = "loc_disc", kSetup = "setup_done"

    static var consented: Bool { UserDefaults.standard.string(forKey: kLocDisc) == "1" }

    /// 앱이 처음 켜졌을 때 한 번: 알림 허용 → (위치 안내 → 위치 허용).
    static func begin() {
        let ud = UserDefaults.standard
        if CommandLine.arguments.contains("-skipSetup") { return }          // 시험(CI 화면 찍기)용 — 기기 창이 화면을 가리지 않게
        if ud.string(forKey: kSetup) == "1" { return }
        ud.set("1", forKey: kSetup)
        Task {
            let c = UNUserNotificationCenter.current()
            let s = await c.notificationSettings()
            if s.authorizationStatus == .notDetermined { _ = try? await c.requestAuthorization(options: [.alert, .sound, .badge]) }
            try? await Task.sleep(nanoseconds: 600_000_000)
            LocationStore.shared.start()
        }
    }

    /// 위치 허용 창을 띄우기 전에 한 번 안내를 보인다. 이미 동의했으면 바로 true · 거부했으면 false.
    static func locGate(_ done: @escaping (Bool) -> Void) {
        if consented { done(true); return }
        if declined { done(false); return }
        waiting.append(done)
        if asking { return }
        asking = true
        Task { await open(tries: 0) }
    }
    private static func open(tries: Int) async {
        guard let h = host else {                                              // 화면이 아직 없으면 잠깐 기다렸다 다시(처음 켜질 때)
            if tries < 20 { try? await Task.sleep(nanoseconds: 300_000_000); await open(tries: tries + 1) } else { finish(false) }
            return
        }
        await h.locdOpen()
    }
    static func answer(_ ok: Bool) {
        if ok { UserDefaults.standard.set("1", forKey: kLocDisc) } else { declined = true }
        finish(ok)
    }
    private static func finish(_ ok: Bool) {
        asking = false
        let w = waiting; waiting = []
        for f in w { f(ok) }
    }
}
