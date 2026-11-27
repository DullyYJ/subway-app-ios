import XCTest
@testable import Gildongmu

/// 중간 환승 버스 고르기(s320): 어느 버스 구간을 기다리는지 읽기(boardCalc) · 고른 번호의 변경분 끼우기(applySwap) — 안드로이드 RideCore 와 같은 값을 내야 한다.
final class RideSwapTests: XCTestCase {
    private func obj(_ s: String) -> [String: Any] { (try? JSONSerialization.jsonObject(with: Data(s.utf8))) as? [String: Any] ?? [:] }

    // 노드: 0 출발(지하철) · 1 버스A 승차 · 2 버스A 하차 · 3 지하철 · 4 버스B 승차
    private let nodes = #"[{"name":"출발","isSub":true},{"name":"가","isBus":true,"lineName":"A"},{"name":"나","isBus":true,"lineName":"A"},{"name":"다","isSub":true},{"name":"라","isBus":true,"lineName":"B"}]"#

    func testBoardCalcFirstAndSecondBusLeg() {
        let w1 = obj(#"{"eta":{"nodes":\#(nodes)},"wait":{"i":1}}"#)
        XCTAssertEqual(RideLoop.boardCalc(w1), RideLoop.Board(i: 1, j: 0))
        let w4 = obj(#"{"eta":{"nodes":\#(nodes)},"wait":{"i":4}}"#)
        XCTAssertEqual(RideLoop.boardCalc(w4), RideLoop.Board(i: 4, j: 1))                   // 두 번째 버스 구간
        let x4 = obj(#"{"eta":{"nodes":\#(nodes)},"xw":{"i":4,"mode":"bus"}}"#)
        XCTAssertEqual(RideLoop.boardCalc(x4), RideLoop.Board(i: 4, j: 1))
    }
    func testBoardCalcRejects() {
        XCTAssertEqual(RideLoop.boardCalc(obj(#"{"eta":{"nodes":\#(nodes)},"wait":{"i":2}}"#)), RideLoop.Board())      // 같은 버스를 타는 중(승차 노드가 아님)
        XCTAssertEqual(RideLoop.boardCalc(obj(#"{"eta":{"nodes":\#(nodes)},"wait":{"i":3}}"#)), RideLoop.Board())      // 지하철
        XCTAssertEqual(RideLoop.boardCalc(obj(#"{"eta":{"nodes":\#(nodes)},"xw":{"i":4,"mode":"sub"}}"#)), RideLoop.Board())
        XCTAssertEqual(RideLoop.boardCalc(obj(#"{"wait":{"i":1}}"#)), RideLoop.Board())
    }
    func testApplySwapMergesAndDropsOldFollow() {
        let state = #"{"cfg":{"targets":[{"nodeIdx":1,"r":10},{"nodeIdx":4,"r":20}]},"eta":{"nodes":[{"n":0},{"n":1},{"n":2}]},"stops":[{"i":1,"x":1},{"i":2,"x":2}],"bl":{"ms":5,"arr":[1],"keep":1}}"#
        let patch = #"{"bl":{"no":"5522","pickMs":777},"nodes":[{"i":1,"name":"새"}],"stops":[{"i":2,"x":9}],"targets":[{"nodeIdx":4,"r":99}]}"#
        let out = obj(RideLoop.applySwap(state, patch))
        let cfg = out["cfg"] as? [String: Any] ?? [:]
        XCTAssertEqual((cfg["bl"] as? [String: Any])?["pickMs"] as? Int, 777)
        let tg = cfg["targets"] as? [[String: Any]] ?? []
        XCTAssertEqual(tg[0]["r"] as? Int, 10); XCTAssertEqual(tg[1]["r"] as? Int, 99)
        let nds = (out["eta"] as? [String: Any])?["nodes"] as? [[String: Any]] ?? []
        XCTAssertEqual(nds[1]["name"] as? String, "새"); XCTAssertEqual(nds[1]["n"] as? Int, 1)
        let st = out["stops"] as? [[String: Any]] ?? []
        XCTAssertEqual(st[0]["x"] as? Int, 1); XCTAssertEqual(st[1]["x"] as? Int, 9)
        let bl = out["bl"] as? [String: Any] ?? [:]
        XCTAssertNil(bl["ms"]); XCTAssertNil(bl["arr"]); XCTAssertEqual(bl["keep"] as? Int, 1)
    }
    func testApplySwapLeavesUnreadableState() {
        XCTAssertEqual(RideLoop.applySwap("not json", #"{"bl":{}}"#), "not json")
        let s = #"{"cfg":{},"eta":{}}"#
        XCTAssertEqual(RideLoop.applySwap(s, #"{"nodes":[]}"#), s)                              // bl 이 없는 변경분은 무시
    }
}
