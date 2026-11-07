import Foundation

/// 장면의 '정해진 그림'들: 하늘·도시·가로수·땅 배경, 버스·자동차, 정류장·역 입구, 말풍선, 우산 — 안드로이드 SceneArt.java.
/// 웹 _CS 의 같은 이름 함수들을 그대로 옮긴 것이다(색·모양·비율 동일). 판단은 없다 — 받은 값대로 그리기만 한다.
enum SceneArt {
    // ── 엔진이 준 시간대·날씨 이름 → 그림 색표(그림 규칙일 뿐 판단이 아니다) ──
    struct Sky {
        let c: [ARGB]; let lum, sx, sy: Double; let moon: Bool
        init(_ a: String, _ b: String, _ c2: String, _ lum: Double, _ sx: Double, _ sy: Double, _ moon: Bool) {
            c = [css(a), css(b), css(c2)]; self.lum = lum; self.sx = sx; self.sy = sy; self.moon = moon
        }
    }
    static func sky(_ slot: String) -> Sky {
        switch slot {
        case "dawn": return Sky("#1d2354", "#6a4f93", "#f6a58f", 0.62, 0.2, 0.47, false)
        case "morning": return Sky("#74c4fb", "#b2e0ff", "#fff0cd", 1, 0.3, 0.2, false)
        case "afternoon": return Sky("#68b4ee", "#a8d9f7", "#ffe7b5", 0.98, 0.74, 0.2, false)
        case "evening": return Sky("#3a3a7c", "#d3687a", "#ffbd78", 0.7, 0.86, 0.43, false)
        case "night": return Sky("#060a22", "#131b4b", "#2a3478", 0.32, 0.74, 0.18, true)
        default: return Sky("#4aa3f2", "#8accfb", "#d9f1ff", 1.05, 0.5, 0.1, false)
        }
    }
    static func wxMix(_ wk: String) -> Double {
        switch wk { case "cloudy": return 0.22; case "overcast": return 0.6; case "rain": return 0.74; case "snow": return 0.5; case "fog": return 0.55; default: return 0 }
    }
    /// 그릴 때 쓰는 값
    final class Pal {
        var slot = "", wk = "", season = "", place = "street"; var c: [ARGB] = [0, 0, 0]
        var lum = 0.0, sunX = 0.0, sunY = 0.0
        var moon = false, night = false, lit = false, hidesSun = false, hot = false, cold = false, sun = false, bright = false
        var wind = 0, pdir = 1
    }
    static func paint(_ lk: SceneModel.Look) -> Pal {
        let S = sky(lk.slot); let wk = lk.wk.isEmpty ? "clear" : lk.wk
        let gray = mix(wk == "snow" ? "#d5dde8" : "#8d98a8", "#141a2c", clamp(1 - S.lum, 0, 0.9) * (wk == "snow" ? 0.75 : 1))
        let m = wxMix(wk)
        let p = Pal()
        p.slot = lk.slot; p.wk = wk; p.season = lk.season.isEmpty ? "autumn" : lk.season
        for i in 0..<3 { p.c[i] = mix(S.c[i], gray, m) }
        p.lum = S.lum; p.sunX = S.sx; p.sunY = S.sy; p.moon = S.moon; p.night = lk.night; p.lit = lk.lit; p.hidesSun = lk.hidesSun
        p.place = lk.place.isEmpty ? "street" : lk.place; p.hot = lk.hot; p.cold = lk.cold; p.sun = lk.sun; p.bright = lk.bright; p.wind = lk.wind; p.pdir = lk.pdir
        return p
    }

    /// ext = 카드 확장 인사 때 바닥을 더 이어 그려 둘 높이(디자인 좌표) — 바닥 그림은 H + ext 까지 그린다
    final class Geom { var W = 0.0, H = 0.0, hy = 0.0, roadY0 = 0.0, nearTop = 0.0, floor = 0.0, ext = 0.0 }
    static func geom(_ W: Double, _ H: Double) -> Geom {
        let tall = H > 230; let g = Geom()
        g.W = W; g.H = H; g.hy = (H * (tall ? 0.44 : 0.5)).rounded(); g.roadY0 = g.hy + 5; g.nearTop = (H * (tall ? 0.62 : 0.7)).rounded(); g.floor = H - 4; g.ext = H
        return g
    }

    final class Bg { var sky: SceneLayer!, far: SceneLayer!, mid: SceneLayer!, gnd: SceneLayer!; var tw = 0 }

