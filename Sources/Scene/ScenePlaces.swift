import Foundation

/// 거리 말고 다른 장소의 배경 그림(공원 · 강변 · 학교 앞 · 시장 골목 · 바닷가 · 산길) — 안드로이드 ScenePlaces.java.
/// ★ 어느 장소를 보일지는 엔진(/scene 의 look.place)이 정한다. 여기는 받은 이름대로 하늘 · 먼 풍경 · 가까운 풍경 · 바닥을 그릴 뿐이다.
enum ScenePlaces {
    // ── 시간대 · 날씨를 색에 입히는 도구 ──
    static func dim(_ L: SceneArt.Pal, _ col: ARGB) -> ARGB {
        var c = mix(col, css("#0a1020"), clamp(1 - L.lum, 0, 0.9) * 0.72)
        if L.wk == "overcast" || L.wk == "rain" || L.wk == "fog" { c = mix(c, css("#8d98a8"), 0.2) }
        return c
    }
    static func dim(_ L: SceneArt.Pal, _ col: String) -> ARGB { dim(L, css(col)) }
    /// 바닥: 비 오면 젖어 어둡게, 눈 오면 하얗게
    static func gnd(_ L: SceneArt.Pal, _ col: ARGB) -> ARGB {
        var c = dim(L, col)
        if L.wk == "rain" { c = mix(c, css("#2a313e"), 0.3) }
        if L.wk == "snow" { c = mix(c, css("#ffffff"), 0.62) }
        return c
    }
    static func gnd(_ L: SceneArt.Pal, _ col: String) -> ARGB { gnd(L, css(col)) }
    static func snowy(_ L: SceneArt.Pal) -> Bool { L.wk == "snow" }
    static func wet(_ L: SceneArt.Pal) -> Bool { L.wk == "rain" }
    static func leafSet(_ season: String) -> [String] {
        season == "autumn" ? ["#e2893a", "#d9a23b", "#c9602f"] : season == "spring" ? ["#f2b6cc", "#a9d98b", "#f7c7d8"]
            : season == "summer" ? ["#4fa866", "#3f9a5a", "#62b878"] : ["#7a6a5a", "#8a7868", "#6b5d50"]
    }

    // ── 나무 · 언덕 도구 ──
    static func roundTree(_ c: SceneCv, _ L: SceneArt.Pal, _ x: Double, _ base: Double, _ h: Double, _ r: Double, _ crown: ARGB, _ snow: Bool) {
        c.fillStyle(dim(L, "#5b4636")); c.fillRect(x - 1.5, base - h * 0.62, 3, h * 0.62)
        c.fillStyle(crown); c.beginPath(); c.arc(x, base - h * 0.72, r, 0, PI2); c.arc(x - r * 0.7, base - h * 0.56, r * 0.75, 0, PI2); c.arc(x + r * 0.7, base - h * 0.56, r * 0.75, 0, PI2); c.fill()
        c.fillStyle("rgba(255,255,255,.12)"); c.beginPath(); c.arc(x - r * 0.25, base - h * 0.8, r * 0.5, 0, PI2); c.fill()
        if snow { c.fillStyle("rgba(255,255,255,.9)"); c.beginPath(); c.ellipse(x, base - h * 0.72 - r * 0.72, r * 0.8, 2.6, 0, 0, PI2); c.fill() }
    }
    static func pine(_ c: SceneCv, _ L: SceneArt.Pal, _ x: Double, _ base: Double, _ h: Double, _ w: Double, _ col: ARGB, _ snow: Bool) {
        c.fillStyle(dim(L, "#4a382a")); c.fillRect(x - 1.3, base - h * 0.22, 2.6, h * 0.22)
        for i in 0..<4 {
            let fi = Double(i), ty = base - h * (0.16 + fi * 0.22), tw2 = w * (1 - fi * 0.2)
            c.fillStyle(shade(col, fi * 0.04)); c.beginPath(); c.moveTo(x - tw2, ty); c.lineTo(x, ty - h * 0.34); c.lineTo(x + tw2, ty); c.closePath(); c.fill()
            if snow { c.fillStyle("rgba(255,255,255,.88)"); c.beginPath(); c.moveTo(x - tw2 * 0.62, ty - h * 0.12); c.lineTo(x, ty - h * 0.34); c.lineTo(x + tw2 * 0.62, ty - h * 0.12); c.closePath(); c.fill() }
        }
    }
    static func hill(_ c: SceneCv, _ tw: Double, _ base: Double, _ amp: Double, _ f: Double, _ ph: Double, _ col: ARGB) {
        c.fillStyle(col); c.beginPath(); c.moveTo(0, base)
        var x = 0.0
        while x <= tw + 4 { c.lineTo(x, base - amp * (0.55 + 0.45 * sin(x * f + ph)) - amp * 0.3 * sin(x * f * 2.3 + ph * 1.7)); x += 4 }
        c.lineTo(tw, base); c.closePath(); c.fill()
    }
    static func glowSpot(_ c: SceneCv, _ x: Double, _ y: Double, _ r: Double, _ a: Int, _ b: Int, _ cc: Int, _ al: Double) {
        let g = c.radial(x, y, 0, x, y, r).stop(0, rgba(a, b, cc, al)).stop(1, rgba(a, b, cc, 0)); c.fillGrad(g); c.fillRect(x - r, y - r, r * 2, r * 2)
    }
    static func lamp(_ c: SceneCv, _ L: SceneArt.Pal, _ g: SceneArt.Geom, _ lx: Double, _ ly: Double, _ dir: Double) {
        let hx = lx + dir * 9
        c.fillStyle(dim(L, "#39404f")); c.fillRect(lx - 1.2, ly - 38, 2.4, 38); c.fillRect(min(lx, hx) - 1.2, ly - 38, 10.4, 2.2)
        if L.lit { glowSpot(c, hx, ly - 35, 38, 255, 224, 140, 0.75) }
        c.fillStyle(L.lit ? "#fff0b0" : "#9aa3b2"); c.beginPath(); c.ellipse(hx, ly - 36, 4, 2.4, 0, 0, PI2); c.fill()
    }

