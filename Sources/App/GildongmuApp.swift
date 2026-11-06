import SwiftUI

@main
struct GildongmuApp: App {
    init() {
        // 시험용: `-demoRide moving` 으로 켜면 견본 overlay 로 다이내믹 아일랜드를 바로 띄운다(클라우드 맥 화면 확인용).
        let a = CommandLine.arguments
        if let i = a.firstIndex(of: "-demoRide"), i + 1 < a.count {
            let kind = a[i + 1]
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                LiveRide.shared.apply(OvState.from(DemoOverlay.json(kind)))
            }
        }
    }
    var body: some Scene {
        WindowGroup { RootView() }
    }
}
