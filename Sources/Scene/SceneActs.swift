import Foundation

/// 캐릭터별 동작·착지 연출 한 벌(웹 _CS 의 ACT 표를 그대로 옮김) — 안드로이드 SceneActs.java.
/// ★ 어떤 동작을 어떤 순서로 하는지(acts)·놓으면 어떤 연출인지(land)는 엔진(/scene 의 traits)이 정한 '이름'이다.
///   여기는 그 이름대로 몸을 기울이고 늘리고 소품·반짝이·땅 위 그림을 그리는 곳뿐이다(판단 없음, 위치·길이는 그림 연출).
/// 파일 나눔: SceneActs(도구·돌솜·뽀푸·러블·두덩·술·챙챙) · SceneActs2(죽순이·뽀송) · SceneActs3(착지 연출 L_*·놀람·날기 등)
enum SceneActs {
    typealias Actor = SceneCore.Actor
    typealias AS = SceneCore.AS
    typealias Ini = (SceneCore, Actor, Double, AS) -> Void
    typealias Stp = (SceneCore, Actor, Double, Double, AS) -> Void
    typealias End = (SceneCore, Actor, AS) -> Void

    /// 웹의 춤 음표 키 충돌을 그대로 재현할지. true 면 웹과 동일(음표 없음).
    static let WEB_DANCE_NOTE_BUG = true

    /// 동작 하나를 등록한다. 닫힘 안에서 SceneCore 를 붙들지 않게(순환 참조 방지) 호출할 때 SceneCore 를 인자로 넘겨 준다.
    static func A_(_ S: SceneCore, _ name: String, _ dur: Double, _ ini: Ini?, _ step: Stp?, _ end: End?) {
        let a = SceneCore.Act(); a.dur = dur
        if let f = ini { a.ini = { [unowned S] x, t, A in f(S, x, t, A) } }
        if let f = step { a.step = { [unowned S] x, u, dt, A in f(S, x, u, dt, A) } }
        if let f = end { a.end = { [unowned S] x, A in f(S, x, A) } }
        S.ACT[name] = a
    }
    static func emergeIn(_ S: SceneCore, _ a: Actor, _ u: Double, _ lim: Double) {
        let D = a.D; a.intro = true; a.ii = Int(min(Double(D.intro - 1), floor(clamp(u / lim, 0, 0.999) * Double(D.intro))))
        if S.R.next() < 0.3 { S.ptx("dirt", a.x, S.feetY(a) - 2, 1, po().a(-PI * 0.95, -PI * 0.05).s(12, 26).g(150).l(0.4, 0.7).jx(6)) }
    }
    static func eagleHead(_ h: Double) -> [Double] { [h * 0.3, -h * 0.66] }
    /// 머리 위치(몸 기준: 바라보는 쪽으로 dx, 발 기준 위로 dy) — 추운 날 입김이 나오는 자리
    static func headOf(_ a: Actor, _ hh: Double) -> [Double] {
        switch a.kind {
        case "eagle": return eagleHead(hh)
        default: return [hh * 0.2, -hh * 0.64]
        }
    }

    static func register(_ S: SceneCore) {
        regDog(S); regPuppy(S); regCat(S); regMole(S); regEagle(S); regTad(S)
        regPanda(S); regHippo(S); regLand(S)
    }

