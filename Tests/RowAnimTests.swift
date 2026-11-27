import XCTest
@testable import Gildongmu

/// 탑승 카드 버튼 줄 전환 연출(ActRowCore · RowAnimSpec) — 안드로이드 ActRowCore.java · ScreenCore row.an 과 같은 값.
final class RowAnimTests: XCTestCase {
    func testEaseEndpointsAndMonotonic() {
        let z = [0.2, 0.0, 0.0, 1.0]
        XCTAssertEqual(ActRowCore.ease(0, z), 0)
        XCTAssertEqual(ActRowCore.ease(1, z), 1)
        var prev = 0.0
        for i in 1..<20 { let v = ActRowCore.ease(Double(i) / 20, z); XCTAssertTrue(v >= prev - 1e-9 && v <= 1); prev = v }
        XCTAssertEqual(ActRowCore.ease(0.5, [0.25, 0.25, 0.75, 0.75]), 0.5, accuracy: 0.001)          // 직선 곡선
    }

    func testPushInGrowsTheNewSlot() {
        let a = ActRowCore.frame("push_in", 0, W: 320, H: 40, g: 8)           // 칸이 둘로 시작(오른쪽 칸은 너비 w3 인 채 오른쪽 끝 밖에서 밀려 들어옴)
        let w2 = (320 - 8) / 2.0, w3 = (320 - 16) / 3.0
        XCTAssertEqual(a[ActRowCore.slotA].w, w2, accuracy: 0.001)
        XCTAssertEqual(a[ActRowCore.slotB].x, w2 + 8, accuracy: 0.001)
        XCTAssertEqual(a[ActRowCore.slotC].x, 2 * (w2 + 8), accuracy: 0.001)
        XCTAssertFalse(a[ActRowCore.slotO].show)
        let b = ActRowCore.frame("push_in", 1, W: 320, H: 40, g: 8)           // 끝: 세 칸 같은 너비
        XCTAssertEqual(b[ActRowCore.slotA].w, w3, accuracy: 0.001)
        XCTAssertEqual(b[ActRowCore.slotC].x, 2 * (w3 + 8), accuracy: 0.001)
        let c = ActRowCore.frame("push_out", 0, W: 320, H: 40, g: 8)          // push_out 은 push_in 의 거꾸로
        XCTAssertEqual(c[ActRowCore.slotA].w, w3, accuracy: 0.001)
    }

    func testSlidesMoveNewAndOldSlot() {
        let w3 = (320 - 16) / 3.0, x3 = 2 * (w3 + 8)
        let d0 = ActRowCore.frame("slide_down", 0, W: 320, H: 40, g: 8)
        XCTAssertEqual(d0[ActRowCore.slotC].y, -40, accuracy: 0.001)          // 새 칸은 위에서
        XCTAssertEqual(d0[ActRowCore.slotO].y, 0, accuracy: 0.001)
        let d1 = ActRowCore.frame("slide_down", 1, W: 320, H: 40, g: 8)
        XCTAssertEqual(d1[ActRowCore.slotC].y, 0, accuracy: 0.001)
        XCTAssertEqual(d1[ActRowCore.slotO].y, 40, accuracy: 0.001)           // 옛 칸은 아래로 빠진다
        XCTAssertEqual(d1[ActRowCore.slotC].x, x3, accuracy: 0.001)
        let u0 = ActRowCore.frame("slide_up", 0, W: 320, H: 40, g: 8)
        XCTAssertEqual(u0[ActRowCore.slotC].y, 40, accuracy: 0.001)
        XCTAssertEqual(ActRowCore.frame("slide_up", 1, W: 320, H: 40, g: 8)[ActRowCore.slotO].y, -40, accuracy: 0.001)
    }

    func testFreshWindow() {
        XCTAssertTrue(ActRowCore.fresh(10_000, 10_500))
        XCTAssertTrue(ActRowCore.fresh(10_000, 8_500))                       // 기기 시계가 조금 느려도
        XCTAssertFalse(ActRowCore.fresh(10_000, 12_600))                     // 2.5초가 지난 전환은 최종 모양만
        XCTAssertFalse(ActRowCore.fresh(10_000, 7_000))
        XCTAssertFalse(ActRowCore.fresh(0, 100))
    }

    private func row(_ an: [String: Any]?, kids: Int = 3, kind: String = "button") -> Node {
        var d: [String: Any] = ["t": "row", "kids": (0..<kids).map { ["t": kind, "s": "k\($0)"] as [String: Any] }]
        if let an = an { d["an"] = an }
        return Node(d: d)
    }

    func testSpecParsing() {
        let ok = RowAnimSpec.parse(row(["k": "slide_down", "ms": 400, "sq": 1_700_000_000_000, "e": [0.1, 0.2, 0.3, 5], "o": ["s": "탑승", "fill": "gold"]]))
        XCTAssertEqual(ok?.kind, "slide_down"); XCTAssertEqual(ok?.ms, 400); XCTAssertEqual(ok?.sq, 1_700_000_000_000)
        XCTAssertEqual(ok?.ez, [0.1, 0.2, 0.3, 2])                              // 곡선 값은 -1 ~ 2
        XCTAssertEqual(ok?.oS, "탑승"); XCTAssertEqual(ok?.oFill, "gold"); XCTAssertNil(ok?.oTc); XCTAssertEqual(ok?.bg, "card")
        XCTAssertEqual(RowAnimSpec.parse(row(["k": "push_in", "ms": 9000, "sq": 5]))?.ms, 1500)
        XCTAssertNil(RowAnimSpec.parse(row(["k": "fade", "ms": 400, "sq": 5])))              // 모르는 종류
        XCTAssertNil(RowAnimSpec.parse(row(["k": "push_in", "ms": 0, "sq": 5])))
        XCTAssertNil(RowAnimSpec.parse(row(["k": "push_in", "ms": 300, "sq": 0])))
        XCTAssertNil(RowAnimSpec.parse(row(["k": "push_in", "ms": 300, "sq": 5], kids: 2)))   // 칸이 셋일 때만
        XCTAssertNil(RowAnimSpec.parse(row(["k": "push_in", "ms": 300, "sq": 5], kind: "text")))
        XCTAssertNil(RowAnimSpec.parse(row(nil)))
    }
}
