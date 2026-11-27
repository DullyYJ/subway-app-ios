import XCTest
@testable import Gildongmu

/// 출퇴근 브리핑 알림의 기기 쪽 상태(안드로이드 CmCore 와 같은 값을 내야 한다).
final class CmCoreTests: XCTestCase {
    private let keys = ["cm_on", "cm_morn", "cm_eve", "cm_days", "cm_from", "cm_to", "cm_efrom", "cm_eto", "cm_from_g", "cm_to_g", "cm_efrom_g", "cm_eto_g"]
    override func setUp() { clear() }
    override func tearDown() { clear(); CmCore.shared.sub = ""; CmCore.shared.pop = false; CmCore.shared.endInline() }
    private func clear() { for k in keys { UserDefaults.standard.removeObject(forKey: k) } }

    func testDefaultsAndHm() {
        XCTAssertEqual(CmCore.morn(), "07:30"); XCTAssertEqual(CmCore.eve(), "18:30")
        XCTAssertFalse(CmCore.on())
        XCTAssertEqual(CmCore.days(), [1, 2, 3, 4, 5])
        XCTAssertEqual(CmCore.hm("9:30", "07:30"), "07:30"); XCTAssertEqual(CmCore.hm("24:00", "07:30"), "07:30"); XCTAssertEqual(CmCore.hm("23:59", "07:30"), "23:59")
    }

    func testOccBodyShape() {
        XCTAssertEqual(CmCore.occBody(0), "{\"op\":\"occ\",\"nowMs\":0,\"morn\":\"07:30\",\"eve\":\"18:30\",\"days\":[1,2,3,4,5]}")
    }

    func testDayAndPresetActions() {
        let c = CmCore.shared
        XCTAssertEqual(c.act("call", v: "cm.day.6", key: nil, on: false, q: nil), CmCore.R.render | CmCore.R.resched)
        XCTAssertEqual(CmCore.days(), [1, 2, 3, 4, 5, 6])
        _ = c.act("call", v: "cm.day.1", key: nil, on: false, q: nil)
        XCTAssertEqual(CmCore.days(), [2, 3, 4, 5, 6])
        _ = c.act("call", v: "cm.preset.weekend", key: nil, on: false, q: nil)
        XCTAssertEqual(CmCore.days(), [0, 6])
        XCTAssertEqual(c.act("call", v: "cm.day.9", key: nil, on: false, q: nil), CmCore.R.none)
    }

    func testSwitchAndTimePicker() {
        let c = CmCore.shared
        XCTAssertEqual(c.act("set", v: nil, key: "cm", on: true, q: nil), CmCore.R.render | CmCore.R.resched)
        XCTAssertTrue(CmCore.on())
        _ = c.act("call", v: "cm.tp.eve", key: nil, on: false, q: nil)          // 18:30 → 오후 6:30
        XCTAssertEqual(c.sub, "tp"); XCTAssertEqual(c.tpAp, "pm"); XCTAssertEqual(c.tpH, 6); XCTAssertEqual(c.tpM, 30)
        _ = c.act("call", v: "tp.h.7", key: nil, on: false, q: nil)
        _ = c.act("call", v: "tp.m.45", key: nil, on: false, q: nil)
        XCTAssertEqual(c.act("call", v: "tp.m.43", key: nil, on: false, q: nil), CmCore.R.none)          // 5분 단위만
        XCTAssertEqual(c.act("call", v: "tp.ok", key: nil, on: false, q: nil), CmCore.R.render | CmCore.R.resched)
        XCTAssertEqual(CmCore.eve(), "19:45"); XCTAssertEqual(c.sub, "")
        _ = c.act("call", v: "cm.tp.morn", key: nil, on: false, q: nil)
        _ = c.act("call", v: "tp.ap.pm", key: nil, on: false, q: nil)
        _ = c.act("call", v: "tp.h.12", key: nil, on: false, q: nil)
        _ = c.act("call", v: "tp.m.0", key: nil, on: false, q: nil)
        _ = c.act("call", v: "tp.ok", key: nil, on: false, q: nil)
        XCTAssertEqual(CmCore.morn(), "12:00")
    }

    func testPlaceSaveAndBriefBody() {
        let c = CmCore.shared
        c.focusInline("from", "")
        XCTAssertTrue(c.inl)
        XCTAssertEqual(c.onInline("from", "아라"), CmCore.R.render | CmCore.R.bus)
        XCTAssertEqual(c.onInline("from", "아"), CmCore.R.render)
        XCTAssertEqual(c.act("call", v: "pk.save.from", key: nil, on: false, q: " 아라 "), CmCore.R.render | CmCore.R.resched)
        XCTAssertEqual(CmCore.place("from"), "아라"); XCTAssertFalse(c.inl)
        c.focusInline("to", "")
        c.setBus(["강남역(버스)"], [(37.5, 127.0)])
        XCTAssertTrue(CmCore.inlineFacts().contains("\"bus\":[\"강남역(버스)\"]"))
        XCTAssertEqual(c.act("call", v: "pk.b.0", key: nil, on: false, q: nil), CmCore.R.render | CmCore.R.resched)
        XCTAssertEqual(CmCore.place("to"), "강남역(버스)")
        let b = CmCore.briefBody(kind: "eve", nowMs: 5, gps: (37.5, 127.25), eta: true)
        XCTAssertEqual(b, "{\"kind\":\"eve\",\"nowMs\":5,\"from\":{\"nm\":\"아라\"},\"to\":{\"nm\":\"강남역(버스)\",\"lat\":37.5,\"lng\":127.0,\"bus\":true},\"gps\":{\"lat\":37.5,\"lng\":127.25},\"eta\":1}")
        // 글자를 모두 지운 채 벗어나면 저장된 것을 그대로 둔다
        c.focusInline("from", "아라")
        XCTAssertEqual(c.blurInline("from", ""), CmCore.R.render)
        XCTAssertEqual(CmCore.place("from"), "아라")
    }

    func testParsers() {
        let occ = Data("{\"ok\":true,\"morn\":[1000,2000,3000],\"eve\":[]}".utf8)
        XCTAssertEqual(CmCore.parseOcc(occ, kind: "morn", max: 2), [1000, 2000])
        XCTAssertEqual(CmCore.parseOcc(occ, kind: "eve", max: 14), [])
        XCTAssertEqual(CmCore.parseOcc(Data("{\"ok\":false}".utf8), kind: "morn", max: 14), [])
        let br = CmCore.parseBrief(Data("{\"ok\":true,\"kind\":\"eve\",\"title\":\"퇴근길\",\"body\":\"비 와요\"}".utf8))
        XCTAssertEqual(br?.0, "퇴근길"); XCTAssertEqual(br?.2, "eve")
        XCTAssertNil(CmCore.parseBrief(Data("{\"ok\":true,\"title\":\"\",\"body\":\"x\"}".utf8)))
        let rt = CmCore.parseRoute(Data("{\"route\":{\"from\":{\"name\":\"아라\",\"lat\":37.1,\"lng\":127.1},\"to\":{\"name\":\"강남\",\"lat\":37.5,\"lng\":127.0,\"bus\":true}}}".utf8))
        XCTAssertEqual(rt?.0.name, "아라"); XCTAssertEqual(rt?.1.bus, true)
        XCTAssertNil(CmCore.parseRoute(Data("{\"route\":{\"from\":{\"name\":\"아라\"}}}".utf8)))
    }
}
