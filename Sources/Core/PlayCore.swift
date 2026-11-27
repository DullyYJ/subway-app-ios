import Foundation

/// 캐릭터 놀이터(웹 _RC.playStart — 역 팝업 · 시간표 제목 옆 빈 칸에서 동물 캐릭터 2~3마리가 논다) 순수 계산 — 안드로이드 PlayCore.java.
/// 순수 장식: 판단 · 계산과 무관하고 그림은 PlayView 가 그린다. 시간 단위는 초, 길이 단위는 pt(안드로이드 dp).
/// 한 장면(8가지 배경: 낮 · 노을 · 풀밭 · 사탕 · 눈 · 바다 · 밤 · 오로라)마다 배경 색(다크/파스텔)과 행동 비중이 다르고,
/// 캐릭터마다 자기만의 놀이가 있다 — 강아지(킁킁 · 응가) · 고양이(나무 타기 · 훌쩍) · 두더지(땅속 · 솟기 · 삽질) · 올챙이(웅덩이 헤엄 · 펄쩍) · 독수리(날기).

/// 시험에서 같은 값을 얻도록 씨앗을 받는 간단한 난수(xorshift64*). 0 이상 1 미만.
struct PlayRng {
    private var s: UInt64
    init(seed: UInt64) { s = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> Double {
        s ^= s >> 12; s ^= s << 25; s ^= s >> 27
        let r = s &* 2685821657736338717
        return Double(r >> 11) / 9007199254740992.0
    }
    mutating func int(_ n: Int) -> Int { n <= 1 ? 0 : min(n - 1, Int(next() * Double(n))) }
    mutating func range(_ a: Double, _ b: Double) -> Double { a + next() * (b - a) }
}

enum PlayCore {
    static let targetH = 34.0                       // 캐릭터 키
    static let hostH: CGFloat = 70, hostMinW: CGFloat = 90          // 놀이터 칸(웹 #nmPopPlay · #nmTtPlay: 높이 70 · 최소 너비 90)