    /// 하늘(그라데이션 + 해/달). 거리와 다른 장소가 같이 쓴다.
    static func drawSky(_ c: SceneCv, _ L: Pal, _ W: Double, _ H: Double, _ hy: Double) {
        let gr = c.linear(0, 0, 0, hy + 6).stop(0, L.c[0]).stop(0.62, L.c[1]).stop(1, L.c[2]); c.fillGrad(gr); c.fillRect(0, 0, W, H)
        let sx = L.sunX * W, sy = L.sunY * H, glow = L.hidesSun ? 0.12 : (L.wk == "cloudy" ? 0.5 : 1)
        if !L.moon {
            let rg = c.radial(sx, sy, 0, sx, sy, H * 0.5).stop(0, rgba(255, 236, 170, 0.55 * glow)).stop(1, rgba(255, 236, 170, 0))
            c.fillGrad(rg); c.fillRect(0, 0, W, hy + 8)
            if !L.hidesSun {
                c.fillStyle(L.slot == "evening" || L.slot == "dawn" ? "#ffd7a0" : "#fff2b3"); c.beginPath(); c.arc(sx, sy, 8.5, 0, PI2); c.fill()
                c.fillStyle("rgba(255,255,255,.55)"); c.beginPath(); c.arc(sx - 2, sy - 2, 4, 0, PI2); c.fill()
            }
        } else {
            let mg = c.radial(sx, sy, 0, sx, sy, 34).stop(0, rgba(210, 225, 255, 0.35 * glow)).stop(1, rgba(210, 225, 255, 0))
            c.fillGrad(mg); c.fillRect(sx - 40, sy - 40, 80, 80)
            if !L.hidesSun {
                c.fillStyle("#f4f1dc"); c.beginPath(); c.arc(sx, sy, 8, 0, PI2); c.fill()
                c.fillStyle("rgba(200,205,185,.55)"); c.beginPath(); c.arc(sx - 2.5, sy + 1.5, 2, 0, PI2); c.arc(sx + 2.5, sy - 2.5, 1.4, 0, PI2); c.fill()
            }
        }
    }

    /// 바닥 가로줄(타일 세로 간격)의 y 목록. 평소 카드 안(i=1..n)은 원근 식 그대로이고, 카드가 늘어나 보이는 아래쪽(H~H+ext)은 마지막 간격 그대로 같은 간격으로 이어 간다.
    static func gridRows(_ top: Double, _ span: Double, _ pw: Double, _ n: Int, _ H: Double, _ ext: Double) -> [Double] {
        var ys: [Double] = []
        if n >= 1 { for i in 1...n { ys.append(top + pow(Double(i) / Double(n), pw) * span) } }
        let last = ys[ys.count - 1], gap = n > 1 ? last - ys[ys.count - 2] : span / Double(n)
        var y = last + gap
        while y <= H + ext && gap > 2 { ys.append(y); y += gap }
        return ys
    }

