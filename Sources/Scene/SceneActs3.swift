import Foundation

/// SceneActs 3/3 — 떨어뜨리기 연출(L_*)·독수리 납치(carry)·화냄·놀람, 전용 시트 칸 표(CELLS)와 적용(applyCells) — 안드로이드 SceneActs.java 이식.
extension SceneActs {
    /// 전용 동작 시트(<id>_act)가 있으면 그 칸을, 없으면(옛 설치) 자세 시트 칸으로 대신 그린다(둘 다 a.cell/a.pose 를 같이 정한다).
    static func cell(_ a: Actor, _ cell: Int, _ pose: Int) { a.cell = cell; a.pose = pose }

    /// 화면에서 (alt 만큼 떠 있을 때) 발이 땅에서 올라간 높이(px).
    static func liftPx(_ S: SceneCore, _ a: Actor, _ alt: Double) -> Double { let z = zs(a.z); return (a.D.lift + alt) * z * (a.kind == "eagle" ? 1 : z) }

    /// 동작마다 어느 구간에 어느 칸을 쓰는지: {시작u, 끝u, 칸A, 자세, [칸B, 초당 번갈음 횟수, 칸A 비율]}
    static let CELLS: [(String, [[Double]])] = [
        // 돌솜
        ("shake", [[0, 1, 4, -1]]),
        ("tailchase", [[0, 0.74, 7, -1, 8, 6], [0.74, 1, 0, 0]]),
        ("loaf", [[0, 0.5, 6, -1], [0.5, 1, 5, 1]]),
        ("ball", [[0, 0.62, 7, -1, 8, 5], [0.62, 0.78, 12, -1], [0.78, 1, 15, 2]]),
        ("mirror", [[0.1, 0.92, 11, -1, 4, 1.6, 0.4]]),
        ("sit", [[0.08, 0.58, 0, 0], [0.58, 1, 15, 2]]),
        ("howl", [[0.1, 0.88, 2, 0]]),
        ("snuffle", [[0, 0.72, 3, -1], [0.72, 1, 4, 2]]),
        ("rollover", [[0, 0.16, 9, -1], [0.16, 0.34, 14, -1], [0.34, 0.72, 15, 2], [0.72, 0.9, 14, -1], [0.9, 1, 15, 2]]),
        ("zoomies", [[0, 1, 7, -1, 8, 7]]),
        // 뽀푸
        ("dig", [[0, 0.45, 9, -1, 10, 5], [0.45, 0.84, 10, -1, 9, 8], [0.84, 1, 15, 2]]),
        ("bone", [[0, 0.35, 3, -1], [0.35, 1, 13, 2]]),
        ("dance", [[0.08, 0.92, 15, 2, 9, 3]]),
        ("slide", [[0, 1, 12, -1]]),
        ("dive", [[0, 0.4, 7, -1, 8, 6], [0.4, 0.62, 14, -1], [0.62, 1, 15, 2]]),
        ("beg", [[0.08, 0.9, 1, 0]]),
        ("scratch", [[0.08, 0.88, 10, 0]]),
        ("bark", [[0.06, 0.92, 11, -1, 4, 2.3, 0.28]]),
        ("frisbee", [[0, 0.5, 7, -1, 8, 6], [0.5, 0.68, 14, -1], [0.68, 1, 15, 2]]),
        ("chew", [[0.08, 0.9, 13, 0]]),
        // 러블
        ("punch", [[0.08, 0.92, 12, -1, 9, 6]]),
        ("box", [[0.3, 0.46, 14, -1], [0.46, 0.9, 0, 0]]),
        ("stretch", [[0, 0.6, 9, -1], [0.6, 1, 0, 0]]),
        ("melt", [[0.2, 0.42, 6, -1], [0.42, 0.9, 5, 1]]),
        ("pounce", [[0, 0.2, 9, -1], [0.2, 0.72, 14, -1], [0.72, 1, 15, 2]]),
        ("groom", [[0.1, 0.9, 1, 0, 10, 2]]),
        ("purr", [[0.1, 0.9, 5, 1]]),
        ("knead", [[0.1, 0.9, 9, -1, 6, 3]]),
        ("yarn", [[0.1, 0.4, 3, -1], [0.4, 0.8, 12, -1, 9, 6], [0.8, 1, 15, 2]]),
        ("cuke", [[0, 0.4, 4, -1], [0.4, 0.7, 14, -1], [0.7, 1, 4, -1]]),
        // 두덩
        ("shades", [[0.3, 1, 0, 0]]),
        ("flag", [[0.26, 0.5, 0, 0], [0.5, 0.92, 1, 2]]),
        ("lens", [[0.14, 0.84, 6, -1]]),
        ("dust", [[0, 0.62, 15, -1], [0.62, 1, 0, 0]]),
        ("vanish", [[0, 0.5, 12, -1]]),
        ("digdig", [[0.08, 0.9, 2, -1, 3, 2.8]]),
        ("lantern", [[0.1, 0.9, 12, -1]]),
        ("popup", [[0, 1, 4, -1]]),
        ("nap", [[0.1, 0.9, 14, 1]]),
        ("treasure", [[0, 0.4, 6, -1], [0.4, 0.7, 2, -1, 3, 3], [0.7, 1, 1, 2]]),
        // 술
        ("stumble", [[0.36, 0.74, 7, -1]]),
        ("preen", [[0.1, 0.9, 8, 0]]),
        ("flapshow", [[0.1, 0.9, 11, -1, 2, 2.5]]),
        ("scan", [[0.1, 0.9, 12, -1]]),
        ("soar", [[0.1, 0.9, 4, -1]]),
        ("swoop", [[0.2, 0.6, 5, -1]]),
        // 챙챙
        ("dash", [[0, 1, 10, -1]]),
        ("flop", [[0, 0.4, 3, -1], [0.4, 0.8, 12, -1], [0.8, 1, 5, 1]]),
        ("hide", [[0.1, 0.9, 14, -1]]),
        ("bubbles", [[0.1, 0.9, 4, -1]]),
        ("dew", [[0.1, 0.86, 0, -1]]),
        ("wiggle", [[0, 1, 6, -1]]),
        ("leap", [[0.2, 0.7, 3, -1]]),
        ("whirl", [[0, 1, 1, -1, 12, 4]]),
        ("tailsplash", [[0, 1, 10, -1, 6, 3]]),
    ]

