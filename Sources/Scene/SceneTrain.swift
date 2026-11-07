import Foundation

/// 지하철 객실 장면 — 혼잡도 카드를 옆으로 밀면 보이는 두 번째 쪽(2026-10-26, YJ: "길동무 친구들이 지하철을 타고 이동하는 장면 · 이동 중이면 이동하는 배경 · 정지하면 일부가 랜덤으로 내리고 타는 애니메이션").
/// 안드로이드 SceneTrain.java 이식.
///
/// ★ 원칙: "계산은 엔진이, 그림은 앱이".
///   · 누가 타고 있다가 어느 역에서 내리고 타는지 · 역 이름 · 말풍선 글은 엔진(sceneTrain)이 정해 준다(res.train).
///   · 지금 달리는 중인지 서 있는지 · 언제 닿고 언제 출발하는지는 탑승 엔진이 정한 시각표(pos.segs: from·to·a(닿는 시각)·t0(출발)·t1(다음 역에 닿는 시각))다.
///     앱은 그 시각표와 지금 시각을 받아 그 순간의 그림을 그리기만 한다. 모든 움직임은 '지금 시각'의 함수라서, 이 쪽을 중간에 열어도 그 순간의 장면이 바로 나온다.
///   · 이 파일은 시각표를 해석하지 않는다 — 구간(달림/섬)을 고르고 거기에 맞춰 그리는 일뿐이다.
enum SceneTrain {
    final class Seg { var from = 0, to = 0; var a = 0.0, t0 = 0.0, t1 = 0.0 }
    /// 한 번의 정차에서 한 친구의 모습
    final class Pax { var ci = 0; var x = 0.0, y = 0.0, z = 0.0; var dir = 1; var sit = false, nap = false, walking = false, behind = false; var alpha = 1.0, walkT = 0.0; var say = "" }

    final class St {
        var T = SceneModel.Train(); var segs: [Seg] = []; var posOk = false
        var nowMs = 0.0; var clocked = false
        var scroll = 0.0, v = 1.0, sway = 0.0, acc = 0.0, vPrev = 0.0
        var seed = 0
        // 현재 구간
        var stop = false; var k = -1, toK = -1; var e = 0.0, dwell = 0.0, el = 0.0, rem = 0.0, dur = 0.0
        var shift = 0.0            // 승강장 가로 이동(화면 px; 도착 때는 음수에서 0으로, 출발 때는 0에서 양수로)
        var platform = false
        // 자리
        var spotX = [Double](repeating: 0, count: 6), spotY = [Double](repeating: 0, count: 6); var spotSit = [Bool](repeating: false, count: 6); var spotOf = [Int](repeating: 0, count: 6)
        // 그림 틀(장면 좌표)
        var ceilB = 0.0, winT = 0.0, winB = 0.0, floorLine = 0.0, benchBack = 0.0, seatY = 0.0, laneY = 0.0, platFeet = 0.0, doorW = 0.0, sillY = 0.0
        var doorX = [0.0, 0.0]
        var nTrip = 0
        // 안무: 달리는 동안 열두 초(EP)마다 친구 몇 명이 자리를 바꾼다(일어서서 걸어가 다른 자리에 앉는다). cur=지금 자리 · prv=바로 전 자리.
        var chor = 0.0, tA = 0.0; var epoch = 0; var cur = [Int](repeating: 0, count: 6), prv = [Int](repeating: 0, count: 6), emo = [Int](repeating: -1, count: 6)
    }
    static let EP = 12.0, SL = 9.0

    /// 자바 String.hashCode()
    static func javaHash(_ s: String) -> Int { var h: Int32 = 0; for u in s.utf16 { h = 31 &* h &+ Int32(u) }; return Int(h) }

    // ═══ 준비 ═══
    static func setup(_ s: SceneCore) {
        let old = s.tr; let z = St(); s.tr = z; z.T = s.res.train ?? SceneModel.Train()
        if let o = old { z.segs = o.segs; z.posOk = o.posOk; z.nowMs = o.nowMs; z.scroll = o.scroll }          // 크기가 바뀌어 다시 만들어도 시각표·시계는 이어서
        let W = s.W, H = s.H
        z.ceilB = jr(H * 0.085); z.winT = jr(H * 0.125); z.winB = jr(H * 0.435); z.benchBack = jr(H * 0.475); z.seatY = jr(H * 0.62)
        z.floorLine = jr(H * 0.765); z.laneY = jr(H * 0.90); z.platFeet = jr(H * 0.72); z.sillY = z.floorLine
        z.doorW = jr(W * 0.165); z.doorX[0] = jr(W * 0.30); z.doorX[1] = jr(W * 0.70)
        var sb = ""; for n in z.T.names { sb += n + "|" }
        z.seed = javaHash(sb + s.res.hero + String(z.T.first))
        // 자리: 앉는 자리 4 · 서는 자리 2 (한 번 정하면 이 여정 내내 같은 친구가 같은 자리)
        let sx = [0.12, 0.43, 0.57, 0.88, 0.50, 0.24]; let sit = [true, true, true, true, false, false]
        let sy = [z.seatY + 12, z.seatY + 12, z.seatY + 12, z.seatY + 12, H * 0.93, H * 0.86]
        for i in 0..<6 { z.spotX[i] = jr(W * sx[i]); z.spotSit[i] = sit[i]; z.spotY[i] = jr(sy[i]) }
        // 대표 캐릭터는 가운데 앉는 자리. 나머지는 시드로 섞는다
        var order = Array(0..<6)
        let rr = JavaRandom(Int64(z.seed) &* 31 &+ 7)
        var i = order.count; while i > 1 { let j = rr.nextInt(i); order.swapAt(i - 1, j); i -= 1 }
        let hi = indexOfId(s.res.hero); var spotOf = [Int](repeating: -1, count: 6)
        if hi >= 0 { spotOf[hi] = 1; if let ix = order.firstIndex(of: 1) { order.remove(at: ix) } }
        for c in 0..<6 where spotOf[c] < 0 { spotOf[c] = order.removeFirst() }
        z.spotOf = spotOf
        if let o = old { z.chor = o.chor; z.tA = o.tA; z.epoch = o.epoch; z.cur = o.cur; z.prv = o.prv; z.emo = o.emo }
        else { z.cur = spotOf; z.prv = spotOf; z.emo = [Int](repeating: -1, count: 6); z.chor = EP - 2 }
        if old == nil { z.nowMs = Date().timeIntervalSince1970 * 1000 }
    }
    /// 같은 여정의 새 엔진 값이 왔다: 친구·역이 같으면 값만 바꾸고(자리·움직임은 그대로), 다른 여정이면 처음부터 다시 만든다.
    static func refresh(_ s: SceneCore) {
        guard let z = s.tr, let n = s.res.train else { setup(s); return }
        let same = z.T.first == n.first && z.T.names == n.names && z.T.`init` == n.`init`
        if same { z.T = n } else { setup(s) }
    }
    static func indexOfId(_ id: String) -> Int { for i in 0..<SceneModel.ORDER.count where SceneModel.ORDER[i] == id { return i }; return -1 }

