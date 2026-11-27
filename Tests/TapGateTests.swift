import XCTest
@testable import Gildongmu

final class TapGateTests: XCTestCase {
    func testSecondTapInsideWindowIsBlocked() {
        var g = TapGate()
        XCTAssertTrue(g.pass("tab:call:tab.map", now: 1000))
        XCTAssertFalse(g.pass("tab:call:tab.map", now: 1200))
        XCTAssertFalse(g.pass("tab:call:tab.map", now: 1349))          // 막힌 눌림은 창을 늘리지 않는다
    }
    func testPassesAfterWindowAndForOtherKeys() {
        var g = TapGate()
        XCTAssertTrue(g.pass("a", now: 0))
        XCTAssertTrue(g.pass("b", now: 10))
        XCTAssertTrue(g.pass("a", now: 350))
        XCTAssertFalse(g.pass("a", now: 400))
    }
    func testClockGoingBackwardsDoesNotLockForever() {
        var g = TapGate()
        XCTAssertTrue(g.pass("a", now: 5000))
        XCTAssertTrue(g.pass("a", now: 100))
    }
}
