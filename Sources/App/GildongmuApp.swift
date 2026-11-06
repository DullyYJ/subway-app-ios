import SwiftUI
import UIKit

@main
struct GildongmuApp: App {
    init() {
        // 시험용: `-demoRide moving` 으로 켜면 견본 overlay 로 다이내믹 아일랜드를 바로 띄운다(클라우드 맥 화면 확인용).
        let a = CommandLine.arguments
        if let i = a.firstIndex(of: "-demoRide"), i + 1 < a.count {
            let kind = a[i + 1]
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if kind == "journey" {
                    // 이동 중 → 잠시 뒤 도착: 앱이 뒤로 가 있어도 갱신이 나가도록 잠깐 백그라운드 작업을 잡는다
                    var bg = UIBackgroundTaskIdentifier.invalid
                    bg = UIApplication.shared.beginBackgroundTask { UIApplication.shared.endBackgroundTask(bg) }
                    LiveRide.shared.apply(OvState.from(DemoOverlay.json("moving")))
                    try? await Task.sleep(nanoseconds: 7_000_000_000)
                    LiveRide.shared.apply(OvState.from(DemoOverlay.json("arrived")))
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    UIApplication.shared.endBackgroundTask(bg)
                } else {
                    LiveRide.shared.apply(OvState.from(DemoOverlay.json(kind)))
                }
            }
        }
    }
    var body: some Scene {
        WindowGroup { RootView() }
    }
}