    /// 장면 하나. p: 파스텔(위→아래 3색) · d: 다크 · g: 바닥색 [파스텔, 다크] · w: 행동 비중(걷기 · 콩콩 · 빙글 · 쉬기).
    struct Scene {
        let name: String
        let p: [UInt32], d: [UInt32], g: [UInt32]
        let deco: String, mark: String
        let wWalk, wHop, wSpin, wRest, spd, hop, chase, sp, restMul: Double
    }
    static let sceneOrder = ["day", "sunset", "meadow", "candy", "snow", "sea", "night", "aurora"]
    static let scenes: [Scene] = [
        Scene(name: "day", p: [0xbfe6ff, 0xe3f5ff, 0xf7fcff], d: [0x14263f, 0x1e3a5c, 0x27507a], g: [0xbfe8c6, 0x1f3d33], deco: "clouds", mark: "♪",
              wWalk: 0.30, wHop: 0.30, wSpin: 0.20, wRest: 0.20, spd: 1.0, hop: 1.0, chase: 0.35, sp: 1, restMul: 1),
        Scene(name: "sunset", p: [0xffd1b8, 0xffb7cf, 0xd9c2ff], d: [0x3a2342, 0x6b2f58, 0xa1475f], g: [0xeeb3b8, 0x4a2438], deco: "sunset", mark: "♡",
              wWalk: 0.35, wHop: 0.10, wSpin: 0.10, wRest: 0.45, spd: 0.7, hop: 0.8, chase: 0.25, sp: 1, restMul: 1.4),
        Scene(name: "meadow", p: [0xd9f6e3, 0xc4efd3, 0xa9e3bd], d: [0x10302a, 0x14403a, 0x1b5246], g: [0x8fd3a4, 0x0f3a2c], deco: "meadow", mark: "♪",
              wWalk: 0.25, wHop: 0.45, wSpin: 0.10, wRest: 0.20, spd: 1.0, hop: 1.2, chase: 0.55, sp: 1.6, restMul: 0.8),
        Scene(name: "candy", p: [0xffe0ef, 0xffd0e8, 0xe8d3ff], d: [0x35203f, 0x4a2a58, 0x6a3a73], g: [0xf7b8d6, 0x52305f], deco: "petals", mark: "♡",
              wWalk: 0.20, wHop: 0.30, wSpin: 0.40, wRest: 0.10, spd: 1.1, hop: 1.0, chase: 0.45, sp: 1.2, restMul: 0.7),
        Scene(name: "snow", p: [0xe4f1ff, 0xf2f8ff, 0xffffff], d: [0x1a2a44, 0x243a5a, 0x31507a], g: [0xdbe9f6, 0x9fb4cc], deco: "snow", mark: "✦",
              wWalk: 0.20, wHop: 0.40, wSpin: 0.30, wRest: 0.10, spd: 1.25, hop: 1.3, chase: 0.4, sp: 0.7, restMul: 0.6),
        Scene(name: "sea", p: [0xc7f0ff, 0x9fe0f5, 0x7fd0ec], d: [0x08283f, 0x0d3b57, 0x12506f], g: [0xf6e4b5, 0x3a4a52], deco: "sea", mark: "♪",
              wWalk: 0.50, wHop: 0.20, wSpin: 0.15, wRest: 0.15, spd: 1.05, hop: 0.9, chase: 0.3, sp: 1, restMul: 1),
        Scene(name: "night", p: [0xbcc8ff, 0xd6cfff, 0xecd9ff], d: [0x0b1030, 0x1a1650, 0x2c1f6b], g: [0xc9c2f0, 0x1b1a3c], deco: "night", mark: "z",
              wWalk: 0.25, wHop: 0.10, wSpin: 0.05, wRest: 0.60, spd: 0.6, hop: 0.7, chase: 0.2, sp: 0.6, restMul: 1.7),
        Scene(name: "aurora", p: [0xd8fff3, 0xd6e8ff, 0xecd8ff], d: [0x06182a, 0x0a3a4a, 0x2a1a5a], g: [0xcfe9ee, 0x10283a], deco: "aurora", mark: "✦",
              wWalk: 0.30, wHop: 0.30, wSpin: 0.30, wRest: 0.10, spd: 0.95, hop: 1.1, chase: 0.35, sp: 1, restMul: 0.9),
    ]
    static func scene(_ name: String) -> Scene? { scenes.first { $0.name == name } }

    /// 종류별 행동 가중치(웹 KM): walk · hop · spin · rest
    static func km(_ kind: String) -> [Double] {
        switch kind {
        case "cat": return [1.2, 0.7, 0.4, 1.4]
        case "mole": return [1.5, 0.2, 0, 0.8]
        case "tad": return [0.6, 1.8, 0.8, 0.6]
        case "eagle": return [1, 0, 0, 1]
        default: return [1, 1, 1, 1]
        }
    }
    static func kindOf(_ id: String) -> String {
        switch id {
        case "lovel": return "cat"
        case "dudung": return "mole"
        case "chaeng": return "tad"
        case "sul": return "eagle"
        case "juksun": return "panda"
        case "bbosong": return "hippo"
        default: return "dog"                       // dolsom · ppopu
        }
    }

    /// 이어받기용 설정(웹 playSnap) — 역 팝업 → 시간표로 넘어갈 때 같은 배경·같은 캐릭터가 같은 자리에서 이어서 논다.
    struct Snap {
        var scene = ""; var ids: [String] = []; var xs: [Double] = []; var dirs: [Int] = []
        var sideA = false; var treeX = -1.0, pondX = -1.0
    }

