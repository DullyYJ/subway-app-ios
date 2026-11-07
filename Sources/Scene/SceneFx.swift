import Foundation

/// 장면의 날씨 연출과 장소별 움직임 — 안드로이드 SceneFx.java (YJ 2026-10-25: "날씨에 맞춰 비·눈·햇빛·바람 같은 이펙트를 연출하고, 장소를 다양하게").
/// ★ 판단은 없다. 햇빛(look.sun)·더위(look.hot)·추위(look.cold)·바람 세기(look.wind)·장소(look.place)는 엔진(/scene)이 정한 값이고,
///   여기는 그 값대로 빛줄기 · 아지랑이 · 나뭇잎 · 바람줄기 · 흔들리는 나무 · 분수 · 물결 · 배 · 깃발 · 김 · 전구줄 · 안개 · 반딧불을 그릴 뿐이다.
enum SceneFx {
    // ═══ 가까운 풍경(나무·가게)을 바람에 흔든다 — 위쪽일수록 많이 ═══
    static func drawMid(_ S: SceneCore, _ c: SceneCv, _ mid: SceneImg, _ tw0: Int) {
        let tw = Double(tw0)
        let wl = S.L.wind
        if wl <= 0 { c.drawImage(mid, 0, 0, tw, S.H); return }
        let dy = Double(mid.h) / S.H, lim = S.g.hy + 12, amp: Double = wl == 1 ? 1.0 : 2.2, sp: Double = wl == 1 ? 1.5 : 2.6, band = 5.0
        var y = 0.0
        while y < S.H {
            let h = min(band, S.H - y), rel = clamp(1 - y / lim, 0, 1)
            let off: Double = y < lim ? (sin(S.t * sp + y * 0.05) * amp + Double(wl) * 0.9) * (0.25 + rel * 0.75) : 0
            c.drawImage(mid, 0, y * dy, Double(mid.w), h * dy, off, y, tw, h)
            y += band
        }
    }

    // ═══ 햇빛: 따뜻한 번짐 · 빛줄기 · 렌즈 반사 ═══
    static func sun(_ S: SceneCore, _ c: SceneCv, _ tt: Double) {
        let L = S.L; if !L.sun || L.night { return }
        let sx = L.sunX * S.W, sy = L.sunY * S.H, k: Double = L.bright ? 1.4 : 1, W = S.W, H = S.H
        let g = c.radial(sx, sy, 0, sx, sy, W * 0.8).stop(0, rgba(255, 240, 190, 0.22 * k)).stop(0.5, rgba(255, 236, 180, 0.08 * k)).stop(1, rgba(255, 236, 180, 0))
        c.fillGrad(g); c.fillRect(0, 0, W, H)
        for i in 0..<6 {
            let di = Double(i)
            let a = PI * (0.2 + di * 0.115) + sin(tt * 0.35 + di) * 0.03, w = 0.035 + 0.01 * Double(i % 3), len = H * 1.5
            c.fillStyle(rgba(255, 244, 205, (0.06 + 0.03 * sin(tt * 0.8 + di * 1.7)) * k))
            c.beginPath(); c.moveTo(sx, sy); c.lineTo(sx + cos(a - w) * len, sy + sin(a - w) * len); c.lineTo(sx + cos(a + w) * len, sy + sin(a + w) * len); c.closePath(); c.fill()
        }
        let cx = W * 0.5, cy = H * 0.5
        for j in 0..<3 {
            let dj = Double(j)
            let u = 0.38 + dj * 0.3, x = sx + (cx - sx) * u * 1.3, y = sy + (cy - sy) * u * 1.3, r = 4 + dj * 3.2
            c.fillStyle(rgba(255, j == 1 ? 210 : 245, j == 1 ? 170 : 200, 0.07 * k)); c.beginPath(); c.arc(x, y, r, 0, PI2); c.fill()
        }
    }

