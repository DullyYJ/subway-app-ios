import Foundation

/// SceneCore 의 그리기(안드로이드 SceneCore.java 의 '그리기' 구간). 그림만 그린다 — 무엇을 할지는 고르지 않는다.
extension SceneCore {
    // ═══ 대나무 ═══
    /// 대나무 한 그루(x,y 가운데, rot 기울기, len 길이).
    func drawBamboo(_ c: SceneCv, _ x: Double, _ y: Double, _ rot: Double, _ len: Double, _ zz: Double) {
        let w = 3.4 * zz
        c.save(); c.translate(x, y); c.rotate(rot); c.lineCapRound(true)
        c.strokeStyle("#3f8f3a"); c.lineWidth(w + 1.2); c.beginPath(); c.moveTo(-len / 2, 0); c.lineTo(len / 2, 0); c.stroke()
        c.strokeStyle("#86d466"); c.lineWidth(w); c.beginPath(); c.moveTo(-len / 2, 0); c.lineTo(len / 2, 0); c.stroke()
        c.strokeStyle("#3f8f3a"); c.lineWidth(1); c.beginPath()
        for i in 1..<4 { let nx = -len / 2 + len * Double(i) / 4; c.moveTo(nx, -w * 0.6); c.lineTo(nx, w * 0.6) }
        c.stroke()
        c.fillStyle("#5fb04a"); c.beginPath(); c.ellipse(len / 2 - 1, -w * 0.9, 4 * zz, 1.6 * zz, -0.5, 0, PI2); c.fill(); c.beginPath(); c.ellipse(len / 2 - 3, w * 0.9, 3.4 * zz, 1.4 * zz, 0.5, 0, PI2); c.fill()
        c.restore()
    }
    func drawBams(_ c: SceneCv, _ air: Bool) {
        for b in bams {
            if b.landed == air || b.taken { continue }
            let zz = zs(b.z), len = TH * zz * 0.9
            if b.landed { c.fillStyle("rgba(0,0,0,.18)"); c.beginPath(); c.ellipse(b.x, b.y + 1.5, len * 0.46, 2.4 * zz, 0, 0, PI2); c.fill() }
            drawBamboo(c, b.x, b.y - (b.landed ? 2.2 * zz : 0), b.rot, len, zz)
        }
    }

    // ═══ 입자 ═══
    func drawPt(_ c: SceneCv, _ p: Pt, _ al: Double) {
        let kk = p.type; let r = p.r != 0 ? p.r : 1
        c.globalAlpha(clamp(al, 0, 1))
        if kk == "heart" { c.fillStyle("#ff6b9a"); SceneArt.heartP(c, p.x, p.y, 3.4 * r) }
        else if kk == "star" { c.fillStyle("#ffd54f"); SceneArt.star4(c, p.x, p.y, 3.4 * r, p.rot + p.age * 4) }
        else if kk == "gold" { let ga = clamp(al, 0, 1); c.globalAlpha(1); SceneArt.sparkle(c, p.x, p.y, 3.4 * r, p.rot + p.age * 3, ga) }      // s415 노란 ✨
        else if kk == "spark" { c.fillStyle("#fffbe0"); SceneArt.star4(c, p.x, p.y, 2.6 * r, p.rot) }
        else if kk == "leaf" { c.fillStyle(p.hasCol ? p.col : css("#d9772b")); c.save(); c.translate(p.x, p.y); c.rotate(p.rot + p.age * 5); c.beginPath(); c.ellipse(0, 0, 2.6, 1.4, 0, 0, PI2); c.fill(); c.restore() }
        else if kk == "drop" { c.fillStyle("rgba(130,190,250,.95)"); c.beginPath(); c.arc(p.x, p.y, 2.1, 0, PI2); c.fill(); c.fillStyle("rgba(255,255,255,.8)"); c.beginPath(); c.arc(p.x - 0.6, p.y - 0.6, 0.7, 0, PI2); c.fill() }
        else if kk == "dirt" { c.fillStyle("#7d5a37"); c.beginPath(); c.arc(p.x, p.y, 1.7, 0, PI2); c.fill() }
        else if kk == "bub" { c.strokeStyle("rgba(255,255,255,.95)"); c.fillStyle("rgba(190,225,255,.35)"); c.lineWidth(0.9); c.beginPath(); c.arc(p.x, p.y, 2.2 * r, 0, PI2); c.fill(); c.stroke() }
        else if kk == "feather" { c.fillStyle("#f2ece0"); c.strokeStyle("#8a6a46"); c.lineWidth(0.6); c.save(); c.translate(p.x, p.y); c.rotate(sin(p.age * 6 + p.rot) * 0.9); c.beginPath(); c.ellipse(0, 0, 4.2, 1.5, 0, 0, PI2); c.fill(); c.stroke(); c.restore() }
        else if kk == "note" || kk == "zzz" { c.fillStyle(kk == "note" ? "#ff7aa5" : "#8aa0c8"); c.font(jr(7 + 3 * r)); c.fillTextC(!p.txt.isEmpty ? p.txt : (kk == "note" ? "♪" : "z"), p.x, p.y) }
        else if kk == "sweat" { let sr = p.r != 0 ? p.r : 1; c.fillStyle("rgba(150,210,255,.95)"); c.beginPath(); c.moveTo(p.x, p.y - 3 * sr); c.quadTo(p.x + 2.4 * sr, p.y + 0.6 * sr, p.x, p.y + 2.2 * sr); c.quadTo(p.x - 2.4 * sr, p.y + 0.6 * sr, p.x, p.y - 3 * sr); c.fill() }
        else if kk == "flake" { c.fillStyle("#ffffff"); c.beginPath(); c.arc(p.x, p.y, 1.5, 0, PI2); c.fill(); c.strokeStyle("rgba(190,215,245,.8)"); c.lineWidth(0.5); c.stroke() }
        else if kk == "breath" {
            let bu = clamp(p.age / p.life, 0, 1), br = (2.2 + bu * 4.2) * (p.r != 0 ? p.r : 1)
            c.globalAlpha(clamp(0.7 * (1 - bu), 0, 1)); c.fillStyle(L.night ? "#e6f0ff" : "#ffffff"); c.beginPath(); c.arc(p.x, p.y, br, 0, PI2); c.fill(); c.beginPath(); c.arc(p.x + br * 0.8 * (p.vx >= 0 ? 1 : -1), p.y - br * 0.3, br * 0.7, 0, PI2); c.fill()
        }
        else if kk == "ring" { let ru = clamp(p.age / p.life, 0, 1); c.strokeStyle("rgba(235,248,255,.9)"); c.lineWidth(1); c.beginPath(); c.ellipse(p.x, p.y, 3 + ru * 13, (3 + ru * 13) * 0.34, 0, 0, PI2); c.stroke() }
        c.globalAlpha(1)
    }

