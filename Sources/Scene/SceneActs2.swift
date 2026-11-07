import Foundation

/// SceneActs 2/3 — 판다(죽순이)·아기하마(뽀송)·날아가기·날씨 반응 · 쮸르/뽀송 전용 동작 · 나머지 여섯 친구 동작 (안드로이드 SceneActs.java 이식).
extension SceneActs {
    // ── 판다(죽순이)·아기하마(뽀송) ──
    static func regPanda(_ S: SceneCore) {
        A_(S, "munch", 4.4, nil, { S, a, u, dt, A in
            // 대나무 줄기를 입에 대고 오물오물(자세 6 ↔ 7: 입을 다물었다 벌렸다) 하다가 흡족해서 하트
            let h = S.HH(a), T = S.t; S.standF(a); let eat = u > 0.08 && u < 0.86, open = sin(T * 9.5) > 0
            a.pose = eat ? (open ? 7 : 6) : 0; a.sy = 1 + (eat && open ? 0.014 : 0); a.ang = eat ? sin(T * 4.7) * 0.02 : 0
            if eat && S.every(A, "lf", 0.5) { S.ptx("leaf", a.x + Double(a.dir) * h * 0.3, S.feetY(a) - h * 0.85, 1, po().a(-PI * 0.85, -PI * 0.15).s(10, 22).g(90).l(0.6, 1.0).jx(4).r(0.8)) }
            if u > 0.1 && S.once(A, "sy") { S.say(a, "냠냠! 대나무 최고!", 2.4) }
            if u > 0.9 && S.once(A, "hh") { S.ptx("heart", a.x, S.feetY(a) - h * 0.8, 3, po().a(-PI * 0.98, -PI * 0.02).s(24, 54).g(55).l(0.9, 1.4).r(1.2).jx(5)) }
        }, nil)
        A_(S, "snooze", 4.8, nil, { S, a, u, dt, A in
            // 앉은 채 꾸벅꾸벅, 대나무를 끌어안고 잠깐 잔다
            let T = S.t; S.standF(a); let zz = u > 0.12 && u < 0.93; a.pose = zz ? 1 : 0; a.sy = 1 + (zz ? sin(T * 2.3) * 0.014 : 0); a.ang = zz ? sin(T * 1.1) * 0.03 : 0
            if zz && S.every(A, "zz", 0.6) { S.ptx("zzz", a.x + Double(a.dir) * S.HH(a) * 0.3, S.feetY(a) - S.HH(a) * 0.85, 1, po().a(-PI * 0.6, -PI * 0.4).s(6, 9).g(-4).l(1, 1.4).r(1)) }
            if u > 0.94 && S.once(A, "wk") { S.say(a, "음냐… 더 잘래", 1.6) }
        }, nil)
        A_(S, "hooray", 3.2, nil, { S, a, u, dt, A in
            // 신나서 폴짝폴짝(활발!)
            let h = S.HH(a), T = S.t; S.standF(a); a.pose = u < 0.92 ? 2 : -1; a.y = -abs(sin(T * 6.6)) * 9; a.sy = 1 + 0.03 * sin(T * 13.2)
            if S.every(A, "sp", 0.22) { S.ptx("spark", a.x + (S.rnd() - 0.5) * h * 0.9, S.feetY(a) - h * (0.5 + S.rnd() * 0.6), 1, po().a(-PI * 0.8, -PI * 0.2).s(8, 16).g(0).l(0.3, 0.5).r(0.9)) }
            if u > 0.05 && S.once(A, "sy") { S.say(a, "야호! 신난다!", 1.8) }
        }, nil)
    }

    static func regHippo(_ S: SceneCore) {
        A_(S, "sniff", 3.8, nil, { S, a, u, dt, A in
            // 데이지 한 송이를 코에 대고 킁킁(자세 6) — 향기가 좋아서 하트
            let h = S.HH(a), T = S.t; S.standF(a); a.pose = u > 0.06 && u < 0.92 ? 6 : 0; a.sy = 1 + (a.pose == 6 ? sin(T * 7) * 0.012 : 0); a.ang = a.pose == 6 ? sin(T * 3.1) * 0.025 : 0
            if u > 0.2 && S.every(A, "hh", 0.7) { S.ptx("heart", a.x + Double(a.dir) * h * 0.35, S.feetY(a) - h * 0.85, 1, po().a(-PI * 0.9, -PI * 0.1).s(14, 26).g(30).l(0.9, 1.3).r(1).jx(5)) }
            if u > 0.1 && S.once(A, "sy") { S.say(a, "꽃 향기 좋아~", 2.2) }
        }, nil)
        A_(S, "shoeshow", 3.4, nil, { S, a, u, dt, A in
            // 한 발을 번쩍 들어 새 신발 자랑(자세 7) — 반짝반짝
            let h = S.HH(a), T = S.t; S.standF(a); let sh = u > 0.08 && u < 0.9; a.pose = sh ? 7 : 0; a.ang = sh ? sin(T * 5) * 0.035 : 0; a.y = sh ? -abs(sin(T * 5)) * 1.2 : 0
            if sh && S.every(A, "sp", 0.16) { S.ptx("spark", a.x + Double(a.dir) * h * 0.45, S.feetY(a) - h * 0.12 - S.rnd() * h * 0.12, 1, po().a(-PI * 0.85, -PI * 0.15).s(8, 16).g(0).l(0.3, 0.5).jx(4).r(0.9)) }
            if u > 0.12 && S.once(A, "sy") { S.say(a, "새 신발이에요!", 2.2) }
        }, nil)
        A_(S, "sparkle", 3.4, nil, { S, a, u, dt, A in
            // 깨끗한 게 최고! 몸을 털고 반짝반짝 윤을 낸다
            let h = S.HH(a), T = S.t; S.standF(a); let on = u > 0.06 && u < 0.9; a.pose = on ? 2 : -1; a.y = on ? -abs(sin(T * 5.4)) * 5 : 0; a.ox = on ? sin(T * 10.8) * 1.2 : 0
            if on && S.every(A, "sp", 0.12) { S.ptx("spark", a.x + (S.rnd() - 0.5) * h * 0.9, S.feetY(a) - h * (0.15 + S.rnd() * 0.8), 1, po().a(-PI * 0.9, -PI * 0.1).s(6, 14).g(0).l(0.3, 0.55).r(1)) }
            if u > 0.1 && S.once(A, "sy") { S.say(a, "깨끗한 게 최고!", 2.0) }
        }, nil)
    }