    static func build(_ root: SceneCv, _ L: SceneArt.Pal, _ g: SceneArt.Geom, _ dpr: Double, _ season: String, _ dark: Bool) -> SceneArt.Bg {
        let W = g.W, H = g.H, hy = g.hy; let tw = Int(ceil(W * 1.7))
        let bg = SceneArt.Bg(); bg.tw = tw
        let twd = Double(tw)
        bg.sky = root.newLayer(W, H, dpr); bg.far = root.newLayer(twd, H, dpr); bg.mid = root.newLayer(twd, H, dpr); bg.gnd = root.newLayer(W, H + g.ext, dpr)
        SceneArt.drawSky(bg.sky.cv, L, W, H, hy)
        let rng = SU.Seeded(javaHash(L.place) &* 31 &+ L.slot.count * 977 &+ L.wk.count * 131 &+ 7)
        switch L.place {
        case "park": park(bg, L, g, twd, season, rng)
        case "river": river(bg, L, g, twd, season, rng)
        case "school": school(bg, L, g, twd, season, rng)
        case "market": market(bg, L, g, twd, season, rng)
        case "beach": beach(bg, L, g, twd, season, rng)
        case "trail": trail(bg, L, g, twd, season, rng)
        default: park(bg, L, g, twd, season, rng)
        }
        return bg
    }

    // ═══ 공원 ═══
    static func park(_ bg: SceneArt.Bg, _ L: SceneArt.Pal, _ g: SceneArt.Geom, _ tw: Double, _ season: String, _ rng: SU.Seeded) {
        let W = g.W, H = g.H, hy = g.hy; var c: SceneCv
        let snow = snowy(L)
        // 먼 풍경: 언덕 두 겹 + 아파트 몇 동
        c = bg.far.cv
        let hz = dim(L, mix(L.c[2], css("#6fae7a"), 0.55))
        hill(c, tw, hy + 6, hy * 0.34, 0.021, 1.3, snow ? mix(hz, css("#ffffff"), 0.6) : mix(hz, css("#5b8fa0"), 0.35))
        hill(c, tw, hy + 6, hy * 0.22, 0.034, 4.1, snow ? mix(hz, css("#ffffff"), 0.7) : hz)
        var x = 20.0
        while x < tw {
            let bw = rng.r(14, 22), bh = rng.r(hy * 0.22, hy * 0.4)
            c.fillStyle(dim(L, mix(L.c[2], css("#9aa6b8"), 0.55))); c.fillRect(x, hy + 5 - bh, bw, bh)
            var wy = hy + 8 - bh
            while wy < hy {
                var wx = x + 2.5
                while wx < x + bw - 2 { if L.lit && rng.r() < 0.4 { c.fillStyle("rgba(255,226,140,.8)"); c.fillRect(wx, wy, 1.8, 2.2) }; wx += 4.5 }
                wy += 5
            }
            x += rng.r(46, 80)
        }
        // 가까운 풍경: 나무 · 벤치 · 꽃울타리
        c = bg.mid.cv
        let leaf = leafSet(season)
        x = 8
        while x < tw {
            let th = rng.r(hy * 0.38, hy * 0.62), r2 = rng.r(10, 16); let cc = leaf[rng.pick(leaf.count)]
            let col = dim(L, mix(css(cc), css(L.lit ? "#3a2a4a" : "#ffffff"), L.night ? 0 : L.lit ? 0.2 : 0.03))
            if rng.r() < 0.28 && season != "winter" { pine(c, L, x, hy + 6, th * 1.1, r2 * 0.8, dim(L, "#2f6f4a"), snow) }
            else { roundTree(c, L, x, hy + 6, th, r2, col, snow) }
            x += rng.r(26, 52)
        }
        // 울타리 낮은 덤불 줄(꽃)
        c.fillStyle(dim(L, season == "winter" ? "#6b7a63" : "#4f9a5c")); c.beginPath(); x = 0; while x < tw { c.ellipse(x + 3, hy + 6, 5, 3.4, 0, 0, PI2); x += 6 }; c.fill()
        if season == "spring" || season == "summer" {
            x = 2
            while x < tw {
                c.fillStyle(season == "spring" ? (rng.r() < 0.5 ? "#f7a8c4" : "#fff0a0") : (rng.r() < 0.5 ? "#ff8aa0" : "#ffe27a")); c.beginPath(); c.arc(x, hy + 4.5 + rng.r(-1, 1.5), 1.3, 0, PI2); c.fill()
                x += rng.r(5, 11)
            }
        }
        // 땅: 잔디 + 굽은 길 + 가로등
        c = bg.gnd.cv
        let grass = gnd(L, season == "winter" ? "#9aa58f" : season == "autumn" ? "#9db36a" : "#6fbf6a")
        let gr = c.linear(0, hy + 3, 0, H).stop(0, shade(grass, 0.08)).stop(1, shade(grass, -0.12)); c.fillGrad(gr); c.fillRect(0, hy + 3, W, H + g.ext - hy - 3)
        c.fillStyle("rgba(255,255,255,.06)")
        for i in 0..<9 { let y0 = hy + 6 + pow(Double(i) / 9.0, 1.4) * (H - hy), y1 = hy + 6 + pow((Double(i) + 0.5) / 9.0, 1.4) * (H - hy); c.fillRect(0, y0, W, max(1, y1 - y0)) }
        let path = gnd(L, "#e5d3b0")
        c.fillStyle(path); c.beginPath(); c.moveTo(W * 0.44, hy + 8); c.bezierTo(W * 0.5, g.nearTop * 0.9, W * 0.02, g.nearTop + 4, -W * 0.06, H); c.lineTo(W * 0.72, H); c.bezierTo(W * 0.6, g.nearTop + 6, W * 0.56, hy + 24, W * 0.54, hy + 8); c.closePath(); c.fill()
        do { let sl = (W * 0.72 - W * 0.6) / max(1, H - g.nearTop - 6), sr = (-W * 0.06 - W * 0.02) / max(1, H - g.nearTop - 4); c.beginPath(); c.moveTo(-W * 0.06, H - 0.5); c.lineTo(W * 0.72, H - 0.5); c.lineTo(W * 0.72 + sl * g.ext, H + g.ext); c.lineTo(-W * 0.06 + sr * g.ext, H + g.ext); c.closePath(); c.fill() }       // 길을 같은 기울기로 아래까지 잇는다
        c.strokeStyle("rgba(0,0,0,.1)"); c.lineWidth(1); c.beginPath(); c.moveTo(W * 0.44, hy + 8); c.bezierTo(W * 0.5, g.nearTop * 0.9, W * 0.02, g.nearTop + 4, -W * 0.06, H); c.stroke()
        c.beginPath(); c.moveTo(W * 0.54, hy + 8); c.bezierTo(W * 0.56, hy + 24, W * 0.6, g.nearTop + 6, W * 0.72, H); c.stroke()
        if wet(L) { for _ in 0..<4 { let pxx = rng.r(0.3, 0.7) * W, pyy = rng.r(g.nearTop + 12, H - 8), prx = rng.r(9, 16); c.fillStyle("rgba(70,90,120,.5)"); c.beginPath(); c.ellipse(pxx, pyy, prx, prx * 0.26, 0, 0, PI2); c.fill() } }
        if season == "autumn" && !snow { for _ in 0..<26 { c.fillStyle(rng.r() < 0.5 ? "rgba(214,120,50,.85)" : "rgba(226,176,60,.85)"); let a = rng.r(0, W), b = rng.r(g.nearTop - 6, H - 3), r3 = rng.r(0, 3); c.beginPath(); c.ellipse(a, b, 2.1, 1.2, r3, 0, PI2); c.fill() } }
        if snow { for _ in 0..<8 { c.fillStyle("rgba(255,255,255,.85)"); let a = rng.r(0, W), b = rng.r(g.nearTop, H - 3), e1 = rng.r(8, 20), e2 = rng.r(2, 4); c.beginPath(); c.ellipse(a, b, e1, e2, 0, 0, PI2); c.fill() } }
        // 벤치
        let bx = W * 0.82, by = g.nearTop + 4
        c.fillStyle(dim(L, "#7a5a3a")); c.fillRect(bx - 12, by - 9, 24, 2.4); c.fillRect(bx - 12, by - 5, 24, 2.4); c.fillStyle(dim(L, "#4b5160")); c.fillRect(bx - 11, by - 3, 2, 6); c.fillRect(bx + 9, by - 3, 2, 6); c.fillRect(bx - 12, by - 14, 2, 8); c.fillRect(bx + 10, by - 14, 2, 8)
        if snow { c.fillStyle("rgba(255,255,255,.92)"); c.fillRect(bx - 12, by - 11, 24, 2.2) }
        c = bg.gnd.cv
        // 분수 받침(물줄기는 SceneFx)
        let fx = W * 0.2, fy = g.nearTop - 2
        c.fillStyle(dim(L, "#a9b2bf")); c.beginPath(); c.ellipse(fx, fy + 2, 17, 5, 0, 0, PI2); c.fill()
        c.fillStyle(dim(L, "#7fb4d8")); c.beginPath(); c.ellipse(fx, fy + 0.6, 14.5, 3.7, 0, 0, PI2); c.fill()
        c.fillStyle(dim(L, "#c7ced9")); c.fillRect(fx - 1.6, fy - 11, 3.2, 12); c.beginPath(); c.ellipse(fx, fy - 11, 5, 1.6, 0, 0, PI2); c.fill()
        lamp(c, L, g, W * 0.07, g.nearTop + 2, 1); lamp(c, L, g, W * 0.93, g.nearTop + 2, -1)
    }