    // ═══ 더위: 땅 위 아지랑이 ═══
    static func heat(_ S: SceneCore, _ c: SceneCv, _ tt: Double) {
        let L = S.L; if !L.hot || L.night { return }
        c.lineWidth(1.4)
        for i in 0..<5 {
            let di = Double(i)
            let y = S.g.nearTop - 22 + di * 15; c.strokeStyle(rgba(255, 255, 255, 0.12 + 0.05 * sin(tt * 1.5 + di)))
            c.beginPath()
            var x = 0.0
            while x <= S.W { let yy = y + sin(x * 0.07 + tt * 2.8 + di * 1.3) * 1.7; if x == 0 { c.moveTo(x, yy) } else { c.lineTo(x, yy) }; x += 5 }
            c.stroke()
        }
    }

    // ═══ 추위: 옅은 푸른 기운 ═══
    static func cold(_ S: SceneCore, _ c: SceneCv) {
        if !S.L.cold { return }
        let g = c.linear(0, 0, 0, S.H).stop(0, rgba(170, 205, 255, 0.1)).stop(1, rgba(170, 205, 255, 0.04)); c.fillGrad(g); c.fillRect(0, 0, S.W, S.H)
    }

    // ═══ 바람: 바람줄기 + 날리는 잎 · 꽃잎 · 모래 ═══
    static func wind(_ S: SceneCore, _ c: SceneCv, _ tt: Double) {
        let wl = S.L.wind; if wl <= 0 { return }
        let W = S.W, H = S.H; let wd = S.wxP.wind; let dwl = Double(wl)
        c.lineWidth(1); c.strokeStyle(S.L.night ? "rgba(200,220,255,.18)" : "rgba(255,255,255,.34)")
        c.beginPath()
        var i = 0
        while i < wd.count && i < 9 * wl {
            let q = wd[i]; let sp = 90 + 70 * dwl, x = ((q[0] * (W + 90) + tt * sp * q[2]).truncatingRemainder(dividingBy: W + 90)) - 45, y = q[1] * H * 0.86 + 6 + sin(tt * 2 + q[4]) * 2, len = 14 + 16 * q[3] * dwl
            c.moveTo(x, y); c.quadTo(x + len * 0.5, y - 2.2, x + len, y)
            i += 1
        }
        c.stroke()
        let place = S.L.place, season = S.L.season; let autumn = season == "autumn", spring = season == "spring"
        i = 0
        while i < wd.count {
            let q = wd[i]; if i >= 14 * wl { break }
            i += 1
            let sp = 55 + 55 * dwl, x = ((q[0] * (W + 70) + tt * sp * (0.7 + q[2] * 0.6)).truncatingRemainder(dividingBy: W + 70)) - 35
            let y = ((q[1] * (H * 0.72) + 12) + sin(tt * 1.7 + q[4]) * 6 + (tt * 6 * q[2]).truncatingRemainder(dividingBy: 6)), rot = tt * (3 + 3 * q[3]) + q[4]
            if S.L.wk == "snow" { c.fillStyle("rgba(255,255,255,.85)"); c.beginPath(); c.arc(x, y, 1.2 + q[3] * 0.6, 0, PI2); c.fill(); continue }
            if place == "beach" { c.fillStyle("rgba(232,215,176,.7)"); c.beginPath(); c.arc(x, H * 0.55 + q[1] * H * 0.4, 1, 0, PI2); c.fill(); continue }
            let col: String = autumn ? (q[4] < 3 ? "#d9772b" : "#e2b83a") : spring ? (q[4] < 3 ? "#f7b6cc" : "#fbd2de") : "#6fae60"
            c.fillStyle(col); c.save(); c.translate(x, y); c.rotate(rot); c.beginPath(); c.ellipse(0, 0, spring ? 1.9 : 2.7, 1.3, 0, 0, PI2); c.fill(); c.restore()
        }
    }

