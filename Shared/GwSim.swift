import Foundation

/// 캐릭터 시계 위젯의 '놀이터' 움직임 — 안드로이드 WidgetSim.java 의 포팅(식 · 값 · 난수열 그대로).
/// 평소(NORMAL): 바닥을 걷고·쉬고·콩콩 뛰다가 시계 위로 올라 걷고·쉬고·응가하고·모서리에 매달렸다 뛰어내린다. 잘 시간엔 각자 집에 들어가 잔다.
/// 출퇴근(COMMUTE): 모두 시계 앞으로 와 줄을 서서 응원 · 위로 · 경고. 경로·시각 계산은 없다(그림용 상태기계).
final class GwSim {
    static let NORMAL = 0, COMMUTE = 1
    static let WALK = 0, REST = 1, HOP = 2, TO_SIDE = 3, JUMP = 4, TOP_WALK = 5, TOP_REST = 6, POOP = 7, HANG = 8, GATHER = 9, CHEER = 10,
        BED_WALK = 11, ENTER = 12, SLEEP = 13, EXIT = 14, LOOK = 15, STRETCH = 16, WIGGLE = 17, DASH = 18, SPIN = 19, BOUNCE = 20,
        VISIT = 21, WAITP = 22, GREET = 23, CHASE = 24, FLEE = 25
    static let nStates = 26
    static let ORDER = ["dolsom", "lovel", "dudung", "sul", "ppopu", "chaeng", "juksun", "bbosong"]

    /// 시트(256px 칸 4×4)의 값: {칸 안 머리 위 끝, 발 높이, 몸 가로 중심, 초당 프레임, 띄울 높이(키 58 기준), 몸 높이 비율}
    static func cfg(_ id: String) -> [Double] {
        switch id {
        case "dolsom": return [8, 248.5, 120.8, 19, 0, 1]
        case "lovel": return [8, 249.5, 133, 11, 0, 1]
        case "ppopu": return [8, 248.5, 120.3, 19, 0, 1]
        case "chaeng": return [14, 244.5, 154.5, 15, 6, 0.9]
        case "sul": return [27, 230.5, 131, 20, 16, 0.76]
        case "juksun": return [24.5, 247.5, 118.4, 12, 0, 0.9]
        case "bbosong": return [27, 249, 118.5, 12, 0, 0.86]
        default: return [15, 222.5, 128, 13, 0, 1]
        }
    }
    /// 캐릭터 셋(8마리 중 3마리). prev 가 있으면 그것과 다른 구성이 나온다.
    static func pickSet(seed: Int64, prev: [String]?) -> [String] {
        var r = JRandom(seed)
        var out: [String] = []
        for _ in 0..<24 {
            var pool = ORDER; r.shuffle(&pool)
            out = [pool[0], pool[1], pool[2]]
            if prev == nil || !sameSet(out, prev!) { break }
        }
        return out
    }
    static func sameSet(_ a: [String], _ b: [String]) -> Bool { a.count == b.count && Set(a) == Set(b) }
    static func houseKind(_ id: String) -> String {
        switch id {
        case "dolsom", "ppopu": return "dog"
        case "lovel": return "cat"
        case "dudung": return "mole"
        case "sul": return "nest"
        case "juksun": return "leaf"
        case "bbosong": return "flower"
        default: return "pond"
        }
    }
    static func houseSize(_ kind: String) -> [Double] {
        switch kind {
        case "dog": return [1.1, 0.9]
        case "cat": return [0.95, 1.1]
        case "mole": return [1.2, 0.9]
        case "nest": return [1.2, 1.1]
        case "leaf", "flower": return [1.4, 0.8]
        default: return [1.2, 0.6]
        }
    }
    /// 자는 장면 그림 값: {칸 한 변이 캐릭터 키의 몇 배, 바닥 기준점 x, y, 초당 프레임, zzz 자리 x, y}
    static func sleepCfg(_ id: String) -> [Double] {
        var r = sleepCfg0(id); r[0] *= 1.1; return r
    }
    private static func sleepCfg0(_ id: String) -> [Double] {
        switch id {
        case "lovel": return [2.822 * 0.42, 137.2 / 256, 220.2 / 256, 5, 154.4 / 256, 87.2 / 256]
        case "chaeng": return [2.756 * 0.45, 128.7 / 256, 158.3 / 256, 5, 128.7 / 256, 137.9 / 256]
        case "sul": return [3.577 * 0.41, 136.4 / 256, 226.1 / 256, 5, 172.2 / 256, 149.0 / 256]
        case "dolsom": return [2.166 * 0.55, 128.9 / 256, 198.8 / 256, 5, 138.2 / 256, 100.4 / 256]
        case "ppopu": return [2.723 * 0.55, 128.7 / 256, 181.4 / 256, 5, 151.6 / 256, 128.7 / 256]
        case "juksun": return [5.578 * 0.25, 132.0 / 256, 182.7 / 256, 5, 63.0 / 256, 50.4 / 256]
        case "bbosong": return [5.496 * 0.23, 129.4 / 256, 184.5 / 256, 5, 64.1 / 256, 46.6 / 256]
        default: return [2.740 * 0.45, 126.5 / 256, 189.2 / 256, 5, 126.5 / 256, 143.0 / 256]
        }
    }
    static func poops(_ id: String) -> Bool { id == "dolsom" || id == "ppopu" || id == "lovel" }