    // ═══ 강변 ═══
    static func river(_ bg: SceneArt.Bg, _ L: SceneArt.Pal, _ g: SceneArt.Geom, _ tw: Double, _ season: String, _ rng: SU.Seeded) {
        let W = g.W, H = g.H, hy = g.hy; var c: SceneCv
        let snow = snowy(L)
        let wTop = hy + 6, wBot = g.nearTop - 12
        // 먼 풍경: 건너편 둔치 · 아파트 숲 · 다리
        c = bg.far.cv
        hill(c, tw, hy + 4, hy * 0.3, 0.018, 2.0, dim(L, mix(L.c[2], css("#7a8fa3"), 0.5)))
        var x = 10.0
        while x < tw {
            let bw = rng.r(8, 15), bh = rng.r(hy * 0.12, hy * 0.34)
            c.fillStyle(dim(L, mix(L.c[2], css("#8fa0b6"), 0.5 + rng.r(0, 0.2)))); c.fillRect(x, hy + 4 - bh, bw, bh)
            var wy = hy + 7 - bh
            while wy < hy {
                var wx = x + 2
                while wx < x + bw - 1.5 { if L.lit && rng.r() < 0.45 { c.fillStyle("rgba(255,226,140,.8)"); c.fillRect(wx, wy, 1.4, 1.8) }; wx += 3.6 }
                wy += 4.5
            }
            x += rng.r(10, 20)
        }
        // 다리(트러스)
        let by0 = hy + 3, bl = W * 0.02, br = W * 1.0
        c.fillStyle(dim(L, "#5d6a7d")); c.fillRect(bl, by0 - 4.6, br - bl, 2.4)
        x = bl; while x < br { c.fillRect(x, by0 - 4.6, 1.6, 6); x += 14 }
        c.strokeStyle(dim(L, "#5d6a7d")); c.lineWidth(1.4); c.beginPath(); x = bl; while x < br { c.moveTo(x, by0 - 4); c.quadTo(x + 14, by0 - 20, x + 28, by0 - 4); x += 28 }; c.stroke()
        x = bl + 9; while x < br { c.fillStyle(dim(L, "#4d596b")); c.fillRect(x, by0 - 2, 3, 6); x += 50 }
        // 건너편 나무 띠
        c = bg.mid.cv
        let leaf = leafSet(season)
        x = 4
        while x < tw {
            let a = rng.r(hy * 0.2, hy * 0.32), b = rng.r(6, 10)
            let col = dim(L, mix(css(leaf[rng.pick(leaf.count)]), css("#2d3a4c"), L.night ? 0.4 : 0.08))
            roundTree(c, L, x, hy + 6, a, b, col, snow)
            x += rng.r(15, 28)
        }
        // 땅: 물 · 둑 · 산책로 · 난간
        c = bg.gnd.cv
        let sw = mix(L.c[2], css(L.night ? "#10244a" : "#4f8fc4"), 0.5)
        let wgr = c.linear(0, wTop, 0, wBot).stop(0, dim(L, mix(L.c[1], css("#7fb6e0"), 0.55))).stop(1, dim(L, shade(sw, -0.25))); c.fillGrad(wgr); c.fillRect(0, wTop, W, wBot - wTop)
        if snow { c.fillStyle("rgba(255,255,255,.18)"); c.fillRect(0, wTop, W, wBot - wTop) }
        // 햇빛/달빛 반사 기둥
        let rx = L.sunX * W; let rgl = c.linear(rx, wTop, rx, wBot).stop(0, rgba(255, 244, 200, L.hidesSun ? 0.08 : L.moon ? 0.26 : 0.5)).stop(1, rgba(255, 244, 200, 0))
        c.fillGrad(rgl); c.fillRect(rx - 14, wTop, 28, wBot - wTop)
        // 둑(돌)
        c.fillStyle(gnd(L, "#9ea6b2")); c.fillRect(0, wBot, W, g.nearTop - wBot + 1)
        c.strokeStyle("rgba(0,0,0,.14)"); c.lineWidth(1); x = 0; while x < W { c.beginPath(); c.moveTo(x, wBot); c.lineTo(x, g.nearTop + 1); c.stroke(); x += 13 }
        c.fillStyle("rgba(0,0,0,.18)"); c.fillRect(0, wBot, W, 1.6)
        // 산책로
        let walk = gnd(L, "#d9cdb8"); let pg = c.linear(0, g.nearTop, 0, H).stop(0, shade(walk, 0.06)).stop(1, shade(walk, -0.1)); c.fillGrad(pg); c.fillRect(0, g.nearTop, W, H + g.ext - g.nearTop)
        c.fillStyle(shade(walk, 0.2)); c.fillRect(0, g.nearTop - 1, W, 2)
        c.fillStyle(gnd(L, "#c0675a")); c.fillRect(0, g.nearTop + (H - g.nearTop) * 0.62, W, 3.4)       // 자전거길 띠
        c.fillStyle("rgba(255,255,255,.55)"); x = 6; while x < W { c.fillRect(x, g.nearTop + (H - g.nearTop) * 0.62 + 1.1, 11, 1.2); x += 22 }
        c.strokeStyle("rgba(0,0,0,.08)"); for yy in SceneArt.gridRows(g.nearTop, H - g.nearTop, 1.5, 4, H, g.ext) { c.beginPath(); c.moveTo(0, yy); c.lineTo(W, yy); c.stroke() }
        if wet(L) { for _ in 0..<4 { let pxx = rng.r(0.08, 0.92) * W, pyy = rng.r(g.nearTop + 10, H - 6), prx = rng.r(9, 16); c.fillStyle("rgba(70,90,120,.5)"); c.beginPath(); c.ellipse(pxx, pyy, prx, prx * 0.26, 0, 0, PI2); c.fill() } }
        if snow { for _ in 0..<8 { c.fillStyle("rgba(255,255,255,.88)"); let a = rng.r(0, W), b = rng.r(g.nearTop + 3, H - 3), e1 = rng.r(8, 20), e2 = rng.r(2, 4); c.beginPath(); c.ellipse(a, b, e1, e2, 0, 0, PI2); c.fill() } }
        // 난간(둑 위)
        let ry = g.nearTop + 1; c.fillStyle(dim(L, "#4b5160")); c.fillRect(0, ry - 8, W, 1.8)
        x = 2; while x < W { c.fillRect(x, ry - 8, 1.6, 9); x += 12 }
        if snow { c.fillStyle("rgba(255,255,255,.92)"); c.fillRect(0, ry - 9.8, W, 1.8) }
        lamp(c, L, g, W * 0.07, g.nearTop + 2, 1); lamp(c, L, g, W * 0.93, g.nearTop + 2, -1)
    }

