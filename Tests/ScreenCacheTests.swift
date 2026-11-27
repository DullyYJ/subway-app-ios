import XCTest
@testable import Gildongmu

/// 화면 기억(ScreenCache) · 뼈대 화면 — 안드로이드 showCached · ShellCore.skeletonScreen 과 같은 모양.
final class ScreenCacheTests: XCTestCase {
    func testFileNameStable() {
        XCTAssertEqual(ScreenCache.fileName("shop|전체"), ScreenCache.fileName("shop|전체"))              // 프로세스가 바뀌어도 같은 이름
        XCTAssertNotEqual(ScreenCache.fileName("shop|전체"), ScreenCache.fileName("shop|간식"))
        XCTAssertTrue(ScreenCache.fileName("x").hasSuffix(".json"))
    }
    func testSkeletonKinds() throws {
        let c = try XCTUnwrap(Screen.skeleton("cards")), l = try XCTUnwrap(Screen.skeleton("list")), m = try XCTUnwrap(Screen.skeleton("map"))
        XCTAssertEqual(c.name, "skel")
        XCTAssertEqual(c.body.first?.t, "skel")
        XCTAssertEqual(c.body.first?.num("rows"), 4)
        XCTAssertEqual(l.body.first?.num("rows"), 8)
        XCTAssertEqual(m.body.first?.num("rows"), 4)
        XCTAssertEqual(m.body.first?.str("kind"), "map")
    }
    @MainActor func testPutGetRoundTripAndSkipsDelayed() throws {
        let key = "test|" + UUID().uuidString
        let ok = try Screen.parse(Data(#"{"ok":true,"screen":"shop","head":[],"body":[{"t":"text","s":"안녕"}]}"#.utf8))
        ScreenCache.shared.put(key, ok)
        XCTAssertEqual(ScreenCache.shared.get(key)?.body.first?.str("s"), "안녕")
        let key2 = "test|" + UUID().uuidString
        let delayed = try Screen.parse(Data(#"{"ok":true,"screen":"shop","delayed":true,"retry":[4],"head":[],"body":[]}"#.utf8))
        ScreenCache.shared.put(key2, delayed)
        XCTAssertNil(ScreenCache.shared.get(key2))                                                       // 지연 안내는 담지 않는다
    }
}

final class ImageUrlsTests: XCTestCase {
    func testUrlsInScreen() {
        let raw: [String: Any] = ["body": [["t": "cards", "cells": [["img": "https://a.example/1.jpg", "name": "x"], ["img": "https://a.example/1.jpg"], ["img": "ftp://no", "name": "y"], ["img": "https://a.example/2.png"]]]]]
        let u = ImageStore.urls(in: raw)
        XCTAssertEqual(u.map { $0.absoluteString }, ["https://a.example/1.jpg", "https://a.example/2.png"])           // 같은 주소는 한 번 · http 가 아닌 것은 뺀다
        XCTAssertEqual(ImageStore.urls(in: raw, limit: 1).count, 1)
    }
}
