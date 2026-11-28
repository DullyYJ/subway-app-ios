import XCTest
@testable import Gildongmu

final class GwSimTests: XCTestCase {
    /// 자바 Random 과 같은 수열이어야 안드로이드와 같은 걸음이 나온다(알려진 값).
    func testJRandomMatchesJava() {
        var r = JRandom(42); XCTAssertEqual(r.nextInt(1 << 30), 781215565)
        var z = JRandom(0); XCTAssertEqual(z.nextInt(1 << 30), 784870680)
    }
    func testGeoHorizontalFitsWidget() {
        let g = GwGeo.of(vertical: false, W: 338, H: 158)
        XCTAssertGreaterThan(g.clkW, 100); XCTAssertLessThanOrEqual(g.clkL + g.clkW, 338); XCTAssertLessThan(g.clkT + g.clkH, 158)
        XCTAssertGreaterThan(g.clkT, g.charH)                                   // 캐릭터가 시계 위에 오를 머리 공간
    }
    func testSimStaysInsideAndDraws() {
        for vertical in [false, true] {
            let g = GwGeo.of(vertical: vertical, W: vertical ? 158 : 338, H: 158)
            let sim = GwSim(geo: g, seed: 5, ids: ["dolsom", "lovel", "sul"])
            sim.wakeAll(0)
            for i in 0..<3000 {                                                  // 5분
                sim.step(0.1)
                for c in sim.cs { XCTAssertTrue(c.x >= -1 && c.x <= g.W + 1, "x=\(c.x) at \(i)"); XCTAssertFalse(c.x.isNaN || c.y.isNaN) }
            }
            XCTAssertFalse(GwArt.draw(sim).isEmpty)
        }
    }
    func testBedThenAllAsleep() {
        let g = GwGeo.of(vertical: false, W: 338, H: 158)
        let sim = GwSim(geo: g, seed: 9, ids: ["dolsom", "juksun", "chaeng"])
        sim.bed(untilTapped: true)
        for _ in 0..<400 { sim.step(0.1) }
        sim.snapBed(); sim.snapAsleep()
        XCTAssertTrue(sim.allInBed())
        let items = GwArt.draw(sim)
        XCTAssertTrue(items.contains { if case .cell(let id, _, _, _, _, _, _) = $0.kind { return id.hasSuffix("_sleep") }; return false })
    }
    func testPlanEpisodeCountsAndOrder() {
        let ep = GwPlan.episode(.init(vertical: false, W: 338, H: 158), seed: 3, prev: nil, t0: 0)
        XCTAssertGreaterThan(ep.snaps.count, 40); XCTAssertLessThan(ep.snaps.count, 100)
        XCTAssertEqual(ep.snaps.map { $0.t }, ep.snaps.map { $0.t }.sorted())
    }
    func testPickSetDiffersFromPrev() {
        let a = GwSim.pickSet(seed: 1, prev: nil), b = GwSim.pickSet(seed: 1, prev: a)
        XCTAssertEqual(a.count, 3); XCTAssertFalse(GwSim.sameSet(a, b))
    }
}