    // ═══ 학교 앞 ═══
    static func school(_ bg: SceneArt.Bg, _ L: SceneArt.Pal, _ g: SceneArt.Geom, _ tw: Double, _ season: String, _ rng: SU.Seeded) {
        let W = g.W, H = g.H, hy = g.hy; var c: SceneCv
        let snow = snowy(L)
        c = bg.far.cv
        hill(c, tw, hy + 5, hy * 0.22, 0.02, 0.7, dim(L, mix(L.c[2], css("#8aa890"), 0.55)))
        // 학교 건물
        let bx = W * 0.12, bw = W * 0.62, bh = hy * 0.62, by = hy + 5
        let wall = dim(L, "#e6dccb")
        c.fillStyle(wall); c.fillRect(bx, by - bh, bw, bh)
        c.fillStyle(shade(wall, -0.12)); c.fillRect(bx, by - bh, bw, 3)
        c.fillStyle(dim(L, "#b7c4d6")); c.fillRect(bx - 2, by - bh - 3, bw + 4, 3.4)
        let rows = 3; let cols = floor(bw / 17)
        for r in 0..<rows {
            for k in 0..<Int(cols) {
                let wx = bx + 6 + Double(k) * (bw - 12) / cols, wy = by - bh + 7 + Double(r) * (bh - 12) / Double(rows)
                let lit = L.lit && rng.r() < 0.45
                c.fillStyle(lit ? css("rgba(255,230,150,.92)") : dim(L, "#9fc2e6")); c.fillRect(wx, wy, 10, 7)
                c.fillStyle(dim(L, "#6d7a8d")); c.fillRect(wx + 4.6, wy, 0.9, 7)
            }
        }
        // 가운데 현관과 시계탑
        let cx = bx + bw / 2; c.fillStyle(shade(wall, -0.06)); c.fillRect(cx - 17, by - bh - 14, 34, bh + 14)
        c.fillStyle(dim(L, "#7a5a3a")); c.fillRect(cx - 7, by - 15, 14, 15); c.fillStyle("rgba(255,255,255,.35)"); c.fillRect(cx - 0.5, by - 15, 1, 15)
        c.fillStyle(dim(L, "#f4f1e6")); c.beginPath(); c.arc(cx, by - bh - 5, 6.2, 0, PI2); c.fill(); c.strokeStyle(dim(L, "#4b5160")); c.lineWidth(1.2); c.stroke()
        c.beginPath(); c.moveTo(cx, by - bh - 5); c.lineTo(cx, by - bh - 9); c.moveTo(cx, by - bh - 5); c.lineTo(cx + 3, by - bh - 4); c.stroke()
        c.fillStyle(dim(L, "#b7c4d6")); c.beginPath(); c.moveTo(cx - 19, by - bh - 14); c.lineTo(cx, by - bh - 25); c.lineTo(cx + 19, by - bh - 14); c.closePath(); c.fill()
        if snow { c.fillStyle("rgba(255,255,255,.92)"); c.beginPath(); c.moveTo(cx - 19, by - bh - 14); c.lineTo(cx, by - bh - 25); c.lineTo(cx + 19, by - bh - 14); c.lineTo(cx + 15, by - bh - 14); c.lineTo(cx, by - bh - 21.5); c.lineTo(cx - 15, by - bh - 14); c.closePath(); c.fill(); c.fillRect(bx - 2, by - bh - 5, bw + 4, 2.6) }
        // 깃대(깃발은 SceneFx 가 펄럭이게)
        let fp = W * 0.84; c.fillStyle(dim(L, "#c7ced9")); c.fillRect(fp - 1, by - hy * 0.72, 2, hy * 0.72 + 1)
        c.fillStyle(dim(L, "#e8c14a")); c.beginPath(); c.arc(fp, by - hy * 0.72 - 1, 1.8, 0, PI2); c.fill()
        // 가까운 풍경: 쇠 울타리 + 은행나무
        c = bg.mid.cv
        let leaf = leafSet(season)
        var x = 4.0
        while x < tw {
            if x > bx - 10 && x < bx + bw + 10 && rng.r() < 0.7 { x += rng.r(34, 60); continue }
            let a = rng.r(hy * 0.4, hy * 0.6), b = rng.r(9, 14)
            let col = dim(L, mix(css(season == "autumn" ? "#e4c13d" : leaf[rng.pick(leaf.count)]), css("#3a2a4a"), L.lit ? 0.25 : 0.03))
            roundTree(c, L, x, hy + 7, a, b, col, snow)
            x += rng.r(34, 60)
        }
        c.fillStyle(dim(L, "#3e4a5c")); c.fillRect(0, hy + 1.5, tw, 1.6); c.fillRect(0, hy + 7.4, tw, 1.6)
        x = 1; while x < tw { c.fillRect(x, hy - 2, 1.2, 12); c.beginPath(); c.moveTo(x - 0.5, hy - 2); c.lineTo(x + 0.6, hy - 5); c.lineTo(x + 1.7, hy - 2); c.closePath(); c.fill(); x += 5 }
        if snow { c.fillStyle("rgba(255,255,255,.9)"); c.fillRect(0, hy, tw, 1.8) }
        // 땅: 운동장 모래 + 인도 + 어린이 보호구역(노랑) + 횡단보도
        c = bg.gnd.cv
        let yard = gnd(L, "#d8bf94"); let yg = c.linear(0, hy + 9, 0, g.nearTop).stop(0, shade(yard, 0.06)).stop(1, shade(yard, -0.06)); c.fillGrad(yg); c.fillRect(0, hy + 9, W, g.nearTop - hy - 9)
        c.fillStyle(gnd(L, "#e1d9c8")); c.fillRect(0, hy + 9, W, 2)
        let walk = gnd(L, "#cfc8ba"); let pg = c.linear(0, g.nearTop, 0, H).stop(0, shade(walk, 0.06)).stop(1, shade(walk, -0.1)); c.fillGrad(pg); c.fillRect(0, g.nearTop, W, H + g.ext - g.nearTop)
        c.fillStyle(shade(walk, 0.2)); c.fillRect(0, g.nearTop - 1, W, 2.2)
        c.fillStyle(gnd(L, "#f2c230")); c.fillRect(0, g.nearTop + (H - g.nearTop) * 0.5, W, 5)
        c.fillStyle(rgba(0, 0, 0, 0.45)); x = 4
        while x < W { let yy = g.nearTop + (H - g.nearTop) * 0.5; c.beginPath(); c.moveTo(x, yy + 5); c.lineTo(x + 6, yy); c.lineTo(x + 8, yy); c.lineTo(x + 2, yy + 5); c.closePath(); c.fill(); x += 14 }
        c.fillStyle(gnd(L, "#ffffff"))       // 횡단보도: 줄마다 폭 · 간격이 같은 비율로 부챗살처럼 벌어진다
        do {
            let yt = g.nearTop + 3, yb = H - 3, xc = W * 0.52 + 37.5 + 4.5, a = 0.5 / max(1, H - 3 - yt), sb = 1 + a * (yb - yt)
            for i in 0..<6 { let ci = W * 0.52 + Double(i) * 15 + 4.5, cb = xc + (ci - xc) * sb; c.beginPath(); c.moveTo(ci - 4.5, yt); c.lineTo(ci + 4.5, yt); c.lineTo(cb + 4.5 * sb, yb); c.lineTo(cb - 4.5 * sb, yb); c.closePath(); c.fill() }
        }
        if wet(L) { for _ in 0..<4 { let pxx = rng.r(0.08, 0.5) * W, pyy = rng.r(g.nearTop + 10, H - 6), prx = rng.r(9, 16); c.fillStyle("rgba(70,90,120,.5)"); c.beginPath(); c.ellipse(pxx, pyy, prx, prx * 0.26, 0, 0, PI2); c.fill() } }
        if snow { for _ in 0..<7 { c.fillStyle("rgba(255,255,255,.88)"); let a = rng.r(0, W * 0.5), b = rng.r(g.nearTop + 3, H - 3), e1 = rng.r(8, 20), e2 = rng.r(2, 4); c.beginPath(); c.ellipse(a, b, e1, e2, 0, 0, PI2); c.fill() } }
        // 보호구역 표지판
        let sx = W * 0.93, sy = g.nearTop + 3
        c.fillStyle(dim(L, "#4a5160")); c.fillRect(sx - 1.2, sy - 36, 2.4, 36)
        c.fillStyle(gnd(L, "#f2c230")); c.beginPath(); c.moveTo(sx, sy - 52); c.lineTo(sx + 11, sy - 33); c.lineTo(sx - 11, sy - 33); c.closePath(); c.fill(); c.strokeStyle(dim(L, "#222833")); c.lineWidth(1.3); c.stroke()
        c.fillStyle(dim(L, "#222833")); c.beginPath(); c.arc(sx - 2, sy - 44, 1.7, 0, PI2); c.arc(sx + 2.8, sy - 43.4, 1.4, 0, PI2); c.fill(); c.fillRect(sx - 3, sy - 42, 2.2, 6); c.fillRect(sx + 1.8, sy - 41.4, 1.8, 5)
        lamp(c, L, g, W * 0.07, g.nearTop + 2, 1)
    }