    final class Ch {
        var id = "", cfg: [Double] = []
        var x = 0.0, y = 0.0, off = 0.0
        var face = 1
        var st = GwSim.REST, t0 = 0.0, until = 0.0
        var ph = 0.0, tx = 0.0
        var zone = 0
        var rot = 0.0, sq = 0.0, sx = 0.0
        weak var pal: Ch?
        var cnt = 0, last = -1, mark = 0.0
        var x0 = 0.0, y0 = 0.0, x1 = 0.0, y1 = 0.0, arc = 0.0, nextSt = 0, nextZone = 0
        var face0 = 1, pooped = false, lastPoop = -99.0, lastTop = -99.0
        var frame = 0
        var alpha = 1.0, zz = 0.0
        var a0 = 0.0, sq0 = 0.0, off0 = 0.0, mix0 = 0.0
        var mix = 0.0
        var home: House?
        var spd = 0.0
    }
    final class House {
        unowned let owner: Ch; let kind: String
        var x = 0.0, w = 0.0, h = 0.0, a = 0.0, want = true
        init(_ o: Ch, _ k: String) { owner = o; kind = k }
    }
    struct Poop { var x = 0.0, y = 0.0, born = 0.0 }
    struct Spark { var x = 0.0, y = 0.0, vx = 0.0, vy = 0.0, age = 0.0, life = 0.0, type = 0 }   // 0 별 · 1 하트 · 2 먼지

    let geo: GwGeo
    var cs: [Ch] = []
    var poops: [Poop] = []
    var sparks: [Spark] = []
    var time = 0.0
    var mode = NORMAL
    var mood = "cheer"
    var settling = false
    var houses: [House] = []
    var forever = false
    private var rnd: JRandom

    init(geo g: GwGeo, seed: Int64, ids: [String]) {
        geo = g; rnd = JRandom(seed)
        let step = g.W / Double(ids.count + 1)
        for i in 0..<ids.count {
            let c = Ch(); c.id = ids[i]; c.cfg = Self.cfg(c.id)
            let sc = g.charH * c.cfg[5] / (c.cfg[1] - c.cfg[0])
            c.spd = c.cfg[3] / 16 * 256 * sc * 0.85
            c.x = clampX(step * Double(i + 1) + (rnd.nextFloat() - 0.5) * 10, 0); c.y = g.ground; c.zone = 0
            c.face = rnd.nextBool() ? 1 : -1
            c.st = Self.REST; c.t0 = 0; c.until = rnd.nextFloat() * 1.5; c.lastTop = -8 + Double(i) * 3
            cs.append(c)
        }
    }

    // ───────── 자리 계산 ─────────
    private func hw() -> Double { geo.charH * 0.55 }
    private func clampX(_ x: Double, _ zone: Int) -> Double {
        var lo = hw() * 0.85, hi = geo.W - hw() * 0.85
        if zone == 1 { lo = max(lo, geo.clkL + hw() * 0.5); hi = min(hi, geo.clkR - hw() * 0.5); if hi < lo { lo = geo.clkCx; hi = lo } }
        return x < lo ? lo : (x > hi ? hi : x)
    }
    private func topY() -> Double { geo.clkT }
    private func canClimb() -> Bool { geo.clkW >= hw() * 2.4 && geo.clkT - geo.charH >= -1 }
    private func topCount() -> Int { cs.filter { $0.zone == 1 || ($0.st == Self.JUMP && $0.nextZone == 1) || $0.zone == 2 }.count }
    private func rr(_ a: Double, _ b: Double) -> Double { a + rnd.nextFloat() * (b - a) }
    private func idx(_ c: Ch) -> Int { cs.firstIndex { $0 === c } ?? 0 }

    func setMode(_ m: Int, mood m2: String?) {
        if m == mode && (m2 == nil || m2 == mood) { return }
        mode = m; if let x = m2 { mood = x }
        for h in houses { h.want = false }
        for c in cs {
            c.pooped = false; c.alpha = 1; c.mix = 0; c.zz = 0; c.home = nil; c.sq = 0; c.sx = 0; c.pal = nil
            if mode == Self.COMMUTE { startGather(c) } else { c.st = Self.REST; c.t0 = time; c.until = time + 0.3 }
        }
    }
    func requestSettle() { settling = true }
    func resume() { settling = false; wakeAll(0) }