    // ── 하얀 강아지(돌솜) ──
    static func regDog(_ S: SceneCore) {
        A_(S, "shake", 2.8, nil, { S, a, u, dt, A in
            // 털을 털다가 털이 자연스럽게 부풀었다가 원래대로 돌아온다(다른 그림을 덧붙이지 않고 캐릭터 자체가 커졌다 줄어든다)
            let T = S.t; let b: Double = u < 0.35 ? ease(u / 0.35) : u < 0.62 ? 1 : 1 - ease((u - 0.62) / 0.38)
            S.standF(a); a.sx = 1 + 0.34 * b; a.sy = a.sx; a.ox = u < 0.5 ? sin(T * 26) * 2 * min(1, u / 0.08) : 0; a.ang = u < 0.5 ? sin(T * 22) * 0.05 : 0
        }, nil)
        A_(S, "tailchase", 3.2, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; let dz = u > 0.74; S.standF(a)
            if !dz {
                let cs = cos(T * 11); a.sx = (cs < 0 ? -1 : 1) * max(0.22, abs(cs)); a.y = -abs(sin(T * 11)) * 2.4
                if S.every(A, "tp", 0.2) { S.ptx("dust", a.x, S.feetY(a) - 1, 1, po().a(-PI * 0.9, -PI * 0.1).s(6, 14)) }
            } else { a.ang = sin(T * 4.2) * 0.22; a.ox = sin(T * 2.1) * 3; S.pr(a, S.prop("stars", 0, -h * 1.06)) }
        }, nil)
        A_(S, "loaf", 4.6, nil, { S, a, u, dt, A in
            let T = S.t; S.standF(a); a.sy = 0.74; a.sx = 1.12; a.ox = u < 0.55 ? sin(T * 14) * 1.5 : 0; if u > 0.5 { a.pose = 1; a.sx = 1; a.sy = 1 }    // 졸다가 엎드려 잔다
            if u > 0.5 && S.every(A, "zz", 0.6) { S.ptx("zzz", a.x + Double(a.dir) * S.HH(a) * 0.3, S.feetY(a) - S.HH(a) * 0.8, 1, po().a(-PI * 0.6, -PI * 0.4).s(6, 9).g(-4).l(1, 1.4).r(1)) }
        }, nil)
        A_(S, "ball", 3.8, { _, _, _, A in A.b = nil }, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t, nx = Double(a.dir) * h * 0.52, ny = -h * 0.62, fy = S.feetY(a)
            S.standF(a)
            if u < 0.62 {
                let bp = abs(sin(T * 6.5)); a.y = -bp * 1.4; S.pr(a, S.prop("ball", h * 0.52, ny - bp * h * 0.4)); a.sy = 1 + (bp < 0.12 ? -0.03 : 0)
            } else {
                if A.b == nil { let nb = SceneCore.Ball(); nb.x = a.x + nx; nb.y = fy + ny; nb.vx = Double(a.dir) * 60; nb.vy = -80; A.b = nb; S.say(a, "!", 0.9) }
                let b = A.b!; b.vy += 260 * dt; b.x += b.vx * dt; b.y += b.vy * dt; if b.y > fy - 4 { b.y = fy - 4; b.vy *= -0.55; b.vx *= 0.8 }
                b.x = clamp(b.x, 6, S.W - 6); S.pr(a, S.propAbs("ball", b.x, b.y))
                if u > 0.78 { _ = S.moveX(a, b.x, a.spd * 1.1, dt) }
            }
        }, nil)
        A_(S, "mirror", 3.8, { S, a, t, A in
            A.mx = S.aheadX(a, S.HH(a) * 0.85); let g = S.addGfx(S.mkGfx("mirror", A.mx, a.z, 3.8 + 0.3)); A.g = g; g.own = a; a.dir = A.mx >= a.x ? 1 : -1
        }, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a); a.dir = A.mx >= a.x ? 1 : -1
            let b = abs(sin(T * 8)); a.y = -b * h * 0.26; a.sy = 1 + (b < 0.15 ? -0.08 : 0.04); a.ang = sin(T * 8) * 0.1 * Double(a.dir) * -1
            if u > 0.1 && u < 0.92 && S.every(A, "ba", 0.62) { S.say(a, "왜왜!", 0.5) }
        }, nil)
    }

    // ── 갈색 강아지(뽀푸) ──
    static func regPuppy(_ S: SceneCore) {
        A_(S, "dig", 3.6, { S, a, t, A in
            A.hx = a.x + Double(a.dir) * S.HH(a) * 0.72; A.g = S.addGfx(S.mkGfx("hole", A.hx, a.z, 3.6 + 0.5))
            let m = S.mkGfx("mound", a.x - Double(a.dir) * S.HH(a) * 0.5, a.z, 3.6 + 0.5); m.r = 9; S.addGfx(m)
        }, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; let ba = S.behindAng(a); S.standF(a); a.pvx = h * 0.38
            if u < 0.45 {
                a.ang = 0.32 + sin(T * 16) * 0.07
                if S.every(A, "d", 0.1) { S.ptx("dirt", a.x - Double(a.dir) * h * 0.1, S.feetY(a) - 3, 1, po().a(ba[0], ba[1]).s(22, 40).g(180).l(0.4, 0.7)) }
            } else if u < 0.84 {
                a.ang = 1.02 + sin(T * 20) * 0.06
                if S.every(A, "d", 0.16) { S.ptx("dirt", a.x + Double(a.dir) * h * 0.7, S.feetY(a) - 3, 1, po().a(-PI * 0.9, -PI * 0.1).s(14, 26).g(160).l(0.4, 0.7)) }
                let mh = S.prop("moundhat", h * 0.62, -3); mh.r = h * 0.26; S.pr(a, mh)
            } else { let p = (u - 0.84) / 0.16; a.ang = 1.02 * (1 - ease(p)); a.ox = sin(T * 40) * 1.6 * (1 - p) }
        }, nil)
        A_(S, "bone", 4.2, { S, a, t, A in A.tx = S.aheadX(a, 70 + S.rnd() * 20) }, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; let r = S.inRange(a); a.y = -abs(sin(T * 10)) * 3.5
            if S.moveX(a, A.tx, a.spd * 1.5, dt) {
                A.tx = clamp(a.x - Double(a.dir) * (70 + S.rnd() * 20), r[0], r[1])
                if abs(A.tx - a.x) < 8 { A.tx = a.x + (a.x < (r[0] + r[1]) / 2 ? 1 : -1) * 60 }
            }
            a.fr += dt * Double(a.D.fps) * 0.3; S.pr(a, S.prop("bone", h * 0.42, -h * 0.3 + sin(T * 10) * 1.4))
        }, nil)
        A_(S, "dance", 3.8, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a); let b = abs(sin(T * 7)); a.ang = -0.55 + sin(T * 7) * 0.1; a.y = -b * h * 0.12; a.ox = sin(T * 3.5) * 2
            // 웹(index.html)의 같은 줄은 every(a.act,'n',.38) 인데 키 'n' 이 act 이름(a.act.n)과 겹쳐 조건이 늘 거짓이다 → 웹에는 춤 음표가 한 번도 안 나온다.
            // 웹과 똑같이 그리는 게 이식의 기준이라 같은 동작을 유지한다(WEB_DANCE_NOTE_BUG).
            if !SceneActs.WEB_DANCE_NOTE_BUG && u > 0.08 && u < 0.92 && S.every(A, "nt", 0.38) { S.ptx("note", a.x + Double(a.dir) * h * 0.35, S.feetY(a) - h * 1.1, 1, po().a(-PI * 0.7, -PI * 0.3).s(12, 20).g(-6).l(0.9, 1.3).r(1).jx(6)) }
        }, nil)
        A_(S, "slide", 2.4, nil, { S, a, u, dt, A in
            let r = S.inRange(a); S.standF(a); a.sx = 1.22; a.sy = 0.74; let v = 120 * (1 - u) * (1 - u) + 6
            if a.x + Double(a.dir) * v * dt < r[0] || a.x + Double(a.dir) * v * dt > r[1] { a.dir = -a.dir }
            a.x = clamp(a.x + Double(a.dir) * v * dt, r[0], r[1])
            if u < 0.8 && S.every(A, "d", 0.09) { S.ptx("dust", a.x - Double(a.dir) * S.HH(a) * 0.5, S.feetY(a) - 1, 1, po().a(-PI * 0.9, -PI * 0.1).s(8, 18)) }
        }, nil)
        A_(S, "dive", 3.8, { S, a, t, A in
            A.px = S.aheadX(a, S.HH(a) * 1.9); A.dir0 = a.dir; A.snow = S.L.wk == "snow"
            let pg = S.mkGfx("pile", A.px, a.z + 0.004, 3.8 + 1.2); pg.front = true; pg.snow = A.snow; A.g = S.addGfx(pg)
        }, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t, fy = S.feetY(a); a.dir = A.px >= a.x ? 1 : -1
            if u < 0.4 { let tx = A.px - Double(A.dir0) * h * 1.0; _ = S.moveX(a, tx, a.spd * 1.2, dt) }
            else if u < 0.62 {
                let p = (u - 0.4) / 0.22; if A.x1.isNaN { A.x1 = a.x }; a.x = A.x1 + (A.px - A.x1) * ease(p)
                a.y = -sin(PI * p) * h * 0.9 + (p > 0.85 ? h * 0.25 * (p - 0.85) / 0.15 : 0); a.pvy = -h * 0.5; a.ang = ease(p) * 1.2; S.standF(a)
            } else if u < 0.86 {
                a.vis = false
                if S.once(A, "burst") { S.ptx("leaf", A.px, fy - h * 0.25, 12, po().a(-PI * 0.95, -PI * 0.05).s(26, 54).g(130).l(0.7, 1.1).jx(6)); A.g?.bump = T }
                if S.every(A, "rs", 0.5) { A.g?.bump = T }
            } else {
                let q = (u - 0.86) / 0.14; a.x = A.px; a.cut = h * 0.55 * (1 - q * 0.2); a.y = h * 0.55 * (1 - ease(q)); S.standF(a)
                if S.once(A, "pop") { S.ptx("leaf", A.px, fy - h * 0.5, 8, po().a(-PI * 0.95, -PI * 0.05).s(20, 44).g(120).l(0.6, 1).jx(5)); A.g?.bump = T }
                if q > 0.7 { a.cut = Double.nan; a.y = 0 }
            }
        }, { S, a, A in a.dir = A.dir0; if let g = A.g { g.life = min(g.life, S.t - g.t0 + 0.8) } })
    }

    // ── 고양이(러블) ──
    static func regCat(_ S: SceneCore) {
        A_(S, "punch", 2.8, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a); let sw = max(0, sin(T * 24)); a.ox = Double(a.dir) * sw * 4; a.sx = 1 + sw * 0.06
            if u > 0.08 && u < 0.92 && S.every(A, "sp", 0.12) { S.ptx("spark", a.x + Double(a.dir) * h * 0.62, S.feetY(a) - h * 0.55, 1, po().a(a.dir > 0 ? -0.6 : PI - 0.6, a.dir > 0 ? 0.6 : PI + 0.6).s(12, 22).g(0).l(0.25, 0.4).jy(8).r(1.1)) }
            if u > 0.1 && S.every(A, "sy", 1.0) { S.say(a, "냥냥냥!", 0.8) }
        }, nil)
        A_(S, "box", 4.8, { S, a, t, A in
            A.bx = S.aheadX(a, S.HH(a) * 1.2); A.b1 = S.addGfx(S.mkGfx("boxb", A.bx, a.z, 4.8 + 0.4))
            let bf = S.mkGfx("boxf", A.bx, a.z + 0.004, 4.8 + 0.4); bf.front = true; A.b2 = S.addGfx(bf)
        }, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a)
            let bh = h * BOX_H                                                  // 상자 앞판 높이 — 이 선 아래의 몸은 그리지 않는다(상자 밖으로 삐져나오지 않게)
            if A.s0.isNaN { A.s0 = a.x }
            if u < 0.3 { _ = S.moveX(a, A.bx - (A.bx >= a.x ? 1 : -1) * h * 0.55, a.spd, dt); if u > 0.27 { A.s1 = a.x } }
            else if u < 0.46 { let p = (u - 0.3) / 0.16; if A.s1.isNaN { A.s1 = a.x }; a.dir = A.bx >= a.x ? 1 : -1; a.x = A.s1 + (A.bx - A.s1) * ease(p); a.y = -sin(PI * p) * h * 0.55 }
            else if u < 0.9 { a.x = A.bx; let k2 = ease(clamp((u - 0.46) / 0.08, 0, 1)); a.y = h * 0.03 * k2; a.ox = sin(T * 12) * 0.8; a.sy = 1 - 0.04 * k2 }
            else {                                                                                // 폴짝 뛰어나와 상자 옆(들어온 쪽)에 내려앉는다
                let q = (u - 0.9) / 0.1; let side: Double = (A.s1.isNaN || A.s1 >= A.bx) ? 1 : -1
                a.x = A.bx + side * h * 1.1 * ease(clamp((q - 0.12) / 0.55, 0, 1))
                a.y = h * 0.05 * (1 - ease(min(1, q * 2.4))) - sin(PI * q) * h * 0.62; a.dir = Int(-side)
            }
            let inBox = u >= 0.38 && abs(a.x - A.bx) < h * BOX_W * 0.62 && a.y > -bh * 0.98
            a.cut = inBox ? bh : Double.nan
        }, nil)
        A_(S, "stretch", 3.4, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a); a.pvx = h * 0.4
            if u < 0.6 { let b = ease(min(1, u / 0.15)); a.ang = 0.5 * b; a.sx = 1 + 0.16 * b; if u > 0.15 { a.ang += sin(T * 9) * 0.015 } }
            else { let q = ease((u - 0.6) / 0.15); a.ang = 0.5 * (1 - q); a.sx = 1.16 - 0.16 * q; a.sy = 1 + 0.06 * sin(PI * clamp((u - 0.6) / 0.4, 0, 1)); if S.once(A, "y") { S.say(a, "하암~", 1.4) } }
        }, nil)
        A_(S, "melt", 3.8, nil, { S, a, u, dt, A in
            let d: Double = u < 0.12 ? 0 : u < 0.42 ? ease((u - 0.12) / 0.3) : u < 0.78 ? 1 : 1 - ease((u - 0.78) / 0.12); S.standF(a)
            let mk = clamp((d - 0.45) / 0.3, 0, 1), sq = 0.7 * (1 - mk) + 0.1 * mk; if mk > 0.5 { a.pose = 1 }       // 녹아내리다 엎드려 잔다
            a.sy = 1 - sq * d + (u > 0.9 ? sin((u - 0.9) * 40) * 0.05 * (1 - (u - 0.9) * 10) : 0); a.sx = 1 + (0.5 * (1 - mk) + 0.05 * mk) * d
            if u > 0.5 && u < 0.76 && S.every(A, "zz", 0.7) { S.ptx("zzz", a.x + Double(a.dir) * S.HH(a) * 0.3, S.feetY(a) - S.HH(a) * 0.35, 1, po().a(-PI * 0.6, -PI * 0.4).s(6, 9).g(-4).l(1, 1.3).r(1)) }
        }, nil)
        A_(S, "pounce", 2.8, nil, { S, a, u, dt, A in
            let h = S.HH(a); S.standF(a)
            if u < 0.2 {
                let f = ease(min(1, u / 0.1)); a.sx = 1 + 0.3 * f; a.sy = a.sx
                if S.once(A, "e") { S.say(a, "!", 1); S.ptx("puff", a.x, S.feetY(a) - h * 0.6, 4, po().a(-PI, 0).s(8, 16).g(6).jx(h * 0.3).l(0.4, 0.7)) }
            } else if u < 0.72 { let p = (u - 0.2) / 0.52; a.y = -sin(PI * p) * h * 0.95; a.sx = 1.3 - 0.22 * sin(PI * p); a.sy = 1.3 - 0.1 * p }
            else { let q = ease((u - 0.72) / 0.28); a.sx = 1 + 0.3 * (1 - q); a.sy = a.sx }
        }, nil)
    }

    // ── 두더지(두덩) ──
    static func regMole(_ S: SceneCore) {
        A_(S, "shades", 3.6, nil, { S, a, u, dt, A in
            let h = S.HH(a); if u < 0.3 { emergeIn(S, a, u, 0.3); return }; S.standF(a)
            let adj: Double = u > 0.4 && u < 0.66 ? sin((u - 0.4) / 0.26 * PI) : 0; a.ang = -0.1 * adj; a.y = -adj * 2
            let gl = S.prop("glasses", h * 0.2, -h * 0.62); gl.s = 1.1; S.pr(a, gl)
            if u > 0.74 && S.every(A, "g", 0.3) { S.ptx("spark", a.x + Double(a.dir) * h * 0.28, S.feetY(a) - h * 0.66, 1, po().a(-PI, 0).s(4, 8).g(0).l(0.3, 0.5).jx(4).r(1.2)) }
        }, nil)
        A_(S, "flag", 4.2, { S, a, t, A in A.fx = a.x + Double(a.dir) * S.HH(a) * 0.8 }, { S, a, u, dt, A in
            let h = S.HH(a); if u < 0.26 { emergeIn(S, a, u, 0.26); return }; S.standF(a)
            if u >= 0.3 && S.once(A, "pl") {
                A.g = S.addGfx(S.mkGfx("flag", A.fx, a.z, 4.2 - 0.3 * 4.2 + 0.6)); S.ptx("dirt", A.fx, S.feetY(a) - 2, 5, po().a(-PI * 0.95, -PI * 0.05).s(12, 24).g(150).jx(3)); S.say(a, "짠!", 1.2)
            }
            if u > 0.5 && u < 0.92 { let b = abs(sin((u - 0.5) * 22)); a.y = -b * h * 0.24; a.sy = 1 + 0.1 * b }
        }, nil)
        A_(S, "lens", 4, { S, a, t, A in A.lx = S.aheadX(a, S.HH(a) * 0.7) }, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a)
            let d: Double = u < 0.14 ? ease(u / 0.14) : u < 0.84 ? 1 : 1 - ease((u - 0.84) / 0.16); a.pvy = -h * 0.5; a.ang = 1.32 * d; a.y = h * 0.12 * d; a.dir = A.lx >= a.x ? 1 : -1
            if d > 0.5 { let ln = S.propAbs("lens", a.x + Double(a.dir) * h * 0.8, S.feetY(a) - h * 0.17 + sin(T * 2) * 1.2); ln.r = h * 0.24; S.pr(a, ln) }
        }, nil)
        A_(S, "dust", 3, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a)
            if u < 0.62 {
                a.ox = sin(T * 45) * 2.4
                if S.every(A, "d", 0.05) { S.ptx("dirt", a.x, S.feetY(a) - h * 0.5, 2, po().a(-PI, 0).s(14, 30).g(120).l(0.4, 0.8).jx(h * 0.3).jy(h * 0.25)) }
            } else { a.y = -abs(sin(T * 14)) * 2; if S.once(A, "c") { S.say(a, "콜록!", 1.2) } }
        }, nil)
        A_(S, "vanish", 3.2, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t, fy = S.feetY(a); S.standF(a)
            if u < 0.5 {
                a.y = -abs(sin(T * 9)) * h * 0.07; let mh = S.prop("moundhat", 0, -h * 1.0); mh.r = h * 0.2; S.pr(a, mh)
                if u > 0.2 && S.once(A, "hi") { S.say(a, "안녕~", 1.1) }
            } else if u < 0.64 {
                let p = ease((u - 0.5) / 0.14); a.y = h * 1.05 * p; a.cut = 0; let mh = S.prop("moundhat", 0, -h * 1.0); mh.r = h * 0.2 * (1 - p * 0.2); S.pr(a, mh)
                if S.once(A, "sk") {
                    let mg = S.mkGfx("mound", a.x, a.z, 1.6); mg.r = 11; A.g = S.addGfx(mg); S.ptx("dirt", a.x, fy - 2, 8, po().a(-PI * 0.95, -PI * 0.05).s(16, 34).g(150).jx(6))
                }
            } else { a.vis = false }
        }, { S, a, A in a.vis = true; a.st = "emerge"; a.t0 = S.t; a.until = S.t + Double(a.D.intro) / Double(a.D.introFps); a.afterEmerge = nil })
        A_(S, "angry", 2, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a)
            if S.once(A, "s") { S.stk(a, "angry", 1.9); S.say(a, "씨씨!", 1.7); S.haptic("angry") }
            a.ox = u < 0.8 ? sin(T * 40) * 1.8 : 0; a.sy = 1 + 0.05 * sin(T * 22)
            if S.every(A, "p", 0.22) { S.ptx("puff", a.x + Double(a.dir) * h * 0.1, S.feetY(a) - h * 1.0, 1, po().a(-PI * 0.8, -PI * 0.2).s(8, 16).g(-8).l(0.4, 0.7).jx(5)) }
        }, nil)
    }

    // ── 독수리(술) ──
    static func regEagle(_ S: SceneCore) {
        A_(S, "glasses", 3.4, { S, a, t, A in A.alt0 = a.alt }, { S, a, u, dt, A in
            let h = S.HH(a), b = ease(min(1, u / 0.25)) * (u > 0.85 ? 1 - ease((u - 0.85) / 0.15) : 1); a.fr += dt * Double(a.D.fps) * 0.15; a.sx = 1 + 0.08 * b; a.sy = a.sx; a.ang = -0.1 * b
            let e = eagleHead(h); let gl = S.prop("glasses", e[0], e[1]); gl.s = 1.1 * b; S.pr(a, gl)
            if u > 0.3 && S.every(A, "w", 0.18) { S.ptx("spark", a.x - Double(a.dir) * h * 0.1, S.feetY(a) - S.liftOf(a) - h * 0.4, 1, po().a(a.dir > 0 ? PI * 0.9 : -0.1, a.dir > 0 ? PI * 1.1 : 0.1).s(24, 40).g(0).l(0.3, 0.5).jy(h * 0.3).r(0.8)) }
        }, nil)
        A_(S, "stumble", 4, { S, a, t, A in A.alt0 = a.alt }, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; let r = S.inRange(a); a.pvy = -h * 0.5
            if u < 0.28 { let p = ease(u / 0.28); a.alt = A.alt0 * (1 - p); a.ang = 0.5 * p; a.fr += dt * Double(a.D.fps) * 0.5; a.x = clamp(a.x + Double(a.dir) * 40 * dt, r[0], r[1]) }
            else if u < 0.36 {
                let q = ease((u - 0.28) / 0.08); a.alt = 0; a.ang = 0.5 + 0.95 * q; S.standF(a)
                if S.once(A, "i") {
                    S.say(a, "으앗!", 1.4); S.ptx("star", a.x + Double(a.dir) * h * 0.3, S.feetY(a) - h * 0.3, 5, po().a(-PI * 0.95, -PI * 0.05).s(18, 34).g(90).l(0.5, 0.9).r(1))
                    S.ptx("dust", a.x, S.feetY(a) - 1, 4, po().a(-PI * 0.9, -PI * 0.1).s(10, 22))
                }
            } else if u < 0.74 { a.alt = 0; a.ang = 1.45 + sin(T * 14) * 0.05; S.standF(a); S.pr(a, S.prop("stars", h * 0.3, -h * 0.5)) }
            else { let w = ease((u - 0.74) / 0.22); a.alt = A.alt0 * ease((u - 0.8) / 0.2); a.ang = 1.45 * (1 - w); a.ox = sin(T * 30) * 1.2 * (1 - w) }
        }, { S, a, A in a.alt = A.alt0 })
        A_(S, "feather", 3.8, { S, a, t, A in A.alt0 = a.alt; A.f = nil }, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t, fy = S.feetY(a)
            if u < 0.2 {
                if A.f == nil { let nf = SceneCore.Feather(); nf.x = a.x + Double(a.dir) * h * 0.1; nf.y = fy - S.liftOf(a) - h * 0.75; nf.vy = 0; nf.ph = S.rnd() * 6; A.f = nf }
                a.fr += dt * Double(a.D.fps) * 0.3
            }
            let F = A.f
            if let F = F, !F.got {
                if !F.land { F.vy = min(F.vy + 40 * dt, 24); F.y += F.vy * dt; F.x += sin(T * 4 + F.ph) * 18 * dt; if F.y >= fy - 3 { F.y = fy - 3; F.land = true } }
                F.x = clamp(F.x, 6, S.W - 6)
            }
            if u >= 0.14 && u < 0.44 { if S.once(A, "ex") { S.say(a, "!", 1.2) }; a.fr += dt * Double(a.D.fps) * 0.2 }
            if u >= 0.44 && u < 0.8 { a.alt = A.alt0 * (1 - ease((u - 0.44) / 0.2)); if let F = F { _ = S.moveX(a, F.x, a.spd * 0.9, dt) } }
            if u >= 0.8 {
                if let F = F { F.got = true }; a.alt = A.alt0 * ease((u - 0.88) / 0.12); let e = eagleHead(h)
                S.pr(a, S.prop("feathr", e[0] + h * 0.12, e[1] + h * 0.18)); a.y = -abs(sin((u - 0.8) * 24)) * 2
            }
            if let F = F, !F.got { S.pr(a, S.propAbs("feathg", F.x, F.y)) }
        }, { S, a, A in a.alt = A.alt0 })
        A_(S, "binoc", 4, { S, a, t, A in A.d0 = a.dir; A.alt0 = a.alt }, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; a.dir = (Int(floor(u * 4.4)) % 2 != 0 ? -1 : 1) * A.d0; a.fr += dt * Double(a.D.fps) * 0.12; let e = eagleHead(h)
            S.pr(a, S.prop("binoc", e[0] + h * 0.06, e[1] + 1)); a.y = sin(T * 3) * 1
        }, { S, a, A in a.dir = A.d0 })
        A_(S, "hover", 3.6, { S, a, t, A in A.alt0 = a.alt }, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; a.fr += dt * Double(a.D.fps) * 1.5; a.alt = 8 + sin(T * 9) * 2.5; a.ox = sin(T * 60) * 0.8
            if S.every(A, "w", 0.12) { S.ptx("spark", a.x + (S.rnd() - 0.5) * h * 0.6, S.feetY(a) - 2, 1, po().a(PI * 0.35, PI * 0.65).s(14, 26).g(0).l(0.25, 0.4).r(0.8)) }
        }, { S, a, A in a.alt = A.alt0 })
    }

    // ── 올챙이(챙챙) ──
    static func regTad(_ S: SceneCore) {
        A_(S, "dash", 2.8, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; let r = S.inRange(a); a.fr += dt * Double(a.D.fps) * 2.2; let nx = a.x + Double(a.dir) * a.spd * 2.6 * dt; if nx < r[0] || nx > r[1] { a.dir = -a.dir }
            a.x = clamp(nx, r[0], r[1]); a.y = sin(T * 14) * 1.8; a.ang = sin(T * 18) * 0.06
            if S.every(A, "b", 0.1) { S.ptx("bub", a.x - Double(a.dir) * h * 0.5, S.feetY(a) - S.liftOf(a) - h * 0.3, 1, po().a(-PI * 0.8, -PI * 0.2).s(4, 10).g(-14).l(0.5, 0.9).jx(3).jy(5)) }
        }, nil)
        A_(S, "flop", 3.4, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a); a.pvy = -h * 0.45
            if u < 0.4 { let p = u / 0.4; a.y = -sin(PI * p) * h * 1.0; a.ang = 1.45 * ease(max(0, p - 0.5) * 2) }
            else if u < 0.8 {
                a.ang = 1.4 + sin(T * 16) * 0.1; a.sx = 1.1
                if S.once(A, "l") { S.say(a, "툭!", 1.2); S.ptx("dust", a.x, S.feetY(a) - 1, 5, po().a(-PI * 0.9, -PI * 0.1).s(10, 22)) }
            } else { let q = ease((u - 0.8) / 0.2); a.ang = 1.4 * (1 - q); a.y = -sin(PI * q) * 3 }
        }, nil)
        A_(S, "hide", 4, { S, a, t, A in
            let gr = S.mkGfx("grass", a.x + Double(a.dir) * S.HH(a) * 0.1, a.z + 0.006, 4 + 0.5); gr.front = true; A.g = S.addGfx(gr)
        }, { S, a, u, dt, A in
            let T = S.t; let bl = (T * 0.9).truncatingRemainder(dividingBy: 1) < 0.14; a.sy = bl ? 0.86 : 1; a.y = 9 * zs(a.z); a.ang = sin(T * 4) * 0.04; a.fr += dt * Double(a.D.fps) * 0.15
            if u > 0.3 && S.every(A, "q", 1.2) { S.say(a, "…", 0.9) }
        }, nil)
        A_(S, "bubbles", 3.8, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; a.fr += dt * Double(a.D.fps) * 0.3; a.ang = sin(T * 3) * 0.07
            if S.every(A, "b", 0.13) { S.ptx("bub", a.x + Double(a.dir) * h * 0.4, S.feetY(a) - S.liftOf(a) - h * 0.58, 1, po().a(-PI * 0.65, -PI * 0.35).s(6, 12).g(-6).l(0.9, 1.5).jx(2).r(1.2 + S.rnd() * 0.6)) }
        }, nil)
        A_(S, "dew", 3.8, { S, a, t, A in A.d0 = a.dir }, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a)
            if u < 0.86 {
                let cs = cos(T * 9); a.sx = (cs < 0 ? -1 : 1) * max(0.22, abs(cs))
                let dw = S.prop("dew", 0, -h * 1.0 + sin(T * 12) * 0.8); dw.r = 4 * zs(a.z); S.pr(a, dw)
            } else if S.once(A, "dr") {
                S.ptx("drop", a.x, S.feetY(a) - h * 1.0, 3, po().a(-PI * 0.75, -PI * 0.25).s(6, 12).g(220).l(0.5, 0.7))
                S.ptx("ring", a.x + Double(a.dir) * 8, S.feetY(a), 1, po().a(0, 0).s(0, 0).g(0).l(0.7, 0.7).delay(0.25))
            }
        }, nil)
    }
}