    // ═══ 시장 골목 ═══
    static func market(_ bg: SceneArt.Bg, _ L: SceneArt.Pal, _ g: SceneArt.Geom, _ tw: Double, _ season: String, _ rng: SU.Seeded) {
        let W = g.W, H = g.H, hy = g.hy; var c: SceneCv
        let snow = snowy(L)
        c = bg.far.cv
        // 뒤쪽 건물 벽(2~3층 상가)
        var x = -4.0
        while x < tw {
            let bw = rng.r(26, 44), bh = rng.r(hy * 0.5, hy * 0.82)
            let col = dim(L, mix(css("#c9b79d"), css(rng.r() < 0.5 ? "#d9a8a0" : "#a9b8c9"), rng.r(0, 0.6)))
            c.fillStyle(col); c.fillRect(x, hy + 6 - bh, bw, bh); c.fillStyle(shade(col, -0.12)); c.fillRect(x, hy + 6 - bh, bw, 2)
            var wy = hy + 6 - bh + 6
            while wy < hy - 8 {
                var wx = x + 4
                while wx < x + bw - 8 { let lit = L.lit && rng.r() < 0.5; c.fillStyle(lit ? css("rgba(255,226,140,.9)") : dim(L, "#8fb0d2")); c.fillRect(wx, wy, 5.5, 5); wx += 9 }
                wy += 9
            }
            if snow { c.fillStyle("rgba(255,255,255,.9)"); c.fillRect(x, hy + 6 - bh - 1.6, bw, 2.4) }
            x += bw + rng.r(0, 2)
        }
        // 가게 줄: 차양 · 좌판 · 간판
        c = bg.mid.cv
        let ac = ["#d9453d", "#2f7d4f", "#e3a21a", "#2f6fd6", "#c9568a"]; let nm = ["과일", "생선", "떡집", "분식", "반찬", "야채", "채소", "약국"]
        var sx = 0.0; var n = 0
        while sx < tw {
            let sw = rng.r(40, 52), top = hy - 24
            let col = dim(L, css(ac[n % ac.count]))
            c.fillStyle(dim(L, "#4a3a2c")); c.fillRect(sx + 2, top + 2, 2, 30); c.fillRect(sx + sw - 4, top + 2, 2, 30)
            c.fillStyle(dim(L, "#3b2f26")); c.fillRect(sx + 4, top + 6, sw - 8, 26)
            for k in 0..<7 {
                c.fillStyle(k % 2 == 0 ? col : dim(L, "#f4efe4")); let a0 = sx + Double(k) * sw / 7
                c.beginPath(); c.moveTo(a0, top - 1); c.lineTo(a0 + sw / 7, top - 1); c.lineTo(a0 + sw / 7 + 1, top + 8); c.quadTo(a0 + sw / 14, top + 11.5, a0 - 0.5, top + 8); c.closePath(); c.fill()
            }
            if snow { c.fillStyle("rgba(255,255,255,.9)"); c.fillRect(sx, top - 3, sw, 2.6) }
            c.fillStyle(dim(L, "#7a5a3a")); c.fillRect(sx + 3, top + 24, sw - 6, 3)
            for k in 0..<Int((sw - 8) / 4.2) {
                let pc = n % 3 == 0 ? css(k % 2 == 0 ? "#d9453d" : "#e8a02a") : n % 3 == 1 ? css(k % 2 == 0 ? "#c9d3dc" : "#8fa3b5") : css(k % 2 == 0 ? "#6db15a" : "#a7d27a")
                c.fillStyle(dim(L, pc)); c.beginPath(); c.arc(sx + 6 + Double(k) * 4.2, top + 22.6, 2.1, 0, PI2); c.fill()
            }
            c.fillStyle(dim(L, "#222833")); rr(c, sx + sw / 2 - 9, top - 7, 18, 7, 2); c.fill(); c.fillStyle("#f6e7b4"); c.font(5.6)
            let pickN = Int(rng.r(0, 8))
            c.fillTextC(nm[(n * 3 + pickN) % nm.count], sx + sw / 2, top - 3.4)
            sx += sw + rng.r(1, 5); n += 1
        }
        // 땅: 돌바닥 + 가로 줄무늬 그림자 + 전구줄은 SceneFx
        c = bg.gnd.cv
        let pave = gnd(L, "#b8ad9c"); let pg = c.linear(0, hy + 6, 0, H).stop(0, shade(pave, -0.08)).stop(1, shade(pave, -0.02)); c.fillGrad(pg); c.fillRect(0, hy + 6, W, H + g.ext - hy - 6)
        c.fillStyle("rgba(0,0,0,.2)"); c.fillRect(0, hy + 6, W, 5)
        c.strokeStyle("rgba(0,0,0,.12)"); c.lineWidth(1)
        for yy in SceneArt.gridRows(hy + 8, H - hy - 8, 1.6, 7, H, g.ext) { c.beginPath(); c.moveTo(0, yy); c.lineTo(W, yy); c.stroke() }
        for i in -10...10 { let fi = Double(i); c.beginPath(); c.moveTo(W / 2 + fi * 12, hy + 8); c.lineTo(W / 2 + fi * (12 + 28 * (H + g.ext - hy - 8) / (H - hy - 8)), H + g.ext); c.stroke() }       // 같은 기울기로 끝까지
        if wet(L) {
            for _ in 0..<6 {
                let pxx = rng.r(0.08, 0.92) * W, pyy = rng.r(g.nearTop - 8, H - 6), prx = rng.r(9, 18)
                c.fillStyle("rgba(70,90,120,.5)"); c.beginPath(); c.ellipse(pxx, pyy, prx, prx * 0.26, 0, 0, PI2); c.fill()
                c.fillStyle("rgba(210,230,255,.3)"); c.beginPath(); c.ellipse(pxx - prx * 0.2, pyy - 1, prx * 0.5, prx * 0.08, 0, 0, PI2); c.fill()
            }
        }
        if snow { for _ in 0..<9 { c.fillStyle("rgba(255,255,255,.85)"); let a = rng.r(0, W), b = rng.r(g.nearTop - 6, H - 3), e1 = rng.r(8, 22), e2 = rng.r(2, 4); c.beginPath(); c.ellipse(a, b, e1, e2, 0, 0, PI2); c.fill() } }
        // 가까운 쪽 손수레
        let cx = W * 0.86, cy = g.nearTop + 10
        c.fillStyle(dim(L, "#7a5a3a")); rr(c, cx - 17, cy - 9, 34, 7, 1.6); c.fill(); c.fillStyle(dim(L, "#5a4128")); c.fillRect(cx - 15, cy - 2, 2, 8); c.fillRect(cx + 13, cy - 2, 2, 8)
        for k in 0..<7 { c.fillStyle(dim(L, k % 2 == 0 ? "#f08a2a" : "#e8c14a")); c.beginPath(); c.arc(cx - 13 + Double(k) * 4.4, cy - 11, 2.5, 0, PI2); c.fill() }
        c.fillStyle(dim(L, "#222833")); c.beginPath(); c.arc(cx - 11, cy + 5, 3.4, 0, PI2); c.arc(cx + 11, cy + 5, 3.4, 0, PI2); c.fill()
    }