    final class Critter {
        var id = "", kind = "", st = "walk"
        var D: RunnerCore.Spec
        var k = 0.0, w = 0.0, bodyH = 0.0, x = 0.0, dir = 1.0, tx = 0.0, until = 0.0, t0 = 0.0, fr = 0.0, dirT = 0.0, y = 0.0, rot = 0.0, ang = 0.0, sq = 0.0, jit = 0.0, ph = 0.0, spd = 0.0, lastSp = -5.0
        var vis = true, clip = false, useIntro = false, pooped = false, chase = false
        var introIdx = 0, legs = 0
        var side = 0.0, ty = 0.0, lx1 = 0.0, jx0 = 0.0, jx1 = 0.0, digAt = 0.0, landUntil = 0.0, groundUntil = Double.greatestFiniteMagnitude, alt = 0.0, landX = 0.0
        var km: [Double] = [1, 1, 1, 1]
        init(spec: RunnerCore.Spec) { D = spec }
    }
    struct Tree { var x = 0.0, th = 0.0 }
    struct Pond { var x = 0.0, rx = 0.0 }
    struct Poop { var x = 0.0, born = 0.0 }
    enum PKind { case splash, star, dirt }
    struct Pt { var kind = PKind.splash; var x = 0.0, y = 0.0, vx = 0.0, vy = 0.0, age = 0.0, life = 0.0 }
    struct Decor { var x = 0.0, y = 0.0, s = 0.0, ph = 0.0, v = 0.0 }

    /// 한 장면의 상태.
    final class Play {
        let sc: Scene
        let W: Double, H: Double, gy: Double, fy: Double          // 칸 크기 · 바닥 띠 시작 · 발 닿는 곳
        var cs: [Critter] = []
        var ids: [String] = []
        var sideA = false
        var tree: Tree? = nil
        var pond: Pond? = nil
        var poops: [Poop] = []
        var pt: [Pt] = []
        var parts: [Decor] = []
        var t = 0.0
        private var rnd: PlayRng