    // 소품(몸에 붙어 따라다니는 것): dx 는 바라보는 쪽으로 +, dy 는 발 기준 위로 −. abs 이면 화면 좌표 그대로.
    func drawProps(_ c: SceneCv, _ a: Actor, _ front: Bool) {
        guard let prs = a.pr else { return }
        let zz = zs(a.z), y0 = zy(a.z) + a.y - liftOf(a), h = HH(a), T = t; let dr = Double(a.dir)
        for p in prs {
            if p.front != front { continue }
            let X = p.abs ? p.x : a.x + a.ox + dr * p.dx, Y = p.abs ? p.y : y0 + p.dy; let k = p.k
            c.save()
            switch k {
            case "stars":
                c.fillStyle("#ffd54f")
                for i in 0..<3 { let an = T * 5 + Double(i) * 2.1; SceneArt.star4(c, X + cos(an) * h * 0.3, Y + sin(an) * h * 0.08, 3.2 * zz, an) }
            case "rotor":                                                    // s354 챙챙: 헬리콥터 꼬리 날개(p.s = 지금 각도, p.r = 크기)
                let rad = p.r != 0 ? p.r : h * 0.42, ph = p.s
                c.fillStyle("rgba(220,235,255,.28)"); c.beginPath(); c.ellipse(X, Y, rad, rad * 0.38, 0, 0, PI2); c.fill()
                c.strokeStyle("rgba(70,80,100,.9)"); c.lineWidth(1.7 * zz); c.lineCapRound(true)
                for i in 0..<2 { let an = ph + Double(i) * PI; c.beginPath(); c.moveTo(X, Y); c.lineTo(X + cos(an) * rad, Y + sin(an) * rad * 0.38); c.stroke() }
                c.fillStyle("#55607a"); c.beginPath(); c.arc(X, Y, 1.7 * zz, 0, PI2); c.fill()
            case "ball":
                c.fillStyle("#ff7aa5"); c.beginPath(); c.arc(X, Y, p.r != 0 ? p.r : 4.4 * zz, 0, PI2); c.fill(); c.fillStyle("rgba(255,255,255,.7)"); c.beginPath(); c.arc(X - 1.3 * zz, Y - 1.4 * zz, 1.3 * zz, 0, PI2); c.fill()
            case "glasses":
                let gw = 3.5 * zz * (p.s != 0 ? p.s : 1); c.fillStyle("#12151c"); c.strokeStyle("#2a2f3d"); c.lineWidth(0.8)
                c.beginPath(); c.ellipse(X - gw * 0.85 * dr, Y, gw, gw * 0.75, 0, 0, PI2); c.fill(); c.beginPath(); c.ellipse(X + gw * 0.85 * dr, Y, gw, gw * 0.75, 0, 0, PI2); c.fill()
                c.beginPath(); c.moveTo(X - gw * 0.1, Y - gw * 0.1); c.lineTo(X + gw * 0.1, Y - gw * 0.1); c.stroke(); c.fillStyle("rgba(255,255,255,.55)"); c.beginPath(); c.arc(X - gw * 1.1 * dr, Y - gw * 0.3, gw * 0.22, 0, PI2); c.fill()
            case "binoc":
                let bw = 3.6 * zz; c.fillStyle("#2b303b"); c.strokeStyle("#11141b"); c.lineWidth(0.8)
                c.beginPath(); c.arc(X - bw * 0.85 * dr, Y, bw, 0, PI2); c.fill(); c.stroke(); c.beginPath(); c.arc(X + bw * 0.85 * dr, Y, bw, 0, PI2); c.fill(); c.stroke()
                c.fillRect(X - bw * 0.5, Y - bw * 0.3, bw, bw * 0.6); c.fillStyle("rgba(140,200,255,.8)"); c.beginPath(); c.arc(X - bw * 1.0 * dr, Y, bw * 0.55, 0, PI2); c.fill(); c.beginPath(); c.arc(X + bw * 0.7 * dr, Y, bw * 0.55, 0, PI2); c.fill()
            case "bone":
                let bl = h * 0.27; c.save(); c.translate(X, Y); c.rotate(-0.18 * dr); c.fillStyle("#fff6df"); c.strokeStyle("#c9b48a"); c.lineWidth(0.8)
                c.fillRect(-bl, -2.1 * zz, bl * 2, 4.2 * zz); c.beginPath(); c.rect(-bl, -2.1 * zz, bl * 2, 4.2 * zz); c.stroke()
                let q: [[Double]] = [[-bl, -1], [-bl, 1], [bl, -1], [bl, 1]]
                for qq in q { c.beginPath(); c.arc(qq[0], qq[1] * 2.6 * zz, 2.8 * zz, 0, PI2); c.fill(); c.stroke() }
                c.fillRect(-bl - 1, -2.4 * zz, 2, 4.8 * zz); c.fillRect(bl - 1, -2.4 * zz, 2, 4.8 * zz); c.restore()
            case "lens":
                let lr = p.r != 0 ? p.r : 7 * zz; c.strokeStyle("#6b4a2c"); c.lineWidth(2.2); c.beginPath(); c.moveTo(X + lr * 0.7, Y - lr * 0.7); c.lineTo(X + lr * 1.9, Y - lr * 1.9); c.stroke()
                c.fillStyle("rgba(210,235,255,.55)"); c.beginPath(); c.arc(X, Y, lr, 0, PI2); c.fill(); c.strokeStyle("#9aa7b8"); c.lineWidth(1.4); c.stroke()
                c.fillStyle("#222")
                for i in 0..<2 { c.beginPath(); c.arc(X + sin(T * 2.4 + Double(i) * 3) * lr * 0.5, Y + cos(T * 1.7 + Double(i) * 2) * lr * 0.35, 1 * zz + 0.2, 0, PI2); c.fill() }
                c.fillStyle("rgba(255,255,255,.7)"); c.beginPath(); c.arc(X - lr * 0.4, Y - lr * 0.4, lr * 0.18, 0, PI2); c.fill()
            case "feathr":
                c.fillStyle("#f2ece0"); c.strokeStyle("#8a6a46"); c.lineWidth(0.7); c.save(); c.translate(X, Y); c.rotate(-0.5 * dr); c.beginPath(); c.ellipse(0, 0, 5 * zz, 1.8 * zz, 0, 0, PI2); c.fill(); c.stroke(); c.restore()
            case "feathg":
                c.fillStyle("#f2ece0"); c.strokeStyle("#8a6a46"); c.lineWidth(0.7); c.save(); c.translate(X, Y); c.rotate(sin(T * 5) * 0.5); c.beginPath(); c.ellipse(0, 0, 4.6, 1.6, 0, 0, PI2); c.fill(); c.stroke(); c.restore()
            case "dew":
                let dw = p.r != 0 ? p.r : 4 * zz; c.fillStyle("rgba(150,215,255,.9)"); c.strokeStyle("rgba(255,255,255,.9)"); c.lineWidth(0.9); c.beginPath(); c.arc(X, Y, dw, 0, PI2); c.fill(); c.stroke()
                c.fillStyle("rgba(255,255,255,.9)"); c.beginPath(); c.arc(X - dw * 0.35, Y - dw * 0.35, dw * 0.32, 0, PI2); c.fill()
            case "fan":
                let fr = 5.2 * zz; c.translate(X, Y); c.rotate(p.r - 0.6 * dr); c.fillStyle("#f2c94c"); c.strokeStyle("#9c6b17"); c.lineWidth(0.8)
                c.beginPath(); c.arc(0, -fr * 1.1, fr, 0, PI2); c.fill(); c.stroke(); c.strokeStyle("#9c6b17"); c.beginPath(); c.moveTo(0, -fr * 0.1); c.lineTo(0, fr * 0.9); c.stroke()
                c.strokeStyle("rgba(156,107,23,.55)"); c.lineWidth(0.6); c.beginPath(); c.moveTo(-fr * 0.6, -fr * 1.1); c.lineTo(fr * 0.6, -fr * 1.1); c.moveTo(0, -fr * 1.9); c.lineTo(0, -fr * 0.3); c.stroke()
            case "jet":
                let X2 = p.s, Y2 = p.r, dx = X2 - X, dy = Y2 - Y; c.lineCapRound(true)
                c.strokeStyle("rgba(110,185,255,.5)"); c.lineWidth(5.2 * zz); c.beginPath(); c.moveTo(X, Y); c.lineTo(X2, Y2); c.stroke()
                c.strokeStyle("rgba(214,238,255,.95)"); c.lineWidth(2.4 * zz); c.beginPath(); c.moveTo(X, Y); c.lineTo(X2, Y2); c.stroke()
                c.fillStyle("#ffffff")
                for i in 0..<5 { let u2 = (T * 3.2 + Double(i) / 5.0).truncatingRemainder(dividingBy: 1); c.beginPath(); c.arc(X + dx * u2, Y + dy * u2, 1.5 * zz, 0, PI2); c.fill() }
                c.fillStyle("rgba(190,225,255,.7)"); c.beginPath(); c.ellipse(X2, Y2, 5.5 * zz, 2.4 * zz, 0, 0, PI2); c.fill()
            case "disc":
                let dd = 6 * zz; c.save(); c.translate(X, Y); c.rotate(sin(T * 9) * 0.25); c.fillStyle("#ff8a3d"); c.strokeStyle("#b3501a"); c.lineWidth(0.8)
                c.beginPath(); c.ellipse(0, 0, dd, dd * 0.38, 0, 0, PI2); c.fill(); c.stroke(); c.fillStyle("#ffd6b0"); c.beginPath(); c.ellipse(0, -dd * 0.06, dd * 0.55, dd * 0.2, 0, 0, PI2); c.fill(); c.restore()
            case "yarn":
                let yr = 5 * zz; c.fillStyle("#ff6f91"); c.strokeStyle("#c23b62"); c.lineWidth(0.8); c.beginPath(); c.arc(X, Y - yr * 0.6, yr, 0, PI2); c.fill(); c.stroke()
                c.save(); c.translate(X, Y - yr * 0.6); c.rotate(p.r); c.beginPath(); c.arc(0, 0, yr * 0.62, 0.3, 2.7); c.moveTo(yr * 0.9, 0); c.arc(0, 0, yr * 0.9, 3.6, 5.6); c.stroke(); c.restore()
            case "cuke":
                let cl = 8 * zz; c.save(); c.translate(X, Y - cl * 0.22); c.rotate(-0.12); c.fillStyle("#4fa83d"); c.strokeStyle("#2e6b25"); c.lineWidth(0.8)
                c.beginPath(); c.ellipse(0, 0, cl, cl * 0.34, 0, 0, PI2); c.fill(); c.stroke(); c.fillStyle("#9be07e")
                for i in -2...2 { c.beginPath(); c.arc(Double(i) * cl * 0.32, -cl * 0.08, 0.9 * zz, 0, PI2); c.fill() }
                c.restore()
            case "lantern":
                let lr = 3.4 * zz; let gl = L.night ? 1.0 : 0.6
                c.fillStyle("rgba(255,215,120," + String(0.12 * gl) + ")"); c.beginPath(); c.arc(X, Y, lr * 7, 0, PI2); c.fill(); c.fillStyle("rgba(255,215,120," + String(0.2 * gl) + ")"); c.beginPath(); c.arc(X, Y, lr * 4, 0, PI2); c.fill()
                c.strokeStyle("#5a4a30"); c.lineWidth(1); c.beginPath(); c.moveTo(X - lr * 0.6, Y - lr * 1.5); c.lineTo(X, Y - lr * 2.3); c.lineTo(X + lr * 0.6, Y - lr * 1.5); c.stroke()
                c.fillStyle("#ffd54f"); c.strokeStyle("#8a6a1a"); c.beginPath(); c.rect(X - lr * 0.8, Y - lr * 1.5, lr * 1.6, lr * 2.6); c.fill(); c.stroke(); c.fillStyle("rgba(255,255,255,.7)"); c.beginPath(); c.arc(X, Y - lr * 0.1, lr * 0.45, 0, PI2); c.fill()
            case "gem":
                let gr = 5 * zz; c.fillStyle("#5fd4f0"); c.strokeStyle("#1d7f99"); c.lineWidth(0.9)
                c.beginPath(); c.moveTo(X, Y - gr); c.lineTo(X + gr, Y - gr * 0.25); c.lineTo(X, Y + gr * 0.9); c.lineTo(X - gr, Y - gr * 0.25); c.closePath(); c.fill(); c.stroke()
                c.fillStyle("rgba(255,255,255,.75)"); c.beginPath(); c.moveTo(X - gr * 0.35, Y - gr * 0.55); c.lineTo(X, Y - gr * 0.9); c.lineTo(X + gr * 0.2, Y - gr * 0.45); c.closePath(); c.fill()
            case "bamboo":
                drawBamboo(c, X, Y, p.r, h * 0.95, zz)
            case "moundhat":
                let mr = p.r != 0 ? p.r : h * 0.2; c.fillStyle("#8a6a45"); c.beginPath(); c.moveTo(X - mr, Y); c.quadTo(X - mr * 0.7, Y - mr * 1.1, X, Y - mr * 1.05); c.quadTo(X + mr * 0.7, Y - mr * 1.1, X + mr, Y); c.closePath(); c.fill()
                c.fillStyle("rgba(0,0,0,.18)"); c.beginPath(); c.arc(X - mr * 0.3, Y - mr * 0.5, mr * 0.2, 0, PI2); c.arc(X + mr * 0.35, Y - mr * 0.35, mr * 0.15, 0, PI2); c.fill()
            default: break
            }
            c.restore()
        }
    }
    // 말풍선 대신 쓰는 얼굴 스티커(씨익 웃음 · 화남)
    func drawSticker(_ c: SceneCv, _ x: Double, _ y: Double, _ k: String, _ u: Double) {
        let s: Double = u < 0.12 ? ease(u / 0.12) * 1.18 : u > 0.86 ? 1 - ease((u - 0.86) / 0.14) : 1 + sin(t * 8) * 0.03
        let angry = k == "angry"
        c.save(); c.translate(x, y); c.scale(s, s)
        c.fillStyle(angry ? "#ff6a57" : "#ffd54f"); c.strokeStyle(angry ? "#9c2a1d" : "#8a6410"); c.lineWidth(1)
        c.beginPath(); c.arc(0, 0, 9, 0, PI2); c.fill(); c.stroke()
        c.fillStyle("#3a2a14"); c.strokeStyle("#3a2a14"); c.lineCapRound(true)
        if k == "smirk" {
            c.beginPath(); c.ellipse(-3.2, -1.6, 1.1, 1.5, 0, 0, PI2); c.ellipse(3.2, -1.6, 1.1, 1.5, 0, 0, PI2); c.fill()
            c.lineWidth(1.5); c.beginPath(); c.moveTo(-4.4, 3.2); c.quadTo(0, 5.4, 5.2, 1.2); c.stroke()
            c.lineWidth(1); c.beginPath(); c.moveTo(0.8, -5); c.lineTo(5.4, -5.8); c.stroke()
        } else {
            c.lineWidth(1.6); c.beginPath(); c.moveTo(-6, -5.4); c.lineTo(-1.4, -2.8); c.moveTo(6, -5.4); c.lineTo(1.4, -2.8); c.stroke()
            c.beginPath(); c.ellipse(-3.2, -0.6, 1.1, 1.3, 0, 0, PI2); c.ellipse(3.2, -0.6, 1.1, 1.3, 0, 0, PI2); c.fill()
            c.lineWidth(1.5); c.beginPath(); c.moveTo(-3.6, 5.2); c.quadTo(0, 2.4, 3.6, 5.2); c.stroke()
            c.strokeStyle("#d32f2f"); c.lineWidth(1.5); c.beginPath(); c.moveTo(5.5, -9.5); c.quadTo(8, -9, 8.5, -6.5); c.moveTo(10, -10.5); c.quadTo(7.4, -8.5, 7.8, -12); c.stroke()
        }
        c.restore()
    }