    static func buildBG(_ root: SceneCv, _ L: Pal, _ g: Geom, _ dpr: Double, _ season: String, _ dark: Bool) -> Bg {
        let W = g.W, H = g.H, hy = g.hy; let tw = Int(ceil(W * 1.7))
        if L.place != "street" { return ScenePlaces.build(root, L, g, dpr, season, dark) }
        let rng = SU.Seeded(L.slot.count * 977 + L.wk.count * 131 + 7)
        let bg = Bg(); bg.tw = tw
        let twd = Double(tw)
        bg.sky = root.newLayer(W, H, dpr); bg.far = root.newLayer(twd, H, dpr); bg.mid = root.newLayer(twd, H, dpr); bg.gnd = root.newLayer(W, H + g.ext, dpr)
        var c: SceneCv; var gr: SceneGrad; var x: Double
        // 하늘
        c = bg.sky.cv; drawSky(c, L, W, H, hy)
        // 먼 도시: 건물 실루엣(+켜진 창)
        c = bg.far.cv
        let fcol = mix(L.c[2], css(L.night ? "#0b1030" : "#39435f"), L.night ? 0.6 : 0.3)
        var bl: [[Double]] = []
        x = -6
        while x < twd { let bw = rng.r(11, 25), bh = rng.r(hy * 0.2, hy * 0.6); bl.append([x, bw, bh]); x += bw + rng.r(0, 3) }
        for b in bl {
            for oi in 0..<2 {
                let off = oi == 0 ? 0.0 : -twd, bx = b[0] + off; if bx > twd || bx + b[1] < 0 { continue }
                c.fillStyle(fcol); c.fillRect(bx, hy + 4 - b[2], b[1], b[2])
                c.fillStyle(shade(fcol, 0.08)); c.fillRect(bx, hy + 4 - b[2], b[1], 2)
                var wy = hy + 4 - b[2] + 5
                while wy < hy - 2 {
                    var wx = bx + 3
                    while wx < bx + b[1] - 3 {
                        if L.lit && rng.r() < 0.33 { c.fillStyle(L.night ? "rgba(255,226,140,.85)" : "rgba(255,214,150,.6)"); c.fillRect(wx, wy, 2.2, 2.6) }
                        else if !L.lit && rng.r() < 0.5 { c.fillStyle("rgba(255,255,255,.12)"); c.fillRect(wx, wy, 2.2, 2.6) }
                        wx += 5
                    }
                    wy += 6
                }
                if L.wk == "snow" { c.fillStyle("rgba(255,255,255,.85)"); c.fillRect(bx, hy + 4 - b[2] - 1, b[1], 2.4) }
            }
        }
        // 가로수(계절 색)
        c = bg.mid.cv
        let leaf = ScenePlaces.leafSet(season)
        x = 6
        while x < twd {
            let th = rng.r(hy * 0.34, hy * 0.5), tx = x, tr = rng.r(9, 14); let cc = leaf[rng.pick(leaf.count)]
            for oi in 0..<2 {
                let off = oi == 0 ? 0.0 : -twd, px = tx + off; if px > twd + 20 || px < -20 { continue }
                c.fillStyle(mix("#5b4636", "#000000", L.night ? 0.5 : 0.1)); c.fillRect(px - 1.4, hy + 4 - th * 0.62, 2.8, th * 0.62)
                var col = mix(css(cc), css(L.night ? "#0a1020" : L.lit ? "#3a2a4a" : "#ffffff"), L.night ? 0.6 : L.lit ? 0.35 : 0.04)
                if L.wk == "overcast" || L.wk == "rain" { col = mix(col, "#7b8594", 0.3) }
                c.fillStyle(col); c.beginPath(); c.arc(px, hy + 4 - th * 0.72, tr, 0, PI2); c.arc(px - tr * 0.7, hy + 4 - th * 0.56, tr * 0.75, 0, PI2); c.arc(px + tr * 0.7, hy + 4 - th * 0.56, tr * 0.75, 0, PI2); c.fill()
                c.fillStyle("rgba(255,255,255,.12)"); c.beginPath(); c.arc(px - tr * 0.25, hy + 4 - th * 0.8, tr * 0.5, 0, PI2); c.fill()
                if L.wk == "snow" { c.fillStyle("rgba(255,255,255,.9)"); c.beginPath(); c.ellipse(px, hy + 4 - th * 0.72 - tr * 0.72, tr * 0.8, 2.6, 0, 0, PI2); c.fill() }
            }
            x += rng.r(17, 36)
        }
        // 땅: 건너편 인도 · 찻길 · 가까운 인도(원근선)
        c = bg.gnd.cv
        let wet = L.wk == "rain", snowy = L.wk == "snow"; let lum = L.lum
        var walk = mix(css(dark ? "#cbbfae" : "#e7dccb"), css("#14182a"), clamp(1 - lum, 0, 0.9) * 0.7), road = mix("#6c7078", "#0d1018", clamp(1 - lum, 0, 0.9) * 0.75)
        var far2 = mix(walk, "#8d8678", 0.25)
        if wet { walk = mix(walk, "#4b5668", 0.4); road = mix(road, "#2a313e", 0.35) }
        if snowy { walk = mix(walk, "#ffffff", 0.6); road = mix(road, "#cfd8e4", 0.35); far2 = mix(far2, "#ffffff", 0.5) }
        c.fillStyle(far2); c.fillRect(0, hy + 3, W, 3)
        c.fillStyle(road); c.fillRect(0, g.roadY0, W, g.nearTop - g.roadY0)
        c.fillStyle("rgba(255,255,255,.5)"); x = 4; while x < W { c.fillRect(x, (g.roadY0 + g.nearTop) / 2 - 0.5, 12, 1.6); x += 24 }
        gr = c.linear(0, g.nearTop, 0, H).stop(0, shade(walk, 0.06)).stop(1, shade(walk, -0.1)); c.fillGrad(gr); c.fillRect(0, g.nearTop, W, H + g.ext - g.nearTop)
        c.fillStyle(shade(walk, 0.2)); c.fillRect(0, g.nearTop - 1, W, 2.2); c.fillStyle("rgba(0,0,0,.18)"); c.fillRect(0, g.nearTop + 1.2, W, 1.4)
        c.strokeStyle("rgba(0,0,0,.09)"); c.lineWidth(1)
        for yy in gridRows(g.nearTop, H - g.nearTop, 1.5, 5, H, g.ext) { c.beginPath(); c.moveTo(0, yy); c.lineTo(W, yy); c.stroke() }
        for i in -8...8 { let fi = Double(i); c.beginPath(); c.moveTo(W / 2 + fi * 16, g.nearTop); c.lineTo(W / 2 + fi * (16 + 28 * (H + g.ext - g.nearTop) / (H - g.nearTop)), H + g.ext); c.stroke() }
        if wet {
            for _ in 0..<5 {
                let pxx = rng.r(0.08, 0.92) * W, pyy = rng.r(g.nearTop + 10, H - 6), prx = rng.r(9, 18)
                c.fillStyle("rgba(70,90,120,.55)"); c.beginPath(); c.ellipse(pxx, pyy, prx, prx * 0.26, 0, 0, PI2); c.fill()
                c.fillStyle("rgba(210,230,255,.35)"); c.beginPath(); c.ellipse(pxx - prx * 0.2, pyy - 1, prx * 0.5, prx * 0.08, 0, 0, PI2); c.fill()
            }
        }
        if snowy {
            for _ in 0..<9 { let snx = rng.r(0, 1) * W, sny = rng.r(g.nearTop + 3, H - 3); c.fillStyle("rgba(255,255,255,.85)"); let e1 = rng.r(8, 22), e2 = rng.r(2, 4); c.beginPath(); c.ellipse(snx, sny, e1, e2, 0, 0, PI2); c.fill() }
            c.fillStyle("rgba(255,255,255,.9)"); c.fillRect(0, g.nearTop - 2, W, 2.4)
        }
        // 가로등(저녁·밤·새벽엔 불이 켜진다)
        for fx in [0.07, 0.93] {
            let lx = fx * W, ly = g.nearTop + 2, hx2 = lx + (fx < 0.5 ? 9 : -9)
            c.fillStyle("#39404f"); c.fillRect(lx - 1.2, ly - 38, 2.4, 38); c.fillRect(min(lx, hx2) - 1.2, ly - 38, 10.4, 2.2)
            if L.lit { let lg = c.radial(hx2, ly - 35, 0, hx2, ly - 35, 38).stop(0, rgba(255, 224, 140, 0.75)).stop(1, rgba(255, 224, 140, 0)); c.fillGrad(lg); c.fillRect(hx2 - 40, ly - 76, 80, 80) }
            c.fillStyle(L.lit ? "#fff0b0" : "#9aa3b2"); c.beginPath(); c.ellipse(hx2, ly - 36, 4, 2.4, 0, 0, PI2); c.fill()
        }
        return bg
    }