    // ═══ 바깥에서 받는 값 ═══
    /// 탑승 엔진의 위치 글({from,to,t0,t1,segs:[{from,to,a,t0,t1}…]}). 없거나 이상하면 시각표 없이 계속 달리는 그림.
    static func feedPos(_ s: SceneCore, _ json: String) {
        guard let z = s.tr else { return }
        z.segs.removeAll(); z.posOk = false
        if json.count < 4 { return }
        guard let d = json.data(using: .utf8), let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any], let so = o["segs"] as? [Any] else { return }
        for x in so {
            guard let m = x as? [String: Any] else { continue }
            guard let f = m["from"] as? NSNumber, let t = m["to"] as? NSNumber, let a = m["a"] as? NSNumber, let t0 = m["t0"] as? NSNumber, let t1 = m["t1"] as? NSNumber else { continue }
            let g = Seg(); g.from = f.intValue; g.to = t.intValue; g.a = a.doubleValue; g.t0 = t0.doubleValue; g.t1 = t1.doubleValue
            if g.t1 > g.t0 && g.t0 >= g.a { z.segs.append(g) }
        }
        z.posOk = !z.segs.isEmpty
    }
    static func feedClock(_ s: SceneCore, _ nowMs: Int64) { guard let z = s.tr else { return }; z.nowMs = Double(nowMs); z.clocked = true }

    // ═══ 구간 고르기 (시각표 + 지금 시각 → 달림/섬) ═══
    static let K_SPEED = 0.42      // 가장 빠를 때 초당 움직이는 거리(장면 폭 배수)
    static func phase(_ s: SceneCore, _ z: St) {
        let now = z.nowMs; z.stop = false; z.k = -1; z.toK = -1; z.e = 0; z.dwell = 1e9; z.el = 0; z.rem = 0; z.dur = 0; z.platform = false; z.shift = 0
        if !z.posOk { z.v = 1; return }
        // 탑승 엔진의 시각표는 환승 뒤 다른 호선·지난 구간까지 이어서 온다 — 이 객실 장면의 역(first … first+n-1) 안에 든 구간만 쓴다
        let lo = z.T.first, hi = z.T.first + z.T.names.count - 1
        var cur: Seg? = nil, last: Seg? = nil
        for g in z.segs { if g.from < lo || g.to > hi { continue }; last = g; if cur == nil && now < g.t1 { cur = g } }
        guard let l = last else { z.v = 1; return }
        guard let c = cur else { z.stop = true; z.k = l.to - z.T.first; z.e = max(0, (now - l.t1) / 1000); z.dwell = 1e9; z.v = 0; z.platform = true; return }
        if now < c.t0 { z.stop = true; z.k = c.from - z.T.first; z.e = max(0, (now - c.a) / 1000); z.dwell = max(1, (c.t0 - c.a) / 1000); z.v = 0; z.platform = true; return }
        z.el = (now - c.t0) / 1000; z.rem = (c.t1 - now) / 1000; z.dur = (c.t1 - c.t0) / 1000; z.k = c.from - z.T.first; z.toK = c.to - z.T.first
        let ta = min(7, z.dur * 0.25), td = min(8, z.dur * 0.3)
        z.v = clamp(min(1, min(z.el / max(0.1, ta), z.rem / max(0.1, td))), 0, 1)
        let Wd = s.W * K_SPEED
        let dd = z.el < ta ? z.el * z.el / (2 * ta) : ta / 2 + (z.el - ta)
        let rr = z.rem < td ? z.rem * z.rem / (2 * td) : td / 2 + (z.rem - td)
        z.shift = z.el <= z.rem ? dd * Wd : -rr * Wd
        z.platform = true      // 보이는지는 그릴 때 범위로 정한다
    }

    // ═══ 한 걸음 ═══
    static func step(_ s: SceneCore, _ dt: Double) {
        guard let z = s.tr else { return }
        if !z.clocked { z.nowMs += dt * 1000 }      // 시계를 받지 못하면 스스로 센다
        z.clocked = false
        phase(s, z)
        z.tA += dt
        var nc = z.chor + dt; if z.stop { nc = min(nc, Double(z.epoch + 1) * EP - 1e-6) }          // 서 있는 동안엔 자리 바꿈을 새로 시작하지 않는다(문 앞에서 길을 막지 않게)
        z.chor = nc
        while z.chor >= Double(z.epoch + 1) * EP { z.epoch += 1; nextEpoch(z) }
        let K = s.W * K_SPEED
        z.scroll += z.v * dt * K
        let tgt = clamp((z.v - z.vPrev) / max(dt, 0.001), -1.2, 1.2)
        z.acc = z.acc * 0.9 + tgt * 0.1; z.vPrev = z.v
        z.sway = sin(s.t * 1.6) * 0.03 - z.acc * 0.05
    }

    // ═══ 친구 한 명의 그 순간 모습 ═══
    /// 자바 int 연산 그대로의 해시(32비트 넘침).
    static func hsh(_ a0: Int, _ b0: Int) -> Int {
        let a = Int32(truncatingIfNeeded: a0), b = Int32(truncatingIfNeeded: b0)
        var x: Int32 = (a &* 73856093) ^ (b &* 19349663)
        x ^= Int32(bitPattern: UInt32(bitPattern: x) >> 13)
        x = x &* 0x5bd1e995
        x ^= Int32(bitPattern: UInt32(bitPattern: x) >> 15)
        return Int(x & 0x7fffffff)
    }

    /// 정차 중(또는 마침) 친구 ci 의 모습. 없으면 nil.
    static func paxAt(_ s: SceneCore, _ z: St, _ ci: Int, _ k: Int, _ e: Double, _ dwell: Double) -> Pax? {
        let T = z.T; let W = s.W, H = s.H
        let sp: [Int] = (k >= 0 && k < T.stops.count) ? T.stops[k] : [T.`init`, 0, 0]
        let before = sp[0], out = sp[1], inn = sp[2], b = 1 << ci
        let isIn = (before & b) != 0, isOut = (out & b) != 0, isBoard = (inn & b) != 0
        let p = Pax(); p.ci = ci; let spot = z.cur[ci]
        let sx = z.spotX[spot], sy = z.spotY[spot]; let sitSpot = z.spotSit[spot]
        let sc = clamp(H / 190.0, 0.8, 1.2)
        if !isOut && !isBoard {
            if !isIn { return nil }
            idleAt(s, z, p, ci); return p
        }
        // 문 열림 시간표
        let tOpen = min(1.1, dwell * 0.1), tClose = dwell >= 1e8 ? 1e9 : dwell - min(3.2, dwell * 0.2)
        let win = tClose >= 1e8 ? 30 : max(2.5, tClose - tOpen - 1.0)
        var idx = 0, cnt = 0                         // 나와 같은 일을 하는 친구들 중 내 순번
        for c in 0..<6 { let bb = 1 << c; let same = isOut ? (out & bb) != 0 : (inn & bb) != 0; if same { if c < ci { idx += 1 }; cnt += 1 } }
        let hs = hsh(z.seed + k, ci)
        var f = 1.0                                  // 정차가 짧으면 모두 서두른다
        let need = 6.5 + 1.4 * Double(max(0, cnt - 1)); if need > win { f = clamp(win / need, 0.35, 1) }
        let d0 = tOpen + 0.7 * f + Double(idx) * 1.5 * f + Double(hs % 60) / 100.0 * f                 // 내 시작 시각
        let doorFoot = z.floorLine + 3
        let dxd = z.doorX[abs(sx - z.doorX[0]) <= abs(sx - z.doorX[1]) ? 0 : 1]
        let laneJ = Double((hs >> 8) % 11 - 5)             // 문 앞에서 몸이 겹치지 않게 조금씩 어긋난다
        let walkSp = 34 * W / 208.0                  // 장면 px/초
        let dh = abs(sx + laneJ - dxd), tW = max(0.4, dh / walkSp) * f
        let tCross = 0.9 * f, tPlat = 2.3 * f, tSit = 0.35 * f, tStand = sitSpot ? 0.35 * f : 0
        let pdir = (hs >> 4) % 2 == 0 ? 1 : -1; let pd = Double(pdir)
        let scLane = 1.0 * sc, scPlat = 0.6 * sc
        if isOut {
            var u = e - d0
            if u < 0 { idleAt(s, z, p, ci); return p }
            if u < tStand { p.x = sx; p.y = sy; p.z = scLane; p.dir = sx < dxd ? 1 : -1; p.sit = false; p.walking = false; p.say = ""; return p }
            u -= tStand
            let ly = max(sy, z.laneY - 4)
            if u < tW { let q = ease(u / tW); p.x = lerp(sx, dxd + laneJ, q); p.y = lerp(sy, ly, min(1, q * 2)); p.z = scLane; p.dir = (dxd + laneJ) >= sx ? 1 : -1; p.walking = true; p.walkT = u; p.say = hs % 3 == 0 && u < 1.6 * f ? pick(T.sayOut, hs) : ""; return p }
            u -= tW
            if u < tCross {
                let q = ease(u / tCross); p.x = lerp(dxd + laneJ, dxd, q); p.y = lerp(ly, z.platFeet, q); p.z = lerp(scLane, scPlat, q); p.dir = 1; p.walking = true; p.walkT = u + tW
                p.behind = p.y < doorFoot - 2; p.say = ""; return p
            }
            u -= tCross
            if u < tPlat { let q = u / tPlat; p.x = dxd + pd * q * z.doorW * 0.9; p.y = z.platFeet; p.z = scPlat; p.dir = pdir; p.walking = true; p.walkT = u + tW + tCross; p.behind = true; p.alpha = q > 0.75 ? 1 - (q - 0.75) / 0.25 : 1; return p }
            return nil
        }
        // 타는 친구
        var u = e - d0
        _ = tSit
        if u < 0 { return nil }
        let tIn = tPlat * 0.6
        if u < tIn { let q = u / tIn; p.x = dxd - pd * (1 - q) * z.doorW * 0.9; p.y = z.platFeet; p.z = scPlat; p.dir = pdir; p.walking = true; p.walkT = u; p.behind = true; p.alpha = min(1, q * 4); p.dir = pdir; return p }
        u -= tIn
        let ly = max(sy, z.laneY - 4)
        if u < tCross { let q = ease(u / tCross); p.x = lerp(dxd, dxd + laneJ, q); p.y = lerp(z.platFeet, ly, q); p.z = lerp(scPlat, scLane, q); p.dir = 1; p.walking = true; p.walkT = u + tIn; p.behind = p.y < doorFoot - 2; p.say = hs % 3 == 0 ? pick(T.sayIn, hs) : ""; return p }
        u -= tCross
        if u < tW { let q = ease(u / tW); p.x = lerp(dxd + laneJ, sx, q); p.y = lerp(ly, sy, max(0, (q - 0.4) / 0.6)); p.z = scLane; p.dir = sx >= dxd + laneJ ? 1 : -1; p.walking = true; p.walkT = u + tIn + tCross; return p }
        idleAt(s, z, p, ci)
        return p
    }
    static func pick(_ l: [String], _ hs: Int) -> String { l.isEmpty ? "" : l[(hs >> 3) % l.count] }

    // ═══ 객실 안에서 하는 일들 (앉았다 일어서서 다른 자리로 · 졸기 · 기지개 · 두리번 · 서성이기 · 콧노래/하트) ═══
    /// 열두 초가 지날 때마다: 타고 있는 친구 한두 명이 다른 자리로 옮긴다(그 자리에 앉은 친구와 맞바꾸거나 빈 자리로).
    static func nextEpoch(_ z: St) {
        z.prv = z.cur
        let k = z.toK; let sp: [Int] = (k >= 0 && k < z.T.stops.count) ? z.T.stops[k] : [z.T.`init`, 0, 0]
        let mask = sp[0], nm = 1 + hsh(z.seed + z.epoch, 99) % 2; var moved = [Bool](repeating: false, count: 6)
        for m in 0..<nm {
            let hs = hsh(z.seed + z.epoch * 31 + m, 17); var n = 0; var cand = [Int](repeating: 0, count: 6)
            for c in 0..<6 where (mask & (1 << c)) != 0 && !moved[c] { cand[n] = c; n += 1 }
            if n == 0 { break }
            let a = cand[hs % n], old = z.cur[a], to = (old + 1 + (hs >> 6) % 5) % 6; var b = -1
            for c in 0..<6 where z.cur[c] == to { b = c }
            z.cur[a] = to; moved[a] = true
            if b >= 0 { z.cur[b] = old; moved[b] = true }
        }
    }
    /// 자리 from → to 로 걷는 길: [전체 시간, 일어서는 시간, 걷는 시간, ly]
    static func movePath(_ s: SceneCore, _ z: St, _ from: Int, _ to: Int) -> [Double] {
        let y0 = z.spotY[from], y1 = z.spotY[to], x0 = z.spotX[from], x1 = z.spotX[to]
        let ly = max(max(y0, y1), z.laneY - 4), sp = 34 * s.W / 208.0
        let len = abs(ly - y0) + abs(x1 - x0) + abs(y1 - ly)
        let ts = z.spotSit[from] ? 0.45 : 0.0, tw = len / sp, tt = z.spotSit[to] ? 0.45 : 0.0
        return [ts + tw + tt, ts, tw, ly]
    }
    static func idleAt(_ s: SceneCore, _ z: St, _ p: Pax, _ ci: Int) {
        let sc = clamp(s.H / 190.0, 0.8, 1.2), u = z.chor - Double(z.epoch) * EP
        let from = z.prv[ci], to = z.cur[ci]
        if from != to {
            let md = movePath(s, z, from, to)
            if u < md[0] { moveAt(s, z, p, from, to, u, sc, md); return }
        }
        restAt(s, z, p, ci, to, sc)
    }
    static func sgn(_ v: Double) -> Double { v > 0 ? 1 : v < 0 ? -1 : 0 }
    static func moveAt(_ s: SceneCore, _ z: St, _ p: Pax, _ from: Int, _ to: Int, _ u: Double, _ sc: Double, _ md: [Double]) {
        let x0 = z.spotX[from], y0 = z.spotY[from], x1 = z.spotX[to], y1 = z.spotY[to], ly = md[3], w = u - md[1]
        p.z = sc; p.alpha = 1; p.sit = false; p.nap = false; p.dir = x1 >= x0 ? 1 : -1
        if w < 0 { p.x = x0; p.y = y0; return }                                         // 일어서는 중
        if w < md[2] {
            let sp = 34 * s.W / 208.0, d = w * sp, l1 = abs(ly - y0), l2 = abs(x1 - x0)
            if d < l1 { p.x = x0; p.y = y0 + sgn(ly - y0) * d }
            else if d < l1 + l2 { p.x = x0 + sgn(x1 - x0) * (d - l1); p.y = ly }
            else { p.x = x1; p.y = ly + sgn(y1 - ly) * (d - l1 - l2) }
            p.walking = true; p.walkT = w; return
        }
        p.x = x1; p.y = y1                                                                 // 새 자리 앞에 섰다(곧 앉는다)
    }
    static func restAt(_ s: SceneCore, _ z: St, _ p: Pax, _ ci: Int, _ spot: Int, _ sc: Double) {
        let sx = z.spotX[spot], sy = z.spotY[spot]; let sitSpot = z.spotSit[spot]
        p.x = sx; p.y = sy; p.z = sc; p.sit = sitSpot; p.dir = sx < s.W / 2 ? 1 : -1; p.walking = false; p.alpha = 1; p.nap = false
        let t = z.tA + Double(ci) * 3.1; let slot = Int(floor(t / SL)); let ph = t - Double(slot) * SL
        let hs = hsh(slot + z.seed, ci * 7 + 3), r = hs % 100
        var emote = false
        if sitSpot {
            if r < 18 { p.nap = true }
            else if r < 34 { if ph >= 1 && ph < 6.5 { p.sit = false } }                   // 일어나 기지개 켰다 다시 앉는다
            else if r < 44 { if ph > 4.5 { p.dir = -p.dir } }                              // 두리번
            else if r < 54 { emote = ph > 1.5 }
        } else {
            if r < 28 {                                                                    // 서성이기: 몇 걸음 갔다가 돌아온다
                let dist = s.W * 0.18, sp = 34 * s.W / 208.0, t1 = dist / sp, g: Double = (hs >> 9) % 2 == 0 ? 1 : -1
                let q = ph - 1
                if q >= 0 && q < t1 { p.x = sx + g * dist * (q / t1); p.dir = Int(g); p.walking = true; p.walkT = q }
                else if q >= t1 && q < t1 + 2.2 { p.x = sx + g * dist; p.dir = Int(g) }
                else if q >= t1 + 2.2 && q < 2 * t1 + 2.2 { let q2 = q - t1 - 2.2; p.x = sx + g * dist * (1 - q2 / t1); p.dir = Int(-g); p.walking = true; p.walkT = q2 }
                p.x = clamp(p.x, 10, s.W - 10)
            } else if r < 40 { if ph > 4.5 { p.dir = -p.dir } }
            else if r < 50 { emote = ph > 1.5 }
        }
        if emote && z.emo[ci] != slot {
            z.emo[ci] = slot
            let ty = ["note", "heart", "star"]
            s.ptx(ty[(hs >> 12) % 3], p.x + 6, p.y - 40 * p.z, 1, po().a(-1.35, -1.05).s(7, 11).g(-4).l(1.1, 1.7).jx(2))
        }
    }

    // ═══ 그리기 ═══
    static func draw(_ s: SceneCore, _ c: SceneCv) {
        guard let z = s.tr else { return }
        let W = s.W, H = s.H
        let T = z.T; let lineCol = SceneArt.lineColor(T.line)
        let night = s.L.night
        // 바탕: 객실 벽
        c.fillStyle("#1a1e29"); c.fillRect(0, 0, W, H)
        // 천장
        let ceil = c.linear(0, 0, 0, z.ceilB + 6).stop(0, css("#d9dee6")).stop(1, css("#b9c0cc")); c.fillGrad(ceil); c.fillRect(3, 3, W - 6, z.ceilB + 3)
        c.fillStyle("#fff9d8"); var lx = 14.0; while lx < W - 14 { rr(c, lx, 5, 30, 3.2, 1.6); c.fill(); lx += 46 }
        // 벽(창 위·아래)
        let wall = c.linear(0, z.ceilB, 0, z.floorLine).stop(0, css("#e7ebf1")).stop(1, css("#c7cfdb")); c.fillGrad(wall); c.fillRect(3, z.ceilB + 3, W - 6, z.floorLine - z.ceilB - 3)
        // 창·문 구멍 모양
        let hl = holes(z, W)
        // ── 바깥 풍경(터널 또는 승강장): 구멍 모양으로 잘라서 보여준다 ──
        c.save(); c.beginPath(); for r in hl { c.rect(r[0], r[1], r[2], r[3]) }; c.clip()
        drawOutside(s, z, c, W, H)
        // 유리 반사
        c.fillStyle("rgba(255,255,255,.08)"); for r in hl { c.beginPath(); c.moveTo(r[0] + 5, r[1]); c.lineTo(r[0] + 14, r[1]); c.lineTo(r[0] + 2, r[1] + r[3]); c.lineTo(r[0] - 7, r[1] + r[3]); c.closePath(); c.fill() }
        // 플랫폼 쪽에 있는 친구(문 구멍 안에서만 보인다)
        let dh = [hl[2], hl[5]]
        let paxes = allPax(s, z)
        c.restore()
        for d in 0..<2 {
            c.save(); c.beginPath(); c.rect(dh[d][0], dh[d][1], dh[d][2], dh[d][3]); c.clip()
            for p in paxes where p.behind && nearestDoor(z, p.x) == d { drawPax(s, c, p) }
            c.restore()
        }
        // 문짝
        let open = doorOpen(z)
        for d in 0..<2 { drawDoor(s, z, c, dh[d], open, lineCol) }
        // 창틀
        c.strokeStyle("#8c95a6"); c.lineWidth(1.6); for r in hl { rr(c, r[0], r[1], r[2], r[3], 2.5); c.stroke() }
        // 의자(창 아래 긴 의자 세 토막)
        drawBench(s, z, c, W, lineCol)
        // 바닥
        let fl = c.linear(0, z.floorLine, 0, H).stop(0, css("#8c93a1")).stop(1, css("#5c6270")); c.fillGrad(fl); c.fillRect(3, z.floorLine, W - 6, H - z.floorLine - 3)
        c.fillStyle("rgba(0,0,0,.18)"); c.fillRect(3, z.floorLine, W - 6, 1.6)
        // 손잡이 봉
        c.fillStyle("#cfd4de"); c.fillRect(8, z.ceilB + 12, W - 16, 2.2); c.fillStyle("rgba(0,0,0,.2)"); c.fillRect(8, z.ceilB + 14.2, W - 16, 0.9)
        let hx = [0.08, 0.20, 0.40, 0.50, 0.60, 0.80, 0.92]
        for q in hx {
            let x = W * q; c.save(); c.translate(x, z.ceilB + 14); c.rotate(z.sway * (q < 0.5 ? 1 : 0.85))
            c.strokeStyle("#4b5263"); c.lineWidth(1.2); c.beginPath(); c.moveTo(0, 0); c.lineTo(0, 15); c.stroke()
            c.strokeStyle("#ffb347"); c.lineWidth(1.8); c.beginPath(); c.arc(0, 19, 4, 0, PI2); c.stroke(); c.restore()
        }
        // 문 옆 기둥
        c.fillStyle("#d4d9e3"); for d in 0..<2 { c.fillRect(z.doorX[d] - z.doorW / 2 - 4, z.ceilB + 6, 2.2, z.floorLine - z.ceilB - 5); c.fillRect(z.doorX[d] + z.doorW / 2 + 2, z.ceilB + 6, 2.2, z.floorLine - z.ceilB - 5) }
        // 안내 표시(문 위 가운데): 다음 역 / 이번 역
        drawLed(s, z, c, W, lineCol)
        // 안쪽 친구들
        var inner: [Pax] = []; for p in paxes where !p.behind { inner.append(p) }
        inner.sort { $0.y < $1.y }
        for p in inner { drawPax(s, c, p) }
        for p in inner where !p.say.isEmpty { SceneArt.drawBubble(c, p.x + Double(p.dir) * 4, p.y - 50 * p.z, p.say) }
        s.drawParts(c, s.dtLast)
        // (s257 YJ: "지하철 이동 때 애니메이션이 살짝 하얗게 깜박여" — 달리는 동안 객실 전체를 훑던 번쩍임을 없앴다. 창밖 터널 등만 지나간다)
        // 바깥 틀(차체 테두리)
        c.strokeStyle("#2a2f3b"); c.lineWidth(3); rr(c, 1.5, 1.5, W - 3, H - 3, 9); c.stroke()
        if night { c.fillStyle("rgba(6,10,30,.05)"); c.fillRect(0, 0, W, H) }
    }

    static func holes(_ z: St, _ W: Double) -> [[Double]] {
        let wt = z.winT, wh = z.winB - z.winT, dw = z.doorW, dt = z.ceilB + 6, dhh = z.floorLine - dt
        let x1 = z.doorX[0] - dw / 2, x2 = z.doorX[0] + dw / 2, x3 = z.doorX[1] - dw / 2, x4 = z.doorX[1] + dw / 2
        return [
            [8, wt, x1 - 13 - 8, wh],                       // 왼쪽 창
            [x2 + 7, wt, x3 - 7 - x2 - 7, wh],              // 가운데 창
            [x1, dt, dw, dhh],                              // 문 1
            [x4 + 13, wt, W - 8 - x4 - 13, wh],             // 오른쪽 창
            [x2 + 7 + 0, wt, 0, 0],                         // 자리 표시(미사용)
            [x3, dt, dw, dhh],                              // 문 2
            [x1 - 13, wt, 0, 0],
        ]
    }
    static func nearestDoor(_ z: St, _ x: Double) -> Int { abs(x - z.doorX[0]) <= abs(x - z.doorX[1]) ? 0 : 1 }

    static func doorOpen(_ z: St) -> Double {
        if !z.stop { return 0 }
        let tOpen = min(1.1, z.dwell * 0.1), tClose = z.dwell >= 1e8 ? 1e9 : z.dwell - min(3.2, z.dwell * 0.2)
        if z.e < 0.4 { return 0 }
        if z.e < 0.4 + tOpen { return ease((z.e - 0.4) / tOpen) }
        if z.e < tClose { return 1 }
        if z.e < tClose + 1.2 { return 1 - ease((z.e - tClose) / 1.2) }
        return 0
    }

    static func allPax(_ s: SceneCore, _ z: St) -> [Pax] {
        var l: [Pax] = []
        var k = z.stop ? z.k : z.toK       // 달리는 동안은 '다음 역에 닿기 직전' 타고 있는 친구들
        let e = z.stop ? z.e : -1, dwell = z.stop ? z.dwell : 1e9
        if !z.stop && z.k >= 0 && z.k < z.T.stops.count { k = z.toK }          // 달리는 중: 직전 정차(k)가 끝난 뒤의 명단 = 다음 역(toK)의 '직전 명단'
        for ci in 0..<6 {
            var p: Pax?
            if z.stop { p = paxAt(s, z, ci, k, e, dwell) }
            else {      // 달림: 다음 역에 닿기 직전의 명단 그대로 앉아 있다
                let sp: [Int] = (k >= 0 && k < z.T.stops.count) ? z.T.stops[k] : [z.T.`init`, 0, 0]
                if (sp[0] & (1 << ci)) == 0 { continue }
                let q = Pax(); q.ci = ci; idleAt(s, z, q, ci); p = q
            }
            if let pp = p { l.append(pp) }
        }
        return l
    }

    static func drawOutside(_ s: SceneCore, _ z: St, _ c: SceneCv, _ W: Double, _ H: Double) {
        let top = z.ceilB, bot = z.floorLine
        // 터널
        let tn = c.linear(0, top, 0, bot).stop(0, css("#0a0e18")).stop(1, css("#1b2332")); c.fillGrad(tn); c.fillRect(0, top, W, bot - top)
        let sp = z.scroll
        // 케이블(느리게) — 가로줄
        c.strokeStyle("rgba(120,140,170,.35)"); c.lineWidth(1)
        for i in 0..<3 { let y = top + (bot - top) * (0.22 + Double(i) * 0.09); c.beginPath(); c.moveTo(0, y); c.lineTo(W, y); c.stroke() }
        // 벽 이음매(중간 속도)
        c.strokeStyle("rgba(150,165,190,.22)"); c.lineWidth(1.6)
        let per = 54.0, off = (sp * 0.6).truncatingRemainder(dividingBy: per); var x = off - per
        while x < W + per { c.beginPath(); c.moveTo(x, top); c.lineTo(x, bot); c.stroke(); x += per }
        // 터널 등(가장 빠르게) — 번쩍 지나가는 불빛
        let lp = 92.0, lo = (sp * 1.1).truncatingRemainder(dividingBy: lp)
        x = lo - lp
        while x < W + lp {
            let lg = c.radial(x, top + 20, 0, x, top + 20, 26).stop(0, rgba(255, 238, 180, 0.55)).stop(1, rgba(255, 238, 180, 0)); c.fillGrad(lg); c.fillRect(x - 26, top - 6, 52, 52)
            c.fillStyle("#fff2b8"); c.fillRect(x - 6, top + 17, 12, 3)
            x += lp
        }
        // 승강장
        let sh = z.shift, E = W * 1.3 + sh, S = E - W * 2.5
        if E > 0 && S < W {
            let x0 = max(0, S), x1 = min(W, E)
            c.save(); c.beginPath(); c.rect(x0, top, x1 - x0, bot - top); c.clip()
            // 타일 벽
            let tw = c.linear(0, top, 0, bot).stop(0, css("#dfe5ee")).stop(1, css("#bcc6d6")); c.fillGrad(tw); c.fillRect(x0, top, x1 - x0, bot - top)
            c.strokeStyle("rgba(110,125,150,.28)"); c.lineWidth(0.8)
            let ty = (bot - top) * 0.62; var y = top + 8; while y < top + ty { c.beginPath(); c.moveTo(x0, y); c.lineTo(x1, y); c.stroke(); y += 14 }
            let tper = 16.0, to = ((sh.truncatingRemainder(dividingBy: tper)) + tper).truncatingRemainder(dividingBy: tper)
            x = x0 - tper + to - x0.truncatingRemainder(dividingBy: tper)
            while x < x1 + tper { c.beginPath(); c.moveTo(x, top); c.lineTo(x, top + ty); c.stroke(); x += tper }
            // 기둥(세계 좌표: 0.5W 마다)
            let pw = 7.0
            for j in -3...6 {
                let px = W * (0.5 * Double(j)) + sh
                if px + pw < x0 - 2 || px - pw > x1 + 2 { continue }
                let pg = c.linear(px - pw, 0, px + pw, 0).stop(0, css("#a9b3c4")).stop(0.5, css("#d7dde8")).stop(1, css("#8e99ac")); c.fillGrad(pg); c.fillRect(px - pw / 2, top, pw, bot - top)
            }
            // 역 이름판(기둥 사이 가운데: 세계 좌표 0.25W + W*j)
            let nm = stationNameForSign(z)
            if !nm.isEmpty {
                for j in -2...3 {
                    let cx = W * (0.25 + 0.5 * Double(j) * 2) + sh
                    if cx + 40 < x0 || cx - 40 > x1 { continue }
                    c.fillStyle("#15213a"); rr(c, cx - 30, z.winT + 2, 60, 17, 3); c.fill(); c.fillStyle("#ffffff"); c.font(10); c.fillTextC(nm, cx + 5, z.winT + 10.5)
                    let lc = SceneArt.lineColor(z.T.line); c.fillStyle(lc); c.beginPath(); c.arc(cx - 21, z.winT + 10.5, 5.6, 0, PI2); c.fill(); c.fillStyle("#fff"); c.font(7); c.fillTextC(z.T.line, cx - 21, z.winT + 10.2)
                }
            }
            // 승강장 바닥 + 안전선
            let pf = c.linear(0, top + ty, 0, bot).stop(0, css("#a7b0c0")).stop(1, css("#8892a4")); c.fillGrad(pf); c.fillRect(x0, top + ty, x1 - x0, bot - top - ty)
            c.fillStyle("#f2c94c"); c.fillRect(x0, bot - 5, x1 - x0, 2.2)
            // 기다리는 사람 그림자(작은 실루엣, 세계 좌표 고정)
            for j in 0..<12 {
                let hh = hsh(z.seed, j + 5); if hh % 3 == 0 { continue }
                let px = W * (-0.9 + Double(j) * 0.30) + sh + Double(hh % 20) - 10
                if px < x0 - 8 || px > x1 + 8 { continue }
                let fy = z.platFeet - 2 - Double((hh >> 5) % 6)
                let nearDoor = abs(px - z.doorX[0]) < z.doorW * 0.5 + 6 || abs(px - z.doorX[1]) < z.doorW * 0.5 + 6
                if nearDoor && z.stop { continue }      // 문 앞은 비워 둔다(타고 내리는 자리)
                let col = hh % 2 == 0 ? css("#59647a") : css("#7a6c86"); c.fillStyle(col)
                c.beginPath(); c.arc(px, fy - 20, 3.2, 0, PI2); c.fill(); rr(c, px - 4, fy - 17, 8, 15, 3); c.fill()
            }
            c.restore()
        }
    }
    /// 창밖 승강장 간판의 역 이름. 서 있으면 그 역 · 달리는 중엔 지금 창밖으로 지나가는 승강장의 역 — 방금 떠난 역(shift ≥ 0)이면 전 역, 곧 닿을 역(shift < 0)이면 다음 역.
    static func stationNameForSign(_ z: St) -> String {
        let k = z.stop ? z.k : (z.shift >= 0 ? z.k : z.toK); if k < 0 || k >= z.T.names.count { return "" }
        return z.T.names[k]
    }
    /// 곧 닿는다(이번 역 안내로 바꾸는 시점): 달리는 중이고 도착까지 남은 시간이 이 안이면
    static let ARRIVING_SEC = 10.0
    static func arriving(_ z: St) -> Bool { !z.stop && z.toK >= 0 && z.rem <= ARRIVING_SEC }

    static func drawDoor(_ s: SceneCore, _ z: St, _ c: SceneCv, _ r: [Double], _ open: Double, _ lineCol: ARGB) {
        let lw = r[2] / 2, vis = lw * (1 - open * 0.9)
        for side in 0..<2 {
            let x = side == 0 ? r[0] : r[0] + r[2] - vis
            c.fillStyle("#c8cfdb"); c.fillRect(x, r[1], vis, r[3])
            c.fillStyle("rgba(160,200,235,.30)"); c.fillRect(x + 2, r[1] + 3, max(0, vis - 4), r[3] * 0.56)
            c.fillStyle("rgba(0,0,0,.14)"); c.fillRect(x, r[1] + r[3] * 0.62, vis, 1.4)
            c.strokeStyle("#8f99ab"); c.lineWidth(1); c.beginPath(); c.rect(x + 0.5, r[1] + 0.5, max(0, vis - 1), r[3] - 1); c.stroke()
        }
        // 문 위 표시등: 열리고 닫히는 동안 깜박인다
        let cx = r[0] + r[2] / 2; let blink = z.stop && ((z.e < 1.6) || (z.dwell < 1e8 && z.e > z.dwell - 3.4)) && (Int(floor(s.t * 4)) % 2 == 0)
        c.fillStyle(blink ? "#ff4a3d" : "#5a2220"); c.beginPath(); c.arc(cx, r[1] - 2.4, 2.1, 0, PI2); c.fill()
    }
    static func drawBench(_ s: SceneCore, _ z: St, _ c: SceneCv, _ W: Double, _ lineCol: ARGB) {
        let sc = mix(lineCol, css("#8a8f9c"), 0.62), dk = shade(sc, -0.22)
        let dw = z.doorW, x1 = z.doorX[0] - dw / 2 - 9, x2 = z.doorX[0] + dw / 2 + 9, x3 = z.doorX[1] - dw / 2 - 9, x4 = z.doorX[1] + dw / 2 + 9
        let seg = [[8, x1], [x2, x3], [x4, W - 8]]
        for sgm in seg {
            let a = sgm[0], b = sgm[1]; if b - a < 12 { continue }
            c.fillStyle(dk); rr(c, a, z.benchBack, b - a, z.seatY - z.benchBack, 4); c.fill()
            c.fillStyle(sc); rr(c, a + 2, z.benchBack + 2, b - a - 4, (z.seatY - z.benchBack) * 0.55, 3); c.fill()
            c.fillStyle(dk); rr(c, a - 1, z.seatY, b - a + 2, (z.floorLine - z.seatY) * 0.42, 3); c.fill()
            c.fillStyle(sc); rr(c, a, z.seatY, b - a, (z.floorLine - z.seatY) * 0.26, 3); c.fill()
        }
    }
    static func drawLed(_ s: SceneCore, _ z: St, _ c: SceneCv, _ W: Double, _ lineCol: ARGB) {
        var nm = ""
        let here = z.stop || arriving(z); let k = z.stop ? z.k : z.toK       // 서 있거나 곧 닿으면 '이번 역' · 출발해서 달리는 동안은 '다음 역'
        if k >= 0 && k < z.T.names.count { nm = z.T.names[k] }
        let lab = here ? z.T.lbHere : z.T.lbNext
        if nm.isEmpty { return }
        let txt = lab + "  " + nm
        let w = max(70, W * 0.5), x = W * 0.5 - w / 2, y = 4.4, hgt = 11.5
        c.fillStyle("#0c0f16"); rr(c, x, y, w, hgt, 3); c.fill()
        c.fillStyle(lineCol); c.beginPath(); c.arc(x + 8, y + hgt / 2, 4.4, 0, PI2); c.fill(); c.fillStyle("#fff"); c.font(6.4); c.fillTextC(z.T.line, x + 8, y + hgt / 2 - 0.2)
        c.fillStyle("#ffb347"); c.font(7.6); c.fillTextC(txt, x + w / 2 + 6, y + hgt / 2 - 0.1)
    }

    // ═══ 친구 그리기 (SceneCore.drawActor 와 같은 시트·칸 규칙) ═══
    static func drawPax(_ s: SceneCore, _ c: SceneCv, _ p: Pax) {
        let id = SceneModel.ORDER[p.ci]; guard let D = SceneModel.D3[id] else { return }
        guard var sheet = s.host.sheet(id) else { return }
        let psh: SceneImg? = (p.sit || p.nap) ? s.host.sheet(id + "_pose") : nil
        let bodyH = (D.base - 8) / 256 * D.cell + D.lift * 0.6, kk = min(0.8, TH / bodyH), zz = p.z, sct = kk * zz, sc = D.cell / 256 * sct
        let idx: Int
        if let ps = psh { sheet = ps; idx = p.nap ? 1 : 0 }
        else if p.walking { idx = jmod(Int(floor(p.walkT * Double(D.fps) * 0.9)), 16) }
        else { idx = SceneModel.stand(id) }
        let bob = p.walking ? sin(p.walkT * 9) * 0.5 * zz : sin(s.t * 1.8 + Double(p.ci)) * 0.5 * zz
        let lift = D.lift * zz * zz
        let sx = Double(idx % 4) * 256, sy = Double(idx / 4) * 256, dx = -D.ox * sc, dy = -D.base * sc - lift + bob
        c.save(); c.globalAlpha(clamp(p.alpha, 0, 1))
        c.fillStyle(rgba(0, 0, 0, 0.28)); c.beginPath(); c.ellipse(p.x, p.y + 1, D.cell * sct * 0.2, 2.8 * zz, 0, 0, PI2); c.fill()
        c.translate(p.x, p.y); if p.dir < 0 { c.scale(-1, 1) }
        let lean = p.sit ? 0 : clamp(-(s.tr?.acc ?? 0) * 0.04, -0.1, 0.1); if lean != 0 { c.rotate(lean) }
        c.drawImage(sheet, sx, sy, 256, 256, dx, dy, D.cell * sct, D.cell * sct)
        c.restore()
        if p.nap && p.alpha > 0.5 && s.R.next() < s.dtLast * 0.7 { s.ptx("zzz", p.x + 8, p.y - 38 * zz, 1, po().a(-1.2, -0.9).s(5, 9).g(-8).l(0.9, 1.4).jx(2)) }
    }
}
