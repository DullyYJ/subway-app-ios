import XCTest
@testable import Gildongmu

/// 설정 '편의 기능' 가운데 팝업 손질(SetPop): 엔진 화면(안드로이드와 같은 것)에서 iOS 에 없는 줄만 빼고 바꾼다.
final class SettingsPopTests: XCTestCase {
    /// 엔진 settings.js settingsScreen({cap:29,p:'conv'}) 의 실제 출력(알림 허용 · 표시 켬 · 갤럭시 아님).
    private let conv = #"""
{"ok":true,"v":1,"screen":"settings","cover":"tab","head":[],"body":[{"t":"panel","pad":[16,8,16,0],"ip":[16,16,16,16],"fill":"card","line":"border","r":14,"kids":[{"t":"text","s":"캐릭터 시계 위젯","size":15,"bold":true,"color":"text","pad":[0,0,0,4],"lh":1.3},{"t":"text","s":"평소엔 캐릭터들이 각자 집에서 자고 있다가, 화면을 켜면 일어나 시계 주변을 돌아다녀요. 출·퇴근 시각이 되면 캐릭터가 모여 응원해요.","size":12,"color":"sub","lh":1.5,"pad":[0,0,0,6]},{"t":"navrow","title":"위젯 추가 · 돌아다니는 시간","act":{"a":"call","v":"pg.gw"},"top":true,"size":13}]},{"t":"panel","pad":[16,12,16,0],"ip":[16,16,16,16],"fill":"card","line":"border","r":14,"kids":[{"t":"toggle","key":"ovl","title":"다른 앱 위에 표시","sub":"현재역 · 남은시간을 화면 위쪽 작은 막대로 띄워요. 광고는 넣지 않아요.\n사용 중 · 다른 앱을 쓰는 동안 위쪽에 표시돼요","on":true,"top":true,"vp":4,"size":13.5,"ssize":11,"onc":"#30d158"}]},{"t":"panel","pad":[16,12,16,0],"ip":[16,16,16,16],"fill":"card","line":"border","r":14,"kids":[{"t":"toggle","key":"bg","title":"백그라운드 유지","sub":"꺼짐 · 켜면 기기가 길동무를 자동으로 절전하지 않아요.","on":false,"top":true,"vp":4,"size":13.5,"ssize":11,"onc":"#30d158"}]},{"t":"panel","pad":[16,12,16,0],"ip":[16,16,16,16],"fill":"card","line":"border","r":14,"kids":[{"t":"toggle","key":"rl","title":"안내 정확도 향상","sub":"목적지에 도착하면 예상 시간과 실제 시간의 차이만 익명으로 보내요. 역 이름·위치·기기 정보는 보내지 않아요.","on":true,"top":true,"vp":4,"size":13.5,"ssize":11,"onc":"#30d158"}]},{"t":"button","s":"닫기","size":14,"h":44,"r":10,"bold":true,"act":{"a":"call","v":"pg.back"},"fill":"none","line":"border2","tc":"text","pad":[0,0,0,0]},{"t":"spacer","h":12}],"info":{"page":"conv","sub":""},"rev":"s2p:2mins4"}
"""#
    private func screen() throws -> Screen { try Screen.parse(Data(conv.utf8)) }
    private func toggles(_ s: Screen) -> [[String: Any]] {
        s.body.flatMap { ($0.d["kids"] as? [[String: Any]] ?? []).filter { ($0["t"] as? String) == "toggle" } }
    }

    func testAdaptConvDropsBackgroundKeepRowAndKeepsTheRest() throws {
        let s = try screen()
        XCTAssertEqual(toggles(s).compactMap { $0["key"] as? String }, ["ovl", "bg", "rl"])          // 고치기 전: 엔진은 셋을 준다
        let a = SetPop.adaptConv(s, ovl: true, granted: true)
        XCTAssertEqual(toggles(a).compactMap { $0["key"] as? String }, ["ovl", "rl"])               // 백그라운드 유지(배터리 최적화)는 iOS 에 없다
        XCTAssertEqual(a.body.count, s.body.count - 1)
        XCTAssertEqual(a.body.last?.t, "spacer")
        XCTAssertTrue(a.body.contains { $0.t == "button" && ($0.act?.v == "pg.back") })              // [닫기] 는 그대로
        XCTAssertTrue(a.body.first?.kids.contains { $0.act?.v == "pg.gw" } ?? false)                // 위젯 줄(pg.gw)도 그대로
        XCTAssertEqual(a.body.enumerated().map { $1.id }, (0..<a.body.count).map { "body\($0)" })     // 자리 번호가 다시 매겨진다(스위치 상태가 안 섞인다)
    }
    func testOverlayRowSpeaksLiveActivity() throws {
        let on = toggles(SetPop.adaptConv(try screen(), ovl: true, granted: true)).first!
        XCTAssertEqual(on["title"] as? String, "잠금 화면 · 다이내믹 아일랜드에 표시")
        XCTAssertTrue((on["sub"] as? String ?? "").contains("사용 중"))
        XCTAssertFalse((on["sub"] as? String ?? "").contains("화면 위쪽"))                            // 안드로이드 막대 설명은 없다
        let blocked = toggles(SetPop.adaptConv(try screen(), ovl: true, granted: false)).first!
        XCTAssertTrue((blocked["sub"] as? String ?? "").contains("권한이 필요해요"))
        let off = toggles(SetPop.adaptConv(try screen(), ovl: false, granted: true)).first!
        XCTAssertTrue((off["sub"] as? String ?? "").hasSuffix("꺼져 있어요"))
    }
    func testFactsAreValidJsonWithTheKeysTheEngineReads() throws {
        let j = SetPop.facts(np: ["arrive": 0, "transfer": 1, "arrive_reco": 1], denied: true, ovl: false, granted: true, rl: false)
        let o = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(j.utf8)) as? [String: Any])
        XCTAssertEqual((o["np"] as? [String: Int])?["arrive"], 0)
        XCTAssertEqual(o["npd"] as? Int, 1)
        XCTAssertEqual(o["ovl"] as? Int, 0)
        XCTAssertEqual(o["gr"] as? Int, 1)
        XCTAssertEqual(o["sup"] as? Int, 1)
        XCTAssertEqual(o["sam"] as? Int, 0)
        XCTAssertEqual(o["ig"] as? Int, 0)
        XCTAssertEqual(o["rl"] as? Int, 0)
    }
    func testFrameMatchesAndroidDialog() throws {
        let f = SetPop.frame(try screen())
        let d = try XCTUnwrap(f.raw["dlg"] as? [String: Any])
        XCTAssertEqual(d["w"] as? Int, 400)          // 너비 min(화면−44, 400)
        XCTAssertEqual(d["mx"] as? Int, 22)
        XCTAssertEqual(d["r"] as? Int, 20)
        XCTAssertEqual(d["dim"] as? Double, 0.68)
        XCTAssertEqual((d["tap"] as? [String: Any])?["v"] as? String, "pg.back")                   // 바깥을 누르면 닫는다
        XCTAssertEqual(f.body.count, try screen().body.count)
    }
    func testOvlSwitchDefaultsOnAndRemembersOff() {
        let ud = UserDefaults(suiteName: "SettingsPopTests")!
        ud.removePersistentDomain(forName: "SettingsPopTests")
        XCTAssertTrue(SetPop.ovlOn(ud))
        ud.set("1", forKey: SetPop.ovlOffKey)
        XCTAssertFalse(SetPop.ovlOn(ud))
        ud.set("0", forKey: SetPop.ovlOffKey)
        XCTAssertTrue(SetPop.ovlOn(ud))
    }
    func testWidgetGuideHasBackButtonAndSteps() {
        let g = SetPop.gwGuide()
        XCTAssertEqual(g.body.first?.act?.v, "pg.back")
        let all = g.body.flatMap { [$0] + $0.kids }.compactMap { $0.str("s") }.joined(separator: "\n")
        XCTAssertTrue(all.contains("길동무"))
        XCTAssertTrue(all.contains("위젯 추가"))
        XCTAssertTrue(all.contains("2~3초"))          // 아이폰 위젯은 계속 그리지 못한다는 안내
    }
}