    // ── 버스·자동차 그림 ──
    static func drawWheel(_ c: SceneCv, _ x: Double, _ y: Double, _ r: Double, _ rot: Double) {
        c.fillStyle("#1a1d24"); c.beginPath(); c.arc(x, y, r, 0, PI2); c.fill()
        c.fillStyle("#9aa1ad"); c.beginPath(); c.arc(x, y, r * 0.5, 0, PI2); c.fill()
        c.strokeStyle("#4b5260"); c.lineWidth(max(0.8, r * 0.12))
        for i in 0..<4 { let a = rot + Double(i) * PI / 2; c.beginPath(); c.moveTo(x, y); c.lineTo(x + cos(a) * r * 0.5, y + sin(a) * r * 0.5); c.stroke() }
        c.fillStyle("#d8dde6"); c.beginPath(); c.arc(x, y, r * 0.15, 0, PI2); c.fill()
    }
    struct VehOpt { var color = css("#2f6fd6"); var door = 0.0, door2 = 0.0, rot = 0.0; var no = ""; var dir = 1; var night = false }

    static func drawBus(_ c: SceneCv, _ cx: Double, _ gy: Double, _ L: Double, _ o: VehOpt) {
        let h = L * 0.4, wr = L * 0.066, y0 = gy - h - wr * 0.55, x0 = cx - L / 2; let col = o.color
        c.save(); if o.dir < 0 { c.translate(cx, 0); c.scale(-1, 1); c.translate(-cx, 0) }
        c.fillStyle("rgba(0,0,0,.26)"); c.beginPath(); c.ellipse(cx, gy + 1, L * 0.5, L * 0.04, 0, 0, PI2); c.fill()
        let g = c.linear(0, y0, 0, y0 + h).stop(0, shade(col, 0.28)).stop(0.45, col).stop(1, shade(col, -0.3))
        c.fillGrad(g); rr(c, x0, y0, L, h, L * 0.055); c.fill()
        c.fillStyle(shade(col, 0.38)); rr(c, x0 + L * 0.22, y0 - L * 0.028, L * 0.26, L * 0.035, L * 0.012); c.fill()
        c.fillStyle("rgba(255,255,255,.88)"); c.fillRect(x0, y0 + h * 0.66, L, h * 0.07)
        let wy = y0 + h * 0.13, wh = h * 0.42
        let glassTop = css(o.night ? "#314a73" : "#cfeaff"), glassBot = css(o.night ? "#1b2845" : "#78acdb")
        let wg = c.linear(0, wy, 0, wy + wh).stop(0, glassTop).stop(1, glassBot)
        c.fillGrad(wg); rr(c, x0 + L * 0.05, wy, L * 0.8, wh, L * 0.02); c.fill()
        c.fillGrad(wg); c.beginPath(); c.moveTo(x0 + L * 0.88, wy); c.lineTo(x0 + L * 0.975, wy + wh * 0.12); c.lineTo(x0 + L * 0.985, wy + wh); c.lineTo(x0 + L * 0.88, wy + wh); c.closePath(); c.fill()
        c.fillStyle(shade(col, -0.18)); for i in 1..<5 { c.fillRect(x0 + L * (0.05 + Double(i) * 0.16) - 1, wy, 2, wh) }
        c.fillStyle("rgba(255,255,255,.3)"); c.beginPath(); c.moveTo(x0 + L * 0.12, wy); c.lineTo(x0 + L * 0.2, wy); c.lineTo(x0 + L * 0.12, wy + wh); c.lineTo(x0 + L * 0.06, wy + wh); c.closePath(); c.fill()
        let ds: [[Double]] = [[0.69, 0.12], [0.3, 0.12]]
        for k in 0..<2 {
            let dx = x0 + L * ds[k][0], dw = L * ds[k][1], dy = y0 + h * 0.13, dh = h * 0.83 - wr * 0.2, op = k == 0 ? o.door : o.door2
            c.fillStyle(shade(col, -0.35)); c.fillRect(dx - 1, dy - 1, dw + 2, dh + 1)
            if op > 0 {
                c.fillStyle(o.night ? "#ffe9b0" : "#3c3f4c"); c.fillRect(dx, dy, dw, dh); c.fillStyle("rgba(255,240,200,.35)"); c.fillRect(dx, dy, dw, dh * 0.4)
                let pw = dw * 0.5 * (1 - op); c.fillGrad(wg); c.fillRect(dx, dy, pw, dh * 0.62); c.fillRect(dx + dw - pw, dy, pw, dh * 0.62)
            } else {
                c.fillGrad(wg); c.fillRect(dx, dy, dw * 0.47, dh * 0.62); c.fillRect(dx + dw * 0.53, dy, dw * 0.47, dh * 0.62)
                c.fillStyle(shade(col, -0.05)); c.fillRect(dx, dy + dh * 0.62, dw, dh * 0.38)
            }
        }
        c.fillStyle("#10131a"); rr(c, x0 + L * 0.66, y0 + h * 0.02, L * 0.22, h * 0.1, 2); c.fill()
        c.fillStyle("#ffb347"); c.font(max(5, h * 0.09))
        if o.dir < 0 { c.save(); c.translate(x0 + L * 0.77, y0 + h * 0.07); c.scale(-1, 1); c.fillTextC(o.no, 0, 0); c.restore() } else { c.fillTextC(o.no, x0 + L * 0.77, y0 + h * 0.07) }
        for f in [0.2, 0.74] { let wx = x0 + L * f; c.fillStyle("#12151c"); c.beginPath(); c.arc(wx, gy - wr, wr * 1.28, PI, 0); c.fill(); drawWheel(c, wx, gy - wr, wr, o.rot) }
        c.fillStyle("#fff2b8"); c.beginPath(); c.ellipse(x0 + L - 2, y0 + h * 0.78, 2.6, 3.4, 0, 0, PI2); c.fill()
        c.fillStyle("#e33"); c.fillRect(x0 - 1, y0 + h * 0.72, 3, 5)
        if o.night { let hg = c.radial(x0 + L, y0 + h * 0.78, 0, x0 + L, y0 + h * 0.78, L * 0.4).stop(0, rgba(255, 240, 170, 0.5)).stop(1, rgba(255, 240, 170, 0)); c.fillGrad(hg); c.fillRect(x0 + L - 4, y0 + h * 0.4, L * 0.5, h * 0.8) }
        c.restore()
    }
    static func drawCar(_ c: SceneCv, _ cx: Double, _ gy: Double, _ L: Double, _ o: VehOpt) {
        let h = L * 0.42, wr = L * 0.12, y0 = gy - h - wr * 0.3; let col = o.color
        c.save(); if o.dir < 0 { c.translate(cx, 0); c.scale(-1, 1); c.translate(-cx, 0) }
        c.fillStyle("rgba(0,0,0,.24)"); c.beginPath(); c.ellipse(cx, gy + 1, L * 0.5, L * 0.07, 0, 0, PI2); c.fill()
        let x0 = cx - L / 2; let g = c.linear(0, y0, 0, y0 + h).stop(0, shade(col, 0.25)).stop(1, shade(col, -0.28))
        c.fillGrad(g); rr(c, x0, y0 + h * 0.38, L, h * 0.5, h * 0.22); c.fill()
        c.beginPath(); c.moveTo(x0 + L * 0.2, y0 + h * 0.42); c.quadTo(x0 + L * 0.27, y0, x0 + L * 0.42, y0); c.lineTo(x0 + L * 0.64, y0); c.quadTo(x0 + L * 0.78, y0 + h * 0.05, x0 + L * 0.84, y0 + h * 0.42); c.closePath(); c.fill()
        c.fillStyle(o.night ? "#27375a" : "#bfe3ff"); c.beginPath(); c.moveTo(x0 + L * 0.26, y0 + h * 0.4); c.quadTo(x0 + L * 0.31, y0 + h * 0.1, x0 + L * 0.43, y0 + h * 0.1); c.lineTo(x0 + L * 0.62, y0 + h * 0.1); c.quadTo(x0 + L * 0.73, y0 + h * 0.14, x0 + L * 0.78, y0 + h * 0.4); c.closePath(); c.fill()
        c.fillStyle("rgba(0,0,0,.25)"); c.fillRect(x0 + L * 0.5, y0 + h * 0.1, 1.4, h * 0.3)
        for f in [0.24, 0.76] { drawWheel(c, x0 + L * f, gy - wr, wr, o.rot) }
        c.fillStyle("#fff3b8"); c.beginPath(); c.ellipse(x0 + L - 1.5, y0 + h * 0.55, 1.8, 2.2, 0, 0, PI2); c.fill()
        c.restore()
    }