    /// register 끝에서 한 번: 위 표대로 동작마다 전용 시트 칸을 정한다(원래 몸짓·소품·말풍선은 그대로, 그림 칸만 바꾼다).
    static func applyCells(_ S: SceneCore) {
        for (name, sg) in CELLS {
            guard let ac = S.ACT[name], let orig = ac.step else { continue }
            ac.step = { [unowned S] a, u, dt, A in
                orig(a, u, dt, A)
                if a.intro { return }
                for s in sg {
                    if u < s[0] || u >= s[1] { continue }
                    var c = Int(s[2])
                    if s.count > 4 && s[4] >= 0 {
                        var ph = (S.t - A.t0) * s[5]; ph -= floor(ph)
                        if ph >= (s.count > 6 ? s[6] : 0.5) { c = Int(s[4]) }
                    }
                    cell(a, c, Int(s[3])); break
                }
            }
        }
    }

    /// ★ s354 떨어뜨리기 연출 — 어떤 연출인지는 엔진(traits[id].land)이 정하고, 여기는 그 이름(cotton·pose·dig·flip·fly·puddle)대로 그리는 곳뿐이다.
    static func regDrop(_ S: SceneCore) {
        // ── 둘숑: 풍선처럼 3배로 부푼 몸이 땅에 닿는 순간 하트 모양으로 변한다 ──
        A_(S, "L_cotton", 3.6, { S, a, t, A in
            let h = S.HH(a), fy = S.feetY(a)
            let bh = S.mkGfx("bigheart", a.x, a.z, 2.3); bh.r = h * 2.35; S.addGfx(bh)
            S.ptx("heart", a.x, fy - h * 1.2, 12, po().a(-PI * 0.98, -PI * 0.02).s(40, 90).g(55).l(1.0, 1.7).r(1.5).jx(h * 0.8)); S.haptic("hearts")
            S.ptx("ring", a.x, fy, 1, po().a(0, 0).s(0, 0).g(0).l(0.8, 0.8)); S.ptx("ring", a.x, fy, 1, po().a(0, 0).s(0, 0).g(0).l(0.8, 0.8).delay(0.15))
            S.ptx("dust", a.x, fy - 1, 6, po().a(-PI * 0.98, -PI * 0.02).s(14, 36).g(30).l(0.4, 0.8).jx(h * 0.6))
            S.flash(255, 170, 205, 0.2, 0.35); S.shake(2.4, 0.35); S.ptx("spark", a.x, fy - h * 1.3, 10, po().a(-PI, 0).s(20, 60).g(20).l(0.5, 0.9).jx(h * 0.6).r(1.2))
        }, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t, tt = u * 3.6; S.standF(a); a.feetScale = true; a.pose = 2; a.cell = tt < 2.85 ? 15 : 14
            let sh = ease(clamp((tt - 0.16) / 0.55, 0, 1)), out = ease(clamp((tt - 2.25) / 0.6, 0, 1)), base = 3 - 1.5 * sh - 0.5 * out      // 3배 → 하트 크기 → 원래 몸
            a.heart = tt < 0.2 ? ease(tt / 0.2) : 1 - out
            if tt < 0.16 { let q = sin(PI * tt / 0.16); a.sx = base + 0.35 * q; a.sy = base - 0.5 * q }                                  // 닿는 순간 납작
            else { let pl = 1 + 0.05 * sin(T * 10) * (1 - out); a.sx = base * pl; a.sy = a.sx }
            if out >= 1 {                                                                                                              // 풍선 몸으로 돌아와 신나서 폴짝
                a.sx = 1; a.sy = 1; a.heart = 0; a.feetScale = false; let hp = clamp((tt - 2.85) / 0.75, 0, 1); a.y = -abs(sin(hp * PI * 2)) * 9 * zs(a.z) * (1 - hp * 0.5); a.cell = hp < 0.85 ? 14 : 15
                if S.once(A, "wf") { S.say(a, "멍멍!", 1.2); S.ptx("heart", a.x, S.feetY(a) - h * 0.9, 5, po().a(-PI * 0.98, -PI * 0.02).s(24, 56).g(55).l(0.9, 1.4).r(1.1).jx(h * 0.5)) }
            }
            if tt > 0.25 && tt < 2.2 && S.every(A, "h", 0.22) { S.ptx("heart", a.x, S.feetY(a) - h * 0.9, 2, po().a(-PI * 0.98, -PI * 0.02).s(24, 60).g(55).l(0.9, 1.5).r(1.2).jx(h * 0.6)) }
            if tt > 0.5 && S.once(A, "sy") { S.say(a, "두근두근~", 1.7); S.ptx("heart", a.x, S.feetY(a) - h * 1.2, 8, po().a(-PI * 0.98, -PI * 0.02).s(30, 70).g(55).l(0.9, 1.5).r(1.3).jx(h * 0.7)) }
        }, nil)

