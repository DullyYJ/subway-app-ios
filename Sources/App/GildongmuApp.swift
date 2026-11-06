import SwiftUI
import UIKit
import CoreLocation

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
                    // 이동 중 → 8초 뒤 도착. 앱이 뒤로 가 있어도 갱신이 나가도록 위치 백그라운드(시험용)로 살려 둔다
                    DemoKeepAlive.shared.start()
                    LiveRide.shared.apply(OvState.from(DemoOverlay.json("moving")))
                    try? await Task.sleep(nanoseconds: 8_000_000_000)
                    LiveRide.shared.apply(OvState.from(DemoOverlay.json("arrived")))
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

/// 시험 전용: 앱이 뒤로 가도 멈추지 않게 위치 갱신을 켜 둔다(`-demoRide journey` 에서만 쓴다).
final class DemoKeepAlive: NSObject, CLLocationManagerDelegate {
    static let shared = DemoKeepAlive()
    private let m = CLLocationManager()
    func start() {
        m.delegate = self
        m.requestAlwaysAuthorization()
        m.allowsBackgroundLocationUpdates = true
        m.pausesLocationUpdatesAutomatically = false
        m.startUpdatingLocation()
    }
}
