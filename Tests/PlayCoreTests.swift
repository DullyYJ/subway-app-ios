import XCTest
import UIKit
@testable import Gildongmu

/// 캐릭터 놀이터 계산(PlayCore) — 안드로이드 PlayCore.java 와 같은 규칙: 장면 8가지 · 칸 위치 · 이어받기 · 오래 돌려도 칸 밖으로 안 나간다.
final class PlayCoreTests: XCTestCase {
    func testRngStaysInUnitRange() {
        var r = PlayRng(seed: 7)
        for _ in 0..<2000 { let v = r.next(); XCTAssertTrue(v >= 0 && v < 1) }
        XCTAssertEqual(r.int(1), 0)
        for _ in 0..<200 { let n = r.int(5); XCTAssertTrue(n >= 0 && n < 5) }
    }

    func testScenesMatchOrder() {
        XCTAssertEqual(PlayCore.scenes.map { $0.name }, PlayCore.sceneOrder)
        for s in PlayCore.scenes { XCTAssertEqual(s.p.count, 3); XCTAssertEqual(s.d.count, 3); XCTAssertEqual(s.g.count, 2) }
        XCTAssertNil(PlayCore.scene("nope"))
        XCTAssertEqual(PlayCore.scene("night")?.mark, "z")
    }

    func testKinds() {
        XCTAssertEqual(PlayCore.kindOf("lovel"), "cat")
        XCTAssertEqual(PlayCore.kindOf("dudung"), "mole")
        XCTAssertEqual(PlayCore.kindOf("chaeng"), "tad")
        XCTAssertEqual(PlayCore.kindOf("sul"), "eagle")
        XCTAssertEqual(PlayCore.kindOf("dolsom"), "dog")
        XCTAssertEqual(PlayCore.kindOf("ppopu"), "dog")
    }

    func testHostRects() {
        let p = PlayCore.popupHost(sheetW: 360, padX: 24, nameX: 24, nameW: 80, nameY: 36, nameH: 30)
        XCTAssertEqual(p, CGRect(x: 114, y: 0, width: 222, height: 70))
        XCTAssertNil(PlayCore.popupHost(sheetW: 360, padX: 24, nameX: 24, nameW: 230, nameY: 36, nameH: 30))          // 이름이 길어 빈 칸이 90 도 안 남는다
        let t = PlayCore.ttHost(barY: 0, barH: 80, titleX: 24, titleW: 100, rightEdge: 336)
        XCTAssertEqual(t, CGRect(x: 134, y: -24, width: 202, height: 70))
        XCTAssertNil(PlayCore.ttHost(barY: 0, barH: 80, titleX: 24, titleW: 230, rightEdge: 336))
    }

    func testPlayStaysInsideTheBoxForALongTime() {
        for seed in 1...12 {
            let pl = PlayCore.Play(wc: 200, hc: 70, snap: nil, rng: PlayRng(seed: UInt64(seed)))
            XCTAssertTrue(pl.cs.count == 2 || pl.cs.count == 3)
            XCTAssertEqual(pl.ids.count, pl.cs.count)
            for _ in 0..<(30 * 90) {                                              // 90초 · 30fps
                pl.tick(1.0 / 30)
                for c in pl.cs {
                    XCTAssertTrue(c.x.isFinite && c.y.isFinite && c.fr.isFinite)
                    XCTAssertTrue(c.x > -c.w && c.x < pl.W + c.w, "seed \(seed) \(c.id) x=\(c.x)")
                    let i = pl.frameIdx(c)
                    XCTAssertTrue(i >= 0 && i < 16)
                }
                XCTAssertTrue(pl.pt.count <= 60 && pl.poops.count <= 3)
            }
        }
    }

    func testEveryCharacterAloneRuns() {                                          // 모든 캐릭터의 특별한 놀이(나무 · 웅덩이 · 땅속 · 하늘)가 한 번씩은 돈다
        for id in RunnerCore.order {
            var s = PlayCore.Snap()
            s.scene = "meadow"; s.ids = [id]; s.xs = [0.5]; s.dirs = [1]; s.sideA = true
            let pl = PlayCore.Play(wc: 180, hc: 70, snap: s, rng: PlayRng(seed: 99))
            XCTAssertEqual(pl.ids, [id])
            var seen = Set<String>()
            for _ in 0..<(30 * 120) { pl.tick(1.0 / 30); seen.insert(pl.cs[0].st); XCTAssertTrue(pl.cs[0].x.isFinite) }
            XCTAssertTrue(seen.count >= 3, "\(id): \(seen)")
        }
    }

    func testSnapContinuesTheSameScene() {
        let a = PlayCore.Play(wc: 220, hc: 70, snap: nil, rng: PlayRng(seed: 5))
        for _ in 0..<100 { a.tick(1.0 / 30) }
        let sn = a.snap()
        XCTAssertEqual(sn.scene, a.sc.name)
        XCTAssertEqual(sn.ids, a.ids)
        let b = PlayCore.Play(wc: 300, hc: 70, snap: sn, rng: PlayRng(seed: 6))          // 시간표는 칸이 달라도 같은 배경 · 같은 캐릭터 · 비슷한 자리
        XCTAssertEqual(b.sc.name, a.sc.name)
        XCTAssertEqual(b.ids, a.ids)
        XCTAssertEqual(b.sideA, a.sideA)
        for (i, c) in b.cs.enumerated() { XCTAssertEqual(c.x / b.W, min(max(a.cs[i].x / a.W, c.w * 0.45 / b.W), 1 - c.w * 0.45 / b.W), accuracy: 0.0001) }
        if let ta = a.tree, let tb = b.tree { XCTAssertEqual(ta.x / a.W, tb.x / b.W, accuracy: 0.0001) }
        if let pa = a.pond, let pb = b.pond { XCTAssertEqual(pa.x / a.W, pb.x / b.W, accuracy: 0.0001) }
    }

    func testCutMakesSixteenFrames() {
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        let sheet = UIGraphicsImageRenderer(size: CGSize(width: 1024, height: 1024), format: fmt).image { c in
            UIColor.red.setFill(); c.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
        }
        let fr = PlaySim.cut(sheet, 0.3)
        XCTAssertEqual(fr.count, 16)
        XCTAssertEqual(fr[0].size.width, CGFloat(256 * 0.3), accuracy: 0.01)
        XCTAssertTrue(PlaySim.cut(UIImage(), 0.3).isEmpty)
    }
}