        // ── 뽀푸: 두 발로 멋지게 착지 — 땅이 갈라지고 흔들려 주변 친구가 깜짝 놀란 뒤, "히힛" 멋있는 척 ──
        A_(S, "L_pose", 4.6, { S, a, t, A in
            let h = S.HH(a), fy = S.feetY(a)
            S.shake(8.5, 1.5); S.haptic("thud"); S.flash(255, 246, 225, 0.24, 0.22)
            let wv = S.mkGfx("wave", a.x, a.z, 1.2); wv.r = h * 3.6; S.addGfx(wv)
            S.ptx("dirt", a.x, fy - 1, 12, po().a(-PI * 0.92, -PI * 0.08).s(40, 110).g(260).l(0.5, 0.9).jx(h * 0.5).r(1.2))
            S.ptx("dust", a.x, fy - 1, 14, po().a(-PI * 0.98, -PI * 0.02).s(26, 76).g(40).l(0.5, 1.0).jx(h * 0.3).r(1.4))
            for i in 0..<3 { S.ptx("ring", a.x, fy, 1, po().a(0, 0).s(0, 0).g(0).l(0.9, 0.9).delay(Double(i) * 0.13)) }
            let cg = S.mkGfx("crack", a.x, a.z, 3.2); cg.r = h * 1.7; S.addGfx(cg)
            for o in S.actors where o !== a && abs(o.x - a.x) < S.W * 0.85 { S.startleK(a, o, "shock") }
        }, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t, tt = u * 4.6; S.standF(a)
            if tt < 0.3 { let q = ease(tt / 0.3); a.sx = 1.2 - 0.2 * q; a.sy = 0.7 + 0.3 * q; a.cell = tt < 0.16 ? 1 : 11; a.pose = 2 }               // 쭈그려 착지(앞발 모음) → 일어선다
            else { a.sx = 0.98; a.sy = 1.05; a.cell = tt < 1.5 ? 11 : 0; a.pose = 2 }                                                          // 꼿꼿이 선 채 숨을 고르다 → 앉아 으스댄다
            if tt < 0.9 && S.every(A, "du", 0.16) { S.ptx("dust", a.x + (S.rnd() - 0.5) * h, S.feetY(a) - 1, 1, po().a(-PI * 0.98, -PI * 0.02).s(10, 30).g(30).l(0.4, 0.8).jx(h * 0.4)) }
            if tt >= 1.5 {
                a.ang = -0.08 + sin(T * 3) * 0.03
                if S.once(A, "p") { S.say(a, "히힛~", 2.2); S.stk(a, "smirk", 2.6); S.haptic("grin"); S.ptx("spark", a.x, S.feetY(a) - h * 0.6, 8, po().a(-PI, 0).s(14, 30).g(0).l(0.4, 0.7).jx(h * 0.35).jy(h * 0.3).r(1.2)) }
                let gb = ease(clamp((tt - 1.85) / 0.22, 0, 1)); if gb > 0 { let gl = S.prop("glasses", h * 0.2, -h * 0.44); gl.s = 1.0 * gb; S.pr(a, gl) }
                if tt > 2.2 && S.every(A, "gl", 0.32) { S.ptx("spark", a.x + Double(a.dir) * h * 0.28, S.feetY(a) - h * 0.66, 1, po().a(-PI, 0).s(4, 8).g(0).l(0.3, 0.5).jx(4).r(1.2)) }
            }
            if tt > 3.9 { a.ang *= 1 - ease((tt - 3.9) / 0.7) }
        }, nil)

        // ── 뽀푸(s415): 노란 별빛이 몸을 감싸고 내려온 뽀푸 — 땅에 닿는 순간 별빛으로 흩어졌다가 → 빛이 다시 모여 뽀푸가 되고 → 활짝 웃는다 ──
        A_(S, "L_star", 3.9, { S, a, t, A in
            S.shake(2.6, 0.4); S.flash(255, 243, 185, 0.32, 0.28)
        }, { S, a, u, dt, A in
            let h = S.HH(a), tt = u * 3.9; S.standF(a); a.pose = 2; a.ang = 0
            let SC = 0.75, GA = 1.65, MT0 = 1.3, MT1 = 1.78                                                                                 // 흩어짐 끝 · 모임 끝 · 몸이 나타나기 시작/끝
            a.fade = tt < 0.16 ? 1 - ease(tt / 0.16) : clamp((tt - MT0) / (MT1 - MT0), 0, 1)                                               // 닿자마자 몸이 빛으로 풀리고, 빛이 모이면 다시 몸이 된다
            if tt < SC { a.sl = 2; a.slU = tt / SC }
            else if tt < GA { a.sl = 3; a.slU = (tt - SC) / (GA - SC) }
            else { a.sl = 4; a.slU = clamp((tt - GA) / (3.9 - GA), 0, 1) }
            let pp = clamp((tt - MT0) / (MT1 - MT0), 0, 1), x1 = pp - 1, bk = 1 + 2.70158 * x1 * x1 * x1 + 1.70158 * x1 * x1                // 몸이 나타날 때 살짝 넘치게 커졌다 자리잡는다
            let sc = tt < MT0 ? 0.55 : 0.55 + 0.45 * bk; a.sx = sc; a.sy = sc
            if tt >= MT0 + 0.2 && S.once(A, "fl") { S.flash(255, 240, 170, 0.3, 0.3); S.haptic("grin"); S.ptx("gold", a.x, S.feetY(a) - h * 0.5, 8, po().a(-PI * 1.05, PI * 0.05).s(60, 120).g(25).l(0.6, 1.0).jx(h * 0.2).jy(h * 0.2).r(1.1)) }
            let sm = [15, 7, 0, 1, 15, 8]                                                                                                   // 웃는 얼굴 칸을 돌려가며 활짝 웃는다
            a.cell = tt < GA ? 15 : sm[max(0, min(sm.count - 1, Int((tt - GA) / 0.42)))]
            if tt >= MT1 && tt < MT1 + 0.75 { let hp = (tt - MT1) / 0.75; a.y = -abs(sin(hp * PI * 2)) * 7 * zs(a.z) * (1 - hp * 0.5) }      // 신나서 콩콩
            if tt >= MT1 && S.once(A, "sy") { S.say(a, "히히~", 2.2) }
            if tt >= MT1 + 0.1 && tt < 3.3 && S.every(A, "tw", 0.34) { S.ptx("gold", a.x + (S.rnd() < 0.5 ? -1 : 1) * h * (0.75 + S.rnd() * 0.4), S.feetY(a) - h * (0.2 + S.rnd() * 0.9), 1, po().a(-PI, 0).s(4, 10).g(0).l(0.4, 0.7).r(0.75)) }
        }, nil)

        // ── 두덩: 떨어지자마자 땅을 파고 들어가 → 땅속을 지나 → 다른 곳 구멍을 뚫고 높이 점프해 착지 ──
        A_(S, "L_dig", 5.4, { S, a, t, A in
            let W = S.W; A.x0 = a.x; A.z0 = a.z; let r = S.inRange(a); let sd: Double = a.x < W / 2 ? 1 : -1
            var lo = max(r[0], W * 0.14), hi = min(r[1], W * 0.86); if hi < lo { lo = r[0]; hi = r[1] }
            A.tx = clamp(a.x + sd * S.rnd(0.2, 0.3) * W, lo, hi); if abs(A.tx - a.x) < W * 0.15 { A.tx = clamp(a.x - sd * S.rnd(0.2, 0.3) * W, lo, hi) }
            A.tz = a.hero ? a.z : S.rnd(0.35, 0.92)
            A.g = S.addGfx(S.mkGfx("hole", a.x, a.z, 5.4 + 1.2)); A.m = nil; A.b1 = nil; A.b2 = nil
            S.ptx("dirt", a.x, S.feetY(a) - 2, 10, po().a(-PI * 0.95, -PI * 0.05).s(16, 38).g(150).jx(8)); S.haptic("thud")
        }, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t, tt = u * 5.4; S.standF(a); a.nograb = true
            if tt < 0.5 {                                                                                                               // 파고 들어간다
                if tt < 0.12 { a.sy = 1 - 0.15 * (tt / 0.12) }
                a.y = h * 1.1 * ease(clamp((tt - 0.1) / 0.4, 0, 1)); a.cut = 0; a.cell = Int(T * 12) % 2 == 0 ? 2 : 3; a.pose = 2                  // 삽질 두 칸을 번갈아
                if S.every(A, "d", 0.1) { S.ptx("dirt", a.x, S.feetY(a) - 2, 3, po().a(-PI * 0.95, -PI * 0.05).s(8, 20).g(120).jx(5)) }
            } else if tt < 2.6 {                                                                                                        // 땅속 이동 — 두둑이 움직인다
                a.vis = false; a.y = h * 1.1; a.cut = 0
                if A.m == nil { let mg = S.mkGfx("mound", a.x, a.z, 3.0); mg.r = 9; A.m = S.addGfx(mg) }
                if tt > 1.9 {                                                                                                           // 나올 자리의 땅이 들썩들썩 부푼다
                    if A.b2 == nil { let bg = S.mkGfx("mound", A.tx, A.tz, 1.6); bg.r = 3; A.b2 = S.addGfx(bg) }
                    if let b2 = A.b2 { b2.r = 3 + 11 * ease(clamp((tt - 1.9) / 0.7, 0, 1)); b2.life = (S.t - b2.t0) + 0.3 }
                    if S.every(A, "bg", 0.08) { S.ptx("dirt", A.tx + (S.rnd() - 0.5) * h * 0.5, S.zy(A.tz) - 2, 1, po().a(-PI * 0.9, -PI * 0.1).s(10, 26).g(150).l(0.3, 0.5).jx(3)) }
                }
                let m = ease(clamp((tt - 0.6) / 1.8, 0, 1)); a.x = A.x0 + (A.tx - A.x0) * m; a.z = A.z0 + (A.tz - A.z0) * m; a.dir = A.tx >= A.x0 ? 1 : -1
                if let mm = A.m { mm.x = a.x; mm.z = a.z; mm.life = (S.t - mm.t0) + 0.4 }
                if S.every(A, "ug", 0.09) { S.ptx("dirt", a.x - Double(a.dir) * h * 0.2, S.feetY(a) - 2, 2, po().a(-PI * 0.95, -PI * 0.05).s(8, 22).g(130).jx(5)) }
                if S.every(A, "rb", 0.45) { S.haptic("thud") }
            } else if tt < 3.85 {                                                                                                       // 구멍을 뚫고 하늘로 높이 점프
                let q = (tt - 2.6) / 1.25, h4 = max(h * 1.5, min(h * 3.4, S.feetY(a) - h * 1.4 - 4))
                if S.once(A, "ex") {
                    if let mm = A.m { mm.life = (S.t - mm.t0) + 0.12 }; if let b2 = A.b2 { b2.life = (S.t - b2.t0) + 0.05 }
                    S.flash(255, 236, 200, 0.16, 0.2); let wv = S.mkGfx("wave", a.x, a.z, 1.0); wv.r = h * 2.4; S.addGfx(wv)
                    let hg = S.mkGfx("hole", a.x, a.z, 3.6); A.b1 = S.addGfx(hg)
                    S.ptx("dirt", a.x, S.feetY(a) - 2, 14, po().a(-PI * 0.9, -PI * 0.1).s(30, 80).g(150).jx(6)); S.shake(3.2, 0.5); S.haptic("land_dig"); S.say(a, "짜잔~!", 1.0)
                }
                a.y = -h4 * (1 - (2 * q - 1) * (2 * q - 1)); a.pvy = a.y - h * 0.5; a.ang = PI2 * 2 * ease(q); a.cell = q < 0.08 ? 4 : (q > 0.42 && q < 0.62 ? 7 : 1); a.pose = 2      // 빼꼼 → 만세 → 깜짝(꼭대기) → 만세
                if S.every(A, "tr", 0.1) { S.ptx("dirt", a.x, S.feetY(a) + a.y, 1, po().a(-PI * 0.9, -PI * 0.1).s(6, 14).g(100).l(0.3, 0.5).jx(h * 0.3)) }
            } else if tt < 4.25 {                                                                                                       // 착지
                let q = ease((tt - 3.85) / 0.32); a.sx = 1.2 - 0.2 * q; a.sy = 0.72 + 0.28 * q; a.cell = 0; a.pose = 0
                if S.once(A, "ld") { S.shake(5.5, 0.8); S.haptic("thud"); S.ptx("dust", a.x, S.feetY(a) - 1, 12, po().a(-PI * 0.98, -PI * 0.02).s(24, 64).g(40).l(0.5, 0.9).jx(h * 0.4)); S.ptx("ring", a.x, S.feetY(a), 1, po().a(0, 0).s(0, 0).g(0).l(0.8, 0.8)) }
            } else {                                                                                                                    // 인사
                cell(a, tt < 4.8 ? 9 : 12, 2); let bn = abs(sin((tt - 4.25) * 6)); a.y = -bn * 3 * (tt < 5.0 ? 1 : 0)                           // 인사 → 손 흔들기
                if S.once(A, "hi") { S.say(a, "두더지 등장!", 1.6); S.ptx("star", a.x, S.feetY(a) - h * 0.9, 6, po().a(-PI * 0.95, -PI * 0.05).s(20, 44).g(70).l(0.5, 0.9).r(1).jx(h * 0.4)) }
            }
        }, { S, a, A in
            a.y = 0; a.cut = Double.nan; a.ang = 0; if let m = A.m { m.life = min(m.life, S.t - m.t0 + 0.1) }
            if let g = A.g { g.life = min(g.life, S.t - g.t0 + 1.2) }; if let b1 = A.b1 { b1.life = min(b1.life, S.t - b1.t0 + 1.4) }
        })

        // ── 러블: 같은 자리에서 앞구르기 3번 착지(fallStep) → 앉아 노려보면 주변이 어두워지고 눈에서 노란 빛, 친구들은 무서워 도망간다 ──
        A_(S, "L_flip", 4.8, { S, a, t, A in
            S.ptx("star", a.x, S.feetY(a) - S.HH(a) * 0.5, 6, po().a(-PI * 0.95, -PI * 0.05).s(18, 36).g(70).l(0.5, 0.9).r(1).jx(6))
            S.ptx("dust", a.x, S.feetY(a) - 1, 5, po().a(-PI * 0.98, -PI * 0.02).s(14, 34).g(30).l(0.4, 0.8).jx(S.HH(a) * 0.4))
        }, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t, tt = u * 4.8, fy = S.feetY(a); S.standF(a)
            if tt < 0.3 { let q = ease(tt / 0.3); a.sx = 1.15 - 0.15 * q; a.sy = 0.76 + 0.24 * q }
            a.pose = 0; a.cell = tt < 0.35 ? 6 : (tt < 1.3 ? 4 : 12)                                                                         // 엎드려 착지 → 고개를 들고 → 몸을 낮춰 노려본다
            if tt > 0.45 { a.sy *= 1 + 0.012 * sin(T * 2.2) }
            let dk = ease(clamp((tt - 0.35) / 0.9, 0, 1)) * (1 - ease(clamp((tt - 3.9) / 0.8, 0, 1)))
            if dk > 0.01 { S.dim(dk, a.x, fy - h * 0.5) }
            let ea = ease(clamp((tt - 0.8) / 0.5, 0, 1)) * (1 - ease(clamp((tt - 3.9) / 0.7, 0, 1)))
            let dr = Double(a.dir)
            if ea > 0.01 { S.eyes(ea, a.x + dr * h * 0.17, fy - h * 0.47, a.x + dr * h * 0.37, fy - h * 0.45, h * 0.055, a.dir) }
            if tt > 1.0 && S.once(A, "sc") {
                S.say(a, "…", 3.0); S.haptic("angry")
                for o in S.actors where o !== a { S.startleK(a, o, "scary") }
            }
        }, nil)

        // ── 독슐: 고공낙하 → 친구를 안고 하늘로 → 한 바퀴 → 내려놓으면 친구가 어질어질 ──
        A_(S, "carry", 8.8, { S, a, t, A in
            var cs: [Actor] = []; for o in S.actors where o !== a && o.kind != "eagle" && S.freeFor(o) { cs.append(o) }
            A.tgt = cs.isEmpty ? nil : cs[min(cs.count - 1, Int(S.rnd() * Double(cs.count)))]
            A.alt0 = clamp(a.altStart != 0 ? a.altStart : 40, 24, 150); a.alt = A.alt0; A.x0 = a.x; A.z0 = a.z; A.dir0 = a.dir
            if let o = A.tgt { o.chain = nil; o.pr = nil; o.cut = Double.nan; o.fearK = ""; S.startAct(o, "carried"); if let oa = o.act { oa.tgt = a }; A.px = o.x; A.tz = o.z }
            else { A.px = clamp(a.x + (a.x < S.W / 2 ? 1 : -1) * S.W * 0.2, a.w * 0.6, S.W - a.w * 0.6); A.tz = a.z }
            A.fr1 = false; A.px1 = A.px; A.pz1 = A.tz; A.pal1 = 0; A.pang1 = 0
            let h = S.HH(a); A.hx = h * 0.62                                                                                              // 안았을 때 친구가 매달리는 거리(px)
        }, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t, tt = u * 8.8, zq = zs(a.z), Le = a.D.lift; var o = A.tgt
            if let oo = o, oo.dead || oo.held || oo.act == nil || oo.act!.n != "carried" || oo.act!.tgt !== a { o = nil; A.tgt = nil; A.fr1 = false }
            let lf = o?.D.lift ?? 0, hang = o != nil ? A.hx : 0
            let gAlt = (hang + lf * zq * zq) / zq - Le, loR = clamp(((S.feetY(a) - 14 - h * 0.9) / zq - Le - (gAlt + 20)) / 2, 18, 44)           // 낮은 화면에서도 위로 벗어나지 않게 반지름을 줄인다
            let bot = gAlt + 20, R = loR, altC = bot + R, Rpx = R * zq
            let gx = A.px; let fd = gx < S.W / 2 ? 1 : -1; let cx = clamp(gx, Rpx + 14, S.W - Rpx - 14)
            var fx = a.x, fal = gAlt, ang = 0.0, cl = 5, th = 0.0, att = false
            a.pvy = -h * 0.5; a.nograb = true
            let fdD = Double(fd)
            if tt < 1.3 {                                                                                                               // 고공낙하 → 친구를 향해 급강하
                let q = tt / 1.3; a.dir = gx >= A.x0 ? 1 : -1; fx = A.x0 + (gx - A.x0) * ease(q); a.z = A.z0 + (A.tz - A.z0) * ease(q)
                fal = gAlt + (A.alt0 - gAlt) * (1 - q * q); ang = q < 0.85 ? 0.95 * ease(min(1, q / 0.3)) : 0.95 - 1.25 * ease((q - 0.85) / 0.15); cl = q < 0.85 ? 5 : 11
                if S.every(A, "wd", 0.09) { S.ptx("puff", a.x - Double(a.dir) * h * 0.3, S.feetY(a) - liftPx(S, a, fal), 1, po().a(-PI, 0).s(2, 6).g(0).l(0.25, 0.4).r(0.8)) }
                a.alt = fal
            } else if tt < 1.75 {                                                                                                       // 낚아챈다
                att = true; a.dir = gx >= A.x0 ? 1 : -1; fx = gx; fal = gAlt; ang = -0.3 * ease((tt - 1.3) / 0.45); cl = 9
                if S.once(A, "gr") {
                    A.fr1 = o != nil; S.haptic("flap"); S.ptx("star", gx, S.feetY(a) - h * 0.6, 6, po().a(-PI, 0).s(18, 40).g(40).l(0.4, 0.7).jx(h * 0.3).r(1)); if let oo = o { S.say(oo, "으앗?!", 1.2) }
                    S.say(a, o != nil ? "잡았다!" : "휙!", 1.2); S.shake(2.6, 0.3); S.flash(255, 255, 255, 0.12, 0.15); S.ptx("puff", gx, S.feetY(a) - h * 0.3, 6, po().a(-PI, 0).s(14, 34).g(30).l(0.3, 0.6).jx(h * 0.4))
                }
                a.alt = fal
            } else if tt < 3.0 {                                                                                                        // 안고 올라간다
                att = true; let q = ease((tt - 1.75) / 1.25); a.dir = fd; fx = gx + (cx - gx) * q; fal = gAlt + (bot - gAlt) * q; ang = -0.6 * sin(PI * q) * (1 - q); cl = q < 0.5 ? 10 : 2 + Int((T * 10).truncatingRemainder(dividingBy: 2))
                a.alt = fal; if S.every(A, "fl", 0.22) { S.haptic("flap") }
            } else if tt < 5.4 {                                                                                                        // 하늘에서 한 바퀴
                att = true; let q = (tt - 3.0) / 2.4; th = PI2 * ease(q) * 1.0; a.dir = fd; fx = cx + fdD * Rpx * sin(th); fal = altC - R * cos(th); ang = -th; cl = 2 + Int((T * 12).truncatingRemainder(dividingBy: 2))
                a.alt = fal; if S.once(A, "lp") { S.say(a, "한 바퀴~!", 1.4); if let oo = o { S.say(oo, "꺄아아~!", 2.0) } }
                if S.every(A, "tr", 0.07) { S.ptx("puff", a.x, S.feetY(a) - liftPx(S, a, fal), 1, po().a(-PI, 0).s(2, 6).g(0).l(0.35, 0.6).r(0.9).jx(3)) }
            } else if tt < 7.0 {                                                                                                        // 안고 천천히 내려온다
                att = true; let q = ease((tt - 5.4) / 1.6); a.dir = fd; fx = clamp(cx + fdD * S.W * 0.15, a.w * 0.6, S.W - a.w * 0.6); fx = cx + (fx - cx) * q; fal = bot + (gAlt - bot) * q; ang = 0.3 * sin(PI * q) * (1 - q * 0.4); cl = 4
                a.alt = fal
            } else {                                                                                                                    // 내려놓고 뿌듯
                if S.once(A, "rl") {
                    A.lx = a.x; if let f = o { f.alt = 0; S.startAct(f, "dizzy"); f.dir = a.dir; A.tgt = nil }; S.say(a, "어때? 재밌지?", 1.9); S.haptic("land_fly")
                    S.ptx("dust", A.lx, S.feetY(a) - 1, 8, po().a(-PI * 0.98, -PI * 0.02).s(14, 40).g(30).l(0.4, 0.8).jx(h * 0.4)); S.shake(1.6, 0.3)
                }
                if tt < 7.4 && S.every(A, "ds", 0.08) { S.ptx("dust", a.x, S.feetY(a) - 1, 1, po().a(-PI * 0.98, -PI * 0.02).s(8, 22).g(30).l(0.3, 0.6).jx(h * 0.4)) }
                fx = a.x; a.alt = gAlt + (16 - gAlt) * ease(clamp((tt - 7.0) / 0.5, 0, 1)); cell(a, 15, 0); ang = 0; a.pvy = 0; if tt > 7.3 { S.standF(a) }
            }
            a.x = fx; a.ang = ang; a.pvy = a.ang != 0 ? -S.liftOf(a) - h * 0.5 : 0; if tt < 7.0 { cell(a, cl, 0); a.fr += dt * Double(a.D.fps) * 0.5 }
            if att, let oo = o {                                                                                                         // 친구가 매달린 자리(독슐 몸 아래쪽)
                let ca = cos(th), sa = sin(th), hp = A.hx, fh = liftPx(S, a, a.alt) - hp * ca                                              // 화면 위 높이(px)
                A.px1 = a.x + Double(a.dir) * hp * sa; A.pz1 = a.z; A.pal1 = max(0, fh / (zq * zq) - oo.D.lift); A.pang1 = -th; A.fr1 = true
            }
        }, { S, a, A in
            a.alt = a.altSave != 0 ? a.altSave : 18; a.ang = 0; a.pvy = 0
            if let o = A.tgt, let oa = o.act, oa.n == "carried" { o.alt = 0; oa.dur = (S.t - oa.t0) + 0.001 }
        })
        A_(S, "carried", 20, nil, { S, a, u, dt, A in                                                                                   // 독수리에게 붙들린 친구: 놀라서 덜덜 → 매달려 함께 난다
            let h = S.HH(a)
            guard let e = A.tgt, let EA = e.act, !e.dead, !e.held, EA.n == "carry", EA.tgt === a else { a.alt = 0; A.dur = (S.t - A.t0) + 0.001; return }
            a.nograb = true; a.pose = 3; S.standF(a)
            if !EA.fr1 {
                a.dir = e.x >= a.x ? 1 : -1; a.ox = sin(S.t * 40) * 0.9
                if S.every(A, "sw", 0.3) { S.ptx("sweat", a.x, S.feetY(a) - h * 0.9, 1, po().a(-PI * 0.85, -PI * 0.15).s(8, 16).g(120).l(0.4, 0.7).jx(4)) }
                return
            }
            a.x = EA.px1; a.z = EA.pz1; a.alt = EA.pal1; a.dir = e.dir; a.ang = EA.pang1; a.pvy = -S.liftOf(a) - h * 0.5
            if S.every(A, "sw", 0.25) { S.ptx("sweat", a.x, S.feetY(a) - liftPx(S, a, a.alt) - h * 0.5, 1, po().a(-PI, 0).s(8, 16).g(80).l(0.4, 0.7).jx(5)) }
        }, { S, a, A in a.alt = 0 })
        A_(S, "dizzy", 3.6, { S, a, t, A in a.alt = 0; S.haptic("grin") }, { S, a, u, dt, A in                                           // 어질어질~: 비틀비틀 별이 빙글
            let h = S.HH(a), T = S.t, tt = u * 3.6, amp = 1 - ease(clamp((tt - 2.7) / 0.9, 0, 1)); S.standF(a); a.pose = 3
            a.ang = sin(T * 3.4) * 0.2 * amp; a.ox = sin(T * 2.2) * 5 * amp; a.pvy = 0
            S.pr(a, S.prop("stars", 0, -h * 1.06)); a.y = 0
            if S.once(A, "sy") { S.say(a, "어질어질~", 2.4) }
        }, { S, a, A in a.alt = 0 })

        // ── 챙챙: 꼬리를 헬리콥터 날개처럼 돌려 하늘을 돌아다니다 천천히 내려오고, 마구 화를 낸다 ──
        A_(S, "heli", 7.6, { S, a, t, A in
            let W = S.W; let r = S.inRange(a); A.alt0 = clamp(a.altStart != 0 ? a.altStart : 40, 14, 150); a.alt = A.alt0; A.x0 = a.x; A.z0 = a.z; A.s0 = 0
            let sd: Double = a.x < W / 2 ? 1 : -1
            A.tx = clamp(a.x + sd * S.rnd(0.25, 0.4) * W, r[0], r[1]); A.bx = clamp(A.tx - sd * S.rnd(0.2, 0.4) * W, r[0], r[1]); A.lx = clamp((A.bx + A.x0) / 2 + S.rnd(-0.1, 0.1) * W, r[0], r[1])
            A.tz = a.hero ? a.z : S.rnd(0.4, 0.9); a.chain = "rage"
        }, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t, tt = u * 7.6, Hh = clamp(A.alt0 * 0.55, 34, 58); S.standF(a); a.nograb = true; a.pose = 2; a.pvy = -h * 0.5
            var om = 0.0, alt = 0.0, x = a.x
            if tt < 1.0 { let q = tt; om = 10 + 50 * ease(q); alt = Hh + (A.alt0 - Hh) * (1 - ease(q)); a.ang = 0.12 + sin(T * 9) * 0.05; if S.once(A, "o") { S.say(a, "우다다다~!", 1.6); S.haptic("flap") } }
            else if tt < 5.2 {
                om = 62 + sin(T * 2) * 4; let q = (tt - 1.0) / 4.2, s3 = q * 3; let leg = min(2, Int(s3)); let lq = ease(s3 - Double(leg))
                let xs = [A.x0, A.tx, A.bx, A.lx]; x = xs[leg] + (xs[leg + 1] - xs[leg]) * lq; a.dir = xs[leg + 1] >= xs[leg] ? 1 : -1; a.z = A.z0 + (A.tz - A.z0) * ease(clamp(q * 1.6, 0, 1))
                alt = Hh + sin(T * 2.6) * 6 + sin(T * 1.3) * 4; a.ang = sin(T * 4) * 0.06 + 0.08
            } else if tt < 6.7 {
                let q = ease((tt - 5.2) / 1.5); om = 62 - 52 * q; alt = Hh * (1 - q) + sin(T * 2.6) * 3 * (1 - q); a.ang = 0.06 * (1 - q); x = a.x
                if S.every(A, "dw", 0.2) { S.ptx("puff", a.x, S.feetY(a) - 1, 1, po().a(-PI * 0.9, -PI * 0.1).s(10, 22).g(10).l(0.3, 0.5).r(0.8).jx(h * 0.4)) }
            } else {
                om = 10 * (1 - ease((tt - 6.7) / 0.9)); alt = 0; let q = clamp((tt - 6.7) / 0.2, 0, 1); a.sx = 1.12 - 0.12 * q; a.sy = 0.8 + 0.2 * q
                if S.once(A, "td") { S.haptic("land_puddle"); S.ptx("dust", a.x, S.feetY(a) - 1, 10, po().a(-PI * 0.98, -PI * 0.02).s(20, 56).g(40).l(0.4, 0.8).jx(h * 0.5)); S.say(a, "…!", 1.0) }
            }
            A.s0 = A.s0.isNaN ? 0 : A.s0; A.s0 += om * dt; a.x = x; a.alt = alt
            a.cell = tt >= 6.7 ? 4 : (Int(T * 9) % 2 == 0 ? 1 : 12); a.pose = 2                                                         // 꼬리를 돌리는 두 칸을 번갈아, 착지하면 깜짝
            if om > 4 { let rp = S.prop("rotor", -h * 0.5, -h * 0.42); rp.s = A.s0; rp.r = h * 0.55; S.pr(a, rp) }
            if tt < 6.7 && S.every(A, "wl", 0.14) { S.ptx("puff", a.x - Double(a.dir) * h * 0.55, S.feetY(a) - liftPx(S, a, alt) - h * 0.42, 1, po().a(-PI * 0.85, -PI * 0.15).s(6, 14).g(0).l(0.25, 0.4).r(0.7)) }
        }, { S, a, A in a.alt = a.altSave != 0 ? a.altSave : 0; a.ang = 0; a.pvy = 0 })
        A_(S, "rage", 4.2, nil, { S, a, u, dt, A in                                                                                     // 마구마구 화낸다
            let h = S.HH(a), T = S.t, tt = u * 4.2, amp = 1 - ease(clamp((tt - 3.5) / 0.7, 0, 1)); S.standF(a); a.pose = 5; a.cell = amp < 0.3 ? 14 : (Int(T * 7) % 2 == 0 ? 15 : 9)     // > < 화난 얼굴을 번갈아
            let b = abs(sin(T * 9.5)); a.y = -b * h * 0.16 * amp; a.sy = 1 - 0.12 * (1 - b) * amp; a.sx = 1 + 0.08 * (1 - b) * amp; a.ox = sin(T * 38) * 1.4 * amp; a.ang = sin(T * 19) * 0.05 * amp
            if S.once(A, "st") { S.stk(a, "angry", 3.4); S.haptic("angry") }
            if S.every(A, "say", 1.3) { S.say(a, ["화났다!!", "누가 던졌어!!", "으아아아!!", "놓지 말랬잖아!"][Int((S.t * 3).truncatingRemainder(dividingBy: 4))], 1.3) }
            if S.every(A, "pf", 0.17) { S.ptx("puff", a.x + (S.rnd() - 0.5) * h * 0.5, S.feetY(a) - h * 1.0, 1, po().a(-PI * 0.85, -PI * 0.15).s(14, 30).g(-10).l(0.4, 0.7).r(1.1).jx(3)) }
            if b < 0.12 && S.every(A, "sp", 0.3) { S.ptx("dust", a.x, S.feetY(a) - 1, 3, po().a(-PI * 0.95, -PI * 0.05).s(14, 34).g(40).l(0.3, 0.6).jx(h * 0.4)); S.shake(1.6, 0.18) }
            if S.every(A, "sk", 0.2) { S.ptx("spark", a.x + (S.rnd() - 0.5) * h, S.feetY(a) - h * (0.7 + S.rnd() * 0.5), 1, po().a(-PI, 0).s(6, 14).g(0).l(0.25, 0.4).r(1.2)) }
        }, nil)

        // ── 뽀푸의 지진에 놀란 친구들: 펄쩍 뛰고 덜덜 ──
        A_(S, "shock", 1.9, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t, tt = u * 1.9; S.standF(a); a.dir = A.fx >= a.x ? 1 : -1
            if tt < 0.32 {
                a.y = -sin(PI * tt / 0.32) * 11 * zs(a.z); a.sy = 1 + 0.08 * sin(PI * tt / 0.32)
                if S.once(A, "bang") { S.say(a, "깜짝이야!", 1.2); S.ptx("sweat", a.x, S.feetY(a) - h * 0.9, 3, po().a(-PI * 0.85, -PI * 0.15).s(10, 22).g(120).l(0.5, 0.8).jx(4)) }
            } else { let am = 1 - ease(clamp((tt - 1.3) / 0.6, 0, 1)); a.pose = 3; a.ox = sin(T * 45) * 1.2 * am }
        }, nil)
    }
}