    // 땅 위에 남는 그림(웅덩이·구멍·흙더미·깃발·거울 = 뒤쪽 / 상자·낙엽더미·풀 = 캐릭터 앞쪽)
    func drawGfx(_ c: SceneCv, _ front: Bool) {
        let T = t
        for i in stride(from: gfx.count - 1, through: 0, by: -1) { let gg = gfx[i]; if T - gg.t0 > gg.life { gfx.remove(at: i) } }
        let list = gfx
        for gg in list {
            if gg.front != front { continue }
            let age = T - gg.t0, zz = zs(gg.z), y = zy(gg.z), x = gg.x
            let al = clamp(min(age / 0.2, (gg.life - age) / 0.45), 0, 1), pop = ease(age / 0.25), hh = TH * zz; let k = gg.k
            c.save(); c.globalAlpha(al)
            switch k {
            case "puddle":
                let fade2: Double = gg.life - age < 0.9 ? clamp((gg.life - age) / 0.9, 0.2, 1) : 1
                let rx = (gg.r != 0 ? gg.r : 15) * zz * pop * fade2, ry = rx * 0.34
                c.fillStyle("rgba(98,160,222,.92)"); c.beginPath(); c.ellipse(x, y, rx, ry, 0, 0, PI2); c.fill()
                c.fillStyle("rgba(190,225,255,.7)"); c.beginPath(); c.ellipse(x - rx * 0.2, y - ry * 0.2, rx * 0.55, ry * 0.5, 0, 0, PI2); c.fill()
                c.strokeStyle("rgba(255,255,255,.85)"); c.lineWidth(0.9)
                for i in 0..<2 { let ru = (age * 0.7 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1); c.globalAlpha(al * (1 - ru)); c.beginPath(); c.ellipse(x, y, rx * (0.3 + ru * 0.7), ry * (0.3 + ru * 0.7), 0, 0, PI2); c.stroke() }
            case "hole":
                let hr = 9 * zz * pop; c.fillStyle("#7d5a37"); c.beginPath(); c.ellipse(x, y, hr * 1.25, hr * 0.48, 0, 0, PI2); c.fill(); c.fillStyle("#2c1f12"); c.beginPath(); c.ellipse(x, y + 0.3, hr, hr * 0.36, 0, 0, PI2); c.fill()
            case "mound":
                let mr = (gg.r != 0 ? gg.r : 10) * zz * pop; c.fillStyle("#8a6a45"); c.beginPath(); c.moveTo(x - mr, y); c.quadTo(x - mr * 0.6, y - mr * 0.95, x, y - mr * 0.95); c.quadTo(x + mr * 0.6, y - mr * 0.95, x + mr, y); c.closePath(); c.fill()
                c.fillStyle("rgba(0,0,0,.16)"); c.beginPath(); c.ellipse(x + mr * 0.2, y - mr * 0.25, mr * 0.45, mr * 0.18, 0, 0, PI2); c.fill()
            case "bigheart":                                                 // s354 둘숑: 땅에 닿는 순간 머리 위에 커다란 하트가 뿅 떠오른다
                let sc2 = ease(age / 0.28) * (1 + 0.09 * sin(age * 11)), yy = y - (gg.r != 0 ? gg.r : hh * 1.6) - age * 8, hs2 = hh * 0.34 * sc2
                let hg = c.radial(x, yy, 0, x, yy, hs2 * 3.4).stop(0, rgba(255, 150, 190, 0.55 * clamp(1 - age / 2.3, 0, 1))).stop(1, rgba(255, 150, 190, 0)); c.fillGrad(hg); c.beginPath(); c.arc(x, yy, hs2 * 3.4, 0, PI2); c.fill()
                c.fillStyle("#ff5c8a"); SceneArt.heartP(c, x, yy, hs2)
                c.fillStyle("rgba(255,255,255,.7)"); c.beginPath(); c.ellipse(x - hs2 * 0.6, yy - hs2 * 0.5, hs2 * 0.26, hs2 * 0.15, -0.7, 0, PI2); c.fill()
            case "wave":                                                     // s354 충격파: 땅 위로 번지는 타원 고리 두 겹
                let wr = (gg.r != 0 ? gg.r : 40) * zz
                for i in 0..<2 {
                    let wu = clamp((age - Double(i) * 0.16) / 0.75, 0, 1); if wu <= 0 { continue }
                    let rr2 = wr * (0.15 + 0.85 * ease(wu)); c.globalAlpha(0.65 * (1 - wu)); c.strokeStyle("rgba(255,244,222,.95)"); c.lineWidth((2.4 - Double(i) * 0.8) * zz * (1 - wu * 0.6)); c.beginPath(); c.ellipse(x, y, rr2, rr2 * 0.3, 0, 0, PI2); c.stroke()
                }
                c.globalAlpha(1)
            case "crack":                                                    // s354 뽀푸: 땅이 갈라진다
                let cr = hh * pop; c.strokeStyle("rgba(60,45,32,.85)"); c.lineWidth(1.3 * zz); c.lineCapRound(true)
                for i in 0..<7 {
                    let an = Double(i) * PI2 / 7 + Double((i * 53) % 7) * 0.05, ln = cr * (0.5 + Double((i * 37) % 5) / 10.0), mx2 = cos(an), my2 = sin(an) * 0.3, px2 = -my2, py2 = mx2 * 0.3
                    c.beginPath(); c.moveTo(x, y); c.lineTo(x + mx2 * ln * 0.4 + px2 * 3, y + my2 * ln * 0.4 + py2 * 3); c.lineTo(x + mx2 * ln * 0.7 - px2 * 3, y + my2 * ln * 0.7 - py2 * 3); c.lineTo(x + mx2 * ln, y + my2 * ln); c.stroke()
                }
            case "flag":
                let drop: Double = age < 0.35 ? (1 - ease(age / 0.35)) * hh * 1.2 : 0; let fh = hh * 1.05, wv = sin(T * 6) * 2.2 * zz
                c.strokeStyle("#d7dbe3"); c.lineWidth(1.8 * zz + 0.4); c.beginPath(); c.moveTo(x, y - drop); c.lineTo(x, y - drop - fh); c.stroke()
                c.fillStyle("#2f6fd6"); c.beginPath(); c.moveTo(x, y - drop - fh); c.quadTo(x + hh * 0.3, y - drop - fh - wv, x + hh * 0.56, y - drop - fh + wv * 0.4); c.lineTo(x + hh * 0.56, y - drop - fh + hh * 0.3 + wv * 0.4); c.quadTo(x + hh * 0.3, y - drop - fh + hh * 0.3 - wv, x, y - drop - fh + hh * 0.3); c.closePath(); c.fill()
                c.fillStyle("#fff"); c.font(jr(hh * 0.22)); c.fillTextC("길", x + hh * 0.28, y - drop - fh + hh * 0.15)
            case "mirror":
                let mw = hh * 0.6, mh = hh * 1.2; c.fillStyle("#8a6a4a"); rr(c, x - mw / 2 - 2, y - mh - 2, mw + 4, mh + 2, 5); c.fill()
                let mg = c.linear(x - mw / 2, y - mh, x + mw / 2, y).stop(0, css("#e6f3ff")).stop(1, css("#b9d6ee")); c.fillGrad(mg); rr(c, x - mw / 2, y - mh, mw, mh - 1, 4); c.fill()
                if let own = gg.own { drawReflect(c, own, x, y - mh, mw, mh - 1, hh, al) }                        // 거울 보며 짖는 친구의 얼굴이 거울에 살짝 비친다(YJ 10-29)
                c.fillStyle("rgba(255,255,255,.65)"); c.beginPath(); c.moveTo(x - mw * 0.3, y - mh + 2); c.lineTo(x - mw * 0.05, y - mh + 2); c.lineTo(x - mw * 0.35, y - mh * 0.45); c.lineTo(x - mw * 0.45, y - mh * 0.45); c.closePath(); c.fill()
            case "boxb":
                let bw = hh * BOX_W, bh = hh * BOX_H; c.fillStyle("#7a5530"); c.beginPath(); c.ellipse(x, y - bh, bw * 0.5, bw * 0.17, 0, 0, PI2); c.fill()
                c.fillStyle("#b98a52"); c.fillRect(x - bw * 0.5, y - bh - 1, bw, 2)
            case "boxf":
                let bw2 = hh * BOX_W, bh2 = hh * BOX_H; c.fillStyle("#c99a62"); c.strokeStyle("#8f6a3c"); c.lineWidth(1); c.fillRect(x - bw2 * 0.5, y - bh2, bw2, bh2); c.beginPath(); c.rect(x - bw2 * 0.5, y - bh2, bw2, bh2); c.stroke()
                c.fillStyle("#e9d6a9"); c.fillRect(x - bw2 * 0.09, y - bh2, bw2 * 0.18, bh2); c.fillStyle("rgba(0,0,0,.1)"); c.fillRect(x - bw2 * 0.5, y - 3, bw2, 3)
                c.fillStyle("#b98a52"); c.beginPath(); c.moveTo(x - bw2 * 0.5, y - bh2); c.lineTo(x - bw2 * 0.62, y - bh2 - bh2 * 0.14); c.lineTo(x - bw2 * 0.5, y - bh2 - 2); c.closePath(); c.fill()
                c.beginPath(); c.moveTo(x + bw2 * 0.5, y - bh2); c.lineTo(x + bw2 * 0.62, y - bh2 - bh2 * 0.14); c.lineTo(x + bw2 * 0.5, y - bh2 - 2); c.closePath(); c.fill()
            case "pile":
                let pw = hh * 1.15
                var bump = 1.0
                if gg.bump != 0 && T - gg.bump < 0.35 { bump = 1 + sin((T - gg.bump) * 24) * 0.08 * (1 - (T - gg.bump) / 0.35) }
                if gg.cs == nil {
                    let leafc = ["#d9772b", "#c4452d", "#e8b23a", "#9c5a2a", "#cf6a2a"]; var arr: [Chip] = []
                    for _ in 0..<54 {
                        let q = Chip(); q.dx = (R.next() - 0.5) * 1.9; q.dy = R.next() * R.next(); q.r = 0.1 + R.next() * 0.08
                        if gg.snow { q.col = R.next() < 0.5 ? css("#ffffff") : css("#e3eefa") } else { q.col = css(pickOf(leafc)) }
                        arr.append(q)
                    }
                    gg.cs = arr
                }
                for q in gg.cs! {
                    let cx = x + q.dx * pw * 0.5, cy = y - 2 - q.dy * hh * 0.6 * (1 - q.dx * q.dx * 0.85) * bump
                    c.fillStyle(q.col); c.beginPath(); c.arc(cx, cy, q.r * hh * 0.95 * pop + 0.8, 0, PI2); c.fill()
                }
            case "grass":
                for i in 0..<9 {
                    let gx = x + Double(i - 4) * hh * 0.1, gh = hh * (0.55 + Double((i * 37) % 7) / 20.0), sw = sin(T * 2 + Double(i)) * 1.8; c.fillStyle(i % 2 != 0 ? "#4e9a3a" : "#66b34a")
                    c.beginPath(); c.moveTo(gx - 2.2 * zz, y); c.quadTo(gx - 1 + sw * 0.4, y - gh * 0.6, gx + sw, y - gh * pop); c.quadTo(gx + 1 + sw * 0.4, y - gh * 0.6, gx + 2.2 * zz, y); c.closePath(); c.fill()
                }
            default: break
            }
            c.restore()
        }
    }
    /// 거울 속 얼굴: 친구가 지금 그리는 그림(칸)에서 머리만 오려(자른 칸 = 한 칸의 오른쪽 위) 좌우로 뒤집어 유리 안에 옅게 그린다 — 얼굴만 살짝. 유리 사각형 (x 가운데, gTop 위, gw 폭, gh 높이).
    func drawReflect(_ c: SceneCv, _ a: Actor, _ x: Double, _ gTop: Double, _ gw: Double, _ gh: Double, _ hh: Double, _ al: Double) {
        if !a.vis { return }
        var sheet: SceneImg? = nil
        if let sk = a.sk, let s = host.sheet(sk) { sheet = s } else { sheet = host.sheet(a.id) }
        guard let sh = sheet else { return }
        let idx = jmod(Int(floor(a.fr)), 16)
        let sx = Double(idx % 4) * 256 + 112, sy = Double(idx / 4) * 256 + 56, cw = 118.0, d = min(gw * 0.9, gh * 0.62)      // 머리 칸(원본 기준 오른쪽 위)
        c.save(); rr(c, x - gw / 2, gTop, gw, gh, 4); c.clip()
        c.globalAlpha(al * 0.5)
        c.translate(x, gTop + gh * 0.1 + d * 0.5); if a.dir > 0 { c.scale(-1, 1) }       // 보는 쪽이 오른쪽이면 거울에서는 반대
        c.drawImage(sh, sx, sy, cw, cw, -d * 0.5, -d * 0.5, d, d)
        c.restore()
        c.fillStyle("rgba(225,240,255,.2)"); rr(c, x - gw / 2, gTop, gw, gh, 4); c.fill()             // 유리 한 겹(얼굴이 옅게 비치도록)
    }

