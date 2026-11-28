import XCTest
@testable import Gildongmu

/// 버스 도착 카운트다운 기억(안드로이드 ScreenView.cdState) · 자동 갱신 박자(안드로이드 busArrGap) · 도착정보 열쇠(ARR_KEY).
final class BusCdTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func testSameValueKeepsRunningStart() {
        let cd = BusCd()
        XCTAssertEqual(cd.rem("k", sec: 300, ph: "2번째전", now: t0), 300, accuracy: 0.001)
        XCTAssertEqual(cd.rem("k", sec: 300, ph: "2번째전", now: t0.addingTimeInterval(40)), 260, accuracy: 0.001)          // 40초 흘렀다
        // 같은 원본 값을 다시 받아도 처음부터 세지 않는다(숫자가 도로 늘지 않는다)
        XCTAssertEqual(cd.rem("k", sec: 300, ph: "2번째전", now: t0.addingTimeInterval(55)), 245, accuracy: 0.001)
    }
    func testChangedValueRestartsFromNewValue() {
        let cd = BusCd()
        _ = cd.rem("k", sec: 300, ph: "2번째전", now: t0)
        XCTAssertEqual(cd.rem("k", sec: 240, ph: "2번째전", now: t0.addingTimeInterval(70)), 240, accuracy: 0.001)         // 새 실시간 값은 그 값에서 다시
        XCTAssertEqual(cd.rem("k", sec: 240, ph: "1번째전", now: t0.addingTimeInterval(80)), 240, accuracy: 0.001)         // 초가 같아도 몇 번째전이 달라졌으면 다른 값
        XCTAssertEqual(cd.age("k", sec: 240, ph: "1번째전", now: t0.addingTimeInterval(95)), 15, accuracy: 0.001)
    }
    func testSourceAgeCountsAlreadyElapsed() {
        let cd = BusCd()
        cd.setSourceAge(90)                                                           // 90초 전에 받아 둔 옛 화면
        let now = Date()
        XCTAssertEqual(cd.rem("a", sec: 200, ph: "", now: now), 110, accuracy: 0.5)
        XCTAssertEqual(cd.age("a", sec: 200, ph: "", now: now), 90, accuracy: 0.5)
    }
    func testScanFindsMinRemainAndStale() {
        let cd = BusCd()
        let card: [String: Any] = ["t": "bcard", "k": "s1", "nm": "정류장", "rows": [
            ["no": "507", "dir": "동대문", "a": [["s": "4분", "p": "1번째전", "sec": 240], ["s": "9분", "p": "3번째전", "sec": 540, "ex": 30, "xs": "확인 중"]]],
            ["no": "421", "a": [["s": "곧 도착", "sec": 0]]]]]
        let wrap: [String: Any] = ["t": "card", "kids": [card]]                                 // 묶음 안에 들어 있어도 찾는다
        let nodes = [Node(d: wrap, id: "r")]
        let a = cd.scan(nodes, now: t0)
        XCTAssertEqual(a.minRem ?? -1, 240, accuracy: 0.001)
        XCTAssertFalse(a.stale)
        let b = cd.scan(nodes, now: t0.addingTimeInterval(31))                                    // 두 번째 칸의 유통기한(30초)이 지났다
        XCTAssertEqual(b.minRem ?? -1, 209, accuracy: 0.001)
        XCTAssertTrue(b.stale)
        XCTAssertNil(cd.scan([Node(d: ["t": "text", "s": "x"], id: "x")], now: t0).minRem)
    }
    func testArrGapAndKeys() {
        XCTAssertEqual(MapModel.arrGap(60), 15)
        XCTAssertEqual(MapModel.arrGap(120), 15)
        XCTAssertEqual(MapModel.arrGap(121), 30)
        XCTAssertEqual(MapModel.arrGap(300), 30)
        XCTAssertEqual(MapModel.arrGap(301), 90)
        XCTAssertEqual(MapModel.arrGap(-5), 15)                                                  // 이미 지나갔을 수 있는 차 — 곧 다시
        for k in ["a1", "f12", "g123", "h9"] { XCTAssertTrue(MapModel.isArrKey(k), k) }
        for k in ["t1", "u12", "a", "a1234", "ab", "r5", ""] { XCTAssertFalse(MapModel.isArrKey(k), k) }
    }
}
