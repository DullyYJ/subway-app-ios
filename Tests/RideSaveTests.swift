import XCTest
@testable import Gildongmu

/// 탑승 안내 저장 · 되살림 · 시한(안드로이드 RideService.save · RideCore.restore · deadlineMs 와 같은 값이어야 한다).
final class RideSaveTests: XCTestCase {
    private let t0: Int64 = 1_800_000_000_000          // 임의의 한 시각(ms)
    private func state(_ stops: String) -> String { #"{"stops":\#(stops),"pad":"xxxxxxxxxx"}"# }
    override func tearDown() { RideLoop.clearSaved() }

    func testDeadlinePrefersFinThenLatestPlusTenMinutes() {
        let a = state(#"[{"arrMs":\#(t0 + 60_000)},{"arrMs":\#(t0 + 120_000),"fin":true},{"arrMs":\#(t0 + 900_000)}]"#)
        XCTAssertEqual(RideLoop.deadline(a), t0 + 120_000 + 600_000)               // 마지막 정류장(fin) 도착 예정 + 10분
        let b = state(#"[{"arrMs":\#(t0 + 60_000)},{"arrMs":\#(t0 + 300_000)}]"#)
        XCTAssertEqual(RideLoop.deadline(b), t0 + 300_000 + 600_000)                // fin 이 없으면 가장 늦은 시각
        XCTAssertEqual(RideLoop.deadline(state("[]")), 0)                          // 모르면 제한 없음
        XCTAssertEqual(RideLoop.deadline("not json"), 0)
    }
    private func put(state st: String, at: Int64) {
        let o: [String: Any] = ["state": st, "text": "신촌까지", "at": at]
        UserDefaults.standard.set(String(data: try! JSONSerialization.data(withJSONObject: o), encoding: .utf8), forKey: "ride.saved")
    }
    func testSavedRideRestoresOnlyWhileFreshAndBeforeDeadline() {
        let st = state(#"[{"arrMs":\#(t0 + 1_200_000),"fin":true}]"#)
        put(state: st, at: t0)
        let ok = RideLoop.savedRide(now: Date(timeIntervalSince1970: Double(t0 + 5 * 60_000) / 1000))
        XCTAssertEqual(ok?.text, "신촌까지")
        XCTAssertEqual(ok?.state, st)
        XCTAssertNil(RideLoop.savedRide(now: Date(timeIntervalSince1970: Double(t0 + 31 * 60_000) / 1000)))      // 30분 넘게 갱신이 없다
        let early = state(#"[{"arrMs":\#(t0 + 60_000),"fin":true}]"#)
        put(state: early, at: t0 + 11 * 60_000)
        XCTAssertNil(RideLoop.savedRide(now: Date(timeIntervalSince1970: Double(t0 + 12 * 60_000) / 1000)))      // 도착 예정 + 10분이 지났다
    }
    func testSavedRideRejectsBrokenAndClears() {
        UserDefaults.standard.set("{}", forKey: "ride.saved")
        XCTAssertNil(RideLoop.savedRide())
        UserDefaults.standard.set("garbage", forKey: "ride.saved")
        XCTAssertNil(RideLoop.savedRide())
        put(state: state("[]"), at: Int64(Date().timeIntervalSince1970 * 1000))
        XCTAssertNotNil(RideLoop.savedRide())
        RideLoop.clearSaved()
        XCTAssertNil(RideLoop.savedRide())
    }
}