    // ── 정류장 · 지하철 역 입구 ──
    static func drawStop(_ c: SceneCv, _ g: Geom, _ x: Double, _ Lk: Pal) {
        let gy = g.nearTop + 6; let lit = Lk.lit
        c.fillStyle("#4a5160"); c.fillRect(x - 1.3, gy - 38, 2.6, 38)
        if lit { let sg = c.radial(x, gy - 40, 0, x, gy - 40, 22).stop(0, rgba(150, 200, 255, 0.55)).stop(1, rgba(150, 200, 255, 0)); c.fillGrad(sg); c.fillRect(x - 24, gy - 64, 48, 48) }
        c.fillStyle("#2f6fd6"); c.beginPath(); c.arc(x, gy - 42, 8.5, 0, PI2); c.fill(); c.strokeStyle("#fff"); c.lineWidth(1.2); c.stroke()
        c.fillStyle("#fff"); rr(c, x - 4.8, gy - 46, 9.6, 7.5, 1.6); c.fill(); c.fillStyle("#2f6fd6"); c.fillRect(x - 3.6, gy - 44.6, 7.2, 2.8)
        c.fillStyle("#fff"); c.beginPath(); c.arc(x - 2.7, gy - 38.5, 1.1, 0, PI2); c.arc(x + 2.7, gy - 38.5, 1.1, 0, PI2); c.fill()
        let sx = x + 24, sw = 58.0, top = gy - 34
        c.fillStyle(rgba(160, 200, 230, lit ? 0.2 : 0.26)); c.fillRect(sx, top + 4, sw, 34)
        c.strokeStyle("rgba(255,255,255,.35)"); c.lineWidth(1); c.beginPath(); c.moveTo(sx + 6, top + 6); c.lineTo(sx + 16, top + 6); c.moveTo(sx + 30, top + 6); c.lineTo(sx + 36, top + 6); c.stroke()
        c.fillStyle("#4a5160"); c.fillRect(sx - 1, top + 2, 2.4, 38); c.fillRect(sx + sw - 1.4, top + 2, 2.4, 38)
        let rg = c.linear(0, top - 2, 0, top + 5).stop(0, css("#6b7385")).stop(1, css("#3c4352")); c.fillGrad(rg); rr(c, sx - 5, top - 2, sw + 10, 6, 2.6); c.fill()
        if Lk.wk == "snow" { c.fillStyle("rgba(255,255,255,.95)"); rr(c, sx - 5, top - 4, sw + 10, 3.4, 1.6); c.fill() }
        c.fillStyle("#8a6a49"); for i in 0..<3 { c.fillRect(sx + 9, top + 24 + Double(i) * 2.2, sw - 18, 1.5) }
        c.fillStyle("#5a4630"); c.fillRect(sx + 11, top + 31, 2.4, 6); c.fillRect(sx + sw - 14, top + 31, 2.4, 6)
        if lit { c.fillStyle("rgba(255,238,170,.85)"); c.fillRect(sx + sw - 13, top + 9, 8, 12) }
    }
    static func lineColor(_ line: String?) -> ARGB {
        switch line ?? "" {
        case "1": return css("#0052a4"); case "2": return css("#00a84d"); case "3": return css("#ef7c1c"); case "4": return css("#00a5de")
        case "5": return css("#996cac"); case "6": return css("#cd7c2f"); case "7": return css("#747f00"); case "8": return css("#e6186c"); case "9": return css("#bdb092")
        default: return css("#4a6fa5")
        }
    }
    static func drawEntrance(_ c: SceneCv, _ g: Geom, _ x: Double, _ Lk: Pal, _ line: String?) {
        let gy = g.nearTop + 7; let lit = Lk.lit; let col = lineColor(line)
        c.fillStyle("#2b303c"); rr(c, x - 21, gy - 27, 42, 28, 5); c.fill()
        c.fillStyle("#3d4352"); for i in 0..<4 { let fi = Double(i); c.fillRect(x - 17 + fi * 3, gy - 22 + fi * 5, 34 - fi * 6, 2.4) }
        if lit { let eg = c.radial(x, gy - 10, 0, x, gy - 10, 28).stop(0, rgba(255, 230, 160, 0.5)).stop(1, rgba(255, 230, 160, 0)); c.fillGrad(eg); c.fillRect(x - 30, gy - 38, 60, 44) }
        let rg = c.linear(0, gy - 38, 0, gy - 26).stop(0, css("#8a93a6")).stop(1, css("#4a5160")); c.fillGrad(rg)
        c.beginPath(); c.moveTo(x - 27, gy - 26); c.lineTo(x - 19, gy - 37); c.lineTo(x + 19, gy - 37); c.lineTo(x + 27, gy - 26); c.closePath(); c.fill()
        if Lk.wk == "snow" { c.fillStyle("rgba(255,255,255,.95)"); c.beginPath(); c.moveTo(x - 20, gy - 36); c.lineTo(x - 17, gy - 40); c.lineTo(x + 17, gy - 40); c.lineTo(x + 20, gy - 36); c.closePath(); c.fill() }
        c.fillStyle("#4a5160"); c.fillRect(x - 25, gy - 27, 2.6, 28); c.fillRect(x + 22.4, gy - 27, 2.6, 28)
        let sx = x + 36; c.fillStyle("#4a5160"); c.fillRect(sx - 1.2, gy - 34, 2.4, 34)
        if lit { let sg = c.radial(sx, gy - 38, 0, sx, gy - 38, 20).stop(0, rgba(255, 255, 255, 0.5)).stop(1, rgba(255, 255, 255, 0)); c.fillGrad(sg); c.fillRect(sx - 22, gy - 60, 44, 44) }
        c.fillStyle(col); c.beginPath(); c.arc(sx, gy - 39, 8.6, 0, PI2); c.fill(); c.strokeStyle("#fff"); c.lineWidth(1.3); c.stroke()
        let ln = (line ?? "").isEmpty ? "역" : line!
        c.fillStyle("#fff"); c.font(ln.count > 1 ? 7 : 10); c.fillTextC(ln, sx, gy - 38.6)
    }

