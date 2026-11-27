import XCTest
@testable import Gildongmu

/// 서버 지연 안내(RetryCard): 엔진이 준 delayed 화면 읽기 · 통신 실패 때의 안내 화면 — 안드로이드 ShellCore.retryHint · errorScreen 과 같은 값.
final class RetryTests: XCTestCase {
    private func obj(_ s: String) -> [String: Any] { (try? JSONSerialization.jsonObject(with: Data(s.utf8))) as? [String: Any] ?? [:] }

    func testRetryHintFromEngine() {
        XCTAssertEqual(Screen.retryHint(obj(#"{"delayed":true,"retry":[4,8,15,30]}"#)), [4, 8, 15, 30])
        XCTAssertEqual(Screen.retryHint(obj(#"{"delayed":true,"retry":[0,500,2]}"#)), [1, 120, 2])      // 1~120초로 맞춘다
        XCTAssertEqual(Screen.retryHint(obj(#"{"delayed":true,"retry":[1,2,3,4,5,6,7,8]}"#))?.count, 6)    // 여섯 번까지
        XCTAssertEqual(Screen.retryHint(obj(#"{"delayed":true}"#)), [4, 8, 16, 30])                        // 간격 없으면 기본
        XCTAssertNil(Screen.retryHint(obj(#"{"screen":"shop"}"#)))
        XCTAssertNil(Screen.retryHint(obj(#"{"delayed":false,"retry":[4]}"#)))
    }
    func testErrorScreen() throws {
        let s = try XCTUnwrap(Screen.errorScreen("서버 503"))
        XCTAssertEqual(s.name, "error")
        XCTAssertEqual(s.body.count, 3)                                                                    // 안내 · 이유 · 단추
        XCTAssertEqual(Screen.errorScreen("")?.body.count, 2)                                              // 이유 없으면 안내 · 단추
        XCTAssertNil(s.retryHint)
        let long = String(repeating: "가", count: 200)
        XCTAssertEqual(Screen.errorScreen(long)?.body.count, 3)
    }
    func testDelayedScreenParses() throws {
        let j = #"{"ok":true,"v":1,"screen":"shop","delayed":true,"retry":[4,8],"head":[],"body":[{"t":"text","s":"서버 연결이 지연되고 있습니다"},{"t":"button","s":"지금 다시 시도","act":{"a":"call","v":"gdm_retry"}}]}"#
        let s = try Screen.parse(Data(j.utf8))
        XCTAssertEqual(s.retryHint, [4, 8])
        XCTAssertEqual(s.body.count, 2)
    }
}
