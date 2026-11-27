import XCTest
import UIKit
import ImageIO
@testable import Gildongmu

/// 내 위치 공유 GIF 의 움직임 계획(ShareAnim) · 마커 자리 · GIF 묶기 — 안드로이드 ShareAnim.java · ShareArt.gif 와 같은 규칙.
final class ShareAnimTests: XCTestCase {
    func testPlanIsDeterministicAndInRange() {
        for seed in [1, 2, 3, 1_700_000_000_123, 99] as [Int64] {
            let a = ShareAnim(seed: seed, lo: 36, hi: 324, charH: 22), b = ShareAnim(seed: seed, lo: 36, hi: 324, charH: 22)
            XCTAssertEqual(a.id, b.id); XCTAssertEqual(a.x, b.x); XCTAssertEqual(a.sheet, b.sheet)
            XCTAssertTrue(ShareAnim.order.contains(a.id))
            XCTAssertEqual(a.x.count, ShareAnim.N)
            for i in 0..<ShareAnim.N {
                XCTAssertTrue(a.x[i] >= 36 - 0.001 && a.x[i] <= 324 + 0.001, "x \(a.x[i])")
                XCTAssertTrue(a.sheet[i] >= 0 && a.sheet[i] < 16)
                XCTAssertTrue(a.face[i] == 1 || a.face[i] == -1)
                XCTAssertTrue(a.pulse[i] >= 0 && a.pulse[i] < 1)
            }
            for i in 0..<ShareAnim.pause { XCTAssertEqual(a.sheet[i], 0); XCTAssertEqual(a.x[i], a.x[0], accuracy: 0.0001) }          // 처음엔 서 있다
        }
    }

    func testLoopIsSeamless() {                                                      // 마지막 프레임 다음이 처음 프레임으로 이어진다: 같은 자리 · 깜박임 한 바퀴의 배수
        XCTAssertEqual(ShareAnim.N % ShareAnim.pulseLen, 0)
        let a = ShareAnim(seed: 7, lo: 36, hi: 324, charH: 22)
        XCTAssertEqual(a.x[ShareAnim.N - 1], a.x[0], accuracy: 0.0001)
    }

    func testDifferentSeedsGiveDifferentPlans() {
        var ids = Set<String>()
        for s in 0..<40 { ids.insert(ShareAnim(seed: Int64(s) * 7919 + 13, lo: 36, hi: 324, charH: 22).id) }
        XCTAssertTrue(ids.count >= 3)
    }

    func testMarkerPosition() {
        let d = ShareCardData(["stations": (0..<12).map { ["n": "역\($0)", "t": "10:0\($0 % 10)"] as [String: Any] }, "hit": 5])
        let slots = ShareLoc.slots(d.names.count, d.hit)
        let p = ShareCardView.markerPos(d)
        XCTAssertNotNil(p)
        XCTAssertEqual(p?.y, 138)
        let k = slots.firstIndex(of: 5)!
        let step = (360 - 18.0 - 18 - 40) / Double(slots.count - 1)
        XCTAssertEqual(Double(p!.x), 18 + 20 + step * Double(k), accuracy: 0.001)
        XCTAssertNil(ShareCardView.markerPos(ShareCardData([:])))                    // 역이 없으면 마커도 없다
    }

    func testEncodeMakesAnimatedGif() {
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        let r = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 12), format: fmt)
        let frames: [CGImage] = (0..<5).compactMap { i in
            r.image { c in UIColor(white: CGFloat(i) / 5, alpha: 1).setFill(); c.fill(CGRect(x: 0, y: 0, width: 20, height: 12)) }.cgImage
        }
        XCTAssertEqual(frames.count, 5)
        guard let d = ShareGif.encode(frames, delayCs: 7) else { return XCTFail("gif") }
        XCTAssertEqual(String(data: d.prefix(6), encoding: .ascii), "GIF89a")
        let src = CGImageSourceCreateWithData(d as CFData, nil)
        XCTAssertEqual(src.map { CGImageSourceGetCount($0) }, 5)
    }
}