    // ═══ 장소별 움직임(뒤쪽 — 캐릭터보다 먼저) ═══
    static func ambient(_ S: SceneCore, _ c: SceneCv, _ tt: Double) {
        let L = S.L; let g = S.g; let W = S.W, H = S.H, hy = g.hy
        let place = L.place.isEmpty ? "street" : L.place; let snow = L.wk == "snow"
        switch place {
        case "park":
            let fx = W * 0.2, fy = g.nearTop - 13
            if !snow && !L.cold {
                c.strokeStyle("rgba(225,245,255,.85)"); c.lineWidth(1.1)
                for i in 0..<7 {
                    let a = -PI / 2 + Double(i - 3) * 0.17, v = 24 + Double(i % 2) * 4
                    c.beginPath()
                    for k in 0...8 { let u = Double(k) / 8.0 * 0.62, x = fx + cos(a) * v * u * 1.7, y = fy + sin(a) * v * u * 1.7 + 70 * u * u; if k == 0 { c.moveTo(x, y) } else { c.lineTo(x, y) } }
                    c.stroke()
                }
                c.fillStyle("rgba(225,245,255,.8)")
                for i in 0..<6 { let ph = (tt * 1.3 + Double(i) * 0.17).truncatingRemainder(dividingBy: 1), a = -PI / 2 + (Double(i) - 2.5) * 0.15; c.beginPath(); c.arc(fx + cos(a) * 24 * ph * 1.7, fy + sin(a) * 24 * ph * 1.7 + 70 * ph * ph * 0.4, 1, 0, PI2); c.fill() }
                c.strokeStyle("rgba(235,248,255,.6)"); c.lineWidth(0.9)
                for i in 0..<2 { let u = (tt * 0.9 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1); c.beginPath(); c.ellipse(fx, fy + 1, 3 + u * 11, (3 + u * 11) * 0.27, 0, 0, PI2); c.stroke() }
            }
            if !L.night && !snow && L.wk != "rain" && (L.season == "spring" || L.season == "summer") {
                for i in 0..<2 {
                    let di = Double(i)
                    let bx = W * (0.55 + di * 0.22) + sin(tt * 0.7 + di * 2) * 26, by = hy + 30 + di * 18 + sin(tt * 1.3 + di) * 10, f = abs(sin(tt * 11 + di)) * 3.4
                    c.fillStyle(i == 0 ? "#ffb347" : "#9ad0ff"); c.beginPath(); c.ellipse(bx - 2, by, 2.4, f + 0.4, -0.4, 0, PI2); c.ellipse(bx + 2, by, 2.4, f + 0.4, 0.4, 0, PI2); c.fill()
                    c.fillStyle("#3a2f2a"); c.fillRect(bx - 0.4, by - 1.4, 0.8, 3)
                }
            }
        case "river":
            let wTop = hy + 6, wBot = g.nearTop - 12
            c.strokeStyle(L.night ? "rgba(200,220,255,.28)" : "rgba(255,255,255,.4)"); c.lineWidth(1)
            for i in 0..<20 {
                let yy = wTop + 4 + Double((i * 37) % 100) / 100.0 * (wBot - wTop - 8), xx = (Double(i * 61) + tt * (6 + Double(i % 3) * 3)).truncatingRemainder(dividingBy: W + 20) - 10, a = 0.25 + 0.35 * abs(sin(tt * 1.6 + Double(i)))
                c.globalAlpha(a); c.beginPath(); c.moveTo(xx, yy); c.lineTo(xx + 5 + Double(i % 4), yy); c.stroke()
            }
            c.globalAlpha(1)
            let bx = ((tt * 7).truncatingRemainder(dividingBy: W + 120)) - 50, by = wTop + (wBot - wTop) * 0.55
            c.fillStyle("rgba(0,0,0,.18)"); c.beginPath(); c.ellipse(bx, by + 2.4, 17, 2.4, 0, 0, PI2); c.fill()
            c.fillStyle(ScenePlaces.dim(L, "#e8e2d4")); c.beginPath(); c.moveTo(bx - 17, by - 2); c.lineTo(bx + 17, by - 2); c.lineTo(bx + 12, by + 3); c.lineTo(bx - 13, by + 3); c.closePath(); c.fill()
            c.fillStyle(ScenePlaces.dim(L, "#d9453d")); c.fillRect(bx - 17, by - 2, 34, 1.6)
            c.fillStyle(ScenePlaces.dim(L, "#f4f1e6")); c.fillRect(bx - 6, by - 8, 13, 6)
            c.fillStyle(L.lit ? css("rgba(255,226,140,.95)") : ScenePlaces.dim(L, "#7fb4d8")); c.fillRect(bx - 4.6, by - 6.6, 3, 2.6); c.fillRect(bx - 0.6, by - 6.6, 3, 2.6); c.fillRect(bx + 3.2, by - 6.6, 2.6, 2.6)
            c.strokeStyle("rgba(255,255,255,.55)"); c.lineWidth(1); c.beginPath(); c.moveTo(bx - 17, by + 3.4); c.lineTo(bx - 36, by + 4); c.stroke()
        case "school":
            let fp = W * 0.84, top = hy + 5 - hy * 0.72, sp2 = 4 + Double(L.wind) * 2, amp = 1.2 + Double(L.wind) * 1.2
            c.fillStyle(ScenePlaces.dim(L, "#2f6fd6")); c.beginPath(); c.moveTo(fp + 1, top + 1)
            for k in 0...6 { c.lineTo(fp + 1 + Double(k) * 2, top + 1 + sin(tt * sp2 - Double(k) * 0.9) * amp * (Double(k) / 6.0)) }
            for k in stride(from: 6, through: 0, by: -1) { c.lineTo(fp + 1 + Double(k) * 2, top + 8 + sin(tt * sp2 - Double(k) * 0.9) * amp * (Double(k) / 6.0)) }
            c.closePath(); c.fill()
            c.fillStyle(ScenePlaces.dim(L, "#f7f4ee")); c.beginPath()
            for k in 0...6 { c.lineTo(fp + 1 + Double(k) * 2, top + 3.4 + sin(tt * sp2 - Double(k) * 0.9) * amp * (Double(k) / 6.0)) }
            for k in stride(from: 6, through: 0, by: -1) { c.lineTo(fp + 1 + Double(k) * 2, top + 5.4 + sin(tt * sp2 - Double(k) * 0.9) * amp * (Double(k) / 6.0)) }
            c.closePath(); c.fill()
        case "market":
            let y0 = hy - 34; var nb = 0
            c.strokeStyle("rgba(30,30,40,.7)"); c.lineWidth(0.9)
            var x = -10.0
            while x < W { c.beginPath(); c.moveTo(x, y0 - 2); c.quadTo(x + 32, y0 + 10, x + 64, y0 - 2); c.stroke(); x += 64 }
            let bc = ["#ffd54f", "#ff7a59", "#ffffff", "#7fd1ff"]
            x = -10.0
            while x < W {
                for k in 1...5 {
                    let u = Double(k) / 6.0, bx = x + 64 * u, by = y0 - 2 + 12 * u * (1 - u) * 2.0, fl: Double = L.lit ? (0.75 + 0.25 * sin(tt * 3 + Double(k) + x)) : 0.5
                    if L.lit { glowSpot(c, bx, by + 2, 9, 255, 220, 140, 0.45 * fl) }
                    if L.lit { c.fillStyle(css(bc[nb % 4])); nb += 1 } else { c.fillStyle(css("#8d95a3")) }
                    c.beginPath(); c.arc(bx, by + 1.6, 1.7, 0, PI2); c.fill()
                }
                x += 64
            }
            for i in 0..<4 { let u = (tt * 0.5 + Double(i) * 0.27).truncatingRemainder(dividingBy: 1), x = W * 0.3 + sin(tt * 1.4 + Double(i) * 2) * 3 + u * 3, y = hy - 3 - u * 24; c.fillStyle(rgba(255, 255, 255, 0.5 * (1 - u))); c.beginPath(); c.arc(x, y, 2.2 + u * 4, 0, PI2); c.fill() }
        case "beach":
            let seaB = g.nearTop - 14; c.lineWidth(1.4)
            for i in 0..<3 {
                let p = (tt * 0.18 + Double(i) / 3.0).truncatingRemainder(dividingBy: 1), y = (hy + 14) + (seaB - hy - 15) * p
                c.strokeStyle(rgba(255, 255, 255, 0.6 * sin(PI * p)))
                c.beginPath()
                var x = 0.0
                while x <= W { let yy = y + sin(x * 0.06 + tt * 1.4 + Double(i)) * (0.8 + 1.6 * p); if x == 0 { c.moveTo(x, yy) } else { c.lineTo(x, yy) }; x += 6 }
                c.stroke()
            }
            let surge = 1.8 + 2.2 * sin(tt * 0.8)
            c.fillStyle("rgba(255,255,255,.82)"); c.beginPath(); c.moveTo(0, seaB + 4)
            var x2 = 0.0
            while x2 <= W { c.lineTo(x2, seaB + 1 + surge + sin(x2 * 0.09 + tt * 1.3) * 1.6); x2 += 4 }
            c.lineTo(W, seaB + 4); c.closePath(); c.fill()
            if !L.night && !snow {
                let gx = ((tt * 11).truncatingRemainder(dividingBy: W + 60)) - 30, gy = hy - 18 + sin(tt * 1.6) * 3, f = sin(tt * 7) * 2.4
                c.strokeStyle("rgba(60,70,90,.85)"); c.lineWidth(1.2); c.beginPath(); c.moveTo(gx - 5, gy + f); c.quadTo(gx - 2, gy - 2.5, gx, gy); c.quadTo(gx + 2, gy - 2.5, gx + 5, gy + f); c.stroke()
            }
        case "trail":
            for i in 0..<2 {
                let fy = hy + 4 + Double(i) * 36, off = sin(tt * 0.2 + Double(i) * 2) * 18
                let fg = c.linear(0, fy - 14, 0, fy + 14).stop(0, rgba(235, 240, 245, 0)).stop(0.5, rgba(235, 240, 245, L.night ? 0.08 : 0.2)).stop(1, rgba(235, 240, 245, 0))
                c.fillGrad(fg); c.fillRect(off - 20, fy - 14, W + 40, 28)
            }
            if L.night && !snow && L.wk != "rain" && L.season != "winter" {
                for i in 0..<11 {
                    let di = Double(i)
                    let x = Double((i * 53) % 100) / 100.0 * W + sin(tt * 0.6 + di * 2.1) * 12, y = hy + 8 + Double((i * 29) % 100) / 100.0 * (H - hy - 24) + cos(tt * 0.5 + di) * 8, a = 0.35 + 0.6 * max(0, sin(tt * 1.7 + di * 1.9))
                    glowSpot(c, x, y, 6, 220, 255, 120, 0.55 * a); c.fillStyle(rgba(240, 255, 160, a)); c.beginPath(); c.arc(x, y, 1, 0, PI2); c.fill()
                }
            }
        default: break
        }
    }
    static func glowSpot(_ c: SceneCv, _ x: Double, _ y: Double, _ r: Double, _ a: Int, _ b: Int, _ cc: Int, _ al: Double) { ScenePlaces.glowSpot(c, x, y, r, a, b, cc, al) }

    /// 하늘 위쪽 구름을 바람 세기에 따라 더 빨리 흘린다
    static func cloudSpeed(_ L: SceneArt.Pal) -> Double { 1 + Double(L.wind) * 1.2 }
}
