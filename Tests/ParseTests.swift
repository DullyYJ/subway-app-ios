import XCTest
@testable import Gildongmu

final class ParseTests: XCTestCase {
    func testScreenParse() throws {
        let json = #"{"ok":true,"v":1,"screen":"x","head":[],"body":[{"t":"text","s":"안녕","pad":[1,2,3,4],"bold":true},{"t":"spacer","h":8},{"t":"mystery"}]}"#
        let s = try Screen.parse(json.data(using: .utf8)!)
        XCTAssertEqual(s.body.count, 3)
        XCTAssertEqual(s.body[0].str("s"), "안녕")
        XCTAssertTrue(s.body[0].bool("bold"))
        XCTAssertEqual(s.body[0].pad.t, 2)
    }
    func testOkFalse() {
        XCTAssertThrowsError(try Screen.parse(#"{"ok":false,"err":"cap"}"#.data(using: .utf8)!))
    }
    func testCssColors() {
        XCTAssertNotNil(Palette.css("#1d9bf0")); XCTAssertNotNil(Palette.css("rgba(0,0,0,.5)")); XCTAssertNil(Palette.css("nope"))
        XCTAssertNotNil(Palette.light.color("gold")); XCTAssertNotNil(Palette.dark.color("ongold"))
    }
    func testSvgPaths() {
        // 머티리얼 '홈' 아이콘 · 호(arc)가 들어간 동그라미
        XCTAssertFalse(SVGPath.path("M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z").isEmpty)
        XCTAssertFalse(SVGPath.path("M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2z").isEmpty)
        XCTAssertFalse(SVGPath.path("M3 12a9 9 0 1 0 18 0a9 9 0 1 0-18 0").isEmpty)
        XCTAssertFalse(SVGPath.path("M1.5.5l-.5 1").isEmpty)
    }
    func testActionSet() { let a = Action.set("k", true); XCTAssertEqual(a.a, "set"); XCTAssertEqual(a.on, true) }

    /// 안드로이드 wrap 과 같은 규칙: 띄어쓰기에서 끊고, 칸이 넉넉하면 한 줄.
    func testWrapLikeAndroid() {
        XCTAssertEqual(Typo.wrap("가나다 라마바", maxW: 1000, size: 12, bold: false).count, 1)
        XCTAssertGreaterThanOrEqual(Typo.wrap("가나다 라마바 사아자 차카타 파하", maxW: 60, size: 12, bold: false).count, 2)
        XCTAssertEqual(Typo.wrap("", maxW: 100, size: 12, bold: false).count, 0)
        XCTAssertEqual(Typo.wrap("가\n나", maxW: 100, size: 12, bold: false), ["가", "나"])
        XCTAssertEqual(Typo.wrap("가나다 라마바 사아자 차카타", maxW: 40, size: 12, bold: false, maxLines: 2).count, 2)
    }

    /// 엔진 overlay → 모델 → 다이내믹 아일랜드 값 (안드로이드 OvCore 와 같은 읽기 규칙).
    func testOverlayToLiveActivity() {
        let ov = OvState.from(DemoOverlay.json("moving"))
        XCTAssertTrue(ov.active); XCTAssertEqual(ov.cells.count, 7); XCTAssertEqual(ov.cur, 2)
        XCTAssertEqual(ov.stateRgb, OvState.cMove)
        let st = RideActivityAttributes.ContentState(ov)
        XCTAssertEqual(st.label, "이동중"); XCTAssertEqual(st.cells.count, 5); XCTAssertEqual(st.cells[st.cur].n, "을지로입구")
        XCTAssertEqual(RideActivityAttributes.ContentState(OvState.from(DemoOverlay.json("arrived"))).label, "도착")
        XCTAssertEqual(RideActivityAttributes.ContentState(OvState.from(DemoOverlay.json("wait"))).label, "대기")
        XCTAssertEqual(RideActivityAttributes.ContentState(OvState.from(DemoOverlay.json("alert1"))).alert, 1)
        XCTAssertFalse(OvState.from(["active": true]).active)                  // line1 이 없으면 꺼짐
        XCTAssertEqual(OvState.color("#f00", 0), 0xFFFF0000); XCTAssertEqual(OvState.color("#80ff0000", 0), 0x80FF0000)
    }
    func testStepBodyShape() {
        let b = RideLoopBody.make(nowMs: 1000, fixes: [[Int64(900), 37.5, 127.0, NSNull()]], state: "{\"x\":1}")
        XCTAssertTrue(b.contains("\"nowMs\":1000")); XCTAssertTrue(b.contains("\"state\":{\"x\":1}")); XCTAssertTrue(b.contains("null"))
    }
}