    // ───────── 잠자리 ─────────
    func bed(untilTapped: Bool) {
        if mode == Self.COMMUTE { return }
        forever = untilTapped; houses.removeAll(); for c0 in cs { c0.pal = nil }
        let hwid = geo.charH * 1.35, lo = hwid * 0.5 + 1, hi = geo.W - hwid * 0.5 - 1
        var order = cs; rnd.shuffle(&order)
        var xs = [Double](); var n = 0
        for c in order {
            var x = -1.0; var okp = false
            var k = 0
            while k < 40 && !okp {
                x = rr(lo, max(lo, hi)); okp = true
                for j in 0..<n where abs(x - xs[j]) < hwid * 1.0 { okp = false }
                k += 1
            }
            if !okp { x = lo + (max(lo, hi) - lo) * ((Double(n) + 0.5) / Double(order.count)) }
            xs.append(x); n += 1
            let h = House(c, Self.houseKind(c.id)); let sz = Self.houseSize(h.kind); h.x = x; h.w = geo.charH * sz[0]; h.h = geo.charH * sz[1]
            houses.append(h); c.home = h; c.tx = clampX(x, 0); c.pooped = false
            if c.zone != 0 || c.st == Self.JUMP || c.st == Self.HANG { jump(c, clampX(c.x, 0), geo.ground, 0, Self.BED_WALK, 0.5, 8) }
            else { c.st = Self.BED_WALK; c.t0 = time; c.until = time + 14 }
        }
    }
    private static func inBedState(_ st: Int) -> Bool { st == BED_WALK || st == ENTER || st == SLEEP || st == EXIT }
    func allInBed() -> Bool { !cs.isEmpty && cs.allSatisfy { $0.st == Self.SLEEP } }
    func allUp() -> Bool { !cs.contains { Self.inBedState($0.st) } && houses.isEmpty }
    func busy() -> Bool { cs.contains { $0.st != Self.SLEEP } || houses.contains { $0.a < 0.999 && $0.want } }
    func snapBed() {
        for c in cs where c.home != nil && c.st != Self.SLEEP {
            c.x = c.home!.x; c.zone = 0; c.y = geo.ground; c.rot = 0; c.st = Self.SLEEP; c.t0 = time; c.until = forever ? 1e9 : time + rr(20, 60)
            c.alpha = 0; c.sq = 0; c.off = 0; c.mix = 1; c.frame = 0
        }
        for h in houses { h.a = 1 }
    }
    func asleepNow() { if mode == Self.COMMUTE { return }; bed(untilTapped: true); snapBed(); snapAsleep() }
    func snapAsleep() {
        for c in cs where c.st == Self.SLEEP { c.zz = 1 }
        for h in houses where h.want { h.a = 1 }
    }
    func wakeAll(_ spread: Double = 0) {
        forever = false; var i = 0
        for c in cs {
            if c.st == Self.BED_WALK { c.st = Self.REST; c.t0 = time; c.until = time + 0.2 + 0.3 * Double(i); c.home?.want = false; c.home = nil }
            else if c.st == Self.ENTER || c.st == Self.SLEEP { startExit(c, spread > 0 ? rr(0, spread) : 0.25 * Double(i)) }
            else if let h = c.home { if c.st == Self.JUMP && c.nextSt == Self.BED_WALK { c.nextSt = Self.REST }; h.want = false; c.home = nil }
            i += 1
        }
    }
    private func startExit(_ c: Ch, _ delay: Double) { c.a0 = c.alpha; c.sq0 = c.sq; c.off0 = c.off; c.mix0 = c.mix; c.st = Self.EXIT; c.t0 = time + delay; c.until = c.t0 + 0.7 }
    func isSettled() -> Bool {
        for c in cs { if mode == Self.COMMUTE { if c.st != Self.CHEER { return false } } else if c.zone != 0 || c.st != Self.REST { return false } }
        return true
    }
    func snapSettled() {
        houses.removeAll(); forever = false
        for c in cs {
            c.pal = nil; c.sx = 0
            if mode == Self.COMMUTE { c.zone = 0; c.off = 0; c.rot = 0; c.frame = 0; continue }
            c.zone = 0; c.y = geo.ground; c.off = 0; c.rot = 0; c.sq = 0; c.st = Self.REST; c.t0 = time; c.until = time + 5; c.x = clampX(c.x, 0)
            c.alpha = 1; c.mix = 0; c.zz = 0; c.home = nil
        }
        poops.removeAll(); sparks.removeAll()
    }

    private func slotX(_ i: Int) -> Double { geo.stageL + geo.stageW * ((Double(i) + 0.5) / Double(cs.count)) }
    private func startGather(_ c: Ch) {
        let i = idx(c)
        c.tx = clampX(slotX(i), 0)
        if c.zone != 0 || c.st == Self.JUMP || c.st == Self.HANG { jump(c, c.x, geo.stageY, 0, Self.GATHER, 0.35, 6); return }
        c.st = Self.GATHER; c.t0 = time; c.until = time + 8; c.y = geo.ground
    }

