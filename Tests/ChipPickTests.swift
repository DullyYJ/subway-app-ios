import XCTest
@testable import Gildongmu

/// 먼저 켜 보이기: 경로 방식 탭(rh.tab.*) 맞바꿈 · 새 화면이 왔는지 가리는 표 — 안드로이드 ScreenView.pickRtab 와 같은 결과여야 한다.
final class ChipPickTests: XCTestCase {
    private func screen(_ on: String) throws -> Screen {
        func b(_ t: String, _ s: String) -> String {
            let isOn = t == on
            return #"{"t":"button","s":"\#(s)","size":11,"h":32,"r":10,"bold":true,"act":{"a":"call","v":"rh.tab.\#(t)"},"fill":"\#(isOn ? "gold" : "card2")","line":"\#(isOn ? "gold" : "border")","tc":"\#(isOn ? "#ffffff" : "sub")"}"#
        }
        let j = #"{"ok":true,"screen":"result","head":[{"t":"row","gap":6,"kids":["# + [b("fast", "최단시간"), b("less", "최소환승"), b("sub", "지하철"), b("bus", "버스")].joined(separator: ",") + #"]}],"body":[]}"#
        return try Screen.parse(Data(j.utf8))
    }
    private func btn(_ s: Screen, _ t: String) -> [String: Any] {
        ((s.head[0].d["kids"] as? [[String: Any]]) ?? []).first { ChipPick.bkey($0) == "rh.tab." + t } ?? [:]
    }

    @MainActor func testRtabSwapStyles() throws {
        let p = ChipPick(); p.clear()
        let s = try screen("fast")
        p.pickBtn(btn(s, "sub"), in: s)                                              // 지하철을 누르면
        XCTAssertEqual(p.restyle["rh.tab.sub"]?.fill, "gold")                        // 지하철은 켜진 모양
        XCTAssertEqual(p.restyle["rh.tab.sub"]?.tc, "#ffffff")
        XCTAssertEqual(p.restyle["rh.tab.fast"]?.fill, "card2")                      // 최단시간은 꺼진 모양
        XCTAssertEqual(p.restyle["rh.tab.fast"]?.tc, "sub")
        XCTAssertNil(p.restyle["rh.tab.bus"])                                        // 나머지는 그대로
        p.pickBtn(btn(s, "bus"), in: s)                                              // 새 화면 전에 한 번 더: 지금 켜진 것(지하철)과 맞바꾼다
        XCTAssertEqual(p.restyle["rh.tab.bus"]?.fill, "gold")
        XCTAssertEqual(p.restyle["rh.tab.sub"]?.fill, "card2")
        p.clear(); XCTAssertTrue(p.restyle.isEmpty)
    }
    @MainActor func testPressingOnTabDoesNothing() throws {
        let p = ChipPick(); p.clear()
        let s = try screen("fast")
        p.pickBtn(btn(s, "fast"), in: s)
        XCTAssertTrue(p.restyle.isEmpty)
    }
    @MainActor func testLightFromSwipe() throws {
        let p = ChipPick(); p.clear()
        let s = try screen("fast")
        p.light(Action(["a": "call", "v": "rh.tab.bus"])!, in: s)                   // 밀어서 넘길 때도 위 탭 단추를 먼저 켠다
        XCTAssertEqual(p.restyle["rh.tab.bus"]?.fill, "gold")
        XCTAssertEqual(p.restyle["rh.tab.fast"]?.fill, "card2")
    }
    func testSigChangesWithOnTab() throws {
        XCTAssertNotEqual(ChipPick.sig(try screen("fast")), ChipPick.sig(try screen("bus")))
        XCTAssertEqual(ChipPick.sig(try screen("sub")), ChipPick.sig(try screen("sub")))
    }
}
