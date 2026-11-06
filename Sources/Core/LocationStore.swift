import Foundation
import CoreLocation

/// 지금 위치(앱이 켜져 있는 동안). 탭이 엔진에 '내 위치'를 실어 보낼 때만 쓴다. 권한은 처음 필요할 때 한 번 묻는다(사용 중에만).
@MainActor
final class LocationStore: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationStore()
    @Published var last: CLLocation? = nil
    @Published var status: CLAuthorizationStatus = .notDetermined
    private let m = CLLocationManager()

    override init() {
        super.init()
        m.delegate = self
        m.desiredAccuracy = kCLLocationAccuracyHundredMeters
        status = m.authorizationStatus
        if let l = m.location { last = l }
    }
    func start() {
        if m.authorizationStatus == .notDetermined { m.requestWhenInUseAuthorization() }
        else if m.authorizationStatus == .authorizedWhenInUse || m.authorizationStatus == .authorizedAlways { m.startUpdatingLocation() }
    }
    /// 소수점 한 자리로 뭉갠 좌표(쇼핑이 가까운 상점 순서를 정할 때만 쓴다 — 안드로이드와 같다).
    var rounded: (Double, Double)? {
        guard let l = last else { return nil }
        return ((l.coordinate.latitude * 10).rounded() / 10, (l.coordinate.longitude * 10).rounded() / 10)
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let s = manager.authorizationStatus
        Task { @MainActor in
            self.status = s
            if s == .authorizedWhenInUse || s == .authorizedAlways { manager.startUpdatingLocation() }
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let l = locations.last else { return }
        Task { @MainActor in self.last = l }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
