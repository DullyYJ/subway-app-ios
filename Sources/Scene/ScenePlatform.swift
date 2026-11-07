import Foundation

/// 지하철역 승강장(역 안) — 지하철을 기다리는 장면의 배경(안드로이드 ScenePlatform.java).
/// ★ 그림만 그린다. 실내라서 하늘·구름·해·비·눈·안개·바람·낙엽·햇빛·더위 효과는 쓰지 않고, 시간대·날씨에 따라 색이 변하지도 않는다.
///   어느 역에서 기다리는지(간판의 이름)와 노선(번호·색)은 엔진이 준 값(res.sta · res.line)이다.
/// 승강장이 필요로 하는 것만 — SceneCore 가 따른다.
protocol ScenePlatformHost: AnyObject { var W: Double { get }; var H: Double { get }; var g: SceneArt.Geom { get }; var res: SceneModel.Res { get }; var sta: String { get } }

enum ScenePlatform {
    /// 승강장 배경 전체(캐릭터 뒤). 날씨·시간대 값은 읽지 않는다.
    static func back(_ S: ScenePlatformHost, _ c: SceneCv) {
        let W = S.W, H = S.H; let g = S.g
        let lineCol = SceneArt.lineColor(S.res.line)
        let ceilB = (H * 0.10).rounded(), hy = g.hy, edgeY = (hy + (g.nearTop - hy) * 0.55).rounded()
        // 천장 + 형광등
        c.fillStyle("#2b303d"); c.fillRect(0, 0, W, ceilB)
        c.fillStyle("#3a4152"); c.fillRect(0, ceilB - 3, W, 3)
        c.fillStyle("#fff8d6"); var lx = 10.0; while lx < W - 24 { rr(c, lx, 3, 30, 3.4, 1.7); c.fill(); lx += 52 }
        // 맞은편 벽(타일) — 노선 색 띠
        let wall = c.linear(0, ceilB, 0, hy + 4).stop(0, css("#e6eaf1")).stop(1, css("#c3ccda")); c.fillGrad(wall); c.fillRect(0, ceilB, W, hy + 4 - ceilB)
        c.strokeStyle("rgba(110,125,150,.26)"); c.lineWidth(0.8)
        var y = ceilB + 9; while y < hy { c.beginPath(); c.moveTo(0, y); c.lineTo(W, y); c.stroke(); y += 13 }
        var x = 0.0; while x < W { c.beginPath(); c.moveTo(x, ceilB); c.lineTo(x, hy + 4); c.stroke(); x += 18 }
        let bandY = ceilB + (hy - ceilB) * 0.52
        c.fillStyle(lineCol); c.fillRect(0, bandY, W, 5)
        c.fillStyle("rgba(255,255,255,.35)"); c.fillRect(0, bandY, W, 1.2)
        // 선로(움푹 들어간 곳) — 어둡게, 레일과 침목
        let pit = c.linear(0, hy + 4, 0, edgeY).stop(0, css("#161a25")).stop(1, css("#262d3b")); c.fillGrad(pit); c.fillRect(0, hy + 4, W, edgeY - hy - 4)
        let rY1 = hy + 4 + (edgeY - hy - 4) * 0.38, rY2 = hy + 4 + (edgeY - hy - 4) * 0.78
        c.strokeStyle("#6f7a8e"); c.lineWidth(1.3); c.beginPath(); c.moveTo(0, rY1); c.lineTo(W, rY1); c.moveTo(0, rY2); c.lineTo(W, rY2); c.stroke()
        c.strokeStyle("rgba(150,160,180,.35)"); c.lineWidth(1)
        x = 4; while x < W { c.beginPath(); c.moveTo(x, rY1 - 1.5); c.lineTo(x - 2, rY2 + 1.5); c.stroke(); x += 11 }
        // 안전 발판(노란 선 + 점자블록)
        c.fillStyle("#f2c94c"); c.fillRect(0, edgeY, W, 3.2)
        c.fillStyle("#d9b23c"); x = 3; while x < W { c.fillRect(x, edgeY + 3.2, 3, 2); x += 7 }
        // 승강장 바닥(타일) — 앞으로 올수록 밝다
        let fl = c.linear(0, edgeY + 5, 0, H).stop(0, css("#a9b2c3")).stop(1, css("#8791a5")); c.fillGrad(fl); c.fillRect(0, edgeY + 5, W, H - edgeY - 5)
        c.strokeStyle("rgba(70,82,104,.22)"); c.lineWidth(0.8)
        y = edgeY + 14; var st = 9.0; while y < H { c.beginPath(); c.moveTo(0, y); c.lineTo(W, y); c.stroke(); y += st; st *= 1.18 }
        let cx0 = W * 0.5
        var dx = -W; while dx <= W { c.beginPath(); c.moveTo(cx0 + dx * 0.55, edgeY + 5); c.lineTo(cx0 + dx * 1.5, H); c.stroke(); dx += 26 }
        // 형광등이 바닥에 비친 부드러운 빛
        lx = 40
        while lx < W {
            let lg = c.radial(lx, H * 0.78, 0, lx, H * 0.78, 46).stop(0, rgba(255, 252, 232, 0.22)).stop(1, rgba(255, 252, 232, 0)); c.fillGrad(lg); c.fillRect(lx - 46, H * 0.78 - 30, 92, 60)
            lx += 104
        }
        // 스크린도어(유리문) — 선로와 승강장 사이
        let doorTop = ceilB + (hy - ceilB) * 0.30, doorH = edgeY - doorTop, n = max(3, (W / 62).rounded()), pw = W / n
        c.fillStyle("rgba(170,205,235,.17)"); c.fillRect(0, doorTop, W, doorH)
        c.strokeStyle("#8d97a9"); c.lineWidth(1.4)
        for i in 0...Int(n) { let xx = Double(i) * pw; c.beginPath(); c.moveTo(xx, doorTop); c.lineTo(xx, edgeY); c.stroke() }
        c.beginPath(); c.moveTo(0, doorTop); c.lineTo(W, doorTop); c.stroke()
        c.fillStyle("rgba(255,255,255,.14)")
        for i in 0..<Int(n) { let xx = Double(i) * pw + 8; c.beginPath(); c.moveTo(xx, doorTop); c.lineTo(xx + 8, doorTop); c.lineTo(xx - 3, edgeY); c.lineTo(xx - 11, edgeY); c.closePath(); c.fill() }
        c.fillStyle("#3f4658")
        for i in 0..<Int(n) { let xx = Double(i) * pw + pw / 2; c.fillRect(xx - 1, doorTop, 2, doorH) }          // 두 짝 문이 만나는 틈
        // 기둥 + 역 이름 간판(엔진이 준 역 이름·노선)
        let nm = S.sta
        for px in [W * 0.16, W * 0.84] {
            let pg = c.linear(px - 5, 0, px + 5, 0).stop(0, css("#9aa5b8")).stop(0.5, css("#d8dee9")).stop(1, css("#8590a4")); c.fillGrad(pg)
            c.fillRect(px - 5, ceilB, 10, g.nearTop + 6 - ceilB)
            c.fillStyle("rgba(0,0,0,.18)"); c.fillRect(px - 5, g.nearTop + 3, 10, 3)
        }
        if !nm.isEmpty {
            c.font(9.5); let tw = c.measureText(nm), bw = max(58, tw + 34), bh = 17.0, bx = W * 0.5 - bw / 2, by = ceilB + 4
            c.fillStyle("#15213a"); rr(c, bx, by, bw, bh, 3.5); c.fill()
            c.fillStyle("#3a4a6c"); c.fillRect(bx + 2, by + bh - 3, bw - 4, 1.2)
            c.fillStyle(lineCol); c.beginPath(); c.arc(bx + 11, by + bh / 2, 6, 0, PI2); c.fill()
            let ln = S.res.line
            c.fillStyle("#fff"); c.font(ln.count > 1 ? 6.4 : 8.4); c.fillTextC(ln, bx + 11, by + bh / 2 - 0.2)
            c.fillStyle("#ffffff"); c.font(9.5); c.fillTextC(nm, bx + 11 + (bw - 11) / 2 + 3, by + bh / 2 - 0.1)
            c.fillStyle("#15213a"); c.fillRect(W * 0.5 - 1, 0, 2, by)       // 천장에서 늘어뜨린 간판 줄
        }
    }
}