    // ═══ 바닷가 ═══
    static func beach(_ bg: SceneArt.Bg, _ L: SceneArt.Pal, _ g: SceneArt.Geom, _ tw: Double, _ season: String, _ rng: SU.Seeded) {
        let W = g.W, H = g.H, hy = g.hy; var c: SceneCv
        let seaB = g.nearTop - 14
        c = bg.far.cv
        // 수평선 위 섬 · 등대 · 배
        hill(c, tw, hy + 4, hy * 0.16, 0.03, 5.1, dim(L, mix(L.c[2], css("#6c8aa0"), 0.55)))
        let lx = W * 0.78; c.fillStyle(dim(L, "#f1ece0")); c.beginPath(); c.moveTo(lx - 3, hy + 3); c.lineTo(lx - 1.8, hy - 22); c.lineTo(lx + 1.8, hy - 22); c.lineTo(lx + 3, hy + 3); c.closePath(); c.fill()
        c.fillStyle(dim(L, "#d9453d")); c.fillRect(lx - 2.5, hy - 14, 5, 3.4); c.fillStyle(dim(L, "#4b5160")); c.fillRect(lx - 2.6, hy - 26, 5.2, 4)
        if L.lit { glowSpot(c, lx, hy - 24, 26, 255, 240, 170, 0.8) }
        for bx in [W * 0.28, W * 0.48] { c.fillStyle(dim(L, "#f4f1e6")); c.beginPath(); c.moveTo(bx, hy + 6.2); c.lineTo(bx, hy - 4); c.lineTo(bx + 6, hy + 5); c.closePath(); c.fill(); c.fillStyle(dim(L, "#3d4a66")); c.fillRect(bx - 3, hy + 5, 11, 2) }
        // 가까운 풍경: 소나무 숲 가장자리 · 파라솔 · 구조대 망루
        c = bg.mid.cv
        var x = tw * 0.52
        while x < tw { let a = rng.r(hy * 0.5, hy * 0.78), b = rng.r(8, 12); pine(c, L, x, g.nearTop - 4, a, b, dim(L, "#2c6a45"), snowy(L)); x += rng.r(15, 26) }
        x = 2
        while x < W * 0.2 { let a = rng.r(hy * 0.5, hy * 0.74), b = rng.r(8, 12); pine(c, L, x, g.nearTop - 4, a, b, dim(L, "#2c6a45"), snowy(L)); x += rng.r(15, 24) }
        // 땅: 바다 · 젖은 모래 · 마른 모래
        c = bg.gnd.cv
        let sg = c.linear(0, hy + 3, 0, seaB).stop(0, dim(L, mix(L.c[1], css("#4fa7c9"), 0.5))).stop(1, dim(L, css(L.night ? "#10325a" : "#2e86b0"))); c.fillGrad(sg); c.fillRect(0, hy + 3, W, seaB - hy - 3)
        let rx = L.sunX * W; let rgl = c.linear(rx, hy + 3, rx, seaB).stop(0, rgba(255, 244, 200, L.hidesSun ? 0.08 : L.moon ? 0.3 : 0.55)).stop(1, rgba(255, 244, 200, 0)); c.fillGrad(rgl); c.fillRect(rx - 16, hy + 3, 32, seaB - hy - 3)
        c.fillStyle("rgba(255,255,255,.28)")
        for _ in 0..<14 { let yy = rng.r(hy + 6, seaB - 3); let a = rng.r(0, W), b = rng.r(6, 16); c.fillRect(a, yy, b, 1) }
        let dry = gnd(L, "#e8d7b0"), wetS = mix(dry, css("#6a5a44"), 0.35)
        let sa = c.linear(0, seaB, 0, H).stop(0, wetS).stop(0.18, wetS).stop(0.26, shade(dry, 0.04)).stop(1, shade(dry, -0.1)); c.fillGrad(sa); c.fillRect(0, seaB, W, H + g.ext - seaB)
        c.fillStyle("rgba(255,255,255,.85)"); c.beginPath(); x = 0; while x <= W { c.lineTo(x, seaB - 1.4 + sin(x * 0.09) * 1.4); x += 4 }; c.lineTo(W, seaB + 3); c.lineTo(0, seaB + 3); c.closePath(); c.fill()
        for _ in 0..<14 { c.fillStyle(rng.r() < 0.5 ? "rgba(255,255,255,.7)" : "rgba(210,170,150,.8)"); let a = rng.r(0, W), b = rng.r(g.nearTop + 6, H - 3), r3 = rng.r(0.8, 1.6); c.beginPath(); c.arc(a, b, r3, 0, PI2); c.fill() }
        c.strokeStyle("rgba(0,0,0,.07)"); c.lineWidth(1); for yy in SceneArt.gridRows(g.nearTop, H - g.nearTop, 1.5, 4, H, g.ext) { c.beginPath(); c.moveTo(0, yy); c.lineTo(W, yy); c.stroke() }
        if wet(L) { for _ in 0..<4 { let pxx = rng.r(0.08, 0.92) * W, pyy = rng.r(g.nearTop + 10, H - 6), prx = rng.r(9, 16); c.fillStyle("rgba(70,90,120,.4)"); c.beginPath(); c.ellipse(pxx, pyy, prx, prx * 0.26, 0, 0, PI2); c.fill() } }
        let pc = ["#e0556c", "#f0b83a", "#5aa9e6", "#e9eef5"]
        for k in 0..<3 {
            let px = W * (0.34 + Double(k) * 0.13), py = g.nearTop + 6
            c.fillStyle(dim(L, "#6a5a48")); c.fillRect(px - 0.7, py - 15, 1.4, 15)
            for s in 0..<6 { c.fillStyle(s % 2 == 0 ? dim(L, pc[k % pc.count]) : dim(L, "#ffffff")); let a0 = px - 12 + Double(s) * 4; c.beginPath(); c.moveTo(a0, py - 12); c.lineTo(a0 + 4, py - 12); c.lineTo(px + (a0 + 2 - px) * 0.15, py - 20); c.closePath(); c.fill() }
        }
        let tx = W * 0.88, ty = g.nearTop + 6; c.fillStyle(dim(L, "#f4f1e6")); c.fillRect(tx - 7, ty - 18, 14, 12); c.fillStyle(dim(L, "#e0556c")); c.beginPath(); c.moveTo(tx - 9, ty - 18); c.lineTo(tx, ty - 25); c.lineTo(tx + 9, ty - 18); c.closePath(); c.fill()
        c.fillStyle(dim(L, "#7a5a3a")); c.fillRect(tx - 6, ty - 6, 2, 7); c.fillRect(tx + 4, ty - 6, 2, 7)
        c.fillStyle(dim(L, "#9fc2e6")); c.fillRect(tx - 5, ty - 15, 10, 5)
    }