    // ───────── 한 걸음 ─────────
    func step(_ dt0: Double) {
        var dt = dt0
        if !(dt > 0) { return }
        if dt > 0.1 { dt = 0.1 }
        time += dt
        for c in cs {
            stepChar(c, dt)
            let tz = c.st == Self.SLEEP ? 1.0 : 0.0
            c.zz += max(-1, min(1, tz - c.zz)) * min(1, dt * 2)
        }
        var i = houses.count - 1
        while i >= 0 {
            let h = houses[i]
            h.a = h.want ? min(1, h.a + dt / 0.9) : max(0, h.a - dt / 0.9)
            if !h.want && h.a <= 0 && h.owner.home !== h { houses.remove(at: i) }
            i -= 1
        }
        poops.removeAll { time - $0.born > 8 }
        i = sparks.count - 1
        while i >= 0 {
            sparks[i].age += dt; sparks[i].x += sparks[i].vx * dt; sparks[i].y += sparks[i].vy * dt
            sparks[i].vy += (sparks[i].type == 1 ? -4 : sparks[i].type == 2 ? 0 : 30) * dt
            if sparks[i].age >= sparks[i].life { sparks.remove(at: i) }
            i -= 1
        }
        if mode == Self.COMMUTE && mood == "comfort" && rnd.nextFloat() < dt * 1.2 {
            let c = cs[rnd.nextInt(cs.count)]; spark(c.x + Double(c.face) * hw() * 0.3, c.y - geo.charH * 1.0, 1)
        }
        if mode == Self.COMMUTE && mood == "cheer" && rnd.nextFloat() < dt * 0.7 {
            let c = cs[rnd.nextInt(cs.count)]; spark(c.x, c.y - geo.charH * 1.05, 0)
        }
    }
    private func dust(_ x: Double, _ y: Double) {
        var s = Spark(); s.x = x; s.y = y; s.type = 2; s.vx = rr(-3, 3); s.vy = rr(-2, 0); s.life = 0.5
        sparks.append(s); if sparks.count > 24 { sparks.removeFirst() }
    }
    private func spark(_ x: Double, _ y: Double, _ type: Int) {
        var s = Spark(); s.x = x; s.y = y; s.type = type; s.vx = rr(-8, 8); s.vy = type == 1 ? rr(-16, -9) : rr(-20, -8); s.life = type == 1 ? 1.5 : 0.8
        sparks.append(s); if sparks.count > 24 { sparks.removeFirst() }
    }
    private func moveToward(_ c: Ch, _ tx: Double, _ dist: Double) -> Bool {
        let d = tx - c.x
        if abs(d) <= dist { c.x = tx; return true }
        c.face = d > 0 ? 1 : -1; c.x += Double(c.face) * dist; return false
    }
    private func go(_ c: Ch, _ st: Int, _ dur: Double) { c.st = st; c.t0 = time; c.until = time + dur; c.sq = 0; c.pooped = false }
    private func jump(_ c: Ch, _ x1: Double, _ y1: Double, _ zone1: Int, _ nextSt: Int, _ dur: Double, _ arc: Double) {
        c.x0 = c.x; c.y0 = c.y; c.x1 = x1; c.y1 = y1; c.nextZone = zone1; c.nextSt = nextSt; c.arc = arc
        c.st = Self.JUMP; c.t0 = time; c.until = time + dur; c.zone = c.zone == 2 ? 0 : c.zone; c.rot = 0
        if x1 != c.x { c.face = x1 > c.x ? 1 : -1 }
    }
    private func groundWalkTarget(_ c: Ch) -> Double {
        let lo = hw() * 0.85, hi = geo.W - hw() * 0.85
        var x = rr(lo, hi)
        var k = 0
        while k < 4 && abs(x - c.x) < geo.W * 0.12 { x = rr(lo, hi); k += 1 }
        return x
    }
    private func nearTop(_ me: Ch, _ x: Double) -> Bool {
        for o in cs where o !== me {
            let ox = (o.st == Self.JUMP && o.nextZone == 1) ? o.x1 : o.x
            if (o.zone == 1 || (o.st == Self.JUMP && o.nextZone == 1)) && abs(ox - x) < hw() * 1.2 { return true }
        }
        return false
    }
    private func pickGround(_ c: Ch) {
        if mode == Self.COMMUTE { startGather(c); return }
        if settling { go(c, Self.REST, 6); return }
        let r = rnd.nextFloat()
        let climbOk = canClimb() && time - c.lastTop > 7 && topCount() < 2
        let poopOk = Self.poops(c.id) && time - c.lastPoop > 12
        if climbOk && r < 0.26 {
            let left = c.x < geo.clkCx
            c.tx = clampX(left ? geo.clkL - hw() * 0.7 : geo.clkR + hw() * 0.7, 0)
            if left && c.tx > geo.clkL - hw() * 0.2 { c.tx = clampX(geo.clkL - hw() * 0.2, 0) }
            go(c, Self.TO_SIDE, 6); return
        }
        if poopOk && r < 0.34 { go(c, Self.POOP, 2.6); return }
        pickExtra(c)
    }
    /// 성격 가중치: 걷기 · 쉬기 · 콩콩 · 질주 · 두리번 · 기지개 · 흔들흔들 · 빙글 · 통통 · 인사 · 술래잡기
    static func mood(_ id: String) -> [Double] {
        switch id {
        case "dolsom": return [18, 6, 8, 12, 5, 3, 5, 10, 6, 7, 12]
        case "ppopu": return [20, 8, 8, 6, 6, 3, 12, 6, 5, 14, 6]
        case "lovel": return [20, 18, 4, 4, 14, 14, 3, 2, 2, 5, 4]
        case "dudung": return [20, 14, 3, 2, 16, 6, 12, 3, 3, 8, 3]
        case "sul": return [14, 10, 10, 6, 14, 8, 4, 5, 14, 6, 6]
        case "chaeng": return [14, 6, 14, 6, 5, 3, 6, 14, 14, 6, 8]
        case "juksun": return [20, 20, 4, 1, 8, 14, 6, 2, 2, 8, 2]
        case "bbosong": return [18, 10, 6, 3, 6, 6, 14, 4, 4, 14, 4]
        default: return [20, 12, 8, 4, 8, 6, 6, 5, 5, 8, 5]
        }
    }
    private static let EX_ST = [WALK, REST, HOP, DASH, LOOK, STRETCH, WIGGLE, SPIN, BOUNCE, VISIT, CHASE]
    private func findPal(_ me: Ch) -> Ch? {
        var ok: [Ch] = []
        for o in cs {
            if o === me || o.pal != nil || o.zone != 0 || o.home != nil || o.alpha < 0.99 { continue }
            if [Self.WALK, Self.REST, Self.HOP, Self.LOOK, Self.STRETCH, Self.WIGGLE].contains(o.st) { ok.append(o) }
        }
        return ok.isEmpty ? nil : ok[rnd.nextInt(ok.count)]
    }
    private func pickExtra(_ c: Ch) {
        let w = Self.mood(c.id); var tot = 0.0; var v = [Double](repeating: 0, count: Self.EX_ST.count)
        let pal: Ch? = (mode == Self.NORMAL && !settling) ? findPal(c) : nil
        for i in 0..<v.count {
            v[i] = w[i]
            if Self.EX_ST[i] == c.last { v[i] *= 0.25 }
            if (Self.EX_ST[i] == Self.VISIT || Self.EX_ST[i] == Self.CHASE) && pal == nil { v[i] = 0 }
            if Self.EX_ST[i] == Self.DASH && geo.W < hw() * 6 { v[i] = 0 }
            tot += v[i]
        }
        var r = rnd.nextFloat() * tot; var pick = 0
        for i in 0..<v.count { if r < v[i] { pick = i; break }; r -= v[i]; pick = i }
        let st = Self.EX_ST[pick]; c.last = st
        switch st {
        case Self.WALK: c.tx = groundWalkTarget(c); go(c, Self.WALK, 7)
        case Self.REST: go(c, Self.REST, rr(1.6, 3.4))
        case Self.HOP: go(c, Self.HOP, rr(0.8, 1.4))
        case Self.DASH:
            let lo = hw() * 0.85, hi = geo.W - hw() * 0.85; var x = rr(lo, hi); var k = 0
            while k < 6 && abs(x - c.x) < geo.W * 0.3 { x = rr(lo, hi); k += 1 }
            c.tx = x; go(c, Self.DASH, 5); c.mark = time
        case Self.LOOK: go(c, Self.LOOK, rr(1.8, 2.8))
        case Self.STRETCH: go(c, Self.STRETCH, rr(1.8, 2.4))
        case Self.WIGGLE: go(c, Self.WIGGLE, rr(1.4, 2.2))
        case Self.SPIN: go(c, Self.SPIN, rr(1.2, 1.8))
        case Self.BOUNCE: go(c, Self.BOUNCE, 2.4); c.cnt = 0
        case Self.VISIT:
            let p = pal!; c.pal = p; p.pal = c; let side = c.x < p.x ? -1.0 : 1.0
            c.tx = clampX(p.x + side * hw() * 1.15, 0); go(c, Self.VISIT, 9)
            p.st = Self.WAITP; p.t0 = time; p.until = time + 10; p.off = 0; p.face = c.x < p.x ? -1 : 1
        default:
            let p = pal!; c.pal = p; p.pal = c; c.cnt = 0; p.cnt = 0
            go(c, Self.CHASE, 4.6); go(p, Self.FLEE, 4.6); p.until = c.until
        }
    }
    private func freePal(_ c: Ch, _ next: Int, _ dur: Double) { let o = c.pal; c.pal = nil; if let o = o, o.pal === c { o.pal = nil }; go(c, next, dur) }
    private func palIn(_ c: Ch, _ a: Int, _ b: Int, _ d: Int) -> Bool { if let o = c.pal, o.pal === c { return o.st == a || o.st == b || o.st == d }; return false }
    private func pickTop(_ c: Ch) {
        if settling || mode == Self.COMMUTE { dropDown(c); return }
        let onTop = time - c.t0
        let r = rnd.nextFloat()
        let poopOk = Self.poops(c.id) && time - c.lastPoop > 10
        if r < 0.28 { c.tx = clampX(rr(geo.clkL, geo.clkR), 1); go(c, Self.TOP_WALK, 6); return }
        if r < 0.46 { go(c, Self.TOP_REST, rr(1.8, 3.4)); return }
        if r < 0.66 && poopOk { go(c, Self.POOP, 2.6); return }
        if r < 0.86 {
            let left = rnd.nextBool()
            let hx = hangX(left)
            c.tx = hx; c.face = left ? 1 : -1
            c.x0 = c.x; c.y0 = c.y; c.x1 = hx; c.y1 = geo.clkT + geo.charH; c.arc = 3; c.nextZone = 2; c.nextSt = Self.HANG
            c.st = Self.JUMP; c.t0 = time; c.until = time + 0.3; return
        }
        if onTop > 4 { dropDown(c); return }
        go(c, Self.TOP_REST, rr(1.2, 2.4))
    }
    private func hangX(_ left: Bool) -> Double {
        let outL = geo.clkL - hw() * 0.4, outR = geo.clkR + hw() * 0.4
        if left { return outL >= hw() * 0.8 ? outL : geo.clkL + hw() * 0.45 }
        return outR <= geo.W - hw() * 0.8 ? outR : geo.clkR - hw() * 0.45
    }
    private func dropDown(_ c: Ch) {
        var side = c.x < geo.clkCx ? geo.clkL - hw() * 0.6 : geo.clkR + hw() * 0.6
        if mode == Self.COMMUTE { side = c.x }
        let gx = clampX(side, 0)
        jump(c, gx, geo.ground, 0, mode == Self.COMMUTE ? Self.GATHER : Self.REST, 0.5, 14)
        c.lastTop = time
    }

