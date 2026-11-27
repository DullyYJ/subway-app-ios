import XCTest
@testable import Gildongmu

/// 좌우 밀기(EngineSwipe): 판정값 · 엔진이 준 sw 읽기 · 이어 넘기는 기억(표) — 안드로이드 SwipeCore · ScreenView 와 같은 값을 내야 한다.
final class SwipeCoreTests: XCTestCase {
    private func obj(_ s: String) -> [String: Any] { (try? JSONSerialization.jsonObject(with: Data(s.utf8))) as? [String: Any] ?? [:] }

    // 칸 a → b → c 순환(왼쪽으로 밀면 다음 · 오른쪽으로 밀면 앞)
    private let tbl = #"{"sw":{"l":{"a":"cat","v":"b"},"r":{"a":"cat","v":"c"},"k":"a","t":{"a":{"l":{"a":"cat","v":"b"},"r":{"a":"cat","v":"c"}},"b":{"l":{"a":"cat","v":"c"},"r":{"a":"cat","v":"a"}},"c":{"l":{"a":"cat","v":"a"},"r":{"a":"cat","v":"b"}}}}}"#

    func testRubberBandShift() {
        XCTAssertEqual(SwipeMath.shift(0), 0)
        XCTAssertEqual(Double(SwipeMath.shift(10)), 88.0 * (1.0 - exp(-10.0 / 88.0)), accuracy: 0.001)       // 처음엔 거의 1:1
        XCTAssertEqual(Double(SwipeMath.shift(-10)), -Double(SwipeMath.shift(10)), accuracy: 0.001)
        XCTAssertLessThan(SwipeMath.shift(1000), 88.0001)                                       // 아무리 밀어도 고무줄 한계
        XCTAssertEqual(SwipeMath.alpha(0), 1, accuracy: 0.0001)
        XCTAssertEqual(SwipeMath.alpha(88), 0.7, accuracy: 0.0001)
    }
    func testFires() {
        XCTAssertTrue(SwipeMath.fires(dx: -32, vx: 0))                                          // 32pt 이상
        XCTAssertFalse(SwipeMath.fires(dx: 31, vx: 0))
        XCTAssertTrue(SwipeMath.fires(dx: 12, vx: 600))                                         // 빠르게 쓸기(같은 쪽)
        XCTAssertFalse(SwipeMath.fires(dx: 12, vx: -600))                                       // 반대쪽 속도는 아님
        XCTAssertFalse(SwipeMath.fires(dx: 9, vx: 900))                                         // 10pt 도 안 갔다
        XCTAssertTrue(SwipeMath.horizontal(dx: 30, dy: 20))
        XCTAssertFalse(SwipeMath.horizontal(dx: 10, dy: 30))
    }
    func testInfoParse() {
        let i = SwipeInfo(obj(tbl))
        XCTAssertNotNil(i)
        XCTAssertEqual(i?.l?.v, "b"); XCTAssertEqual(i?.r?.v, "c"); XCTAssertEqual(i?.k, "a")
        XCTAssertEqual(i?.t.count, 3)
        XCTAssertEqual(i?.t["b"]?.l?.v, "c")
        XCTAssertNil(SwipeInfo(obj(#"{"screen":"x"}"#)))                                        // sw 없음
        let h = SwipeInfo(obj(#"{"sw":{"l":{"a":"call","v":"cc.board"},"lh":true,"lc":"정치"}}"#))
        XCTAssertEqual(h?.lh, true); XCTAssertEqual(h?.lc, "정치"); XCTAssertNil(h?.r)
        XCTAssertEqual(SwipeInfo(obj(#"{"sw":{}}"#))?.has, false)
    }
    func testTablePickAndNote() {
        var c = SwipeCore()
        c.onScreen(SwipeInfo(obj(tbl)), tab: "shop")
        XCTAssertTrue(c.hasTable); XCTAssertEqual(c.cur, "a")
        XCTAssertEqual(c.pick(dir: -1, tab: "shop")?.v, "b")
        XCTAssertEqual(c.pick(dir: 1, tab: "shop")?.v, "c")
        XCTAssertNil(c.pick(dir: -1, tab: "food"))                                              // 다른 탭의 표는 안 쓴다
        // 새 화면이 오기 전에 한 번 더 밀어도 같은 칸을 되풀이하지 않는다: a → b → c
        c.note(c.pick(dir: -1, tab: "shop")!)
        XCTAssertEqual(c.cur, "b")
        XCTAssertEqual(c.pick(dir: -1, tab: "shop")?.v, "c")
        c.note(c.pick(dir: -1, tab: "shop")!)
        XCTAssertEqual(c.cur, "c")
        XCTAssertEqual(c.pick(dir: -1, tab: "shop")?.v, "a")                                    // 순환
    }
    func testSkeletonKeepsTableAndOwnSwDropsIt() {
        var c = SwipeCore()
        c.onScreen(SwipeInfo(obj(tbl)), tab: "shop")
        c.onScreen(SwipeInfo(obj(#"{"screen":"skeleton"}"#)), tab: "shop")                      // sw 없는 뼈대 화면 — 앞의 표를 둔다
        XCTAssertTrue(c.hasTable); XCTAssertEqual(c.cur, "a")
        c.onScreen(SwipeInfo(obj(#"{"sw":{"l":{"a":"cat","v":"z"}}}"#)), tab: "shop")           // 표 없는 sw 화면 — 표를 버린다
        XCTAssertFalse(c.hasTable); XCTAssertEqual(c.cur, "")
        XCTAssertNil(c.pick(dir: -1, tab: "shop"))
    }
    func testNoteRideTabName() {
        var c = SwipeCore()
        let t = #"{"sw":{"k":"bus","t":{"bus":{"l":{"a":"call","v":"rh.tab.sub"}},"sub":{"r":{"a":"call","v":"rh.tab.bus"}}}}}"#
        c.onScreen(SwipeInfo(obj(t)), tab: "home")
        XCTAssertEqual(c.cur, "bus")
        c.note(c.pick(dir: -1, tab: "home")!)                                                   // 경로 결과 카드: 탭 이름이 칸 이름
        XCTAssertEqual(c.cur, "sub")
        XCTAssertNil(c.pick(dir: -1, tab: "home"))                                              // 끝에서 멈춘다(엔진이 안 줌)
        XCTAssertEqual(c.pick(dir: 1, tab: "home")?.v, "rh.tab.bus")
    }
}