        init(wc: Double, hc: Double, snap o: Snap?, rng: PlayRng) {
            var r0 = rng
            var s: Scene? = nil
            if let o = o { s = PlayCore.scene(o.scene) }
            sc = s ?? PlayCore.scenes[r0.int(PlayCore.scenes.count)]
            W = wc; H = hc; gy = hc - 7; fy = hc - 7 + 1
            rnd = r0
            var ids2: [String] = []
            if let o = o { for i in o.ids where RunnerCore.spec(i) != nil { ids2.append(i) } }
            if ids2.isEmpty {
                var pool = RunnerCore.order
                let n = rnd.next() < 0.5 ? 2 : 3
                while ids2.count < n && !pool.isEmpty { ids2.append(pool.remove(at: rnd.int(pool.count))) }
            }
            ids = ids2
            for (q, id) in ids.enumerated() {
                guard let spec = RunnerCore.spec(id) else { continue }
                let c = Critter(spec: spec)
                c.id = id; c.kind = PlayCore.kindOf(id); c.km = PlayCore.km(c.kind)
                let bh = (spec.base - 8) / 256 * spec.cell + spec.lift * 0.6
                c.k = min(0.62, PlayCore.targetH / bh); c.w = spec.cell * c.k; c.bodyH = bh * c.k
                c.dir = rnd.next() < 0.5 ? -1 : 1; c.fr = rnd.next() * 16; c.ph = rnd.next() * 6.28
                c.x = rr(c.w * 0.5, max(c.w * 0.6, W - c.w * 0.5))
                if let o = o, q < o.xs.count, o.xs[q] >= 0 {                    // 팝업 → 시트로 넘어올 때 서 있던 자리 그대로
                    c.x = clampX(c, o.xs[q] * W)
                    if q < o.dirs.count, o.dirs[q] != 0 { c.dir = Double(o.dirs[q]) }
                }
                c.spd = Double(spec.fps) / 16 * spec.cell * c.k * (id == "lovel" ? 0.9 : 1.0) * sc.spd
                cs.append(c)
            }
            ids = cs.map { $0.id }
            let sa: Bool = (o != nil && !(o!.ids.isEmpty)) ? o!.sideA : rnd.next() < 0.5
            sideA = sa
            if has("cat") {
                var tr = Tree()
                tr.x = W * ((o != nil && o!.treeX >= 0) ? o!.treeX : (sa ? rr(0.22, 0.34) : rr(0.66, 0.78)))
                tr.th = min(H * 0.58, 42)
                tree = tr
            }
            if has("tad") {
                var po = Pond()
                po.x = W * ((o != nil && o!.pondX >= 0) ? o!.pondX : (sa ? rr(0.66, 0.78) : rr(0.22, 0.34)))
                po.rx = min(26, W * 0.14)
                pond = po
            }
            let np = Play.npOf(sc.deco)
            for _ in 0..<np {
                var d = Decor(); d.x = rnd.next(); d.y = rnd.next(); d.s = rr(0.6, 1.4); d.ph = rnd.next() * 6.28; d.v = rr(0.5, 1.2)
                parts.append(d)
            }
            for c in cs {                                                           // 시작 상태
                c.tx = target(c)
                if c.kind == "mole" { c.digAt = 1e9; c.vis = false; go(c, "hidden", 0.5, 0); c.tx = c.x }
                else if c.kind == "tad", let po = pond { c.landUntil = 1e9; c.x = po.x; go(c, "swim", rr(1.2, 2.2), 0) }
                else if c.kind == "eagle" { c.alt = rr(14, 24); c.legs = 2; go(c, "fly", 0, 0) }
            }
        }
        private static func npOf(_ d: String) -> Int {
            switch d {
            case "snow": return 18
            case "petals": return 10
            case "night": return 24
            case "aurora": return 10
            case "sea": return 6
            case "meadow", "sunset", "clouds": return 3
            default: return 0
            }
        }
        private func has(_ kind: String) -> Bool { cs.contains { $0.kind == kind } }
        private func rr(_ a: Double, _ b: Double) -> Double { rnd.range(a, b) }
        private func clampX(_ c: Critter, _ x: Double) -> Double { max(c.w * 0.45, min(W - c.w * 0.45, x)) }
        private static func ease(_ u: Double) -> Double { u < 0 ? 0 : (u > 1 ? 1 : u * u * (3 - 2 * u)) }
        private func go(_ c: Critter, _ st: String, _ dur: Double, _ t: Double) { c.st = st; c.t0 = t; c.until = t + dur }
        private func spawn(_ kind: PKind, _ x: Double, _ y: Double, _ cnt: Int) {
            for _ in 0..<cnt {
                let a = kind == .splash ? rr(-Double.pi * 0.95, -Double.pi * 0.05) : rr(-Double.pi * 0.85, -Double.pi * 0.15)
                let sp = kind == .splash ? rr(18, 42) : rr(14, 34)
                var p = Pt(); p.kind = kind; p.x = x + rr(-2, 2); p.y = y; p.vx = cos(a) * sp; p.vy = sin(a) * sp; p.age = 0; p.life = rr(0.45, 0.85)
                pt.append(p)
            }
            while pt.count > 60 { pt.removeFirst() }
        }
        private func target(_ c: Critter) -> Double {
            let other = cs[rnd.int(cs.count)]
            if other !== c && other.vis && rnd.next() < sc.chase { c.chase = true; return clampX(c, other.x + rr(-0.8, 0.8) * c.w) }          // 친구에게 다가간다
            c.chase = false
            return rr(c.w * 0.45, max(c.w * 0.5, W - c.w * 0.45))
        }
        private func generic(_ c: Critter, _ t: Double) {
            let wh = sc.wHop * c.km[1], ws = sc.wSpin * c.km[2], wr = sc.wRest * c.km[3], ww = sc.wWalk * c.km[0]
            let tot = wh + ws + wr + ww
            let r = rnd.next() * tot
            c.t0 = t
            if (c.chase && c.km[1] > 0) || r < wh { go(c, "hop", rr(1.1, 2.2), t) }
            else if r < wh + ws { go(c, "spin", rr(1.0, 1.8), t); c.dirT = t }
            else if r < wh + ws + wr { go(c, "rest", rr(0.9, 2.0) * sc.restMul, t) }
            else { c.st = "walk"; c.tx = target(c) }
        }
        // 캐릭터마다 자기만의 놀이 — 도착할 때마다 '특별한 행동'을 먼저 고려하고, 아니면 공통 행동(걷기·콩콩·빙글·쉬기)
        private func decide(_ c: Critter, _ t: Double) {
            switch c.kind {
            case "dog":
                if t - c.lastSp > 8 && rnd.next() < 0.26 * sc.sp { go(c, "poop", 2.6, t); c.pooped = false; return }
                if rnd.next() < 0.2 { go(c, "sniff", rr(1.4, 2.4), t); return }
            case "cat":
                if let tr = tree, t - c.lastSp > 6 && rnd.next() < 0.4 * sc.sp {
                    c.side = c.x < tr.x ? 1 : -1; c.tx = clampX(c, tr.x - c.side * c.w * 0.5); go(c, "toTree", 0, t); return
                }
            case "mole":
                if t >= c.digAt { c.dir = c.dir != 0 ? c.dir : 1; go(c, "dig", 1.3, t); return }
            case "tad":
                if let po = pond, t >= c.landUntil { c.side = c.x < po.x ? -1 : 1; c.tx = clampX(c, po.x + c.side * po.rx * 0.95); go(c, "toPond", 0, t); return }
            case "eagle":
                if t >= c.groundUntil { c.alt = rr(14, 24); c.dir = c.x < W / 2 ? 1 : -1; go(c, "takeoff", 0.9, t); return }
            default: break
            }
            generic(c, t)
        }
        /// 목표 쪽으로 한 걸음. 도착했으면 true.
        private func moveToward(_ c: Critter, _ dt: Double, _ mul: Double) -> Bool {
            let dx = c.tx - c.x
            if abs(dx) < 3 { return true }
            c.dir = dx > 0 ? 1 : -1
            c.x += c.dir * min(abs(dx), c.spd * mul * dt)
            return false
        }