    private func stepChar(_ c: Ch, _ dt: Double) {
        let u = c.until > c.t0 ? min(1, (time - c.t0) / (c.until - c.t0)) : 1
        c.rot = 0; c.sq = 0; c.sx = 0; c.alpha = 1
        let H = geo.charH
        switch c.st {
        case Self.WALK:
            c.y = geo.ground; c.off = 0; c.ph += dt
            if moveToward(c, c.tx, c.spd * dt) || time >= c.until { pickGround(c) }
        case Self.REST:
            c.y = c.zone == 1 ? topY() : geo.ground; c.off = 0; c.frame = 0; c.ph += dt * 0.15
            if time >= c.until { if c.zone == 1 { pickTop(c) } else { pickGround(c) } }
        case Self.HOP:
            c.y = geo.ground; c.ph += dt * 1.4; c.off = abs(sin(u * .pi * 2)) * H * 0.28
            c.x = clampX(c.x + Double(c.face) * c.spd * 0.35 * dt, 0)
            if time >= c.until { c.off = 0; pickGround(c) }
        case Self.TO_SIDE:
            c.y = geo.ground; c.off = 0; c.ph += dt
            if moveToward(c, c.tx, c.spd * dt) {
                var lx = clampX(rr(geo.clkL, geo.clkR), 1)
                var k = 0
                while k < 6 && nearTop(c, lx) { lx = clampX(rr(geo.clkL, geo.clkR), 1); k += 1 }
                c.face = lx > c.x ? 1 : -1
                jump(c, lx, topY(), 1, Self.TOP_REST, 0.6, H * 0.5)
            } else if time >= c.until { pickGround(c) }
        case Self.JUMP:
            let e = min(1, (time - c.t0) / max(0.05, c.until - c.t0))
            let ee = e * e * (3 - 2 * e)
            c.x = c.x0 + (c.x1 - c.x0) * ee
            c.y = c.y0 + (c.y1 - c.y0) * ee; c.off = 4 * c.arc * e * (1 - e); c.ph += dt * 1.2
            if e >= 1 {
                c.x = c.x1; c.y = c.y1; c.off = 0; c.zone = c.nextZone
                if c.zone == 1 { c.t0 = time }
                if c.nextSt == Self.HANG { go(c, Self.HANG, rr(3, 5)) }
                else if c.nextSt == Self.BED_WALK { c.st = Self.BED_WALK; c.t0 = time; c.until = time + 14 }
                else if c.nextSt == Self.GATHER { c.st = Self.GATHER; c.t0 = time; c.until = time + 8; c.tx = clampX(slotX(idx(c)), 0) }
                else { go(c, c.nextSt, c.nextSt == Self.TOP_REST ? rr(1.5, 3) : rr(2, 4)) }
                if c.nextSt == Self.TOP_REST { c.lastTop = time }
            }
        case Self.TOP_WALK:
            c.y = topY(); c.off = 0; c.ph += dt
            if moveToward(c, c.tx, c.spd * 0.8 * dt) || time >= c.until { pickTop(c) }
        case Self.TOP_REST:
            c.y = topY(); c.off = 0; c.frame = 0
            c.rot = sin((time - c.t0) * 2.4 + c.x) * 3.5
            if time >= c.until { pickTop(c) }
        case Self.POOP:
            c.off = 0; c.y = c.zone == 1 ? topY() : geo.ground; c.frame = 4
            c.sq = (u > 0.14 && u < 0.78) ? 0.2 + sin(u * 60) * 0.02 : 0
            if u > 0.58 && !c.pooped {
                c.pooped = true; var p = Poop(); p.x = c.x - Double(c.face) * hw() * 0.55; p.y = c.y; p.born = time; poops.append(p); if poops.count > 3 { poops.removeFirst() }
                c.lastPoop = time; spark(p.x, p.y - 4, 0)
            }
            if time >= c.until { if c.zone == 1 { go(c, Self.TOP_REST, 1.2) } else { go(c, Self.HOP, 0.9) } }
        case Self.HANG:
            c.y = geo.clkT + H; c.off = 0; c.frame = 5; c.zone = 2
            c.rot = sin((time - c.t0) * 3.6) * 11 * (c.face > 0 ? 1 : -1)
            if time >= c.until {
                c.zone = 2
                let gx = clampX(c.x + (c.face > 0 ? -hw() * 0.4 : hw() * 0.4), 0)
                jump(c, gx, geo.ground, 0, Self.REST, 0.5, 6); c.lastTop = time
            }
        case Self.GATHER:
            c.y = geo.stageY; c.off = 0; c.ph += dt * 1.3
            if moveToward(c, c.tx, c.spd * 1.6 * dt) || time >= c.until {
                c.face = c.x < geo.clkCx ? 1 : -1
                if abs(c.x - geo.clkCx) < geo.clkW * 0.12 { c.face = idx(c) % 2 == 0 ? 1 : -1 }
                go(c, Self.CHEER, 1e6); c.t0 = time + Double(idx(c)) * 0.23; c.face0 = c.face
            }
        case Self.CHEER:
            c.y = geo.stageY; c.zone = 0; c.ph += dt * 0.9
            let tt = max(0, time - c.t0)
            if mood == "cheer" { c.off = abs(sin(tt * 5.2)) * H * 0.26; c.frame = Int(tt * 14) % 16 }
            else if mood == "comfort" { c.off = 0; c.frame = 0; c.rot = sin(tt * 1.8) * 4 }
            else { c.off = tt.truncatingRemainder(dividingBy: 1.6) < 0.18 ? H * 0.12 : 0; c.frame = 0; c.face = (Int(tt / 1.6) % 2 == 0) ? c.face0 : -c.face0 }
        case Self.LOOK:
            c.y = geo.ground; c.off = 0; c.frame = 0
            if c.cnt == 0 { c.cnt = 1; c.face0 = c.face }
            let k = Int(u * 4.6); c.face = (k % 2 == 0) ? c.face0 : -c.face0
            c.rot = sin(time * 5) * 2.5
            if time >= c.until { c.cnt = 0; pickGround(c) }
        case Self.STRETCH:
            c.y = geo.ground; c.off = 0; c.frame = 0
            var bell = u < 0.2 ? u / 0.2 : u > 0.8 ? (1 - u) / 0.2 : 1; bell = bell * bell * (3 - 2 * bell)
            c.rot = Double(c.face) * 9 * bell; c.sx = 0.13 * bell; c.sq = 0.05 * bell + (u > 0.3 && u < 0.7 ? sin(time * 18) * 0.01 : 0)
            if time >= c.until { pickGround(c) }
        case Self.WIGGLE:
            c.y = geo.ground; c.off = 0; c.frame = 0
            let env = u < 0.15 ? u / 0.15 : u > 0.85 ? (1 - u) / 0.15 : 1
            c.rot = sin((time - c.t0) * 15) * 7.5 * env; c.sx = sin((time - c.t0) * 15 + 1.6) * 0.04 * env
            if time >= c.until { pickGround(c) }
        case Self.DASH:
            c.y = geo.ground; c.off = abs(sin(time * 14)) * H * 0.04; c.ph += dt * 1.7; c.rot = Double(c.face) * 4
            if time - c.mark > 0.22 { c.mark = time; dust(c.x - Double(c.face) * hw() * 0.5, c.y - 2) }
            if moveToward(c, c.tx, c.spd * 2.3 * dt) || time >= c.until { dust(c.x - Double(c.face) * hw() * 0.6, c.y - 2); go(c, Self.REST, rr(0.8, 1.6)); c.mark = 0 }
        case Self.SPIN:
            c.y = geo.ground; c.ph += dt; c.off = abs(sin(u * .pi * 5)) * H * 0.12
            if c.cnt == 0 { c.cnt = 1; c.face0 = c.face }
            c.face = Int((time - c.t0) / 0.14) % 2 == 0 ? c.face0 : -c.face0; c.sq = 0.04 * abs(sin(time * 22))
            if time >= c.until { c.cnt = 0; c.face = c.face0; go(c, Self.REST, rr(0.5, 1.2)) }
        case Self.BOUNCE:
            c.y = geo.ground; c.ph += dt * 1.2
            let v = abs(sin(u * .pi * 3)); c.off = v * H * 0.6; c.sq = (1 - v) < 0.12 ? 0.12 * (1 - (1 - v) / 0.12) : 0
            let land = Int(u * 3 + 0.0001)
            if land > c.cnt { c.cnt = land; dust(c.x, c.y - 2) }
            if time >= c.until { c.off = 0; c.cnt = 0; go(c, Self.REST, rr(0.6, 1.4)) }
        case Self.VISIT:
            c.y = geo.ground; c.off = 0; c.ph += dt
            if !palIn(c, Self.WAITP, Self.WAITP, Self.WAITP) { freePal(c, Self.REST, rr(0.4, 1)); break }
            if moveToward(c, c.tx, c.spd * 1.1 * dt) {
                let o = c.pal!; c.face = c.x < o.x ? 1 : -1; o.face = -c.face
                go(c, Self.GREET, 1.9); go(o, Self.GREET, 1.9); c.mark = time; o.mark = time; spark((c.x + o.x) / 2, c.y - H * 1.05, 1)
            } else if time >= c.until { freePal(c, Self.REST, 0.6) }
        case Self.WAITP:
            c.y = geo.ground; c.off = 0; c.frame = 0; c.rot = sin(time * 4) * 1.5
            if !palIn(c, Self.VISIT, Self.GREET, Self.GREET) || time >= c.until { freePal(c, Self.REST, 0.3) }
        case Self.GREET:
            c.y = geo.ground; c.ph += dt * 1.2
            let first = idx(c) < (c.pal == nil ? 0 : idx(c.pal!))
            let ph2 = (time - c.t0) * 6.5 + (first ? 0 : .pi * 0.5)
            c.off = max(0, sin(ph2)) * H * 0.2 * (u < 0.85 ? 1 : 0.4)
            if u > 0.5 && time - c.mark > 0.7 { c.mark = time; if first { spark((c.x + (c.pal?.x ?? c.x)) / 2, c.y - H * 1.05, 1) } }
            if time >= c.until { c.off = 0; c.last = Self.HOP; freePal(c, Self.HOP, rr(0.6, 1)) }
        case Self.CHASE:
            c.y = geo.ground; c.off = abs(sin(time * 13)) * H * 0.035; c.ph += dt * 1.6
            if !palIn(c, Self.FLEE, Self.FLEE, Self.FLEE) { freePal(c, Self.REST, rr(0.5, 1.2)); break }
            let o = c.pal!
            if time >= c.until { c.off = 0; c.last = Self.HOP; let p2 = o; freePal(c, Self.HOP, 1.2); if p2.st == Self.FLEE || p2.st == Self.CHASE { go(p2, Self.HOP, 1.4) }; break }
            _ = moveToward(c, o.x, c.spd * 1.7 * dt)
            if abs(c.x - o.x) < hw() * 0.95 {
                spark((c.x + o.x) / 2, c.y - H * 1.0, 0); dust(c.x, c.y - 2)
                if c.cnt >= 2 { c.off = 0; c.last = Self.HOP; let p2 = o; freePal(c, Self.HOP, 1.2); if p2.st == Self.FLEE || p2.st == Self.CHASE { go(p2, Self.HOP, 1.4) }; break }
                let n = c.cnt + 1; let un = c.until; c.st = Self.FLEE; o.st = Self.CHASE; c.cnt = n; o.cnt = n; c.until = un; o.until = un; o.t0 = time; c.t0 = time
                c.x += (c.x < o.x ? -1 : 1) * hw() * 0.3
            }
        case Self.FLEE:
            c.y = geo.ground; c.off = abs(sin(time * 13)) * H * 0.035; c.ph += dt * 1.6
            if !palIn(c, Self.CHASE, Self.CHASE, Self.CHASE) { freePal(c, Self.REST, rr(0.5, 1.2)); break }
            let o = c.pal!; var away = c.x >= o.x ? 1.0 : -1.0; let lo = hw() * 0.85, hi = geo.W - hw() * 0.85
            if (away > 0 && c.x > hi - hw() * 0.4) || (away < 0 && c.x < lo + hw() * 0.4) { away = -away }
            c.face = away > 0 ? 1 : -1; c.x = clampX(c.x + away * c.spd * 1.55 * dt, 0)
        case Self.BED_WALK:
            c.y = geo.ground; c.off = 0; c.ph += dt; c.alpha = 1
            if c.home == nil { go(c, Self.REST, 0.3); break }
            if moveToward(c, c.tx, c.spd * dt) || time >= c.until { c.x = c.tx; c.st = Self.ENTER; c.t0 = time; c.until = time + 0.7 }
        case Self.ENTER:
            let k = u * u * (3 - 2 * u)
            c.y = geo.ground; c.frame = 0; c.alpha = 1 - k; c.mix = k; c.sq = 0; c.off = 0
            if time >= c.until { c.st = Self.SLEEP; c.t0 = time; c.until = forever ? 1e9 : time + rr(20, 60) }
        case Self.SLEEP:
            c.y = geo.ground; c.frame = 0; c.alpha = 0; c.mix = 1; c.sq = 0; c.off = 0
            if time >= c.until { startExit(c, 0) }
        case Self.EXIT:
            let e = max(0, min(1, (time - c.t0) / max(0.05, c.until - c.t0))), k = e * e * (3 - 2 * e)
            c.y = geo.ground; c.frame = 0; c.alpha = c.a0 + (1 - c.a0) * k; c.mix = c.mix0 * (1 - k); c.sq = c.sq0 * (1 - k); c.off = c.off0 * (1 - k)
            if c.home != nil && time >= c.t0 { c.home!.want = false }
            if time >= c.until { c.home = nil; c.alpha = 1; c.mix = 0; c.sq = 0; c.off = 0; go(c, Self.REST, rr(0.3, 1.2)) }
        default: break
        }
        let walking = [Self.WALK, Self.TO_SIDE, Self.TOP_WALK, Self.JUMP, Self.GATHER, Self.BED_WALK, Self.DASH, Self.VISIT, Self.CHASE, Self.FLEE, Self.HOP, Self.BOUNCE, Self.SPIN, Self.GREET]
        if walking.contains(c.st) { c.frame = Int(c.ph * c.cfg[3]) % 16 }
        if c.frame < 0 { c.frame = 0 }
    }
}