    /// 놓았을 때 날아가기 + 날씨/전용/떨어뜨리기 동작 묶음 등록 + 칸 표 적용
    static func regLand(_ S: SceneCore) {
        A_(S, "flyaway", 3.6, { S, a, t, A in
            A.alt0 = clamp(a.altStart != 0 ? a.altStart : 14, 14, 160); a.alt = A.alt0; let W = S.W; A.x0 = a.x; A.z0 = a.z
            A.tx = clamp(a.x + (a.x < W / 2 ? 1 : -1) * S.rnd(0.3, 0.55) * W, a.w * 0.6, W - a.w * 0.6); A.tz = S.rnd(0.1, 0.95); A.dir0 = a.dir
        }, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; a.pvy = -h * 0.5; a.y = 0
            let fps = Double(a.D.fps)
            if u < 0.2 { let p = u / 0.2; a.alt = 12 + (A.alt0 - 12) * (1 - p * p); a.ang = 0.32 * p; a.fr += dt * fps * 0.3 }
            else if u < 0.32 {
                let q = ease((u - 0.2) / 0.12); a.alt = 12 + 18 * q; a.ang = 0.32 * (1 - q) - 0.08 * q; a.fr += dt * fps * 1.4
                if S.once(A, "o") { S.say(a, "푸득!", 1.2); S.ptx("puff", a.x, S.feetY(a) - 6, 4, po().a(-PI, 0).s(10, 20).g(10).jx(h * 0.3)) }
            } else if u < 0.82 {
                let m = ease((u - 0.32) / 0.5); a.x = A.x0 + (A.tx - A.x0) * m; a.z = A.z0 + (A.tz - A.z0) * m; a.dir = A.tx >= A.x0 ? 1 : -1; a.alt = 30 + sin(T * 4) * 3; a.ang = -0.05; a.fr += dt * fps * 1.3
            } else if u < 0.96 {
                let d = ease((u - 0.82) / 0.14); a.alt = 30 * (1 - d); a.ang = 0; a.fr += dt * fps * 0.7
                if d > 0.8 && S.once(A, "td") { S.ptx("dust", a.x, S.feetY(a) - 1, 5, po().a(-PI * 0.9, -PI * 0.1).s(10, 22)); S.haptic("land_fly") }
            } else { a.alt = 0; S.standF(a) }
        }, { S, a, A in a.alt = a.altSave != 0 ? a.altSave : 18 })
        regWx(S)
        regMo(S)
        regMo2(S)
        regDrop(S)
        applyCells(S)
    }

    // ── 엔진이 정한 날씨 반응 말 ──
    static func wsay(_ S: SceneCore, _ a: Actor, _ act: String, _ sec: Double) {
        if !S.hasRes { return }
        guard let T = S.res.traits[a.id], let v = T.say[act], !v.isEmpty else { return }
        S.say(a, v, sec)
    }

    // ── 날씨 반응 ──
    static func regWx(_ S: SceneCore) {
        // 추위: 덜덜 떨고 입김이 난다
        A_(S, "shiver", 3.0, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a); let k = min(1, u / 0.1) * (u > 0.9 ? (1 - u) / 0.1 : 1)
            a.pose = 3; let s = sin(T * 44); a.ox = s * 1.5 * k; a.sy = 1 - 0.05 * k + abs(s) * 0.012 * k; a.sx = 1 + 0.04 * k; a.ang = sin(T * 31) * 0.025 * k
            let hd = headOf(a, h); let dr = Double(a.dir)
            if S.every(A, "br", 0.55) { S.ptx("breath", a.x + dr * (hd[0] + h * 0.1), S.feetY(a) - S.liftOf(a) + hd[1] + h * 0.1, 1, po().a(a.dir > 0 ? -0.5 : PI + 0.5, a.dir > 0 ? -0.2 : PI + 0.2).s(8, 14).g(-6).l(0.9, 1.3).r(1 + S.rnd() * 0.5)) }
            if u > 0.08 && S.once(A, "sy") { wsay(S, a, "shiver", 2.0) }
        }, nil)
        // 더위: 헥헥대고 땀이 나고 부채질
        A_(S, "pant", 3.4, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a); let k = min(1, u / 0.12) * (u > 0.9 ? (1 - u) / 0.1 : 1)
            a.pose = u > 0.1 && u < 0.9 ? 4 : -1; let b = sin(T * 13); a.sy = 1 + 0.05 * b * k; a.sx = 1 - 0.035 * b * k; a.ang = -0.05 * k
            let hd = headOf(a, h); let dr = Double(a.dir)
            if S.every(A, "sw", 0.42) { S.ptx("sweat", a.x + dr * (hd[0] - h * 0.08), S.feetY(a) - S.liftOf(a) + hd[1] - h * 0.05, 1, po().a(-PI * 0.8, -PI * 0.2).s(10, 20).g(120).l(0.5, 0.8).jx(3)) }
            if u > 0.3 && u < 0.88 && a.kind != "eagle" { let f = S.prop("fan", h * 0.55, -h * 0.4 + sin(T * 18) * 1.6); f.r = sin(T * 18) * 0.55; S.pr(a, f) }
            if u > 0.08 && S.once(A, "sy") { wsay(S, a, "pant", 2.2) }
        }, nil)
        // 햇빛: 눈이 부셔 고개를 살짝 들고 선글라스
        A_(S, "squint", 3.2, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a); let b = ease(min(1, u / 0.22)) * (u > 0.86 ? 1 - ease((u - 0.86) / 0.14) : 1)
            a.ang = -0.09 * b; a.sy = 1 + 0.03 * b; a.pvy = -h * 0.3
            let hd = headOf(a, h); let dr = Double(a.dir)
            if u < 0.42 { a.pose = 5 } else { let gl = S.prop("glasses", hd[0], hd[1]); gl.s = 1.1 * b; S.pr(a, gl) }      // 처음엔 눈을 찡그리다 선글라스를 낀다
            if u > 0.3 && u < 0.85 && S.every(A, "sp", 0.35) { S.ptx("spark", a.x + dr * (hd[0] + h * 0.2), S.feetY(a) - S.liftOf(a) + hd[1] - h * 0.12, 1, po().a(-PI * 0.7, -PI * 0.3).s(6, 12).g(0).l(0.3, 0.55).jx(5).r(0.9)) }
            if u > 0.2 && S.once(A, "sy") { wsay(S, a, "squint", 2.0) }
            _ = T
        }, nil)
        // 바람: 바람을 마주 보고 몸을 기울여 버틴다 · 바람에 떠밀려 조금 밀리고 낙엽이 날아간다
        A_(S, "gust", 3.0, { S, a, t, A in A.d0 = a.dir }, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; let r = S.inRange(a); S.standF(a); a.dir = -1
            let k = min(1, u / 0.15) * (u > 0.85 ? (1 - u) / 0.15 : 1), sw = sin(T * 7); a.pose = k > 0.3 ? 5 : -1
            a.ang = (0.2 + 0.03 * sw) * k; a.pvy = -h * 0.05; a.ox = sin(T * 23) * 0.8 * k; a.sx = 1 + 0.03 * sw * k
            a.x = clamp(a.x + (10 + 6 * Double(S.L.wind)) * dt * k, r[0], r[1])
            if S.every(A, "lf", 0.16) { S.ptx(S.rnd() < 0.5 ? "leaf" : "dust", max(2, a.x - h * 1.2), S.feetY(a) - h * (0.2 + S.rnd() * 0.9), 1, po().a(-0.15, 0.15).s(70, 130).g(-4).l(0.7, 1.1).jy(4)) }
            if u > 0.08 && S.once(A, "sy") { wsay(S, a, "gust", 2.0) }
        }, { S, a, A in a.dir = A.d0 != 0 ? A.d0 : 1 })
        // 비: 물웅덩이에서 첨벙첨벙
        A_(S, "splash", 3.0, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t, fy = S.feetY(a); S.standF(a); let ph = T * 7, hop = abs(sin(ph))
            if hop > 0.35 { a.pose = 2 }; a.y = -hop * h * 0.2; a.sy = 1 + (hop < 0.12 ? -0.1 : 0.02); a.sx = 1 + (hop < 0.12 ? 0.08 : 0)
            if hop < 0.1 && S.every(A, "lnd", 0.38) {
                S.ptx("drop", a.x - Double(a.dir) * 2, fy - 1, 6, po().a(-PI * 0.95, -PI * 0.05).s(26, 56).g(190).l(0.4, 0.75).jx(h * 0.22))
                S.ptx("ring", a.x, fy, 1, po().a(0, 0).s(0, 0).g(0).l(0.7, 0.7)); S.haptic("splash")
            }
            if u > 0.08 && S.once(A, "sy") { wsay(S, a, "splash", 2.0) }
        }, nil)
        // 비: 젖은 몸을 부르르 털어 물방울이 사방으로 튄다
        A_(S, "shakeoff", 2.6, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a); let k = u < 0.2 ? ease(u / 0.2) : u < 0.75 ? 1 : 1 - ease((u - 0.75) / 0.25)
            if k > 0.3 { a.pose = 3 }; a.ox = sin(T * 36) * 2.4 * k; a.ang = sin(T * 28) * 0.09 * k; a.sx = 1 + 0.1 * k; a.sy = a.sx
            if k > 0.3 && S.every(A, "wd", 0.07) { S.ptx("drop", a.x, S.feetY(a) - S.liftOf(a) - h * 0.5, 2, po().a(-PI * 0.98, -PI * 0.02).s(40, 85).g(150).l(0.35, 0.6).jx(h * 0.12).jy(h * 0.2)) }
            if u > 0.1 && S.once(A, "sy") { wsay(S, a, "shakeoff", 1.9) }
        }, nil)
        // 눈: 고개를 들고 눈송이를 받아 먹는다
        A_(S, "snowcatch", 3.4, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a); let b = ease(min(1, u / 0.2)) * (u > 0.88 ? 1 - ease((u - 0.88) / 0.12) : 1)
            if u > 0.4 && u < 0.85 { a.pose = 4 }; a.ang = -0.2 * b + sin(T * 5) * 0.02 * b; a.pvy = -h * 0.2; a.y = -abs(sin(T * 6.5)) * h * 0.06 * b
            let hd = headOf(a, h); let dr = Double(a.dir)
            if S.every(A, "fl", 0.12) { S.ptx("flake", a.x + dr * (hd[0] + h * 0.05) + S.rnd(-h * 0.25, h * 0.25), S.feetY(a) - S.liftOf(a) + hd[1] - h * 0.8, 1, po().a(PI * 0.45, PI * 0.55).s(26, 40).g(10).l(0.35, 0.5)) }
            if u > 0.45 && u < 0.85 && S.every(A, "cg", 0.6) { S.ptx("spark", a.x + dr * (hd[0] + h * 0.12), S.feetY(a) - S.liftOf(a) + hd[1] - h * 0.1, 2, po().a(-PI, 0).s(8, 16).g(0).l(0.25, 0.45).jx(4).r(0.8)) }
            if u > 0.15 && S.once(A, "sy") { wsay(S, a, "snowcatch", 2.2) }
        }, nil)
        // 안개: 두리번거리며 앞을 살핀다
        A_(S, "peer", 3.6, { S, a, t, A in A.d0 = a.dir }, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a); a.dir = (Int(floor(u * 4.5)) % 2 != 0 ? -1 : 1) * (A.d0 != 0 ? A.d0 : 1)
            let lk = sin(u * PI * 4.5 * 0.5 * 2); a.ang = 0.06 * lk; a.sy = 1 + 0.02 * sin(T * 3); a.y = -abs(sin(T * 5)) * 1.2
            if S.every(A, "q", 0.9) { S.ptx("note", a.x + Double(a.dir) * h * 0.35, S.feetY(a) - S.liftOf(a) - h * 1.05, 1, po().a(-PI * 0.6, -PI * 0.4).s(6, 10).g(-4).l(0.9, 1.2).r(1)) }
            if u > 0.1 && S.once(A, "sy") { wsay(S, a, "peer", 2.2) }
        }, { S, a, A in a.dir = A.d0 != 0 ? A.d0 : 1 })
    }

    // ── 쮸르(죽순이)·베비히포(뽀송) 전용 동작 + L_tumble·L_hose·flee ──
    static func regMo(_ S: SceneCore) {
        // ── 쮸르(죽순이) ──
        A_(S, "roll", 3.6, { S, a, t, A in A.tx = S.aheadX(a, 70 + S.rnd() * 40) }, { S, a, u, dt, A in
            // 몸을 동그랗게 말아 데굴데굴 굴러간다
            let h = S.HH(a), T = S.t; S.standF(a)
            if u < 0.1 { cell(a, 2, 0); a.sy = 0.9 + 0.1 * (u / 0.1); if S.once(A, "sy") { S.say(a, "데굴데굴~!", 2.2) } }
            else if u < 0.84 {
                cell(a, 0, 2); a.pvy = -h * 0.5; a.ang = (T - A.t0 - 0.36) * 9.5; a.y = 0
                if S.moveX(a, A.tx, a.spd * 1.55, dt) { A.tx = S.aheadX(a, 70 + S.rnd() * 40) }
                if S.every(A, "dt", 0.13) { S.ptx("dust", a.x - Double(a.dir) * h * 0.22, S.feetY(a) - 1, 1, po().a(-PI * 0.9, -PI * 0.1).s(8, 18)) }
            } else {
                cell(a, 15, 2); a.y = -abs(sin((u - 0.84) / 0.16 * PI * 2)) * 4
                if S.once(A, "h") { S.ptx("heart", a.x, S.feetY(a) - h * 0.8, 3, po().a(-PI * 0.98, -PI * 0.02).s(24, 50).g(55).l(0.9, 1.3).r(1).jx(5)) }
            }
        }, nil)
        A_(S, "twirl", 3.4, nil, { S, a, u, dt, A in
            // 대나무를 번쩍 들어 빙글빙글 돌린다
            let h = S.HH(a), T = S.t; S.standF(a); let on = u > 0.08 && u < 0.9; cell(a, on ? 6 : -1, on ? 2 : -1)
            if on {
                a.ang = sin(T * 5) * 0.03; a.y = -abs(sin(T * 5)) * 1.5
                let bp = S.prop("bamboo", h * 0.34, -h * 1.0); bp.r = T * 10; S.pr(a, bp)
                if S.every(A, "sp", 0.2) { S.ptx("spark", a.x + Double(a.dir) * h * 0.34 + (S.rnd() - 0.5) * h * 0.8, S.feetY(a) - h * (0.9 + S.rnd() * 0.4), 1, po().a(-PI * 0.85, -PI * 0.15).s(8, 16).g(0).l(0.3, 0.5).r(0.9)) }
            }
            if u > 0.1 && S.once(A, "sy") { S.say(a, "빙글빙글~ 대나무 돌리기!", 2.2) }
        }, nil)
        A_(S, "peek", 3.4, nil, { S, a, u, dt, A in
            // 두리번두리번 살피다 빼꼼
            let T = S.t; S.standF(a)
            if u < 0.3 { cell(a, 3, 0); a.dir = A.d0 }
            else if u < 0.62 { cell(a, 3, 0); a.dir = -A.d0 }
            else { cell(a, 7, 0); a.dir = A.d0; a.sy = 1 + sin(T * 6) * 0.012 }
            if u > 0.04 && S.once(A, "q") { S.say(a, "뭐가 있나~?", 1.6) }
            if u > 0.66 && S.once(A, "e") { S.say(a, "빼꼼! 아무도 없네", 1.8) }
        }, nil)
        A_(S, "bellypat", 4.0, nil, { S, a, u, dt, A in
            // 배불러서 앉아 배를 통통 두드린다
            let h = S.HH(a), T = S.t; S.standF(a); let on = u > 0.08 && u < 0.92; cell(a, on ? 8 : -1, on ? 0 : -1)
            if on {
                let b = max(0, sin(T * 9)); a.sy = 1 - 0.035 * b; a.sx = 1 + 0.03 * b
                if S.every(A, "pt", 0.7) { S.ptx("note", a.x + Double(a.dir) * h * 0.3, S.feetY(a) - h * 0.7, 1, po().a(-PI * 0.75, -PI * 0.25).s(10, 18).g(-6).l(0.8, 1.1).r(1)) }
            }
            if u > 0.1 && S.once(A, "sy") { S.say(a, "배불러~ 퉁퉁!", 2.4) }
            if u > 0.88 && S.once(A, "hh") { S.ptx("heart", a.x, S.feetY(a) - h * 0.8, 3, po().a(-PI * 0.98, -PI * 0.02).s(24, 54).g(55).l(0.9, 1.4).r(1.2).jx(5)) }
        }, nil)
        A_(S, "yawn", 4.2, nil, { S, a, u, dt, A in
            // 하아암~ 큰 하품 뒤에 기지개
            let h = S.HH(a); S.standF(a)
            if u < 0.08 { cell(a, -1, -1) }
            else if u < 0.56 { cell(a, 9, 0); a.sy = 1 + 0.02 * sin((u - 0.08) / 0.48 * PI) }
            else if u < 0.9 { cell(a, 6, 2); a.sy = 1 + 0.03 * sin((u - 0.56) / 0.34 * PI) }
            if u > 0.1 && u < 0.56 && S.every(A, "zz", 0.8) { S.ptx("zzz", a.x + Double(a.dir) * h * 0.3, S.feetY(a) - h * 0.85, 1, po().a(-PI * 0.6, -PI * 0.4).s(6, 9).g(-4).l(1, 1.4).r(1)) }
            if u > 0.12 && S.once(A, "sy") { S.say(a, "하아암~", 1.8) }
            if u > 0.58 && S.once(A, "st") { S.say(a, "으아~ 시원하다!", 1.6) }
        }, nil)
        A_(S, "kungfu", 3.6, nil, { S, a, u, dt, A in
            // 쿵푸 자세 — 한 발 들고 서서(10) 앞으로 내지른다(11)
            let h = S.HH(a), T = S.t; S.standF(a); let on = u > 0.06 && u < 0.92; let ph = (T - A.t0) * 2.6; let strike = Int(floor(ph)) % 2 == 1
            cell(a, on ? (strike ? 11 : 10) : -1, on ? 2 : -1)
            if on {
                a.ox = strike ? Double(a.dir) * 3.5 : 0; a.y = strike ? -1.2 : 0
                if strike && S.every(A, "sk", 0.38) { S.ptx("spark", a.x + Double(a.dir) * h * 0.62, S.feetY(a) - h * 0.55, 2, po().a(a.dir > 0 ? -0.7 : PI - 0.7, a.dir > 0 ? 0.7 : PI + 0.7).s(12, 24).g(0).l(0.25, 0.4).jy(6).r(1.1)); S.say(a, "하이얍!", 0.5) }
            }
            if u > 0.94 && S.once(A, "e") { S.say(a, "쿵푸 판다!", 1.2) }
        }, nil)
        A_(S, "sneeze", 3.2, nil, { S, a, u, dt, A in
            // 에… 에… 에취! (코가 간질간질)
            let h = S.HH(a), T = S.t; S.standF(a); let dr = Double(a.dir)
            if u < 0.44 { cell(a, 12, 0); let k = u / 0.44; a.sy = 1 + 0.035 * k; a.ang = -0.05 * k + sin(T * 30) * 0.006 * k; if u > 0.08 && S.once(A, "a") { S.say(a, "에… 에…", 1.2) } }
            else if u < 0.64 {
                cell(a, 13, 0); a.ox = -dr * 3.5; a.sy = 0.94
                if S.once(A, "x") {
                    S.say(a, "에취!!", 1.4); S.haptic("thud")
                    S.ptx("puff", a.x + dr * h * 0.6, S.feetY(a) - h * 0.5, 6, po().a(a.dir > 0 ? -0.5 : PI - 0.5, a.dir > 0 ? 0.5 : PI + 0.5).s(26, 54).g(10).l(0.3, 0.5).jy(5))
                    S.ptx("leaf", a.x + dr * h * 0.4, S.feetY(a) - h * 0.55, 4, po().a(a.dir > 0 ? -0.6 : PI - 0.6, a.dir > 0 ? 0.6 : PI + 0.6).s(26, 50).g(90).l(0.6, 0.9).jx(3).r(0.8))
                }
            } else { cell(a, 12, 0); a.ang = -0.03; if u > 0.7 && S.once(A, "n") { S.say(a, "…훌쩍. 감기 걸렸나", 1.8) } }
        }, nil)
        // ── 놓았을 때: 죽순을 공중에 떨어뜨리고 앞구르기 → 착지 → 죽순 찾으러 가기 ──
        A_(S, "L_tumble", 1.3, { S, a, t, A in
            S.ptx("dirt", a.x, S.feetY(a) - 2, 6, po().a(-PI * 0.95, -PI * 0.05).s(14, 30).g(150).l(0.35, 0.6).jx(8))
            S.ptx("star", a.x, S.feetY(a) - S.HH(a) * 0.9, 3, po().a(-PI * 0.95, -PI * 0.05).s(14, 30).g(40).l(0.6, 0.9).r(0.9).jx(8))
            S.say(a, "어이쿠! 내 죽순!", 1.8); a.chain = "search"
        }, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a); a.sk = "juksun_nb"
            if u < 0.45 { cell(a, 2, 0); a.sy = 0.86 + 0.14 * ease(u / 0.45); a.sx = 1.1 - 0.1 * ease(u / 0.45) }
            else { cell(a, 3, 0); a.ang = sin(T * 7) * 0.04; S.pr(a, S.prop("stars", 0, -h * 1.06)) }
        }, nil)
        A_(S, "search", 9.0, { S, a, t, A in A.mx = 0; A.lx = t; A.dir0 = a.dir }, { S, a, u, dt, A in
            // 두리번 → 킁킁 → 걸어가서 → 집어 들고 "찾았다!"
            let h = S.HH(a), T = S.t; let bo = S.bamOf(a); S.standF(a); a.sk = "juksun_nb"
            let ph = Int(A.mx); let pe = T - A.lx
            if bo == nil && !(ph == 3 && A.on["pick"] != nil) { A.dur = (T - A.t0) + 0.01; return }          // 대나무가 사라졌다(잡혀서 옮겨짐 등) — 찾기를 접는다
            if ph == 0 {
                let b = bo!
                cell(a, 3, 0); a.dir = pe < 0.65 ? A.dir0 : -A.dir0; if S.once(A, "q") { S.say(a, "어디 갔지…?", 1.4) }
                if pe > 1.3 { A.mx = 1; A.lx = T; a.dir = b.x >= a.x ? 1 : -1 }
            } else if ph == 1 {
                let b = bo!
                cell(a, 4, 0); a.dir = b.x >= a.x ? 1 : -1; a.ang = sin(T * 9) * 0.02; if S.once(A, "sn") { S.say(a, "킁킁… 이쪽이다!", 1.2) }
                if pe > 1.1 { A.mx = 2; A.lx = T }
            } else if ph == 2 {
                let b = bo!
                a.cell = -1; let tx = b.x - (b.x >= a.x ? 1.0 : -1.0) * h * 0.34
                if S.moveX(a, tx, a.spd * 1.3, dt) || pe > 6.5 { a.x = tx; A.mx = 3; A.lx = T; a.dir = b.x >= a.x ? 1 : -1 }
            } else {
                if pe < 0.35, let b = bo {
                    cell(a, 2, 0); a.sy = 0.9; let q = ease(pe / 0.35); b.x += (a.x + Double(a.dir) * h * 0.3 - b.x) * q * 0.5; b.y += (S.feetY(a) - h * 0.45 - b.y) * q * 0.5; b.rot += (1.2 * Double(a.dir) - b.rot) * q * 0.5
                } else if pe >= 0.35 {
                    if S.once(A, "pick") { bo?.taken = true; S.say(a, "찾았다! 내 죽순!", 2.0); S.haptic("hearts"); S.ptx("heart", a.x, S.feetY(a) - h * 0.85, 5, po().a(-PI * 0.98, -PI * 0.02).s(24, 54).g(55).l(0.9, 1.4).r(1.2).jx(5)) }
                    cell(a, 5, 2); a.sk = nil; a.y = -abs(sin((pe - 0.35) * 9)) * 4
                }
                if pe > 1.7 { A.dur = (T - A.t0) + 0.01 }
            }
        }, nil)

        // ── 베비히포(뽀송) ──
        A_(S, "fountain", 3.6, nil, { S, a, u, dt, A in
            // 고개를 젖히고 입으로 분수를 뿜는다
            let h = S.HH(a), T = S.t; S.standF(a); let on = u > 0.1 && u < 0.88; cell(a, on ? 5 : -1, on ? 0 : -1)
            if on {
                let mx = a.x + Double(a.dir) * h * 0.3, my = S.feetY(a) - h * 0.92; S.pr(a, S.jetProp(mx, my, mx + Double(a.dir) * 3, my - h * (0.55 + 0.12 * sin(T * 12))))
                if S.every(A, "dr", 0.08) { S.ptx("drop", mx + Double(a.dir) * 3, my - h * 0.55, 1, po().a(-PI * 0.85, -PI * 0.15).s(10, 30).g(190).l(0.5, 0.8).jx(2)) }
            }
            if u > 0.12 && S.once(A, "sy") { S.say(a, "쏴아~ 분수 쇼!", 2.0) }
            if u > 0.9 && S.once(A, "sp") { S.ptx("spark", a.x, S.feetY(a) - h * 0.9, 4, po().a(-PI, 0).s(12, 26).g(0).l(0.3, 0.5).jx(h * 0.3).r(1)) }
        }, nil)
        A_(S, "tapdance", 3.8, nil, { S, a, u, dt, A in
            // 새 신발로 탭탭탭 탭댄스
            let h = S.HH(a), T = S.t; S.standF(a); let on = u > 0.06 && u < 0.92; let ph = (T - A.t0) * 4.6; let r2 = Int(floor(ph)) % 2 == 1
            cell(a, on ? (r2 ? 7 : 6) : -1, on ? 2 : -1)
            if on {
                a.y = -abs(sin(ph * PI)) * 2.4; a.ox = sin(ph * PI * 0.5) * 1.6
                if S.every(A, "tp", 0.22) { S.ptx("spark", a.x + (r2 ? -1 : 1) * h * 0.3, S.feetY(a) - 1, 1, po().a(-PI * 0.9, -PI * 0.1).s(8, 16).g(0).l(0.25, 0.4).r(0.9)) }
                if S.every(A, "nt", 0.6) { S.ptx("note", a.x + Double(a.dir) * h * 0.35, S.feetY(a) - h * 1.0, 1, po().a(-PI * 0.7, -PI * 0.3).s(12, 20).g(-6).l(0.9, 1.3).r(1).jx(6)) }
            }
            if u > 0.08 && S.once(A, "sy") { S.say(a, "탭탭탭~ 신발 소리 좋다!", 2.2) }
        }, nil)
        A_(S, "blowbub", 3.8, nil, { S, a, u, dt, A in
            // 후~ 비눗방울을 불어 날린다
            let h = S.HH(a), T = S.t; S.standF(a); let on = u > 0.1 && u < 0.88; cell(a, on ? 15 : -1, on ? 0 : -1)
            if on {
                a.sy = 1 + sin(T * 5) * 0.012
                if S.every(A, "bb", 0.2) { S.ptx("bub", a.x + Double(a.dir) * h * 0.38, S.feetY(a) - h * 0.62, 1, po().a(a.dir > 0 ? -0.55 : PI - 0.55, a.dir > 0 ? -0.1 : PI - 0.1).s(14, 34).g(-26).l(1.4, 2.2).r(1 + S.rnd() * 1.4).jx(2)) }
            }
            if u > 0.12 && S.once(A, "sy") { S.say(a, "후~ 비눗방울이다!", 2.2) }
        }, nil)
        A_(S, "gape", 3.6, nil, { S, a, u, dt, A in
            // 하마답게 입을 쩌억~ 크게 하품
            let h = S.HH(a); S.standF(a); let on = u > 0.1 && u < 0.84; cell(a, on ? 8 : -1, on ? 0 : -1)
            if on { let k = sin((u - 0.1) / 0.74 * PI); a.sy = 1 + 0.03 * k; a.ang = -0.03 * k }
            if on && S.every(A, "zz", 0.8) { S.ptx("zzz", a.x + Double(a.dir) * h * 0.3, S.feetY(a) - h * 0.85, 1, po().a(-PI * 0.6, -PI * 0.4).s(6, 9).g(-4).l(1, 1.4).r(1)) }
            if u > 0.14 && S.once(A, "sy") { S.say(a, "하아~암! 졸려요", 2.0) }
        }, nil)
        A_(S, "shoeswap", 4.2, nil, { S, a, u, dt, A in
            // 앉아서 신발을 갈아 신어 본다 — 이것도 예쁘고 저것도 예뻐!
            let h = S.HH(a), T = S.t; S.standF(a); let on = u > 0.06 && u < 0.92; let alt = Int(floor((T - A.t0) / 0.85)) % 2 == 1
            cell(a, on ? (alt ? 12 : 9) : -1, on ? 7 : -1)
            if on && S.every(A, "sp", 0.2) { S.ptx("spark", a.x + Double(a.dir) * h * 0.1 + (S.rnd() - 0.5) * h * 0.5, S.feetY(a) - h * 0.12 - S.rnd() * h * 0.14, 1, po().a(-PI * 0.85, -PI * 0.15).s(8, 16).g(0).l(0.3, 0.5).r(0.9)) }
            if u > 0.1 && S.once(A, "sy") { S.say(a, "이 신발도 예쁘고~", 1.8) }
            if u > 0.56 && S.once(A, "s2") { S.say(a, "저 신발도 예쁘다!", 1.8) }
        }, nil)
        A_(S, "polish", 3.6, nil, { S, a, u, dt, A in
            // 허리를 굽혀 신발을 쓱쓱 닦아 반짝반짝
            let h = S.HH(a), T = S.t; S.standF(a); let on = u > 0.06 && u < 0.9; cell(a, on ? 10 : -1, on ? 0 : -1)
            if on {
                a.ox = sin(T * 13) * 1.4; a.sy = 1 - 0.015 * abs(sin(T * 13))
                if S.every(A, "sp", 0.14) { S.ptx("spark", a.x + Double(a.dir) * h * 0.3 + (S.rnd() - 0.5) * h * 0.3, S.feetY(a) - h * 0.12 - S.rnd() * h * 0.1, 1, po().a(-PI * 0.9, -PI * 0.1).s(8, 18).g(0).l(0.3, 0.5).r(1)) }
            }
            if u > 0.1 && S.once(A, "sy") { S.say(a, "쓱쓱~ 반짝반짝 닦자!", 2.2) }
        }, nil)
        A_(S, "flower", 3.4, nil, { S, a, u, dt, A in
            // 머리의 데이지 꽃을 매만지며 으쓱
            let h = S.HH(a), T = S.t; S.standF(a); let on = u > 0.08 && u < 0.9; cell(a, on ? 11 : -1, on ? 2 : -1)
            if on { a.ang = sin(T * 3.2) * 0.02; a.y = -abs(sin(T * 4)) * 1.2 }
            if on && S.every(A, "hh", 0.8) { S.ptx("heart", a.x + Double(a.dir) * h * 0.2, S.feetY(a) - h * 1.0, 1, po().a(-PI * 0.9, -PI * 0.1).s(14, 26).g(30).l(0.9, 1.3).r(1).jx(5)) }
            if u > 0.1 && S.once(A, "sy") { S.say(a, "내 꽃이 제일 예쁘죠?", 2.2) }
        }, nil)
        // ── 놓았을 때: 입에서 땅으로 물대포로 안전하게 착지 → 주변 친구들에게 물대포 발사 → 친구들이 놀라 도망 ──
        A_(S, "L_hose", 1.4, { S, a, t, A in
            let pg = S.mkGfx("puddle", a.x, a.z, 3.4); pg.r = 13; S.addGfx(pg)
            S.ptx("splash", a.x, S.feetY(a) - 1, 8, po().a(-PI * 0.95, -PI * 0.05).s(20, 50).g(170).l(0.35, 0.7).jx(7)); S.ptx("ring", a.x, S.feetY(a), 1, po().a(0, 0).s(0, 0).g(0).l(0.8, 0.8))
            S.say(a, "사뿐~ 안전 착지!", 1.5); a.chain = "squirt"
        }, { S, a, u, dt, A in
            S.standF(a)
            if u < 0.5 { cell(a, 2, 0); a.sy = 0.86 + 0.14 * ease(u / 0.5); a.sx = 1.1 - 0.1 * ease(u / 0.5) } else { cell(a, 4, 2); a.ang = sin(S.t * 6) * 0.02 }
        }, nil)
        A_(S, "squirt", 9.0, { S, a, t, A in
            var L: [Actor] = []
            for o in S.actors where o !== a && !o.dead && !o.hidden && !o.hero && o.vis && !o.leaving { L.append(o) }
            let ax = a.x; L.sort { abs($0.x - ax) < abs($1.x - ax) }
            A.tg = Array(L.prefix(3)); A.lx = t
        }, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t, e = T - A.t0; S.standF(a); let tg = A.tg ?? []; let n = tg.count
            let fire0 = 0.8, per = 0.95, fireEnd = fire0 + (n == 0 ? 1.3 : per * Double(n))
            var mx = a.x + Double(a.dir) * h * 0.3; let my = S.feetY(a) - h * 0.6
            if e < fire0 {
                cell(a, 3, 0); if n > 0 { a.dir = tg[0].x >= a.x ? 1 : -1 }; a.sx = 1 + 0.05 * sin(e * 24) * (e / fire0); if S.once(A, "rd") { S.say(a, "이번엔 내 차례! 물대포~!", 2.0) }
            } else if e < fireEnd {
                let fe = e - fire0
                if n == 0 {
                    cell(a, 5, 0); S.pr(a, S.jetProp(mx, my, mx + Double(a.dir) * h * 1.4, my - h * 0.5)); if S.once(A, "sy") { S.say(a, "쏴아~!", 1.2); S.haptic("squirt") }
                } else {
                    let i = min(n - 1, Int(floor(fe / per))); let o = tg[i]; cell(a, 3, 0); a.dir = o.x >= a.x ? 1 : -1
                    mx = a.x + Double(a.dir) * h * 0.3; let tx = o.x + o.ox, ty = S.feetY(o) - S.HH(o) * 0.5 + o.y, k = clamp((fe - Double(i) * per) / 0.14, 0.05, 1)
                    S.pr(a, S.jetProp(mx, my, mx + (tx - mx) * k, my + (ty - my) * k))
                    if S.once(A, "st\(i)") { S.startle(a, o); S.haptic("squirt") }
                    if k >= 1 && S.every(A, "sp", 0.09) { S.ptx("splash", tx, ty, 2, po().a(-PI * 0.95, -PI * 0.05).s(16, 40).g(170).l(0.3, 0.6).jx(5)) }
                }
            } else {
                cell(a, 4, 2); a.ang = sin(T * 6) * 0.02; if S.once(A, "sm") { S.say(a, "헤헤~ 시원하지?", 1.8); S.ptx("heart", a.x, S.feetY(a) - h * 0.8, 3, po().a(-PI * 0.98, -PI * 0.02).s(24, 50).g(55).l(0.9, 1.3).r(1).jx(5)) }
                if e > fireEnd + 1.2 { A.dur = e + 0.01 }
            }
        }, nil)
        // ── 물대포를 맞은 친구들: 깜짝 놀라 달아난다 ──
        A_(S, "flee", 2.8, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t, side: Double = a.x >= A.fx ? 1 : -1; S.standF(a)
            if u < 0.13 {
                a.dir = Int(-side); a.y = -sin(PI * u / 0.13) * 10 * zs(a.z); a.sy = 1 + 0.08 * sin(PI * u / 0.13)
                if S.once(A, "bang") { S.say(a, "!!", 0.9); S.ptx("sweat", a.x, S.feetY(a) - h * 0.9, 3, po().a(-PI * 0.85, -PI * 0.15).s(10, 22).g(120).l(0.5, 0.8).jx(4)) }
            } else {
                let r = S.inRange(a); let tx = clamp(a.x + side * 220, r[0], r[1]); a.dir = Int(side)
                _ = S.moveX(a, tx, a.spd * 2.4, dt); a.y = -abs(sin(T * 15)) * 2.2
                if S.once(A, "yell") { let ln = (a.id.count + a.ai) % 3; S.say(a, a.fearK == "scary" ? (ln == 0 ? "으악 무서워!" : ln == 1 ? "눈이 빛나!!" : "살려줘~!") : (ln == 0 ? "으앗, 차가워!" : ln == 1 ? "꺄악! 도망가자!" : "물이다~!"), 1.6) }
                if S.every(A, "sw", 0.3) { S.ptx("sweat", a.x - side * h * 0.1, S.feetY(a) - h * 0.9, 1, po().a(-PI * 0.85, -PI * 0.15).s(8, 16).g(120).l(0.4, 0.7).jx(3)) }
            }
        }, nil)
    }

    // ── 나머지 여섯 친구 전용 동작 5가지씩 ──
    static func regMo2(_ S: SceneCore) {
        // ── 돌솜(하얀 강아지): 앉아 · 아우~ · 킁킁 · 배 보이기 · 우다다 ──
        A_(S, "sit", 3.8, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a)
            if u < 0.08 { /* 서 있다가 */ } else if u < 0.58 { a.pose = 0; a.ox = sin(T * 17) * 0.7; a.sy = 1 + sin(T * 2.6) * 0.012; if S.once(A, "sy") { S.say(a, "앉아! 기다려~", 2.0) } }
            else { a.pose = 2; a.y = -abs(sin(T * 7)) * 6; if S.once(A, "ok") { S.say(a, "잘했어요!", 1.6); S.haptic("grin") }; if S.every(A, "hh", 0.5) { S.ptx("heart", a.x, S.feetY(a) - h * 0.8, 1, po().a(-PI * 0.98, -PI * 0.02).s(22, 44).g(55).l(0.9, 1.3).r(1).jx(6)) } }
        }, nil)
        A_(S, "howl", 3.8, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a); let on = u > 0.1 && u < 0.88
            if on {
                a.pose = 0; a.pvx = 0; a.pvy = -h * 0.4; a.ang = -0.3 * ease(min(1, (u - 0.1) / 0.15)) + sin(T * 5) * 0.02; a.sy = 1.02
                if S.every(A, "nt", 0.45) { S.ptx("note", a.x + Double(a.dir) * h * 0.35, S.feetY(a) - h * 1.05, 1, po().a(-PI * 0.8, -PI * 0.2).s(12, 20).g(-6).l(0.9, 1.3).r(1).jx(6)) }
            }
            if u > 0.12 && S.once(A, "sy") { S.say(a, "아우~~~!", 2.4) }
        }, nil)
        A_(S, "snuffle", 4.4, { S, a, t, A in A.tx = S.aheadX(a, 55 + S.rnd() * 20) }, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t
            if u < 0.72 {
                _ = S.moveX(a, A.tx, a.spd * 0.38, dt); a.pvx = h * 0.3; a.pvy = -h * 0.3; a.ang = 0.3 + sin(T * 9) * 0.03; a.y = sin(T * 9) * 0.8
                if S.every(A, "dt", 0.4) { S.ptx("dust", a.x + Double(a.dir) * h * 0.55, S.feetY(a) - 1, 1, po().a(-PI * 0.9, -PI * 0.1).s(4, 10)) }
                if S.once(A, "sy") { S.say(a, "킁킁킁…", 1.6) }
            } else {
                S.standF(a); a.pose = 2; a.y = -abs(sin(T * 8)) * 5
                if S.once(A, "f") { S.say(a, "뭔가 있다!", 1.6); S.ptx("spark", a.x + Double(a.dir) * h * 0.5, S.feetY(a) - h * 0.3, 4, po().a(-PI, 0).s(12, 26).g(0).l(0.3, 0.5).jx(5).r(1)); S.haptic("grin") }
            }
        }, nil)
        A_(S, "rollover", 3.6, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a); a.pvy = -h * 0.4
            if u < 0.16 { a.sy = 1 - 0.06 * (u / 0.16) }
            else if u < 0.34 { a.ang = PI * ease((u - 0.16) / 0.18); a.y = -sin(PI * (u - 0.16) / 0.18) * 3 }
            else if u < 0.72 { a.ang = PI + sin(T * 9) * 0.14; a.pose = 2; if S.once(A, "sy") { S.say(a, "배 쓰다듬어 주세요~", 2.2) }; if S.every(A, "hh", 0.55) { S.ptx("heart", a.x, S.feetY(a) - h * 0.9, 1, po().a(-PI * 0.98, -PI * 0.02).s(22, 44).g(55).l(0.9, 1.3).r(1).jx(6)) } }
            else if u < 0.9 { a.ang = PI + PI * ease((u - 0.72) / 0.18); a.y = -sin(PI * (u - 0.72) / 0.18) * 3 }
            else { a.pose = 2; a.y = -abs(sin(T * 8)) * 3 }
        }, nil)
        A_(S, "zoomies", 3.6, { S, a, t, A in A.tx = S.aheadX(a, 110) }, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; let r = S.inRange(a)
            if S.moveX(a, A.tx, a.spd * 3.0, dt) { A.tx = clamp(a.x - Double(a.dir) * (90 + S.rnd() * 60), r[0], r[1]) }
            a.y = -abs(sin(T * 18)) * 3.2; a.ang = 0.08
            if S.every(A, "dt", 0.1) { S.ptx("dust", a.x - Double(a.dir) * h * 0.45, S.feetY(a) - 1, 1, po().a(-PI * 0.9, -PI * 0.1).s(8, 18)) }
            if S.once(A, "sy") { S.say(a, "우다다다다!", 1.8) }
        }, nil)
        // ── 뽀푸(갈색 강아지): 간식 조르기 · 벅벅 · 왈왈 · 원반 잡기 · 뼈다귀 와작 ──
        A_(S, "beg", 3.8, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a); let on = u > 0.08 && u < 0.9; a.pose = on ? 0 : -1
            if on { a.ang = sin(T * 6) * 0.03; a.y = -abs(sin(T * 6)) * 1.6; S.pr(a, S.prop("bone", h * 0.55, -h * 1.0 + sin(T * 4) * 1.5)) }
            if u > 0.1 && S.once(A, "sy") { S.say(a, "간식 주세요~!", 2.4) }
        }, nil)
        A_(S, "scratch", 3.4, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a); let on = u > 0.08 && u < 0.88; a.pose = on ? 0 : -1
            if on {
                a.pvx = 0; a.pvy = -h * 0.4; a.ang = -0.08 + sin(T * 36) * 0.045; a.ox = sin(T * 36) * 0.8
                if S.every(A, "dt", 0.14) { S.ptx("dust", a.x + Double(a.dir) * h * 0.1, S.feetY(a) - h * 0.75, 1, po().a(-PI * 0.9, -PI * 0.1).s(6, 14)) }
            }
            if u > 0.1 && S.once(A, "sy") { S.say(a, "벅벅~ 간지러워!", 2.0) }
            if u > 0.9 && S.once(A, "e") { S.say(a, "시원하다~", 1.2) }
        }, nil)
        A_(S, "bark", 3.2, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a); let ph = (T - A.t0) * 2.3, f = ph - floor(ph); let on = u > 0.06 && u < 0.92
            if on {
                let k = f < 0.28 ? sin(PI * f / 0.28) : 0; a.sx = 1 + 0.09 * k; a.sy = 1 - 0.05 * k; a.ox = -Double(a.dir) * 2.6 * k; a.ang = -0.06 * k
                if f < 0.05 && S.every(A, "br", 0.3) {
                    S.say(a, Int(floor(ph)) % 2 == 0 ? "왈!" : "왈왈!", 0.6); S.haptic("grin")
                    S.ptx("spark", a.x + Double(a.dir) * h * 0.7, S.feetY(a) - h * 0.62, 2, po().a(a.dir > 0 ? -0.5 : PI - 0.5, a.dir > 0 ? 0.5 : PI + 0.5).s(14, 26).g(0).l(0.25, 0.4).r(1))
                }
            }
        }, nil)
        A_(S, "frisbee", 4.8, { S, a, t, A in A.tx = S.aheadX(a, 80); A.x0 = a.x; A.dir0 = a.dir }, { S, a, u, dt, A in
            // 원반이 휙 날아오면 폴짝 뛰어 입으로 잡는다
            let h = S.HH(a), fy = S.feetY(a); S.standF(a)
            let x1 = A.tx, x0 = A.x0 - Double(A.dir0) * 60; let d0 = Double(A.dir0)
            if u < 0.5 {
                let p = u / 0.5; let dx = x0 + (x1 + d0 * 10 - x0) * p, dy = fy - h * (0.5 + 0.9 * sin(PI * min(1, p)) * 0.8); S.pr(a, S.propAbs("disc", dx, dy))
                if u < 0.3 { _ = S.moveX(a, x1, a.spd * 0.8, dt) } else { a.dir = A.dir0 }
                if u > 0.3 { let q = ease((u - 0.3) / 0.2); a.y = -sin(PI * q) * h * 0.75; a.ang = -0.35 * sin(PI * q) }
                if S.once(A, "sy") { S.say(a, "원반이다!", 1.4) }
            } else {
                a.y = 0; S.pr(a, S.prop("disc", Double(a.dir) * h * 0.52, -h * 0.42)); a.pose = u < 0.7 ? 2 : -1; if u >= 0.7 { _ = S.moveX(a, A.x0, a.spd * 1.1, dt) }
                if S.once(A, "ca") { S.say(a, "잡았다!", 1.6); S.haptic("grin"); S.ptx("spark", a.x + Double(a.dir) * h * 0.5, S.feetY(a) - h * 0.45, 4, po().a(-PI, 0).s(12, 26).g(0).l(0.3, 0.5).jx(5).r(1)) }
            }
        }, nil)
        A_(S, "chew", 4.2, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a); let on = u > 0.08 && u < 0.9; a.pose = on ? 0 : -1
            if on {
                let b = abs(sin(T * 10)); a.sy = 1 - 0.02 * b; a.ang = sin(T * 5) * 0.02; S.pr(a, S.prop("bone", h * 0.42, -h * 0.22 + b * 1.2))
                if S.every(A, "cr", 0.6) { S.ptx("dust", a.x + Double(a.dir) * h * 0.45, S.feetY(a) - h * 0.3, 2, po().a(-PI * 0.9, -PI * 0.1).s(6, 12)) }
            }
            if u > 0.1 && S.once(A, "sy") { S.say(a, "와작와작! 맛있다", 2.2) }
        }, nil)
        // ── 러블(고양이): 그루밍 · 갸르릉 · 꾹꾹이 · 털실 · 오이 깜짝 ──
        A_(S, "groom", 3.8, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a); let on = u > 0.08 && u < 0.9; a.pose = on ? 0 : -1
            if on {
                a.pvx = 0; a.pvy = -h * 0.45; a.ang = 0.12 + sin(T * 8) * 0.07
                if S.every(A, "sp", 0.3) { S.ptx("spark", a.x + Double(a.dir) * h * 0.35, S.feetY(a) - h * (0.2 + S.rnd() * 0.6), 1, po().a(-PI * 0.85, -PI * 0.15).s(8, 16).g(0).l(0.3, 0.5).r(0.9)) }
            }
            if u > 0.1 && S.once(A, "sy") { S.say(a, "핥핥~ 털 정리!", 2.0) }
        }, nil)
        A_(S, "purr", 4.2, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a); let on = u > 0.08 && u < 0.92; a.pose = on ? 2 : -1
            if on {
                a.sy = 1 + sin(T * 3.6) * 0.02; a.ox = sin(T * 38) * 0.5
                if S.every(A, "hh", 0.7) { S.ptx("heart", a.x + Double(a.dir) * h * 0.3, S.feetY(a) - h * 0.85, 1, po().a(-PI * 0.9, -PI * 0.1).s(14, 26).g(30).l(0.9, 1.3).r(1).jx(5)) }
            }
            if u > 0.1 && S.once(A, "sy") { S.say(a, "갸르릉~ 갸르릉~", 2.8) }
        }, nil)
        A_(S, "knead", 4.0, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a); let on = u > 0.08 && u < 0.9; a.pose = on ? 0 : -1
            if on {
                let b = max(0, sin(T * 8)); a.sy = 1 - 0.04 * b; a.ang = 0.04 * sin(T * 4)
                if S.every(A, "pt", 0.36) { S.ptx("note", a.x + Double(a.dir) * h * 0.35, S.feetY(a) - h * 0.3, 1, po().a(-PI * 0.75, -PI * 0.25).s(8, 14).g(-4).l(0.7, 1.0).r(0.9)) }
            }
            if u > 0.1 && S.once(A, "sy") { S.say(a, "꾹꾹꾹~ 폭신폭신", 2.2) }
        }, nil)
        A_(S, "yarn", 4.4, { S, a, t, A in A.bx = S.aheadX(a, 60 + S.rnd() * 30); A.mx = a.x + Double(a.dir) * S.HH(a) * 0.5; A.px = 0 }, { S, a, u, dt, A in
            // 털실 뭉치를 굴리고 따라가 덮친다
            let h = S.HH(a), T = S.t, fy = S.feetY(a); S.standF(a)
            let yx = A.mx + (A.bx - A.mx) * ease(min(1, u / 0.6)); let bob = u < 0.6 ? abs(sin(u * 22)) * 3 : 0
            let yp = S.propAbs("yarn", yx, fy - 4 - bob); yp.r = T * 8; S.pr(a, yp)
            if u < 0.1 { S.say(a, "털실이다냥!", 1.4) }
            if u < 0.62 { a.dir = A.bx >= a.x ? 1 : -1; if u > 0.14 { _ = S.moveX(a, A.bx - Double(a.dir) * h * 0.45, a.spd * 1.0, dt) } }
            else if u < 0.78 { let q = ease((u - 0.62) / 0.16); a.dir = A.bx >= a.x ? 1 : -1; a.y = -sin(PI * q) * h * 0.5; a.ang = 0.35 * q }
            else { a.ang = 0.2 * (1 - ease((u - 0.78) / 0.22)); a.sy = 0.94; a.pose = u > 0.85 ? 2 : -1; if S.once(A, "gt") { S.say(a, "잡았다냥!", 1.4); S.haptic("grin") } }
        }, nil)
        A_(S, "cuke", 3.4, { S, a, t, A in A.bx = S.aheadX(a, S.HH(a) * 1.0) }, { S, a, u, dt, A in
            // 뒤에 슬쩍 놓인 오이에 화들짝!
            let h = S.HH(a), T = S.t; S.standF(a)
            let cp = S.propAbs("cuke", A.bx, S.feetY(a) - 3); S.pr(a, cp)
            if u < 0.3 { a.dir = A.bx >= a.x ? 1 : -1; a.sy = 1 + 0.02 * sin(T * 4); if S.once(A, "q") { S.say(a, "…뭐지?", 1.0) } }
            else if u < 0.56 {
                let q = (u - 0.3) / 0.26; a.y = -sin(PI * min(1, q * 1.2)) * h * 0.8; a.sy = 1.16; a.sx = 0.88; a.ang = -0.16 * Double(a.dir) * sin(PI * q)
                if S.once(A, "!") { S.say(a, "냥?!!", 1.0); S.haptic("thud"); S.ptx("sweat", a.x, S.feetY(a) - h, 3, po().a(-PI * 0.85, -PI * 0.15).s(10, 22).g(120).l(0.5, 0.8).jx(4)) }
            } else { a.pose = 3; a.ox = sin(T * 40) * 0.8 * (1 - (u - 0.56) / 0.44); if S.once(A, "e") { S.say(a, "오이는 무서워냥…", 1.8) } }
        }, nil)
        // ── 두덩(두더지): 삽질 · 랜턴 · 두더지 잡기 · 낮잠 · 보물 ──
        A_(S, "digdig", 4.0, { S, a, t, A in
            A.hx = a.x + Double(a.dir) * S.HH(a) * 0.72; A.g = S.addGfx(S.mkGfx("hole", A.hx, a.z, 4.0 + 0.6)); let m = S.mkGfx("mound", a.x - Double(a.dir) * S.HH(a) * 0.55, a.z, 4.0 + 0.6); m.r = 8; S.addGfx(m)
        }, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a); let sw = sin(T * 9); a.pvx = h * 0.3; a.ang = 0.22 + sw * 0.1
            if S.every(A, "d", 0.22) { S.ptx("dirt", a.x + Double(a.dir) * h * 0.72, S.feetY(a) - 3, 2, po().a(-PI * 0.9, -PI * 0.1).s(14, 28).g(170).l(0.35, 0.6).jx(3)) }
            if u > 0.08 && S.once(A, "sy") { S.say(a, "삽질 삽질~ 영차!", 2.2) }
        }, nil)
        A_(S, "lantern", 4.2, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a); a.dir = A.d0 * (sin(T * 1.9) > 0 ? 1 : -1); a.pose = -1
            let lp = S.prop("lantern", h * 0.52, -h * 0.52 + sin(T * 3) * 1.4); S.pr(a, lp); a.ang = sin(T * 3) * 0.02
            if u > 0.08 && S.once(A, "sy") { S.say(a, "어두운 굴 탐험 중~", 2.4) }
        }, nil)
        A_(S, "popup", 4.6, { S, a, t, A in
            A.hx = a.x; A.g = S.addGfx(S.mkGfx("hole", A.hx, a.z, 4.6 + 0.6)); let m = S.mkGfx("mound", a.x + S.HH(a) * 0.5, a.z, 4.6 + 0.6); m.r = 8; S.addGfx(m)
        }, { S, a, u, dt, A in
            // 구멍에서 쏙 나왔다 쏙 들어갔다 — 두더지 잡기!
            let h = S.HH(a), T = S.t, e = T - A.t0; S.standF(a); a.x = A.hx; a.cut = 0
            let v = u < 0.1 ? 0 : u > 0.9 ? 1 : max(0, sin((e - 0.45) * 3.6)); a.y = h * 1.1 * (1 - ease(min(1, v * 1.25)))
            if u > 0.9 { a.cut = Double.nan; a.y = 0 }
            if v > 0.85 && S.every(A, "pk", 1.4) { S.say(a, "짠! 여기야~", 0.9); S.ptx("dirt", a.x, S.feetY(a) - 2, 3, po().a(-PI * 0.95, -PI * 0.05).s(10, 22).g(130).jx(5)) }
        }, nil)
        A_(S, "nap", 4.8, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a); let zz = u > 0.1 && u < 0.92; a.pose = zz ? 1 : 0; a.sy = 1 + (zz ? sin(T * 2.1) * 0.014 : 0)
            if zz && S.every(A, "zz", 0.6) { S.ptx("zzz", a.x + Double(a.dir) * h * 0.3, S.feetY(a) - h * 0.8, 1, po().a(-PI * 0.6, -PI * 0.4).s(6, 9).g(-4).l(1, 1.4).r(1)) }
            if u > 0.94 && S.once(A, "wk") { S.say(a, "드르렁… 헉! 파헤치던 중이었는데", 2.0) }
        }, nil)
        A_(S, "treasure", 4.6, { S, a, t, A in A.hx = a.x + Double(a.dir) * S.HH(a) * 0.7; let m = S.mkGfx("mound", A.hx, a.z, 4.6 + 0.4); m.r = 9; A.g = S.addGfx(m) }, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a)
            if u < 0.5 {
                a.ang = 0.22 + sin(T * 9) * 0.08; a.pvx = h * 0.3
                if S.every(A, "d", 0.2) { S.ptx("dirt", A.hx, S.feetY(a) - 3, 2, po().a(-PI * 0.9, -PI * 0.1).s(14, 26).g(170).l(0.35, 0.6).jx(3)) }
                if S.once(A, "sy") { S.say(a, "여기가 수상해…", 1.6) }
            } else {
                let q = ease((u - 0.5) / 0.3); a.pose = 2; a.y = -abs(sin(T * 7)) * 3
                let gp = S.propAbs("gem", A.hx, S.feetY(a) - 6 - h * 0.7 * q - sin(T * 5) * 1.2); S.pr(a, gp)
                if S.once(A, "f") { S.say(a, "보물이다! 반짝반짝!", 2.4); S.haptic("hearts"); S.ptx("spark", A.hx, S.feetY(a) - h * 0.6, 8, po().a(-PI, 0).s(16, 34).g(0).l(0.4, 0.7).jx(h * 0.3).jy(h * 0.2).r(1.2)) }
            }
        }, nil)
        // ── 술(독수리): 선회 · 깃 다듬기 · 급강하 · 망보기 · 날개 자랑 ──
        A_(S, "soar", 4.8, { S, a, t, A in A.x0 = a.x; A.tx = a.x + (a.x < S.W / 2 ? 1 : -1) * S.W * 0.38; A.alt0 = max(16, a.alt) }, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; let p = ease(clamp(u / 0.85, 0, 1)); a.pvy = -h * 0.5
            let up = u < 0.3 ? ease(u / 0.3) : u > 0.8 ? 1 - ease((u - 0.8) / 0.2) : 1
            a.alt = A.alt0 + 44 * up + sin(T * 2.2) * 4; a.x = A.x0 + (A.tx - A.x0) * p; a.dir = A.tx >= A.x0 ? 1 : -1; a.ang = -0.12 + sin(T * 2.2) * 0.06; a.fr += dt * Double(a.D.fps) * (u < 0.25 ? 1.2 : 0.35)
            if S.once(A, "sy") { S.say(a, "높이 높이~!", 1.6) }
        }, nil)
        A_(S, "preen", 3.8, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a); let on = u > 0.08 && u < 0.9; a.pose = on ? 0 : -1
            if on {
                a.ang = sin(T * 7) * 0.05 + 0.05
                if S.every(A, "fe", 0.7) { S.ptx("feather", a.x + Double(a.dir) * h * 0.1, S.feetY(a) - h * 0.6, 1, po().a(-PI * 0.7, -PI * 0.3).s(6, 14).g(40).l(0.9, 1.4).jx(5)) }
            }
            if u > 0.1 && S.once(A, "sy") { S.say(a, "깃털 정리 정리~", 2.2) }
        }, nil)
        A_(S, "swoop", 3.4, { S, a, t, A in A.alt0 = 78; A.x0 = a.x; A.tx = a.x + (a.x < S.W / 2 ? 1 : -1) * S.W * 0.28 }, { S, a, u, dt, A in
            let h = S.HH(a); a.pvy = -h * 0.5; let fps = Double(a.D.fps)
            if u < 0.22 { a.alt = 18 + (A.alt0 - 18) * ease(u / 0.22); a.x = A.x0; a.dir = A.tx >= A.x0 ? 1 : -1; a.fr += dt * fps * 1.2; if S.once(A, "sy") { S.say(a, "급강하 간다!", 1.4) } }
            else if u < 0.56 { let q = (u - 0.22) / 0.34; a.alt = A.alt0 * (1 - q * q); a.x = A.x0 + (A.tx - A.x0) * ease(q); a.dir = A.tx >= A.x0 ? 1 : -1; a.ang = 0.55 * sin(PI * min(1, q)) + 0.1; a.fr += dt * fps * 0.5 }
            else {
                let q = (u - 0.56) / 0.44; a.alt = 6 * max(0, 1 - q * 4); a.x = A.tx; a.ang = 0; a.fr += dt * fps * 0.6
                if S.once(A, "td") { S.ptx("dust", a.x, S.feetY(a) - 1, 6, po().a(-PI * 0.9, -PI * 0.1).s(10, 22)); S.ptx("feather", a.x, S.feetY(a) - 6, 3, po().a(-PI * 0.9, -PI * 0.1).s(10, 24).g(40).l(0.9, 1.3).jx(5)); S.haptic("land_fly"); S.say(a, "착!", 1.0) }
            }
        }, { S, a, A in a.alt = 0 })
        A_(S, "scan", 4.2, nil, { S, a, u, dt, A in
            let T = S.t; S.standF(a); a.pose = 0; a.dir = A.d0 * (Int(floor((T - A.t0) / 0.85)) % 2 == 0 ? 1 : -1); a.ang = sin(T * 3) * 0.015
            if u > 0.08 && S.once(A, "sy") { S.say(a, "수상한 놈은 없나…", 2.2) }
            if u > 0.78 && S.once(A, "ok") { S.say(a, "이상 무!", 1.4) }
        }, nil)
        A_(S, "flapshow", 3.6, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; let on = u > 0.08 && u < 0.9; a.fr += dt * Double(a.D.fps) * (on ? 1.5 : 0.6); a.pvy = -h * 0.5
            if on {
                let b = abs(sin(T * 9)); a.alt = 14 + b * 9; a.sx = 1.1; a.sy = 1 + 0.04 * b
                if S.every(A, "fe", 0.35) { S.ptx("feather", a.x + (S.rnd() - 0.5) * h * 1.2, S.feetY(a) - h * (0.6 + S.rnd() * 0.4), 1, po().a(-PI * 0.85, -PI * 0.15).s(8, 18).g(40).l(0.9, 1.4)) }
            }
            if u > 0.1 && S.once(A, "sy") { S.say(a, "내 날개 멋지지?", 2.2) }
        }, { S, a, A in a.alt = 0 })
        // ── 챙챙(올챙이): 헤엄 · 꼬물꼬물 · 점프 · 빙글빙글 · 꼬리 첨벙 ──
        A_(S, "swim", 4.0, { S, a, t, A in A.tx = S.aheadX(a, 100) }, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; if S.moveX(a, A.tx, a.spd * 1.5, dt) { A.tx = S.aheadX(a, 100) }
            a.y = sin(T * 5) * 5; a.ang = cos(T * 5) * 0.1; a.fr += dt * Double(a.D.fps) * 0.6
            if S.every(A, "bb", 0.25) { S.ptx("bub", a.x - Double(a.dir) * h * 0.5, S.feetY(a) - h * 0.5, 1, po().a(-PI * 0.8, -PI * 0.2).s(8, 18).g(-24).l(0.8, 1.3).r(1).jx(3)) }
            if S.once(A, "sy") { S.say(a, "쏘옥~ 쏘옥~", 1.6) }
        }, nil)
        A_(S, "wiggle", 3.4, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a); a.pose = u > 0.08 && u < 0.9 ? 2 : -1; a.ang = sin(T * 20) * 0.22; a.ox = sin(T * 20 + 1) * 1.6
            if S.every(A, "bb", 0.3) { S.ptx("bub", a.x, S.feetY(a) - h * 0.8, 1, po().a(-PI * 0.8, -PI * 0.2).s(8, 18).g(-24).l(0.8, 1.3).r(1).jx(4)) }
            if u > 0.1 && S.once(A, "sy") { S.say(a, "꼬물꼬물~", 1.8) }
        }, nil)
        A_(S, "leap", 3.2, nil, { S, a, u, dt, A in
            let h = S.HH(a); S.standF(a); a.pvy = -h * 0.4
            if u < 0.2 { a.sy = 1 - 0.16 * (u / 0.2); a.sx = 1 + 0.1 * (u / 0.2) }
            else if u < 0.7 { let q = (u - 0.2) / 0.5; a.y = -sin(PI * q) * h * 1.3; a.ang = PI2 * ease(q); a.sy = 1 + 0.1 * sin(PI * q); if S.once(A, "sy") { S.say(a, "점~프!", 1.2) } }
            else {
                let q = (u - 0.7) / 0.3; a.sy = 0.86 + 0.14 * ease(q); a.sx = 1.12 - 0.12 * ease(q)
                if S.once(A, "td") { S.ptx("drop", a.x, S.feetY(a) - 2, 12, po().a(-PI * 0.95, -PI * 0.05).s(26, 56).g(170).l(0.5, 0.9).jx(4)); S.ptx("ring", a.x, S.feetY(a), 1, po().a(0, 0).s(0, 0).g(0).l(0.8, 0.8)); S.haptic("splash") }
            }
        }, nil)
        A_(S, "whirl", 3.4, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a); let on = u > 0.08 && u < 0.86; let k = on ? sin(PI * (u - 0.08) / 0.78) : 0
            a.pvy = -h * 0.45; a.ang = (T - A.t0) * 13 * k; a.y = -k * 4
            if on && S.every(A, "bb", 0.12) { S.ptx("bub", a.x + (S.rnd() - 0.5) * h * 0.8, S.feetY(a) - h * (0.3 + S.rnd() * 0.5), 1, po().a(-PI * 0.8, -PI * 0.2).s(10, 24).g(-24).l(0.8, 1.3).r(1)) }
            if u > 0.1 && S.once(A, "sy") { S.say(a, "빙글빙글~ 어지러워!", 2.0) }
        }, nil)
        A_(S, "tailsplash", 3.6, nil, { S, a, u, dt, A in
            let h = S.HH(a), T = S.t; S.standF(a); let on = u > 0.08 && u < 0.9; a.pose = on ? 2 : -1
            if on {
                a.y = -abs(sin(T * 8)) * 4; let ph = (T - A.t0) * 4.2
                if ph - floor(ph) < 0.08 && S.every(A, "sp", 0.22) { S.ptx("drop", a.x - Double(a.dir) * h * 0.45, S.feetY(a) - h * 0.3, 6, po().a(-PI * 0.9, -PI * 0.1).s(24, 52).g(170).l(0.5, 0.9).jx(3)); S.haptic("splash") }
            }
            if u > 0.1 && S.once(A, "sy") { S.say(a, "꼬리로 첨벙첨벙!", 2.0) }
        }, nil)
    }
}