    // ═══ 캐릭터 한 명 ═══
    func drawActor(_ c: SceneCv, _ a: Actor) {
        if !a.vis { return }
        let D = a.D
        var sheetO: SceneImg? = nil
        if a.intro { sheetO = host.intro() } else if let sk = a.sk, let s = host.sheet(sk) { sheetO = s } else { sheetO = host.sheet(a.id) }
        guard var sheet = sheetO else { return }
        let psh: SceneImg? = (!a.intro && a.pose >= 0) ? host.sheet(a.id + "_pose") : nil          // 자세 시트가 없으면(옛 설치·읽기 실패) 걷기 시트로 그린다
        let ash: SceneImg? = (!a.intro && a.cell >= 0) ? host.sheet(a.id + "_act") : nil           // 전용 동작 시트(쮸르·베비히포) — 없으면 자세·걷기 시트로 대신
        let zz = zs(a.z), s = a.k * zz * (a.held ? 1.12 : 1), sc = D.cell / 256 * s, y = zy(a.z)
        var idx = a.intro ? a.ii : jmod(Int(floor(a.fr)), 16)
        if let ash = ash { sheet = ash; idx = max(0, min(15, a.cell)) }
        else if let psh = psh { sheet = psh; idx = max(0, min(7, a.pose)) }
        let wh: SceneWearHook? = a.intro ? nil : SceneCore.wearHook                                  // 자녀가 꾸민 옷(연동된 부모만) — 두덩이 새 모자를 쓰면 안전모 없는 시트로
        if let wh = wh, psh == nil { if let nh = wh.nh(a.id, ash != nil) { sheet = nh } }
        let lift = (D.lift + a.alt) * zz * (a.kind == "eagle" ? 1 : s / a.k)
        let shA = (L.night ? 0.22 : 0.34) * (a.kind == "eagle" ? 0.7 : 1) * (L.wk == "rain" || L.wk == "overcast" ? 0.7 : 1)
        let sunk = !a.cut.isNaN && a.y > TH * zz * 0.9
        if !sunk {
            let air = max(0, -a.y) + a.alt                                                                // s354: 떠 있는 높이만큼 그림자가 작고 옅어진다(떨어질수록 커지며 짙어진다)
            let aAl: Double = air > 0 ? clamp(1 - air / 110, 0.3, 1) : 1
            c.fillStyle(rgba(0, 0, 0, shA * a.fade * aAl))
            let sqk: Double = (a.sq != 0 || a.sy < 0.9) ? 1.15 : 1
            let sxk = abs(a.sx != 0 ? a.sx : 1)
            let airK: Double = air > 0 ? clamp(1 - air / 300, 0.6, 1) : 1
            c.beginPath(); c.ellipse(a.x + a.ox, y + 1, D.cell * s * 0.2 * sqk * sxk * airK, 3.2 * zz * airK, 0, 0, PI2); c.fill()
        }
        let sx = Double(idx % 4) * 256, sy = Double(idx / 4) * 256, dx = -D.ox * sc, dy = -D.base * sc - lift + (a.feetScale ? 0 : a.y)
        if a.sl > 0 { starLight(c, a, false, s, y) }                                                  // s415 뽀푸: 몸 뒤쪽 노란 빛무리(몸에 거는 변환 밖 — 화면 좌표)
        c.save()
        if !a.cut.isNaN { c.beginPath(); c.rect(a.x - D.cell * s, y - D.cell * s * 2.4, D.cell * s * 2, D.cell * s * 2.4 - a.cut); c.clip() }
        c.translate(a.x + a.ox, y + (a.feetScale ? a.y : 0)); if a.dir < 0 { c.scale(-1, 1) }; if a.sx != 1 || a.sy != 1 { c.scale(a.sx, a.sy) }
        if a.ang != 0 { let px = a.pvx, py = a.pvy; c.translate(px, py); c.rotate(a.ang); c.translate(-px, -py) }
        if a.heart > 0 || a.fade < 1 { c.globalAlpha(clamp((a.heart > 0 ? 1 - a.heart * 1.05 : 1) * a.fade, 0, 1)) }    // 몸이 하트로 바뀌는 동안 · 별빛으로 흩어졌다 모이는 동안 원래 그림은 옅어진다
        if a.fade > 0.004 { c.drawImage(sheet, sx, sy, 256, 256, dx, dy, D.cell * s, D.cell * s) }
        if let wh = wh, a.fade > 0.004 { wh.draw(c, a, ash != nil ? 2 : psh != nil ? 1 : 0, idx, dx, dy, D.cell * s / 256) }
        if a.heart > 0 {                                                                         // s354 둘숑: 하트 모양 몸(풍선처럼 부푼 몸이 땅에 닿는 순간)
            let hs = TH * zz * 0.3, hk = ease(a.heart); c.globalAlpha(clamp(hk, 0, 1))
            let hy = -TH * zz * 0.5, hr = hs * (0.6 + 0.4 * hk)
            c.fillStyle("#ee4d7e"); SceneArt.heartP(c, 0, hy, hr)                                  // 겉(진한 분홍) → 안쪽 밝은 분홍 → 반짝 하이라이트
            c.fillStyle("#ff7ba5"); SceneArt.heartP(c, -hr * 0.03, hy - hr * 0.04, hr * 0.8)
            c.fillStyle("rgba(255,255,255,.8)"); c.beginPath(); c.ellipse(-hr * 0.62, hy - hr * 0.52, hr * 0.26, hr * 0.15, -0.7, 0, PI2); c.fill()
            c.globalAlpha(1)
        }
        c.globalAlpha(1)
        c.restore()
        if a.umb { SceneArt.drawUmbrella(c, a.x + Double(a.dir) * 2, y - TH * zz * 0.98 + a.y, zz, a.id) }
        drawProps(c, a, true)
        if a.sl > 0 { starLight(c, a, true, s, y) }                                                  // s415 뽀푸: 몸 앞쪽 ✨ 별빛
    }
    /// s415 뽀푸 별빛(YJ 2026-11-03: 공중에서 노란 별빛이 몸을 감싸고 → 땅에 닿는 순간 흩어지고 → 빛이 다시 모여 뽀푸가 된다, ✨ 모양으로 반짝).
    /// 언제 어떤 단계인지(a.sl) · 얼마나 진행됐는지(a.slU)는 엔진이 고른 land 동작(L_star)이 정한다. 여기서는 그 값대로 점 위치·크기·투명도만 계산해 그린다(무작위 없음).
    func starLight(_ c: SceneCv, _ a: Actor, _ front: Bool, _ s: Double, _ footY: Double) {
        let h = HH(a), u = a.slU, T = t, cx = a.x + a.ox, cy = footY + a.y - h * 0.5
        if a.sl == 1 {                                                                           // 감싸는 별빛: 후광 + 몸 둘레를 도는 ✨ + 위로 흩날리는 꼬리
            if !front { SceneArt.halo(c, cx, cy, h * 0.95, h * 0.95, 0.9 * u); return }
            for i in 0..<SL_N {
                let di = Double(i)
                let ph = di * 2.39996, orb = T * (1.9 + Double(i % 3) * 0.35) + ph, rad = h * (0.52 + 0.2 * Double((i * 7) % 5) / 4.0), bz = sin(orb)
                let tw = 0.55 + 0.45 * sin(T * 8.5 + di * 1.7), sz = h * (0.09 + 0.06 * Double((i * 5) % 4) / 3.0) * (0.7 + 0.5 * tw)
                if i < 10 {
                    let back: Double = (bz < 0 && i % 2 == 0) ? 0.75 : 1
                    SceneArt.sparkle(c, cx + cos(orb) * rad, cy + bz * rad * 0.55 - h * 0.04, sz, T * 1.3 + ph, u * back * tw)       // 몸 둘레를 도는 별빛
                } else {                                                                             // 떨어지는 몸 위쪽으로 길게 이어지는 꼬리 별빛
                    let fl = (T * 1.6 + Double(i - 10) * 0.17).truncatingRemainder(dividingBy: 1.0)
                    SceneArt.sparkle(c, cx + sin(ph * 3 + T) * h * 0.38, cy - h * (0.55 + fl * 1.5), sz * (1 - fl * 0.7), T * 2 + ph, u * (1 - fl) * tw)
                }
            }
        } else if a.sl == 2 {                                                                    // 흩어짐: 몸이 있던 자리에서 별빛이 사방으로 퍼지며 사라진다
            if !front { SceneArt.halo(c, cx, cy, h * (1 + 1.6 * u), h * (1 + 1.6 * u), 0.85 * (1 - u) * (1 - u)); return }
            let eo = 1 - (1 - u) * (1 - u) * (1 - u)
            for i in 0..<(SL_N + 10) {
                let di = Double(i)
                let ph = di * 2.39996, d = h * (0.25 + 1.55 * (0.45 + 0.55 * Double((i * 11) % 7) / 6.0) * eo), an = ph, tw = 0.6 + 0.4 * sin(T * 12 + di * 2.1)
                let sz = h * (0.1 + 0.09 * Double((i * 5) % 4) / 3.0) * (1 - 0.5 * u) * (0.75 + 0.4 * tw)
                SceneArt.sparkle(c, cx + cos(an) * d * 1.15, cy + sin(an) * d * 0.8 - eo * h * 0.15, sz, T * 2.2 + ph, (1 - u * u) * tw)
            }
        } else if a.sl == 3 {                                                                    // 다시 모임: 흩어졌던 빛이 한 점으로 소용돌이치며 모여 뽀푸의 모습이 된다
            let gi = 1 - u, eg = gi * gi
            if !front { SceneArt.halo(c, cx, cy, h * (0.55 + 0.5 * u), h * (0.55 + 0.5 * u), (0.25 + 0.65 * u * u)); return }
            for i in 0..<(SL_N + 10) {
                let di = Double(i)
                let ph = di * 2.39996, d = h * (0.18 + 1.65 * (0.45 + 0.55 * Double((i * 11) % 7) / 6.0) * eg), an = ph + gi * 2.6, tw = 0.6 + 0.4 * sin(T * 12 + di * 2.1)
                let sz = h * (0.1 + 0.1 * Double((i * 5) % 4) / 3.0) * (0.6 + 0.5 * u) * (0.75 + 0.4 * tw)
                let tail: Double = u > 0.92 ? (1 - u) / 0.08 : 1
                SceneArt.sparkle(c, cx + cos(an) * d * 1.15, cy + sin(an) * d * 0.8, sz, -T * 2.2 + ph, clamp(u * 2.2, 0, 1) * tail * tw)
            }
        } else if a.sl == 4 {                                                                    // 여운: 뽀푸가 웃는 동안 몇 개의 ✨ 가 반짝이며 사그라든다
            if !front { SceneArt.halo(c, cx, cy, h * 1.05, h * 1.05, 0.5 * (1 - u)); return }
            for i in 0..<7 {
                let di = Double(i)
                let ph = di * 2.39996, an = ph + T * 0.9, rad = h * (0.88 + 0.12 * Double(i % 3)), tw = 0.5 + 0.5 * sin(T * 7 + di * 1.9)
                SceneArt.sparkle(c, cx + cos(an) * rad, cy + sin(an) * rad * 0.75 - h * 0.05, h * (0.055 + 0.04 * Double(i % 3) / 2.0) * (0.6 + 0.6 * tw), T + ph, (1 - u) * tw)
            }
        }
    }