    static func drawBubble(_ c: SceneCv, _ x: Double, _ y: Double, _ text: String) {
        c.font(10); let w = c.measureText(text) + 10
        c.fillStyle("rgba(255,255,255,.95)"); rr(c, x - w / 2, y - 14, w, 15, 6); c.fill()
        c.beginPath(); c.moveTo(x - 3, y + 0.5); c.lineTo(x, y + 5); c.lineTo(x + 3, y + 0.5); c.fill()
        c.fillStyle("#2a3142"); c.fillTextC(text, x, y - 6)
    }
    static func drawUmbrella(_ c: SceneCv, _ x: Double, _ y: Double, _ s: Double, _ id: String) {
        let col = id == "chaeng" ? "#ffb74d" : id == "lovel" ? "#ff7aa5" : id == "dolsom" ? "#5aa9ff" : id == "ppopu" ? "#7bd88f" : id == "sul" ? "#ffd54f" : id == "juksun" ? "#66bb6a" : id == "bbosong" ? "#f48fb1" : "#b388ff"
        let r = 17 * s
        c.save(); c.translate(x, y - 6 * s)
        c.strokeStyle("#555c6b"); c.lineWidth(1.4); c.beginPath(); c.moveTo(0, -1); c.lineTo(0, 15 * s); c.stroke()
        c.fillStyle(col); c.beginPath(); c.moveTo(-r, 0); c.quadTo(-r * 0.9, -r * 0.95, 0, -r * 1.02); c.quadTo(r * 0.9, -r * 0.95, r, 0); c.quadTo(r * 0.5, -3, 0, 0); c.quadTo(-r * 0.5, -3, -r, 0); c.closePath(); c.fill()
        c.strokeStyle("rgba(255,255,255,.55)"); c.lineWidth(0.9); c.beginPath(); c.moveTo(0, -r); c.lineTo(0, -1); c.moveTo(-r * 0.55, -r * 0.72); c.lineTo(-r * 0.3, -1); c.moveTo(r * 0.55, -r * 0.72); c.lineTo(r * 0.3, -1); c.stroke()
        c.restore()
    }
    static func cloud(_ c: SceneCv, _ x: Double, _ y: Double, _ r: Double, _ col: ARGB) {
        c.fillStyle(col); c.beginPath(); c.ellipse(x, y, r * 1.5, r * 0.6, 0, 0, PI2); c.ellipse(x - r * 0.75, y + r * 0.12, r * 0.85, r * 0.5, 0, 0, PI2); c.ellipse(x + r * 0.8, y + r * 0.14, r * 0.9, r * 0.5, 0, 0, PI2); c.ellipse(x - r * 0.1, y - r * 0.32, r * 0.75, r * 0.55, 0, 0, PI2); c.fill()
    }
    static func heartP(_ c: SceneCv, _ x: Double, _ y: Double, _ s: Double) {
        c.beginPath(); c.moveTo(x, y + s * 0.9); c.bezierTo(x - s * 1.7, y - s * 0.1, x - s * 0.8, y - s * 1.25, x, y - s * 0.45); c.bezierTo(x + s * 0.8, y - s * 1.25, x + s * 1.7, y - s * 0.1, x, y + s * 0.9); c.fill()
    }
    static func star4(_ c: SceneCv, _ x: Double, _ y: Double, _ r: Double, _ rot: Double) {
        c.beginPath()
        for i in 0..<8 { let an = rot + Double(i) * PI / 4, rd = i % 2 != 0 ? r * 0.4 : r; if i != 0 { c.lineTo(x + cos(an) * rd, y + sin(an) * rd) } else { c.moveTo(x + cos(an) * rd, y + sin(an) * rd) } }
        c.closePath(); c.fill()
    }