        /// dt 초만큼 흐른다(웹은 30fps 로 부른다).
        func tick(_ dt: Double) { t += dt; step(dt) }

        private func step(_ dt: Double) {
            let climbRot = -1.2, climbDx = 3.0
            for c in cs {
                let D = c.D
                let fps = Double(D.fps)
                let u = c.until > c.t0 ? (t - c.t0) / (c.until - c.t0) : 0
                c.clip = false; c.ang = 0; c.rot = 0; c.sq = 0; c.jit = 0; c.vis = true; c.useIntro = false
                switch c.st {
                case "walk":
                    let slow = c.kind == "eagle" ? 0.5 : 1.0
                    if moveToward(c, dt, slow) { decide(c, t) } else { c.fr += dt * fps * sc.spd * (c.kind == "eagle" ? 0.35 : 1.0) }
                    c.y = 0
                case "hop":
                    c.fr += dt * fps * 0.7; c.y = -abs(sin((t - c.t0) * 7.5)) * min(11, H * 0.18) * sc.hop
                    if t >= c.until { c.y = 0; c.st = "walk"; c.tx = target(c) }
                case "spin":
                    c.fr += dt * fps * 0.45; c.y = 0
                    if t - c.dirT > 0.42 { c.dir = -c.dir; c.dirT = t }
                    if t >= c.until { c.st = "walk"; c.tx = target(c) }
                case "rest":
                    c.fr += dt * fps * 0.22; c.y = 0
                    if t >= c.until { c.st = "walk"; c.tx = target(c) }
                case "sniff":                                                 // 강아지: 코를 땅에 대고 킁킁
                    c.x = clampX(c, c.x + c.dir * c.spd * 0.28 * dt); c.fr += dt * fps * 0.42; c.ang = 0.14 + sin(t * 14) * 0.03; c.y = 0
                    if t >= c.until { c.st = "walk"; c.tx = target(c) }
                case "poop":                                                  // 강아지: 멈춰서 쭈그리고 응가
                    c.y = 0; c.fr = 4
                    let on = u > 0.14 && u < 0.78
                    c.sq = on ? 0.2 + sin(u * 60) * 0.02 : 0
                    c.jit = on ? sin(t * 50) * 0.5 : 0
                    if u > 0.58 && !c.pooped {
                        c.pooped = true
                        poops.append(Poop(x: c.x - c.dir * c.w * 0.3, born: t))
                        if poops.count > 3 { poops.removeFirst() }
                        spawn(.star, c.x - c.dir * c.w * 0.3, fy - 3, 4)
                    }
                    if t >= c.until { c.lastSp = t; go(c, "hop", 0.9, t) }
                case "toTree":                                                // 고양이: 나무 쪽으로 걸어간다
                    guard let tr = tree else { c.st = "walk"; c.tx = target(c); continue }
                    c.dir = c.side
                    if moveToward(c, dt, 1) { c.dir = c.side; let ty0 = tr.th * 0.55; c.ty = ty0; go(c, "climb", ty0 / 20, t) } else { c.fr += dt * fps }
                    c.y = 0
                case "climb":                                                 // 나무를 타고 오른다(몸을 세워서)
                    guard let tr = tree else { c.st = "walk"; c.tx = target(c); continue }
                    c.rot = climbRot; c.x = tr.x - c.dir * climbDx; c.y = -c.ty * Play.ease(u); c.fr += dt * fps * 0.9
                    if t >= c.until { go(c, "perch", rr(2.4, 3.8), t) }
                case "perch":                                                 // 가지 위에 앉아 쉰다
                    guard let tr = tree else { c.st = "walk"; c.tx = target(c); continue }
                    c.x = tr.x + c.dir * 9; c.y = -c.ty; c.fr = 3
                    if t >= c.until {
                        if rnd.next() < 0.5 { c.lx1 = clampX(c, tr.x + c.dir * rr(24, 42)); go(c, "leap", 0.75, t) } else { go(c, "down", c.ty / 22, t) }
                    }
                case "down":                                                  // 뒷걸음으로 내려온다
                    guard let tr = tree else { c.st = "walk"; c.tx = target(c); continue }
                    c.rot = climbRot; c.x = tr.x - c.dir * climbDx; c.y = -c.ty * (1 - Play.ease(u)); c.fr -= dt * fps * 0.9
                    if t >= c.until { c.x = tr.x - c.dir * c.w * 0.5; c.y = 0; c.lastSp = t; c.st = "walk"; c.tx = target(c) }
                case "leap":                                                  // 훌쩍 뛰어내린다
                    guard let tr = tree else { c.st = "walk"; c.tx = target(c); continue }
                    let lx0 = tr.x + c.dir * 9
                    c.x = lx0 + (c.lx1 - lx0) * u; c.y = -c.ty * (1 - u) * (1 - u) - sin(Double.pi * u) * 9; c.ang = (u - 0.35) * 0.9; c.fr = 8
                    if t >= c.until { c.y = 0; c.lastSp = t; go(c, "hop", 0.8, t) }
                case "hidden":                                                // 두더지: 땅속에서 흙두둑만 움직인다
                    c.vis = false; c.y = 0
                    let dxh = c.tx - c.x
                    if abs(dxh) > 2 { c.x += (dxh > 0 ? 1.0 : -1.0) * min(abs(dxh), 46 * dt) }
                    if rnd.next() < dt * 6 { spawn(.dirt, c.x, fy - 2, 1) }
                    if t >= c.until { go(c, "emerge", 1.0, t); c.digAt = t + 1 + rr(3.6, 6) }
                case "emerge":                                                // 땅을 뚫고 솟는다(3D 시트의 솟아나는 장면)
                    c.useIntro = true; c.introIdx = max(0, min(D.intro - 1, Int(floor(u * Double(D.intro))))); c.y = 0
                    if t >= c.until { c.useIntro = false; c.st = "walk"; c.tx = target(c) }
                case "dig":                                                   // 삽질: 몸을 들썩이며 흙을 튀긴다
                    c.fr = 2; c.y = 0; c.ang = sin(u * 20) * 0.13
                    if rnd.next() < dt * 22 { spawn(.dirt, c.x + c.dir * c.w * 0.3, fy - 3, 1) }
                    if t >= c.until { go(c, "sink", 1.0, t) }
                case "sink":                                                  // 구멍으로 쏙 들어간다(솟는 장면을 거꾸로)
                    c.useIntro = true; c.introIdx = max(0, min(D.intro - 1, D.intro - 1 - Int(floor(u * Double(D.intro))))); c.y = 0
                    if t >= c.until { c.useIntro = false; c.vis = false; c.tx = rr(c.w * 0.5, W - c.w * 0.5); go(c, "hidden", rr(1.0, 1.9), t) }
                case "swim":                                                  // 올챙이: 웅덩이에서 헤엄
                    guard let po = pond else { c.st = "walk"; c.tx = target(c); continue }
                    c.x = po.x + sin((t - c.t0) * 2.2 + c.ph) * po.rx * 0.5; c.dir = cos((t - c.t0) * 2.2 + c.ph) > 0 ? 1 : -1
                    c.fr += dt * fps; c.y = c.bodyH * 0.36; c.clip = true
                    if t >= c.until {
                        c.side = rnd.next() < 0.5 ? -1 : 1
                        let lt = po.x + c.side * (po.rx + rr(16, 46))
                        if lt < c.w * 0.5 || lt > W - c.w * 0.5 { c.side = -c.side }
                        c.jx0 = c.x; c.jx1 = clampX(c, po.x + c.side * (po.rx + rr(16, 46))); c.dir = c.side
                        go(c, "jumpOut", 0.95, t); spawn(.splash, c.x, fy, 7)
                    }
                case "jumpOut":                                               // 물에서 펄쩍 뛰어나온다
                    c.x = c.jx0 + (c.jx1 - c.jx0) * u; c.y = -sin(Double.pi * u) * 28 + c.bodyH * 0.36 * max(0, 1 - u * 5)
                    c.clip = c.y > 0.5; c.ang = c.dir * (u - 0.5) * 0.9; c.fr += dt * fps * 1.2
                    if t >= c.until { c.y = 0; c.landUntil = t + rr(3.6, 5.6); c.st = "walk"; c.tx = target(c) }
                case "toPond":                                                // 웅덩이 가장자리로 걸어간다
                    guard let po = pond else { c.st = "walk"; c.tx = target(c); continue }
                    if moveToward(c, dt, 1) { c.jx0 = c.x; c.jx1 = po.x + rr(-0.3, 0.3) * po.rx; c.dir = c.side > 0 ? -1 : 1; go(c, "jumpIn", 0.8, t) } else { c.fr += dt * fps }
                    c.y = 0
                case "jumpIn":                                                // 다시 물로 풍덩
                    c.x = c.jx0 + (c.jx1 - c.jx0) * u; c.y = -sin(Double.pi * u) * 22 + c.bodyH * 0.36 * max(0, (u - 0.8) * 5)
                    c.clip = c.y > 0.5; c.ang = c.dir * (u - 0.5) * 0.9; c.fr += dt * fps * 1.2
                    if t >= c.until { spawn(.splash, c.x, fy, 7); c.landUntil = 1e9; go(c, "swim", rr(1.6, 2.6), t) }
                case "fly":                                                   // 독수리: 하늘을 날아다닌다
                    if c.tx == 0 || abs(c.tx - c.x) < 3 {
                        let left = c.legs; c.legs -= 1
                        if left <= 0 { c.landX = clampX(c, c.x); go(c, "land", 1.0, t); c.y = -c.alt; continue }
                        c.tx = rr(c.w * 0.5, W - c.w * 0.5)
                    }
                    c.dir = c.tx > c.x ? 1 : -1
                    c.x += c.dir * min(abs(c.tx - c.x), c.spd * 1.7 * dt); c.fr += dt * fps; c.y = -c.alt + sin(t * 3 + c.ph) * 2.2
                case "land":                                                  // 땅으로 내려앉는다
                    c.y = -c.alt * (1 - Play.ease(u)); c.fr += dt * fps * (1 - 0.6 * u); c.ang = -0.18 * (1 - u)
                    if t >= c.until { c.y = 0; c.groundUntil = t + rr(3, 5.5); c.st = "walk"; c.tx = target(c) }
                case "takeoff":                                               // 다시 날아오른다
                    c.y = -c.alt * (1 - pow(1 - Play.ease(u), 2)); c.x = clampX(c, c.x + c.dir * 18 * dt); c.fr += dt * fps * 1.2; c.ang = 0.12 * (1 - u)
                    if t >= c.until { c.legs = 1 + Int(floor(rnd.next() * 2)); c.tx = 0; go(c, "fly", 0, t) }
                default:
                    c.st = "walk"; c.tx = target(c)
                }
            }
            var i = pt.count - 1
            while i >= 0 {
                pt[i].age += dt; pt[i].vy += 95 * dt; pt[i].x += pt[i].vx * dt; pt[i].y += pt[i].vy * dt
                if pt[i].age > pt[i].life { pt.remove(at: i) }
                i -= 1
            }
            poops.removeAll { t - $0.born > 8 }
        }