    // ═══ 하늘 · 날씨 ═══
    func pal() -> SceneArt.Pal { L }
    func drawSkyFx(_ c: SceneCv, _ tt: Double) {
        let Lk = L; let wk = Lk.wk
        if (Lk.night || Lk.slot == "dawn") && wk != "overcast" && wk != "rain" && wk != "snow" {
            let sa: Double = Lk.night ? 1 : 0.5
            let dim2: Double = (wk == "cloudy" || wk == "fog") ? 0.5 : 1
            for q in wxP.stars {
                c.fillStyle(rgba(255, 255, 255, (0.35 + 0.45 * sin(tt * 2 + q[2])) * sa * dim2)); c.beginPath(); c.arc(q[0] * W, q[1] * g.hy, q[3], 0, PI2); c.fill()
            }
            if Lk.night && wk == "clear" {
                let ph = (tt.truncatingRemainder(dividingBy: 14)) / 14
                if ph < 0.1 { let u = ph / 0.1; c.strokeStyle(rgba(255, 255, 255, 0.8 * (1 - u))); c.lineWidth(1.3); c.beginPath(); c.moveTo(W * (0.2 + u * 0.18), 8 + u * 22); c.lineTo(W * (0.2 + u * 0.18) - 14, 8 + u * 22 - 6); c.stroke() }
            }
        }
        let dk: Double = Lk.night ? 0.75 : Lk.lit ? 0.35 : 0
        var cc: ARGB
        if wk == "overcast" || wk == "rain" { cc = mix("#aeb6c2", "#2a3140", clamp(dk + 0.1, 0, 0.9)) }
        else if wk == "snow" { cc = mix("#e3e9f2", "#3a4256", dk) }
        else if wk == "fog" { cc = mix("#dfe4ea", "#444c5e", dk) }
        else {
            let tgt = Lk.slot == "evening" ? "#ff9f80" : Lk.slot == "dawn" ? "#c9a0c0" : "#1c2440"
            let amt: Double = Lk.night ? 0.85 : Lk.lit ? 0.35 : 0
            cc = mix(css("#ffffff"), css(tgt), amt)
        }
        for q in wxP.clouds {
            let x = ((q[0] * (W + 90) + tt * 4 * q[3] * SceneFx.cloudSpeed(Lk)).truncatingRemainder(dividingBy: W + 90)) - 45, y = 8 + q[1] * g.hy
            SceneArt.cloud(c, x, y, 8 * q[2] * ((wk == "overcast" || wk == "rain") ? 1.3 : 1), cc)
        }
        if wk == "clear" && (Lk.slot == "morning" || Lk.slot == "noon" || Lk.slot == "afternoon") {
            c.strokeStyle("rgba(40,50,70,.55)"); c.lineWidth(1.1)
            for q in wxP.birds {
                let x = ((q[0] * (W + 40) + tt * 14 * q[2]).truncatingRemainder(dividingBy: W + 40)) - 20, y = 14 + q[1] * g.hy + sin(tt * 1.5 + q[3]) * 3, f = sin(tt * 9 + q[3]) * 2.2
                c.beginPath(); c.moveTo(x - 4, y + f); c.quadTo(x - 1.5, y - 2, x, y); c.quadTo(x + 1.5, y - 2, x + 4, y + f); c.stroke()
            }
        }
    }
    func drawWxFront(_ c: SceneCv, _ tt: Double) {
        let Lk = L
        if Lk.wk == "rain" {
            c.strokeStyle(Lk.night ? "rgba(170,200,255,.5)" : "rgba(110,140,190,.6)"); c.lineWidth(1); c.beginPath()
            for q in wxP.rain {
                let y = ((q[1] * (H + 20) + tt * 210 * q[2]).truncatingRemainder(dividingBy: H + 20)) - 10
                let x = ((q[0] * (W + 30) - y * (0.22 + 0.12 * Double(Lk.wind)) + W + 30).truncatingRemainder(dividingBy: W + 30)) - 5
                c.moveTo(x, y); c.lineTo(x - 1.6 - 1.4 * Double(Lk.wind), y - q[3])
            }
            c.stroke()
            for rp in ripples {
                let u = (tt - rp.t0) / 0.8; if u >= 1 { continue }
                c.strokeStyle(rgba(220, 235, 255, 0.55 * (1 - u))); c.lineWidth(0.9); c.beginPath(); c.ellipse(rp.x, rp.y, 2 + u * 8, (2 + u * 8) * 0.28, 0, 0, PI2); c.stroke()
            }
        } else if Lk.wk == "snow" {
            c.fillStyle(Lk.night ? "rgba(255,255,255,.9)" : "rgba(255,255,255,.95)")
            for q in wxP.snow {
                let y = ((q[1] * (H + 8) + tt * 22 * q[2]).truncatingRemainder(dividingBy: H + 8)) - 4, x = (q[0] * W + sin(tt * 0.9 + q[4]) * 8 + W).truncatingRemainder(dividingBy: W)
                c.globalAlpha(0.55 + 0.4 * q[2]); c.beginPath(); c.arc(x, y, q[3], 0, PI2); c.fill()
            }
            c.globalAlpha(1)
        } else if Lk.wk == "fog" {
            for i in 0..<3 {
                let fy = g.hy - 10 + Double(i) * 22, off = sin(tt * 0.25 + Double(i) * 2) * 14
                let fg = c.linear(0, fy - 16, 0, fy + 16).stop(0, rgba(225, 230, 236, 0)).stop(0.5, rgba(225, 230, 236, Lk.night ? 0.16 : 0.42)).stop(1, rgba(225, 230, 236, 0))
                c.fillGrad(fg); c.fillRect(off - 20, fy - 16, W + 40, 32)
            }
        }
    }
    func drawParts(_ c: SceneCv, _ dt: Double) {
        for i in stride(from: pt.count - 1, through: 0, by: -1) {
            let p = pt[i]; p.age += dt; p.vy += p.g * dt; if p.age < 0 { continue }; p.x += p.vx * dt; p.y += p.vy * dt
            if p.age > p.life {
                if p.type == "bub" { let r2 = Pt(); r2.type = "ring"; r2.x = p.x; r2.y = p.y; r2.age = 0; r2.life = 0.3; r2.g = 0; r2.r = 1; pt.append(r2) }
                pt.remove(at: i); continue
            }
            let al = 1 - p.age / p.life
            if p.type == "splash" || p.type == "puff" || p.type == "dust" {
                c.fillStyle(p.type == "splash" ? rgba(160, 200, 245, al) : p.type == "puff" ? rgba(255, 255, 255, al) : rgba(200, 185, 160, al * 0.8))
                c.beginPath(); c.arc(p.x, p.y, p.type == "puff" ? 1.8 : 1.3, 0, PI2); c.fill()
            } else { drawPt(c, p, p.type == "ring" ? 1 : al * 1.4) }
        }
    }
    func drawTraffic(_ c: SceneCv, _ lane: Int) {
        for v in traffic {
            if v.lane != lane { continue }
            var o = SceneArt.VehOpt(); o.color = v.color; o.rot = v.rot; o.no = v.no; o.dir = v.dir; o.night = L.night || (L.lit && L.slot != "dawn")
            if v.bus { SceneArt.drawBus(c, v.x, laneGy(lane), v.L, o) } else { SceneArt.drawCar(c, v.x, laneGy(lane), v.L, o) }
        }
    }
    /// 길 아래 바닥(인도). 바닥 그림은 처음부터 카드가 가장 길게 늘어난 높이(H + g.ext)까지 같은 무늬로 이어 그려 두었다 — 늘어난 만큼 그 위쪽 부분을 1:1 로 더 보여 줄 뿐 그림을 늘이지 않는다.
    func drawGnd(_ c: SceneCv) {
        let show = min(H + stretch, H + g.ext)
        if show <= H + 0.01 { c.drawImage(bg.gnd, 0, 0, jr(W * dpr), jr(H * dpr), 0, 0, W, H); return }
        let hp = jr(show * dpr); c.drawImage(bg.gnd, 0, 0, jr(W * dpr), hp, 0, 0, W, hp / dpr)
    }
    func drawStreet(_ c: SceneCv, _ dt: Double) {
        let tw = Double(bg.tw)
        if inside {                                           // 역 안 승강장: 실내라서 하늘·날씨·바람 효과 없이 승강장만 그린다
            ScenePlatform.back(self, c)
        } else if pan >= 0 && panBg != nil {                      // 장소 이동 중: 캐릭터와 함께 옛 배경이 새 배경으로 겹쳐 이어진다
            drawPanBack(c)
        } else {
            c.drawImage(bg.sky, 0, 0, W, H); drawSkyFx(c, t)
            c.drawImage(bg.far, 0, 0, tw, H); SceneFx.drawMid(self, c, bg.mid, bg.tw); drawGnd(c)
            SceneFx.ambient(self, c, t)
        }
        drawTrafficPan(c, 0); drawTraffic(c, 0)
        if let q = seq, q.busOn {
            var o = SceneArt.VehOpt(); o.color = q.color; o.door = q.door; o.door2 = 0; o.dir = 1; o.rot = q.busX * 0.12; o.no = busLabel(); o.night = L.night
            SceneArt.drawBus(c, q.busX, g.nearTop - 3, q.L, o)
        }
        drawTrafficPan(c, 1); drawTraffic(c, 1)
        if !inside && (mode == "wait" || mode == "alight") { if venue == "sub" { SceneArt.drawEntrance(c, g, entX, L, res.line) } else { SceneArt.drawStop(c, g, stopX, L) } }
        drawGfx(c, false); drawBams(c, false)
        var arr: [Actor] = []; for a in actors where a.vis { arr.append(a) }
        arr = arr.enumerated().sorted { (p, q) in
            let za = p.element.held ? 9.0 : p.element.z, zb = q.element.held ? 9.0 : q.element.z
            return za != zb ? za < zb : p.offset < q.offset
        }.map { $0.element }
        for a in arr { drawActor(c, a) }
        drawGfx(c, true); drawBams(c, true)
        for a in arr {
            guard let sk = a.stk else { continue }
            let su = (t - sk.t0) / sk.dur
            if su >= 1 { a.stk = nil } else { drawSticker(c, a.x + Double(a.dir) * a.w * 0.12, zy(a.z) - TH * zs(a.z) * 1.12 - 12 - (!a.bub.isEmpty ? 16 : 0) + min(0, a.y), sk.k, su) }
        }
        for a in arr where !a.bub.isEmpty { let y = zy(a.z) - TH * zs(a.z) - 6 + a.y, x = a.x + Double(a.dir) * a.w * 0.2; SceneArt.drawBubble(c, x, y, a.bub) }
        drawParts(c, dt)
        if inside { return }                                      // 실내: 비·눈·안개·바람·햇빛·더위·추위 효과는 그리지 않는다
        if pan >= 0 && panBg != nil { drawPanFront(c) } else { drawWxFront(c, t) }
        SceneFx.cold(self, c); SceneFx.sun(self, c, t); SceneFx.heat(self, c, t); SceneFx.wind(self, c, t)
    }