    /// ✨ 모양 반짝이: 오목한 네 갈래 별(곡선) + 안쪽 흰 심지 + 가는 빛무리. 모든 모양·크기·투명도는 호출하는 쪽(장면 계산)이 정한다.
    static func sparkle(_ c: SceneCv, _ x: Double, _ y: Double, _ r: Double, _ rot: Double, _ al: Double) {
        if r <= 0.05 || al <= 0 { return }
        let k = 0.16 * r
        c.save(); c.translate(x, y); c.rotate(rot)
        c.globalAlpha(min(1, al * 0.55)); c.fillGrad(c.radial(0, 0, 0, 0, 0, r * 1.25).stop(0, 0xCCFFF2B0).stop(0.45, 0x66FFD54A).stop(1, 0x00FFC83C)); c.beginPath(); c.arc(0, 0, r * 1.25, 0, 2 * PI); c.fill()
        c.globalAlpha(min(1, al))
        c.fillGrad(c.linear(-r, -r, r, r).stop(0, 0xFFFFF0A0).stop(0.5, 0xFFFFD23C).stop(1, 0xFFFFB300))
        c.beginPath(); c.moveTo(0, -r)
        c.quadTo(k, -k, r, 0); c.quadTo(k, k, 0, r); c.quadTo(-k, k, -r, 0); c.quadTo(-k, -k, 0, -r); c.closePath(); c.fill()
        c.globalAlpha(min(1, al * 0.95)); c.fillStyle(0xFFFFFFFF); let q = r * 0.5, kk = 0.07 * r
        c.beginPath(); c.moveTo(0, -q); c.quadTo(kk, -kk, q, 0); c.quadTo(kk, kk, 0, q); c.quadTo(-kk, kk, -q, 0); c.quadTo(-kk, -kk, 0, -q); c.closePath(); c.fill()
        c.globalAlpha(min(1, al * 0.7)); c.fillStyle(0xFFFFFFFF); c.beginPath(); c.arc(0, 0, r * 0.13, 0, 2 * PI); c.fill()
        c.restore(); c.globalAlpha(1)
    }
    /// 부드러운 노란 빛무리(몸을 감싸는 후광).
    static func halo(_ c: SceneCv, _ x: Double, _ y: Double, _ rx: Double, _ ry: Double, _ al: Double) {
        if al <= 0 { return }
        c.save(); c.translate(x, y); c.scale(1, ry / rx); c.globalAlpha(min(1, al))
        c.fillGrad(c.radial(0, 0, 0, 0, 0, rx).stop(0, 0x66FFF4C0).stop(0.55, 0x55FFD95A).stop(1, 0x00FFC83C)); c.beginPath(); c.arc(0, 0, rx, 0, 2 * PI); c.fill()
        c.restore(); c.globalAlpha(1)
    }
}