        /// 그릴 프레임 번호(0~15). 두더지가 솟고 가라앉을 땐 '솟는 시트'의 번호.
        func frameIdx(_ c: Critter) -> Int {
            if c.useIntro { return c.introIdx }
            let n = c.D.n
            return ((Int(floor(c.fr)) % n) + n) % n
        }

        /// 이어받기용 설정(웹 playSnap).
        func snap() -> Snap {
            var s = Snap()
            s.scene = sc.name; s.ids = ids
            s.xs = cs.map { $0.x / W }; s.dirs = cs.map { Int($0.dir) }
            s.sideA = sideA; s.treeX = tree.map { $0.x / W } ?? -1; s.pondX = pond.map { $0.x / W } ?? -1
            return s
        }
    }

    /// 놀이터 칸의 위치(pt): 이름 글 오른쪽 빈 칸. 역 팝업은 이름 줄 아래에 맞춰 위로 솟고, 시간표 시트는 제목 줄 가운데에서 위로 24 솟는다. 못 놓으면 nil.
    /// 반환 [x, y, 너비, 높이].
    static func popupHost(sheetW: CGFloat, padX: CGFloat, nameX: CGFloat, nameW: CGFloat, nameY: CGFloat, nameH: CGFloat) -> CGRect? {
        let x0 = nameX + nameW + 10, right = sheetW - padX
        if right - x0 < hostMinW { return nil }                              // 이름이 길어 최소 칸도 못 내면 놓지 않는다
        let rowBottom = nameY + max(nameH, hostH - 48)                       // 웹: margin -44 0 -4 → 줄 높이 = max(이름 높이, 22)
        return CGRect(x: x0, y: rowBottom + 4 - hostH, width: right - x0, height: hostH)
    }
    static func ttHost(barY: CGFloat, barH: CGFloat, titleX: CGFloat, titleW: CGFloat, rightEdge: CGFloat) -> CGRect? {
        let x0 = titleX + titleW + 10
        if rightEdge - x0 < hostMinW { return nil }
        let rowH = max(barH, hostH - 24), rowTop = barY + (barH - rowH) / 2   // 웹: margin -24 0 0 → 줄 높이 = max(제목 높이, 46)
        return CGRect(x: x0, y: rowTop - 24, width: rightEdge - x0, height: hostH)
    }
}