    // ═══ 버스 안(타고 가는 중) ═══
    func drawRide(_ c: SceneCv) {
        guard let Rd = ride, let h = hero else { return }
        let D = h.D, Lk = L, col = busColor
        let roofY = 7.0, floorY = H - 37, bodyBot = H - 22, wy0 = 22.0, wy1 = 76.0
        // 길(아래)
        c.fillStyle(mix("#6c7078", "#0d1018", clamp(1 - Lk.lum, 0, 0.9) * 0.75)); c.fillRect(0, H - 14, W, 14)
        c.fillStyle("rgba(255,255,255,.55)"); let dOff = (Rd.scroll * 1.6).truncatingRemainder(dividingBy: 30); var dx = -dOff; while dx < W { c.fillRect(dx, H - 6, 15, 1.8); dx += 30 }
        // 차체(안쪽 벽)
        let wall = c.linear(0, roofY, 0, floorY).stop(0, css(Lk.night ? "#4a4f68" : "#e8edf3")).stop(1, css(Lk.night ? "#2f3348" : "#cfd7e1"))
        c.fillStyle(shade(col, -0.2)); rr(c, 4, roofY - 3, W - 8, bodyBot - roofY + 5, 10); c.fill()
        c.fillGrad(wall); rr(c, 8, roofY, W - 16, floorY - roofY, 7); c.fill()
        // 창밖(하늘·도시·가로수) — 창 모양으로 잘라서 보여준다
        var wins: [[Double]] = []; let pw = (W - 28) / 5
        for i in 0..<5 { wins.append([14 + Double(i) * pw + 2, wy0, pw - 4, wy1 - wy0]) }
        c.save(); c.beginPath(); for r in wins { c.rect(r[0], r[1], r[2], r[3]) }; c.clip()
        c.drawImage(bg.sky, 0, 0, W, H)
        drawSkyFx(c, t)
        let tw = Double(bg.tw); let fo = (Rd.scroll * 0.35).truncatingRemainder(dividingBy: tw), mo = (Rd.scroll * 0.9).truncatingRemainder(dividingBy: tw)
        c.drawImage(bg.far, -fo, 0, tw, H); c.drawImage(bg.far, tw - fo, 0, tw, H)
        c.drawImage(bg.mid, -mo, 0, tw, H); c.drawImage(bg.mid, tw - mo, 0, tw, H)
        c.fillStyle(mix("#8d8678", "#14182a", clamp(1 - Lk.lum, 0, 0.9) * 0.7)); c.fillRect(0, g.hy + 3, W, 40)          // 건너편 인도
        let lp = (Rd.scroll * 1.1).truncatingRemainder(dividingBy: 90)
        var lx = -lp + 20
        while lx < W {
            c.fillStyle("#39404f"); c.fillRect(lx, g.hy - 18, 2, 24)
            if Lk.lit { let lg = c.radial(lx + 1, g.hy - 19, 0, lx + 1, g.hy - 19, 16).stop(0, rgba(255, 224, 140, 0.8)).stop(1, rgba(255, 224, 140, 0)); c.fillGrad(lg); c.fillRect(lx - 16, g.hy - 36, 34, 34) }
            c.fillStyle(Lk.lit ? "#fff0b0" : "#9aa3b2"); c.beginPath(); c.arc(lx + 1, g.hy - 19, 2.2, 0, PI2); c.fill()
            lx += 90
        }
        if Lk.night { c.fillStyle("rgba(6,10,30,.22)"); c.fillRect(0, 0, W, H) }
        drawWxFront(c, t)
        // 창 유리 반사
        c.fillStyle("rgba(255,255,255,.1)")
        for r in wins { c.beginPath(); c.moveTo(r[0] + 6, r[1]); c.lineTo(r[0] + 16, r[1]); c.lineTo(r[0] + 4, r[1] + r[3]); c.lineTo(r[0] - 6, r[1] + r[3]); c.closePath(); c.fill() }
        c.restore()
        // 창틀
        c.strokeStyle(shade(col, -0.25)); c.lineWidth(2.4); for r in wins { rr(c, r[0], r[1], r[2], r[3], 3); c.stroke() }
        // 천장 손잡이 봉 + 손잡이
        c.fillStyle("#c9ced8"); c.fillRect(12, 14, W - 24, 2.4); c.fillStyle("rgba(0,0,0,.18)"); c.fillRect(12, 16.4, W - 24, 1)
        let bumpAdd: Double = (t - Rd.bump < 0.4) ? sin((t - Rd.bump) * 30) * 0.05 * (1 - (t - Rd.bump) / 0.4) : 0
        let sway = sin(t * 2.1 + Rd.scroll * 0.01) * 0.05 - Rd.acc * 0.06 + bumpAdd
        let hs = [W * 0.28, W * 0.46, W * 0.64, W * 0.82]
        for k2 in 0..<4 {
            c.save(); c.translate(hs[k2], 16); c.rotate(sway * (k2 % 2 != 0 ? 1 : 0.85)); c.strokeStyle("#4b5263"); c.lineWidth(1.5); c.beginPath(); c.moveTo(0, 0); c.lineTo(0, 24); c.stroke()
            c.strokeStyle("#ffb347"); c.lineWidth(2.2); c.beginPath(); c.arc(0, 29, 5, 0, PI2); c.stroke(); c.restore()
        }
        // 좌석(창 아래 벽 쪽)
        let sc2 = shade(col, 0.1)
        for i in 0..<4 {
            let sx1 = 22 + Double(i) * (W - 40) / 4 + 6
            c.fillStyle(shade(sc2, -0.12)); rr(c, sx1, floorY - 46, 30, 30, 6); c.fill(); c.fillStyle(sc2); rr(c, sx1 + 2, floorY - 44, 26, 12, 5); c.fill()
            c.fillStyle(shade(sc2, -0.2)); rr(c, sx1 - 3, floorY - 18, 36, 14, 5); c.fill(); c.fillStyle(sc2); rr(c, sx1 - 1, floorY - 18, 32, 8, 4); c.fill()
        }
        // 하차벨 기둥
        let bx = W * 0.9; c.fillStyle("#c9ced8"); c.fillRect(bx - 1.2, 18, 2.4, floorY - 18)
        let bellOn = res.nearEnd && (t - Rd.bellT < 1.6 ? (Int(floor(t * 4)) % 2 == 0) : true)
        c.fillStyle(bellOn ? "#ff5a4d" : "#7a2b28"); c.beginPath(); c.arc(bx, 54, 4.2, 0, PI2); c.fill()
        if bellOn { let bg2 = c.radial(bx, 54, 0, bx, 54, 14).stop(0, rgba(255, 90, 70, 0.55)).stop(1, rgba(255, 90, 70, 0)); c.fillGrad(bg2); c.fillRect(bx - 14, 40, 28, 28) }
        // 바닥
        let fl = c.linear(0, floorY - 2, 0, bodyBot).stop(0, css(Lk.night ? "#3a3a48" : "#8a8f9b")).stop(1, css(Lk.night ? "#22222c" : "#5e626d")); c.fillGrad(fl); c.fillRect(8, floorY - 1, W - 16, bodyBot - floorY + 1)
        // 대표 캐릭터(서 있다) — 가속·제동에 몸이 쏠리고 길 요철에 통통
        let kk = min(0.9, 52 / ((D.base - 8) / 256 * D.cell + D.lift * 0.6)), sc = D.cell / 256 * kk; let idx = SceneModel.stand(h.id); let sheet = host.sheet(h.id)
        let lean = clamp(-Rd.acc * 0.05, -0.12, 0.12) + sin(t * 1.8) * 0.012
        let bump2: Double = (t - Rd.bump < 0.25) ? sin((t - Rd.bump) / 0.25 * PI) * 2.6 : 0
        let bob = sin(t * 17) * 0.5 * Rd.speed - bump2
        let hx = h.x + sin(t * 0.9) * 1.5, hy = floorY - 1
        c.fillStyle("rgba(0,0,0,.28)"); c.beginPath(); c.ellipse(hx, hy + 1, D.cell * kk * 0.2, 3, 0, 0, PI2); c.fill()
        if let sh = sheet { c.save(); c.translate(hx, hy); c.rotate(lean); c.drawImage(sh, Double(idx % 4) * 256, Double(idx / 4) * 256, 256, 256, -D.ox * sc, -D.base * sc - D.lift * 0.6 * kk + bob, D.cell * kk, D.cell * kk); c.restore() }
        if !h.bub.isEmpty { SceneArt.drawBubble(c, hx + 6, hy - 52 * 1.02, h.bub) }
        // 아래 차체(띠 + 바퀴)
        let bg3 = c.linear(0, floorY + 8, 0, bodyBot).stop(0, col).stop(1, shade(col, -0.3)); c.fillGrad(bg3); rr(c, 4, floorY + 6, W - 8, bodyBot - floorY - 3, 6); c.fill()
        c.fillStyle("rgba(255,255,255,.85)"); c.fillRect(6, floorY + 12, W - 12, 3)
        for f in [0.2, 0.76] { let wx = W * f, wyc = H - 17; c.fillStyle("#10131a"); c.beginPath(); c.arc(wx, wyc, 14.5, PI, 0); c.fill(); c.fillRect(wx - 14.5, wyc - 0.5, 29, 1); SceneArt.drawWheel(c, wx, wyc, 11.5, Rd.rot) }
        // 앞쪽 행선 표지판
        c.fillStyle("#10131a"); rr(c, W - 44, 8, 34, 11, 3); c.fill(); c.fillStyle("#ffb347"); c.font(8); c.fillTextC(busLabel(), W - 27, 13.6)
        if Lk.night { let gl = c.linear(0, roofY, 0, floorY).stop(0, rgba(255, 225, 150, 0.18)).stop(1, rgba(255, 225, 150, 0)); c.fillGrad(gl); c.fillRect(8, roofY, W - 16, floorY - roofY) }
    }
}