    // ═══ 산길 ═══
    static func trail(_ bg: SceneArt.Bg, _ L: SceneArt.Pal, _ g: SceneArt.Geom, _ tw: Double, _ season: String, _ rng: SU.Seeded) {
        let W = g.W, H = g.H, hy = g.hy; var c: SceneCv
        let snow = snowy(L)
        c = bg.far.cv
        let m1 = dim(L, mix(L.c[2], css("#6f8fb0"), 0.6)), m2 = dim(L, mix(L.c[2], css("#5f8a78"), 0.6)), m3 = dim(L, mix(L.c[2], css("#4a7a5a"), 0.5))
        hill(c, tw, hy + 6, hy * 0.62, 0.013, 0.4, snow ? mix(m1, css("#ffffff"), 0.6) : m1)
        c.fillStyle("rgba(255,255,255,.2)"); c.fillRect(0, hy - hy * 0.26, tw, 5)
        hill(c, tw, hy + 6, hy * 0.44, 0.021, 2.8, snow ? mix(m2, css("#ffffff"), 0.55) : m2)
        c.fillStyle("rgba(255,255,255,.18)"); c.fillRect(0, hy - hy * 0.12, tw, 5)
        hill(c, tw, hy + 6, hy * 0.26, 0.033, 5.5, snow ? mix(m3, css("#ffffff"), 0.5) : m3)
        // 숲
        c = bg.mid.cv
        let leaf = leafSet(season)
        var x = 3.0
        while x < tw {
            let th = rng.r(hy * 0.42, hy * 0.86)
            if rng.r() < 0.55 { let a = rng.r(7, 11); let b = rng.r(0, 0.4); pine(c, L, x, hy + 7, th, a, dim(L, mix(css("#2f6a4a"), css("#16322a"), b)), snow) }
            else { let a = rng.r(8, 13); roundTree(c, L, x, hy + 7, th * 0.8, a, dim(L, css(leaf[rng.pick(leaf.count)])), snow) }
            x += rng.r(11, 22)
        }
        // 바위
        x = 14
        while x < tw {
            let rw = rng.r(8, 14); c.fillStyle(dim(L, "#8a8f98")); c.beginPath(); c.ellipse(x, hy + 8, rw, rw * 0.5, 0, PI, 0); c.fill()
            if snow { c.fillStyle("rgba(255,255,255,.9)"); c.beginPath(); c.ellipse(x, hy + 6.5, rw * 0.8, rw * 0.2, 0, PI, 0); c.fill() }
            x += rng.r(70, 130)
        }
        // 땅: 풀 · 흙길 · 나무 울타리
        c = bg.gnd.cv
        let grass = gnd(L, season == "winter" ? "#8d9a7e" : season == "autumn" ? "#8a9a5a" : "#5c9a58")
        let gr = c.linear(0, hy + 3, 0, H).stop(0, shade(grass, 0.04)).stop(1, shade(grass, -0.14)); c.fillGrad(gr); c.fillRect(0, hy + 3, W, H + g.ext - hy - 3)
        let dirt = gnd(L, "#a98a62")
        c.fillStyle(dirt); c.beginPath(); c.moveTo(W * 0.5, hy + 8); c.bezierTo(W * 0.46, g.nearTop * 0.85, W * 0.1, g.nearTop + 2, -W * 0.1, H); c.lineTo(W * 0.78, H); c.bezierTo(W * 0.6, g.nearTop + 4, W * 0.56, hy + 22, W * 0.56, hy + 8); c.closePath(); c.fill()
        do { let sl = (W * 0.78 - W * 0.6) / max(1, H - g.nearTop - 4), sr = (-W * 0.1 - W * 0.1) / max(1, H - g.nearTop - 2); c.beginPath(); c.moveTo(-W * 0.1, H - 0.5); c.lineTo(W * 0.78, H - 0.5); c.lineTo(W * 0.78 + sl * g.ext, H + g.ext); c.lineTo(-W * 0.1 + sr * g.ext, H + g.ext); c.closePath(); c.fill() }
        c.fillStyle("rgba(0,0,0,.09)")
        for _ in 0..<18 { let a = rng.r(W * 0.08, W * 0.7), b = rng.r(g.nearTop - 4, H - 3), e1 = rng.r(1.6, 4), e2 = rng.r(0.8, 1.6); c.beginPath(); c.ellipse(a, b, e1, e2, 0, 0, PI2); c.fill() }
        c.fillStyle(dim(L, "#7e8590"))
        for _ in 0..<9 { let a = rng.r(W * 0.05, W * 0.75), b = rng.r(g.nearTop, H - 3), e1 = rng.r(2, 4.4), e2 = rng.r(1.2, 2.4); c.beginPath(); c.ellipse(a, b, e1, e2, 0, 0, PI2); c.fill() }
        c.strokeStyle(dim(L, "#6b4f33")); c.lineWidth(1.6)
        for _ in 0..<3 { let rx = rng.r(W * 0.2, W * 0.6), ry = rng.r(g.nearTop + 6, H - 8); c.beginPath(); c.moveTo(rx, ry); c.quadTo(rx + 8, ry - 3, rx + 15, ry + 1); c.stroke() }
        if wet(L) { for _ in 0..<4 { let pxx = rng.r(0.15, 0.6) * W, pyy = rng.r(g.nearTop + 10, H - 6), prx = rng.r(8, 14); c.fillStyle("rgba(70,90,120,.5)"); c.beginPath(); c.ellipse(pxx, pyy, prx, prx * 0.26, 0, 0, PI2); c.fill() } }
        if snow { for _ in 0..<9 { c.fillStyle("rgba(255,255,255,.88)"); let a = rng.r(0, W), b = rng.r(g.nearTop + 2, H - 3), e1 = rng.r(8, 20), e2 = rng.r(2, 4); c.beginPath(); c.ellipse(a, b, e1, e2, 0, 0, PI2); c.fill() } }
        // 이정표 · 나무 울타리
        let sx = W * 0.84, sy = g.nearTop + 6
        c.fillStyle(dim(L, "#6b4f33")); c.fillRect(sx - 1.4, sy - 30, 2.8, 30)
        c.fillStyle(dim(L, "#8a6a43")); rr(c, sx - 12, sy - 30, 24, 9, 1.6); c.fill(); c.fillStyle("#f6e7b4"); c.font(5.8); c.fillTextC("등산로", sx, sy - 25.4)
        if snow { c.fillStyle("rgba(255,255,255,.92)"); c.fillRect(sx - 12, sy - 32, 24, 2.2) }
        c.strokeStyle(dim(L, "#6b4f33")); c.lineWidth(1.6); c.beginPath(); c.moveTo(W * 0.04, g.nearTop - 6); c.lineTo(W * 0.2, g.nearTop - 6); c.moveTo(W * 0.04, g.nearTop - 1); c.lineTo(W * 0.2, g.nearTop - 1); c.stroke()
        c.lineWidth(2.4); for px in [W * 0.04, W * 0.12, W * 0.2] { c.beginPath(); c.moveTo(px, g.nearTop - 9); c.lineTo(px, g.nearTop + 3); c.stroke() }
    }
}
