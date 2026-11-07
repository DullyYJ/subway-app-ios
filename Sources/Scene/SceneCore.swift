import Foundation

/// 혼잡도 카드의 3D 캐릭터 장면 — 안드로이드 SceneCore.java 를 1:1 로 옮긴 것(웹 _CS 와 같은 식).
/// ★ 원칙: "계산은 엔진이, 그림은 앱이". 어떤 장면(mode)인지·누가 주인공인지·누가 등장하는지·어떤 동작을 어떤 순서로 하는지·
///   놓았을 때 어떤 연출인지는 모두 엔진(/scene)이 준 SceneModel.Res 값이다. 이 코드는 받은 이름대로 몸을 기울이고 소품·반짝이를 그릴 뿐 무엇을 할지 고르지 않는다.
/// 파일 나눔: SceneCore.swift(상태·동작 진행·잡기·떨어뜨리기) · SceneCoreDraw.swift(그리기) · SceneCoreRun.swift(받기·장소이동·갱신·TV·확장 인사).

// ───────────── 바깥 세계와의 접점 ─────────────
protocol SceneRng: AnyObject { func next() -> Double }
extension SU.Seeded: SceneRng {}
final class SysRng: SceneRng { func next() -> Double { Double.random(in: 0..<1) } }

protocol SceneHost: AnyObject {
    func sheet(_ id: String) -> SceneImg?
    func intro() -> SceneImg?
    func ready() -> Bool
    /// 진동 이름: grab, release, land_cotton, land_pose, land_dig, land_flip, land_fly, land_puddle, land_tumble, land_hose, squirt, land, hearts, thud, angry, splash, flap
    func haptic(_ name: String)
    /// 길게 눌러 캐릭터를 잡았다(→ 아래 화면의 손가락 동작을 취소해야 한다)
    func held()
}
/// 자녀가 꾸민 옷 입히기(부모 앱이 붙인다). 기본은 nil — 연동되지 않았거나 입은 것이 없으면 장면은 원래대로 그린다.
protocol SceneWearHook: AnyObject {
    func draw(_ c: SceneCv, _ a: SceneCore.Actor, _ kind: Int, _ idx: Int, _ dx: Double, _ dy: Double, _ sc: Double)
    func nh(_ id: String, _ act: Bool) -> SceneImg?
}

// ───────────── 상수·표 ─────────────
let TH = 44.0                                        // 캐릭터 키(px, 가장 가까운 줄 기준)
let LONGPRESS = 0.38                                 // 꾹 누름(초)
let SLOP_DP = 10.0                                   // 이만큼 움직이면 길게 누르기 취소(= 화면 스크롤)
let BUS_COLORS = ["#2f6fd6", "#2fa862", "#d6453a", "#e3a21a"]
let CAR_COLORS = ["#e0556c", "#f0b83a", "#5aa9e6", "#8e7bd6", "#e9eef5", "#4cbf9a"]
let BUS_NOS = ["146", "3300", "9401", "N61", "472", "6411"]
let BOX_W = 1.3, BOX_H = 0.38                        // 러블 상자(폭·높이, 캐릭터 키 대비)
let TV_OFF = 0.30, TV_HOLD = 0.08, TV_ON = 0.42
let TV_T = TV_OFF + TV_HOLD + TV_ON
let XF_T = 1.1, PAN_MIN = 2.4, PAN_MAX = 4.6
let SL_N = 16

func lerp(_ a: Double, _ b: Double, _ u: Double) -> Double { a + (b - a) * u }
func zs(_ z: Double) -> Double { 0.74 + 0.34 * clamp(z, -0.2, 1.1) }
func easeIO(_ u0: Double) -> Double { let u = clamp(u0, 0, 1); return u < 0.5 ? 2 * u * u : 1 - pow(-2 * u + 2, 2) / 2 }
func eIn(_ x0: Double) -> Double { let x = clamp(x0, 0, 1); return x * x }
func eOut(_ x0: Double) -> Double { let x = clamp(x0, 0, 1); let u = 1 - x; return 1 - u * u * u }
/// 자바 Math.round(반올림, .5 는 위로)
func jr(_ x: Double) -> Double { floor(x + 0.5) }
func jmod(_ a: Int, _ n: Int) -> Int { ((a % n) + n) % n }

/// 입자 옵션
final class PO {
    var fa0 = Double.nan, fa1 = 0.0, fs0 = 10.0, fs1 = 26.0, fjx = 3.0, fjy = 0.0, fdelay = 0.0, fl0 = 0.5, fl1 = 0.9, fg = Double.nan, fr = 0.0
    @discardableResult func a(_ a0: Double, _ a1: Double) -> PO { fa0 = a0; fa1 = a1; return self }
    @discardableResult func s(_ s0: Double, _ s1: Double) -> PO { fs0 = s0; fs1 = s1; return self }
    @discardableResult func l(_ l0: Double, _ l1: Double) -> PO { fl0 = l0; fl1 = l1; return self }
    @discardableResult func g(_ v: Double) -> PO { fg = v; return self }
    @discardableResult func jx(_ v: Double) -> PO { fjx = v; return self }
    @discardableResult func jy(_ v: Double) -> PO { fjy = v; return self }
    @discardableResult func r(_ v: Double) -> PO { fr = v; return self }
    @discardableResult func delay(_ v: Double) -> PO { fdelay = v; return self }
}
func po() -> PO { PO() }

final class SceneCore: ScenePlatformHost {
    // ═══ 그릇들 ═══
    final class Prop { var k = ""; var abs = false, front = false; var x = 0.0, y = 0.0, dx = 0.0, dy = 0.0, r = 0.0, s = 0.0 }
    final class Stk { var k = ""; var t0 = 0.0, dur = 0.0 }
    final class Ball { var x = 0.0, y = 0.0, vx = 0.0, vy = 0.0 }
    /// 죽순이가 떨어뜨린 대나무(공중에서 구르다 땅에 눕는다 — 주인이 찾으러 와서 집어 든다)
    final class Bam { var x = 0.0, y = 0.0, z = 0.0, vx = 0.0, vy = 0.0, rot = 0.0, vr = 0.0, t0 = 0.0; var landed = false, taken = false; var bounces = 0; var owner: Actor? }
    final class Feather { var x = 0.0, y = 0.0, vy = 0.0, ph = 0.0; var land = false, got = false }
    final class Chip { var dx = 0.0, dy = 0.0, r = 0.0; var col = 0 }
    final class Gfx {
        var k = ""; var x = 0.0, z = 0.0, life = 0.0, t0 = 0.0, r = 0.0, bump = 0.0; var front = false, snow = false; var cs: [Chip]?; var own: Actor?      // own: 거울을 보는 주인(얼굴이 거울에 비친다)
    }
    final class Pt { var type = "", txt = ""; var x = 0.0, y = 0.0, vx = 0.0, vy = 0.0, age = 0.0, life = 0.0, g = 90.0, r = 0.0, rot = 0.0; var col = 0; var hasCol = false }
    final class Traffic { var lane = 0; var bus = false; var L = 0.0, x = 0.0, v = 0.0, rot = 0.0; var dir = 1; var color = 0; var no = "" }
    final class Ripple { var x = 0.0, y = 0.0, t0 = 0.0 }
    final class Seq { var ph = 0.0, t0 = 0.0, busX = 0.0, busV = 0.0, door = 0.0, L = 0.0, t1 = 0.0, t2 = 0.0, t3 = 0.0; var busOn = false; var color = 0 }
    final class Ride { var scroll = 0.0, rot = 0.0, speed = 0.0, vPrev = 0.0, acc = 0.0, cyc = 0.0, bump = 0.0, nextBump = 0.0, bellT = -9.0; var stopped = false }
    final class Drag { var a: Actor; var fx = 0.0, fy = 0.0, px = 0.0, py = 0.0; init(_ a: Actor) { self.a = a } }
    final class Pend { var a: Actor; var t0 = 0.0, sxdp = 0.0, sydp = 0.0; init(_ a: Actor) { self.a = a } }
    typealias Arrive = (Actor) -> Void

    /// 동작 한 번의 상태(웹의 a.act 객체)
    final class AS {
        var n = ""; var t0 = 0.0, dur = 0.0; var d0 = 0
        var b: Ball?; var f: Feather?; var g: Gfx?, b1: Gfx?, b2: Gfx?, m: Gfx?; var tgt: Actor?; var tg: [Actor]?
        var mx = 0.0, hx = 0.0, tx = 0.0, px = 0.0, x0 = 0.0, x1 = Double.nan, bx = 0.0, s0 = Double.nan, s1 = Double.nan, fx = 0.0, lx = 0.0, alt0 = 0.0, z0 = 0.0, tz = 0.0
        var dir0 = 0; var snow = false
        var px1 = 0.0, pz1 = 0.0, pal1 = 0.0, pang1 = 0.0; var fr1 = false      // s354 독슐이 안고 가는 친구의 자리(독슐 동작이 정하고 친구 동작이 따라 한다)
        var ev: [String: Double] = [:]
        var on: [String: Bool] = [:]
    }
    typealias Init = (Actor, Double, AS) -> Void
    typealias Step = (Actor, Double, Double, AS) -> Void
    typealias End = (Actor, AS) -> Void
    final class Act { var dur = 0.0; var ini: Init?; var step: Step?; var end: End? }

    final class Actor {
        var id = "", kind = ""; var D: SceneModel.Spec; var k = 1.0, w = 0.0, x = 0.0, z = 0.0; var dir = 1; var st = "walk"
        var tx = 0.0, tz = 0.0, t0 = 0.0, until = 0.0, fr = 0.0, y = 0.0, ang = 0.0, sq = 0.0, hop = 0.0; var vis = true, intro = false; var ii = 0
        var alt = 0.0, life = 0.0, born = 0.0
        var leaving = false, hero = false, nograb = false, chase = false, held = false, pinned = false, dead = false, hidden = false, umb = false, lastBounce = false
        var ph = 0.0, bubUntil = 0.0, sx = 1.0, sy = 1.0, ox = 0.0, pvx = 0.0, pvy = 0.0, cut = Double.nan, spd = 0.0; var pose = -1     // pose: 자세 시트(<id>_pose) 칸 0 앉기·1 잠·2 웃음·3 덜덜·4 헥헥·5 찡그림, -1 이면 걷기 시트
        var bub = ""; var pr: [Prop]?; var stk: Stk?; var ai = 0; var act: AS?; var onArrive: Arrive?
        var lastCyc: Int?; var dirT = 0.0; var afterEmerge: String?; var prevSt: String?; var landK = ""
        var pinX = Double.nan, altSave = 0.0, altStart = 0.0, fy0 = 0.0, vy = 0.0, airT = 0.0, lookUntil = 0.0, boost = 0.0
        var feetScale = false; var heart = 0.0; var fearK = ""     // s354: feetScale — 늘어나는 몸이 발을 기준으로 커진다 · heart — 몸이 하트로 바뀐 정도(0~1) · fearK — 놀란 까닭
        var sl = 0; var slU = 0.0, fade = 1.0     // s415 뽀푸 별빛: sl 0 없음 · 1 감싸는 별빛(낙하) · 2 흩어짐 · 3 다시 모임 · 4 여운 / slU 진행 / fade 몸 투명도
        var cell = -1; var sk: String?; var chain: String?     // cell: 전용 동작 시트(<id>_act 4×4) 칸 · sk: 걷기 시트 대신 쓸 시트 열쇠 · chain: 지금 동작이 끝나면 이어서 할 동작
        init(_ d: SceneModel.Spec) { D = d }
    }
    final class P { var rain: [[Double]] = [], snow: [[Double]] = [], clouds: [[Double]] = [], stars: [[Double]] = [], birds: [[Double]] = [], wind: [[Double]] = [] }

    /// 자녀가 꾸민 옷(부모 앱이 붙인다)
    static var wearHook: SceneWearHook?
    /// 키즈 앱 등: true 이면 친구들이 스스로 놀 때의 진동을 모두 끈다 — 손으로 잡고 놓는 진동은 그대로.
    static var quietAuto = false

    // ═══ s354: 떨어뜨리기 연출 도구(화면 흔들림 · 러블의 어둠 · 노란 눈빛) ═══
    var shkEnd = -1.0, shkDur = 1.0, shkAmp = 0.0
    /// 땅이 흔들린다(뽀푸 착지): amp(장면 px)로 시작해 dur 초 동안 잦아든다.
    func shake(_ amp: Double, _ dur: Double) { shkAmp = max(shkAmp * max(0, (shkEnd - t) / max(0.01, shkDur)), amp); shkDur = dur; shkEnd = t + dur }
    var flEnd = -1.0, flDur = 1.0, flAmt = 0.0; var flR = 255, flG = 255, flB = 255
    /// 번쩍(착지 충격): 색 · 세기 · 길이.
    func flash(_ r: Int, _ g: Int, _ b: Int, _ amt: Double, _ dur: Double) { flR = r; flG = g; flB = b; flAmt = amt; flDur = dur; flEnd = t + dur }
    var dkAmt = 0.0, dkX = 0.0, dkY = 0.0, dkT = -9.0, eyeAmt = 0.0, eyeX1 = 0.0, eyeY1 = 0.0, eyeX2 = 0.0, eyeY2 = 0.0, eyeR = 0.0, eyeDir = 0.0
    /// 주변이 어두워진다(가운데 (x,y) 만 밝게). 매 프레임 불러야 유지되고, 부르지 않으면 곧 사라진다.
    func dim(_ amt: Double, _ x: Double, _ y: Double) { dkAmt = amt; dkX = x; dkY = y; dkT = t }
    /// 노란 눈빛(두 눈 위치 · 크기 r · 세기 amt · 보는 쪽 dir).
    func eyes(_ amt: Double, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, _ r: Double, _ dir: Int) { eyeAmt = amt; eyeX1 = x1; eyeY1 = y1; eyeX2 = x2; eyeY2 = y2; eyeR = r; eyeDir = Double(dir); dkT = t }

    // ═══ 상태 ═══
    let host: SceneHost; let factory: SceneCv; let R: SceneRng
    var laid = false, running = false; var PW = 0.0, PH = 0.0, dens = 1.0, k = 1.0, W = 0.0, H = 0.0, dpr = 1.0; var dark = true, reduce = false
    /// s340: 카드 확장 인사 — 카드가 늘어난 만큼(디자인 좌표)의 바닥. 하늘 · 먼 도시 · 길은 그대로 두고 인도(길 아래)만 아래로 늘려 그린다. 0 이면 평소.
    var stretch = 0.0
    func setStretch(_ d: Double) { stretch = d < 0.5 ? 0 : d }
    var g = SceneArt.Geom(); var t = 0.0, fade = 0.0; var frames = 0
    /// TV 전원 전환: 장면이 바뀌는 순간부터 지난 초(없으면 -1).
    var tv = -1.0
    var mode = ""; var res = SceneModel.Res(); var hasRes = false; var LAST: SceneModel.Res?; var L = SceneArt.Pal(); var bg: SceneArt.Bg!; var prev: SceneLayer?
    var actors: [Actor] = []; var traffic: [Traffic] = []; var pt: [Pt] = []; var gfx: [Gfx] = []; var ripples: [Ripple] = []; var bams: [Bam] = []
    var hero: Actor?; var seq: Seq?; var ride: Ride?; var nextCar = 0.0, spawnAt = 0.0, waitNext = 0.0, bellAt = 0.0; var castI = 0
    var stopX = 0.0, entX = 0.0; var inside = false; var sta = "", vk = ""; var venue = "bus"; var baseDir = -1; var busColor = 0; var busNo: String?; var bgKey = ""
    var tr: SceneTrain.St?
    var dtLast = 0.0; var DRAG: Drag?; var PEND: Pend?; var rideBell = false
    var wxP = P()
    // 장소가 바뀔 때(s246): 캐릭터가 모두 한쪽으로 걸어 나가는 동안 옛 배경은 반대쪽으로 밀려 나가고 새 배경이 이어 붙어 들어온다. 어느 쪽인지(look.pdir)는 엔진이 정했다.
    var oldTraffic: [Traffic] = []; var pan = -1.0, panDur = 2.6; var panDir = 1; var panBg: SceneArt.Bg?; var panL: SceneArt.Pal?; var panWx: P?; var bgTail = ""
    // 날씨·시간대·계절만 바뀔 때는 옛 장면 한 장이 새 장면 위에서 서서히 사라진다
    var xf = -1.0
    var ACT: [String: Act] = [:]
    var error: String?
    var hello: HelloRun?
    var hotUntil = 0.0
    var evg: [String: Double] = [:]

    init(host: SceneHost, factory: SceneCv, rng: SceneRng) {
        self.host = host; self.factory = factory; self.R = rng
        SceneActs.register(self)
    }

    // ═══ 작은 도구 ═══
    func rnd(_ a: Double, _ b: Double) -> Double { a + R.next() * (b - a) }
    func rnd() -> Double { R.next() }
    func pickOf<T>(_ a: [T]) -> T { a[Int(floor(R.next() * Double(a.count)))] }
    func zy(_ z: Double) -> Double { g.nearTop + 4 + z * (g.floor + stretch - g.nearTop - 4) }       // 깊이(0~1) → 화면 y (원근: 멀수록 위·작게)
    func HH(_ a: Actor) -> Double { TH * zs(a.z) * (a.hero ? 1.12 : 1) }
    func liftOf(_ a: Actor) -> Double { (a.D.lift + a.alt) * zs(a.z) * (a.kind == "eagle" ? 1 : zs(a.z)) }
    func feetY(_ a: Actor) -> Double { zy(a.z) }
    func standF(_ a: Actor) { a.fr = Double(SceneModel.stand(a.id)) }
    func pr(_ a: Actor, _ p: Prop) { if a.pr == nil { a.pr = [] }; a.pr!.append(p) }
    func prop(_ k: String) -> Prop { let p = Prop(); p.k = k; return p }
    func prop(_ k: String, _ dx: Double, _ dy: Double) -> Prop { let p = prop(k); p.dx = dx; p.dy = dy; p.front = true; return p }
    func propAbs(_ k: String, _ x: Double, _ y: Double) -> Prop { let p = prop(k); p.abs = true; p.x = x; p.y = y; p.front = true; return p }
    func say(_ a: Actor, _ txt: String, _ sec: Double) { a.bub = txt; a.bubUntil = t + sec }
    func stk(_ a: Actor, _ k: String, _ sec: Double) { let s = Stk(); s.k = k; s.t0 = t; s.dur = sec; a.stk = s }
    func every(_ A: AS, _ key: String, _ gap: Double) -> Bool { if let v = A.ev[key], t - v < gap { return false }; A.ev[key] = t; return true }
    func once(_ A: AS, _ key: String) -> Bool { if A.on[key] != nil { return false }; A.on[key] = true; return true }
    func haptic(_ n: String) { if SceneCore.quietAuto { return }; tHaptic(n) }
    func tHaptic(_ n: String) { host.haptic(n) }

    // 입자
    func ptx(_ type: String, _ x: Double, _ y: Double, _ n: Int, _ o: PO) {
        for _ in 0..<n {
            let ang = !o.fa0.isNaN ? rnd(o.fa0, o.fa1) : rnd(-PI * 0.85, -PI * 0.15), sp = rnd(o.fs0, o.fs1)
            let p = Pt(); p.type = type; p.x = x + rnd(-o.fjx, o.fjx); p.y = y + rnd(-o.fjy, o.fjy); p.vx = cos(ang) * sp; p.vy = sin(ang) * sp
            p.age = -o.fdelay; p.life = rnd(o.fl0, o.fl1); p.g = !o.fg.isNaN ? o.fg : 90; p.r = o.fr; p.rot = rnd(0, 6.28)
            pt.append(p)
        }
        if pt.count > 120 { pt.removeFirst(pt.count - 120) }
    }
    func addPart(_ type: String, _ x: Double, _ y: Double, _ n: Int) {
        for _ in 0..<n {
            let sp2 = type == "splash"; let ang = sp2 ? rnd(-PI * 0.9, -PI * 0.1) : rnd(-PI * 0.85, -PI * 0.15), sp = sp2 ? rnd(16, 38) : rnd(10, 26)
            let p = Pt(); p.type = type; p.x = x + rnd(-3, 3); p.y = y; p.vx = cos(ang) * sp; p.vy = sin(ang) * sp; p.age = 0; p.life = rnd(0.4, 0.8)
            pt.append(p)
        }
        if pt.count > 50 { pt.removeFirst(pt.count - 50) }
    }
    func landFx(_ a: Actor) {
        let wk = L.wk; let y = zy(a.z); if L.night && wk == "clear" { return }
        addPart(wk == "rain" ? "splash" : wk == "snow" ? "puff" : "dust", a.x, y - 1, wk == "rain" ? 5 : 3)
    }
    @discardableResult func addGfx(_ o: Gfx) -> Gfx { o.t0 = t; _ = R.next() /* 웹의 o.sd = Math.random() — 난수열을 웹과 같게 맞춘다 */; gfx.append(o); if gfx.count > 12 { gfx.removeFirst() }; return o }
    func mkGfx(_ k: String, _ x: Double, _ z: Double, _ life: Double) -> Gfx { let o = Gfx(); o.k = k; o.x = x; o.z = z; o.life = life; return o }

    // ═══ 이동 도구 ═══
    func inRange(_ a: Actor) -> [Double] {
        let lo = a.w * 0.55, hi = W - a.w * 0.55
        if a.hero && mode == "wait" {
            if a.pinned && !a.pinX.isNaN { return [clamp(a.pinX - 34, lo, hi), clamp(a.pinX + 34, lo, hi)] }
            if inside { return [clamp(W * 0.22, lo, hi), clamp(W * 0.72, lo, hi)] }
            return venue == "sub" ? [entX - 40, entX + 30] : [W * 0.36, W * 0.62]
        }
        return [lo, hi]
    }
    func moveX(_ a: Actor, _ tx: Double, _ v: Double, _ dt: Double) -> Bool {
        let dx = tx - a.x; if abs(dx) < 2 { return true }
        a.dir = dx > 0 ? 1 : -1; a.x += Double(a.dir) * min(abs(dx), v * dt); a.fr += dt * Double(a.D.fps) * (a.kind == "eagle" ? 0.5 : 1); return false
    }
    func aheadX(_ a: Actor, _ d: Double) -> Double {
        let r = inRange(a); var x = a.x + Double(a.dir) * d
        if x < r[0] || x > r[1] { a.dir = -a.dir; x = a.x + Double(a.dir) * d }
        return clamp(x, r[0], r[1])
    }
    func behindAng(_ a: Actor) -> [Double] { let base = a.dir > 0 ? -PI * 0.68 : -PI * 0.32; return [base - 0.3, base + 0.3] }

    func mkActor(_ id: String, _ x: Double, _ z: Double, _ dir: Int) -> Actor {
        let D = SceneModel.D3[id]!; let a = Actor(D)
        let bodyH = (D.base - 8) / 256 * D.cell + D.lift * 0.6, kk = min(0.8, TH / bodyH)
        a.id = id; a.kind = SceneModel.kind(id); a.k = kk; a.w = D.cell * kk; a.x = x; a.z = z; a.dir = dir == 0 ? 1 : dir; a.tx = x; a.tz = z
        a.fr = R.next() * 16; a.alt = a.kind == "eagle" ? rnd(14, 24) : 0; a.life = rnd(15, 26); a.born = running ? t : 0; a.ph = R.next() * 6
        a.spd = (Double(D.fps) / 16) * D.cell * kk * (id == "lovel" ? 0.9 : 1) * 0.85
        return a
    }
    func pickTarget(_ a: Actor, _ friends: [Actor]?) -> (Double, Double) {
        var o: Actor? = nil
        if let fr = friends, !fr.isEmpty, R.next() < 0.42 { o = fr[Int(floor(R.next() * Double(fr.count)))] }
        if let o = o, o !== a { a.chase = true; return (clamp(o.x + rnd(-0.8, 0.8) * a.w, a.w * 0.5, W - a.w * 0.5), clamp(o.z + rnd(-0.12, 0.12), 0, 1)) }
        a.chase = false; return (rnd(a.w * 0.55, W - a.w * 0.55), rnd(0.05, 0.98))
    }

    // ═══ 이름대로 시작 · 끝나면 다음(동작 대본은 엔진 traits) ═══
    func nextName(_ a: Actor) -> String {
        let T = hasRes ? res.traits[a.id] : nil
        if let T = T, !T.acts.isEmpty { let n = T.acts[a.ai % T.acts.count]; a.ai += 1; return n }
        return "walk"
    }
    func nextAct(_ a: Actor) { startAct(a, nextName(a)) }
    func startAct(_ a: Actor, _ name: String) {
        if name == "hop" { a.st = "hop"; a.t0 = t; a.until = t + rnd(1.1, 2); a.lastCyc = nil; return }
        if name == "spin" { a.st = "spin"; a.t0 = t; a.until = t + rnd(1, 1.7); a.dirT = t; return }
        if name == "rest" { a.st = "rest"; a.t0 = t; a.until = t + rnd(1.2, 2.6) * (L.night ? 1.6 : 1); if L.night { a.bub = "z"; a.bubUntil = a.until }; return }
        let d = ACT[name]
        if name == "walk" || d == nil {
            var tx: Double, tz: Double
            if a.hero && mode == "wait" {
                let r = inRange(a); tx = clamp(a.x + rnd(-14, 14), r[0], r[1]); tz = a.pinned ? clamp(a.z + rnd(-0.04, 0.04), -0.1, 1) : clamp(a.z + rnd(-0.06, 0.06), 0.55, 0.85)
                a.onArrive = { [unowned self] o in o.st = "stand"; o.dir = self.baseDir; self.waitNext = self.t + self.rnd(1.2, 2.4) }
            } else {
                var fr: [Actor] = []; for o in actors where o !== a && !o.leaving && o.vis { fr.append(o) }
                let tg = pickTarget(a, fr); tx = tg.0; tz = tg.1
            }
            a.tx = tx; a.tz = tz; a.st = "walk"; return
        }
        a.st = "act"; let A = AS(); A.n = name; A.t0 = t; A.dur = d!.dur; A.d0 = a.dir; a.act = A; d!.ini?(a, t, A)
    }
    func endAct(_ a: Actor) {
        a.pr = nil; a.cut = Double.nan; a.sx = 1; a.sy = 1; a.ox = 0; a.pvx = 0; a.pvy = 0; a.ang = 0; a.act = nil; a.stk = nil; a.feetScale = false; a.heart = 0; a.sl = 0; a.fade = 1; if a.pinned { a.pinX = a.x }
        if let h = hello, !h.free.contains(a.id) { helloSettle(a); return }                  // s340: 카드 확장 인사 중에는 어떤 동작이든 끝나면 자리에 서서 인사를 기다린다
        if a.hero && (mode == "wait" || mode == "alight") { a.st = "stand"; waitNext = t + rnd(1.0, 2.2); if mode == "wait" && a.lookUntil == 0 { a.dir = baseDir } }
        else { nextAct(a) }
    }
    func actStep(_ a: Actor, _ dt: Double) {
        guard let A = a.act, let d = ACT[A.n] else { endAct(a); return }
        let u = A.dur > 0 ? (t - A.t0) / A.dur : 1
        if u >= 1 {
            d.end?(a, A)
            if let cn = a.chain, a.st == "act" { a.chain = nil; startAct(a, cn); return }          // 착지 연출 → 이어지는 동작(죽순 찾기·물대포 쏘기)
            if a.st == "act" { endAct(a) }; return
        }
        d.step?(a, u, dt, A)
        if a.hero && mode == "wait" { let r = inRange(a); a.x = clamp(a.x, r[0], r[1]) }
    }
    func stepActor(_ a: Actor, _ dt: Double) {
        let D = a.D; let u = a.until > a.t0 ? (t - a.t0) / (a.until - a.t0) : 0; let st = a.st
        if !a.bub.isEmpty && t > a.bubUntil && st != "rest" { a.bub = "" }
        if st == "fall" { fallStep(a, dt); return }
        a.ang = 0; a.vis = true; a.y = 0; a.sq = 0; a.intro = false; a.sx = 1; a.sy = 1; a.ox = 0; a.pvx = 0; a.pvy = 0; a.cut = Double.nan; a.pr = nil; a.nograb = false; a.pose = -1; a.cell = -1; a.sk = nil; a.feetScale = false; a.heart = 0; a.sl = 0; a.fade = 1
        if a.kind == "eagle" && !a.hero { a.alt = 16 + sin(t * 1.7 + a.x * 0.03) * 5 }
        if st == "emerge" {
            a.intro = true; a.ii = Int(min(Double(D.intro - 1), floor(u * Double(D.intro))))
            if t >= a.until { a.intro = false; if let af = a.afterEmerge { a.afterEmerge = nil; startAct(a, af) } else { endAct(a) } }
            return
        }
        if st == "pan" {                                    // 장소 이동 중: 땅이 흐르는 만큼 제자리에서 걸으며 서서히 모여 선다
            a.dir = panDir; a.fr += dt * Double(D.fps) * (a.kind == "eagle" ? 0.5 : 1) * max(1, a.boost)
            let dx2 = a.tx - a.x; a.x += clamp(dx2, -1, 1) * min(abs(dx2), 14 * dt)
        } else if st == "walk" {
            let dx = a.tx - a.x, dz = a.tz - a.z
            if abs(dx) < 3 && abs(dz) < 0.03 {
                if a.leaving { a.dead = true; return }
                if let f = a.onArrive { a.onArrive = nil; f(a); return }
                endAct(a)
            } else {
                if abs(dx) >= 3 { a.dir = dx > 0 ? 1 : -1; a.x += Double(a.dir) * min(abs(dx), a.spd * (a.leaving ? 1.25 : 1) * (a.boost > 1 ? a.boost : 1) * dt) }
                a.z += (dz > 0 ? 1 : dz < 0 ? -1 : 0) * min(abs(dz), 0.28 * dt)
                a.fr += dt * Double(D.fps) * (a.kind == "eagle" ? 0.5 : 1)
            }
        } else if st == "hop" {
            a.fr += dt * Double(D.fps) * 0.7; let ph = abs(sin((t - a.t0) * 7.2)); a.y = -ph * 9 * zs(a.z) * (a.kind == "tad" ? 1.2 : 1)
            let cyc = Int(floor((t - a.t0) * 7.2 / PI))
            if a.lastCyc == nil || cyc != a.lastCyc! { if a.lastCyc != nil && ph < 0.3 { landFx(a) }; a.lastCyc = cyc }
            if t >= a.until { a.lastCyc = nil; endAct(a) }
        } else if st == "spin" {
            a.fr += dt * Double(D.fps) * 0.4; if t - a.dirT > 0.4 { a.dir = -a.dir; a.dirT = t }; if t >= a.until { endAct(a) }
        } else if st == "rest" {
            a.fr = Double(SceneModel.stand(a.id)); a.y = -abs(sin((t - a.t0) * 2.2)) * 0.8; a.pose = L.night ? 1 : 0; if a.kind == "eagle" { a.alt = 0 }   // 밤엔 눈 감고 자고, 낮엔 앉아 쉰다
            if a.pose == 1 { a.y = sin((t - a.t0) * 1.6) * 0.5 }; if t >= a.until { a.bub = ""; endAct(a) }
        } else if st == "act" {
            actStep(a, dt)
        } else if st == "stand" {                // 서 있기(대기·하차 장면의 대표 캐릭터)
            a.fr = Double(SceneModel.stand(a.id)); a.y = -abs(sin(t * 2.0 + a.ph)) * 0.9
        }
        if a.pose >= 0 && a.kind == "eagle" && a.pose != 2 && a.pose != 4 { a.alt = 0 }        // 독수리는 앉기·잠·덜덜·찡그림 자세에선 땅(횃대)에 내려앉는다
        a.z = clamp(a.z, -0.2, 1.05); a.x = clamp(a.x, -a.w * 1.2, W + a.w * 1.2)
        if a.kind == "tad" { a.y -= 2 + sin(t * 2.4 + a.x) * 1.6 }
    }

    // ═══ 찻길 차량 ═══
    func laneGy(_ l: Int) -> Double { l == 0 ? g.roadY0 + (g.nearTop - g.roadY0) * 0.4 : g.nearTop - 3 }
    func laneL(_ l: Int, _ bus: Bool) -> Double { l == 0 ? (bus ? 66 : 36) : (bus ? 100 : 50) }
    @discardableResult func spawnTraffic() -> Traffic {
        let allowNear = !(mode == "alight" && seq != nil && seq!.busOn)
        let lane = allowNear && R.next() < 0.55 ? 1 : 0; let bus = R.next() < (mode == "wait" ? 0.5 : 0.32)
        let v = Traffic(); v.lane = lane; v.bus = bus; v.L = laneL(lane, bus); v.dir = lane == 1 ? 1 : -1; v.x = v.dir > 0 ? -v.L * 0.6 : W + v.L * 0.6
        v.v = lane == 1 ? rnd(46, 66) : rnd(28, 44); v.color = css(bus ? pickOf(BUS_COLORS) : pickOf(CAR_COLORS)); v.no = pickOf(BUS_NOS)
        traffic.append(v); return v
    }
    /// 찻길이 있는 장소인가(거리만 — 공원·강변·바닷가 등엔 차가 지나가지 않는다). 장소는 엔진이 정한다(look.place).
    func streetPlace() -> Bool { L.place.isEmpty || L.place == "street" }
    func stepTraffic(_ dt: Double) {
        if mode != "ride" && !inside && pan < 0 && streetPlace() && t >= nextCar && traffic.count < 3 {
            let v = spawnTraffic(); nextCar = t + rnd(4.5, 9)
            if mode == "wait" && venue == "bus" && v.bus && v.lane == 1, let h = hero { h.bub = "!"; h.bubUntil = t + 1.3; h.dir = -1; h.lookUntil = t + 1.6 }
        }
        for i in stride(from: traffic.count - 1, through: 0, by: -1) {
            let v2 = traffic[i]; v2.x += Double(v2.dir) * v2.v * dt; v2.rot += Double(v2.dir) * v2.v * dt * 0.1
            if v2.x < -v2.L || v2.x > W + v2.L { traffic.remove(at: i) }
        }
    }

    // ═══ 장면 준비 ═══
    func dragReset() {
        PEND = nil
        if let d = DRAG { if actors.contains(where: { $0 === d.a }) { d.a.held = false; dropEnd(d.a) }; DRAG = nil }
    }
    /// 장면의 '자리' 열쇠(정류장 · 역 입구 · 역 안 승강장). 같은 mode(wait)여도 버스 → 지하철처럼 자리가 바뀌면 장면을 다시 만든다.
    static func venueKey(_ r: SceneModel.Res) -> String { r.venue + (r.inside ? "/in" : "") }
    func setup(_ m0: String) {
        var m = m0
        dragReset(); mode = m; actors = []; traffic = []; pt = []; gfx = []; bams = []; hero = nil; seq = nil; nextCar = t + rnd(1.2, 3); spawnAt = t + 0.2; castI = 0; ripples = []; rideBell = false
        stopX = jr(W * 0.3); entX = jr(W * 0.36); venue = res.venue == "sub" ? "sub" : "bus"; baseDir = venue == "sub" ? 1 : -1
        inside = false; sta = ""; vk = SceneCore.venueKey(res)
        if m == "train" { venue = "sub"; SceneTrain.setup(self); return }                  // 지하철 객실(혼잡도 카드의 두 번째 쪽): 친구·자리·승하차는 엔진(res.train)이 정한 값
        tr = nil
        let heroId: String? = (!res.hero.isEmpty && SceneModel.D3[res.hero] != nil) ? res.hero : nil       // 대표 캐릭터는 엔진이 정한다. 없으면 앱이 대신 고르지 않고 캐릭터 없이 배경만 그린다
        if heroId == nil && m != "idle" { m = "idle"; mode = "idle" }
        inside = m == "wait" && venue == "sub" && res.inside; sta = inside ? res.sta : ""           // 지하철 대기 = 역 안 승강장(실내: 날씨 효과 없음)
        if m == "wait" {
            let h = mkActor(heroId!, inside ? W * 0.5 : venue == "sub" ? entX + 6 : W * 0.48, venue == "sub" ? 0.62 : 0.66, baseDir); h.hero = true; h.k *= 1.12; h.w *= 1.12; h.spd *= 1.1; h.st = "stand"; h.ph = R.next() * 6; h.umb = !inside && (L.wk == "rain" || L.wk == "snow"); h.life = 1e9; hero = h; actors.append(h); waitNext = t + rnd(1.5, 3)
            if venue == "bus" { let v = Traffic(); v.lane = 1; v.bus = true; v.L = laneL(1, true); v.dir = 1; v.x = -40; v.v = 52; v.color = css(pickOf(BUS_COLORS)); v.no = lineNo(pickOf(BUS_NOS)); traffic.append(v) }          // 기다리는 버스는 엔진이 알려 준 내 버스 번호(res.line) — 지나가는 다른 차만 장식 번호(s293)
        } else if m == "alight" {
            let h2 = mkActor(heroId!, 0, -0.12, -1); h2.hero = true; h2.k *= 1.1; h2.w *= 1.1; h2.vis = false; h2.life = 1e9; h2.umb = L.wk == "rain" || L.wk == "snow"; h2.st = "hidden"; hero = h2; actors.append(h2)
            let q = Seq(); q.ph = 0; q.t0 = t; q.busOn = venue != "sub"; q.busX = W * 0.66; q.L = 120; q.color = busColor; seq = q
        } else if m == "ride" {
            let h3 = mkActor(heroId!, W * 0.46, 1, 1); h3.hero = true; h3.st = "stand"; h3.ph = R.next() * 6; hero = h3
            let rd = Ride(); rd.cyc = rnd(0, 20); rd.nextBump = t + rnd(1.5, 3.5); ride = rd
        }
    }
    func idleManage() {
        if pan >= 0 { return }                                      // 장소 이동 중에는 친구들이 함께 걷는다(내보내거나 새로 부르지 않는다)
        let want = W < 260 ? 2 : 3; var alive = 0
        for o in actors {
            if !o.hero && !o.leaving && !o.held && o.st != "fall" && !bigAct(o) && t - o.born > o.life { o.leaving = true; o.st = "walk"; o.tx = o.x < W / 2 ? -o.w * 1.1 : W + o.w * 1.1; o.tz = o.z; o.onArrive = nil }
            if !o.leaving { alive += 1 }
        }
        for i in stride(from: actors.count - 1, through: 0, by: -1) where actors[i].dead { actors.remove(at: i) }
        if alive < want && t >= spawnAt && !(mode == "alight" && seq != nil && (seq!.busOn || seq!.ph < 3)) {
            let cast = res.cast; var id: String? = nil; var tries = 0
            while tries < cast.count {                                         // 등장 순서도 엔진이 정한다(없으면 아무도 안 나온다)
                tries += 1
                let cand = cast[castI % cast.count]; castI += 1; var dup = false
                for o in actors where o.id == cand && !o.leaving { dup = true }
                if !dup && SceneModel.D3[cand] != nil { id = cand; break }
            }
            if let id = id {
                let left = R.next() < 0.5; let a2 = mkActor(id, 0, rnd(0.1, 0.95), left ? 1 : -1); let D = a2.D
                if id == "dudung" && D.intro > 0 && host.intro() != nil && R.next() < 0.75 { a2.x = rnd(a2.w, W - a2.w); a2.st = "emerge"; a2.t0 = t; a2.until = t + Double(D.intro) / Double(D.introFps) }
                else {
                    a2.x = left ? -a2.w * 0.9 : W + a2.w * 0.9
                    var fr: [Actor] = []; for o in actors where !o.leaving { fr.append(o) }
                    let tg = pickTarget(a2, fr); a2.tx = tg.0; a2.tz = tg.1
                    if let h = hero, mode == "alight", let sq = seq, sq.ph >= 3 {
                        a2.tx = clamp(h.x + rnd(-1, 1) * 28, a2.w * 0.5, W - a2.w * 0.5); a2.tz = clamp(h.z + rnd(-0.12, 0.12), 0, 1); a2.chase = true
                        a2.onArrive = { [unowned self] o in o.st = "hop"; o.t0 = self.t; o.until = self.t + 1.4 }
                    }
                }
                a2.born = t; actors.append(a2); spawnAt = t + rnd(0.9, 2.4)
            }
        }
    }
    func waitManage() {
        guard let h = hero else { return }
        if !h.bub.isEmpty && t > h.bubUntil { h.bub = "" }
        if h.lookUntil != 0 && t > h.lookUntil { h.lookUntil = 0; h.dir = baseDir }
        if h.st == "walk" && h.onArrive == nil { h.st = "stand" }
        if t < waitNext || h.st != "stand" || h.lookUntil != 0 { return }
        waitNext = t + 9                                                  // 동작이 끝나면(endAct) 다시 정한다
        nextAct(h)                                                        // 무엇을 할지는 엔진 대본(traits)대로
    }
    func alightManage(_ dt: Double) {
        guard let q = seq, let h = hero else { return }
        let doorX = q.busX + q.L * 0.25
        if venue == "sub" && q.ph < 3 {                  // 지하철: 역 입구 계단으로 올라와 걸어 나온다
            if q.ph == 0 && t - q.t0 > 0.9 {
                q.ph = 1; h.vis = true; h.x = entX; h.z = 0.02; h.dir = -1; h.tx = entX - 36; h.tz = 0.62; h.st = "walk"
                h.onArrive = { [unowned self] o in q.ph = 3; q.t3 = self.t; self.spawnAt = self.t + 0.3; o.st = "stand"; o.dir = 1 }
            }
            return
        }
        if q.ph == 0 {
            q.door = clamp((t - q.t0) / 0.7, 0, 1)
            if t - q.t0 > 0.9 {
                q.ph = 1; h.vis = true; h.x = doorX; h.z = -0.1; h.dir = -1; h.tx = q.busX - q.L * 0.45; h.tz = 0.6; h.st = "walk"
                h.onArrive = { [unowned self] o in q.ph = 2; q.t1 = self.t; o.st = "stand"; o.dir = -1 }
            }
        } else if q.ph == 1 { if h.st != "walk" && h.st != "stand" { h.st = "walk" }; q.door = 1 }
        else if q.ph == 2 { q.door = clamp(1 - (t - q.t1) / 0.6, 0, 1); if t - q.t1 > 1.0 { q.ph = 2.5; q.t2 = t } }
        else if q.ph == 2.5 {
            q.busV = min(95, q.busV + 60 * dt); q.busX += q.busV * dt
            if q.busX - q.L / 2 > W { q.busOn = false; q.ph = 3; q.t3 = t; spawnAt = t + 0.3; h.st = "stand"; h.dir = 1 }
        } else if q.ph == 3 { if h.st == "stand" && t - q.t3 > 1.6 && t >= waitNext { waitNext = t + 9; nextAct(h) } }
        if !h.bub.isEmpty && t > h.bubUntil { h.bub = "" }
    }

    // ═══ 캐릭터 잡아서 옮기기 ═══
    //   꾹(약 .4초) 누르면 캐릭터가 손에 들려 올라오고, 손가락을 따라 다니다가 놓은 자리에 내려앉는다. 길게 누르기 전에 손가락이 움직이면 평소처럼 화면이 스크롤된다.
    //   손가락 위치 → 그림 자리 변환과 내려앉는 모양만 그린다(판단·계산은 없다). 입력 좌표는 dp(웹의 css px).
    func hitActor(_ x: Double, _ y: Double) -> Actor? {
        var best: Actor? = nil
        for a in actors {
            if !a.vis || a.hidden || a.st == "hidden" || a.st == "fall" || a.dead || a.nograb || a.intro { continue }
            let zz = zs(a.z), h = TH * zz * (a.hero ? 1.1 : 1), feet = zy(a.z) + a.y - a.alt * zz, hw = max(15, h * 0.52)
            if abs(x - a.x) <= hw + 6 && y >= feet - h - 8 && y <= feet + 8 && (best == nil || a.z > best!.z) { best = a }
        }
        return best
    }
    /// 손가락이 캐릭터 위에 닿았다. 캐릭터가 있으면 true(길게 누르기 대기 시작)
    func down(_ xdp: Double, _ ydp: Double) -> Bool {
        if !running || mode == "ride" || mode == "train" || DRAG != nil || tv >= 0 { return false }      // TV 전환 중에는 집지 못한다
        guard let a = hitActor(xdp / k, ydp / k) else { return false }
        let p = Pend(a); p.t0 = t; p.sxdp = xdp; p.sydp = ydp; PEND = p; return true
    }
    func move(_ xdp: Double, _ ydp: Double) {
        if let p = PEND { if hypot(xdp - p.sxdp, ydp - p.sydp) > SLOP_DP { PEND = nil }; return }
        if let d = DRAG, running { d.fx = xdp / k; d.fy = ydp / k }
    }
    func up() { PEND = nil; if DRAG != nil { release() } }
    func cancel() { up() }
    func isHeld() -> Bool { DRAG != nil }
    /// 손가락이 닿았거나 · 잡혀 있거나 · 놓은 뒤 떨어지고 착륙 연출 중이면 true — 이때만 화면 주사율을 끝까지 쓰고, 평소엔 아낀다.
    func interactive() -> Bool {
        if !running { return false }
        if DRAG != nil || PEND != nil || t < hotUntil || tv >= 0 { return true }          // TV 전환도 끝까지 부드럽게
        for a in actors where a.st == "held" || a.st == "fall" { return true }
        return false
    }
    func isPending() -> Bool { PEND != nil }
    func grab() {
        guard let P = PEND else { return }; PEND = nil
        let a = P.a; if a.dead || !actors.contains(where: { $0 === a }) || mode == "ride" { return }
        let zc = zy(a.z)
        let d = Drag(a); d.fx = a.x; d.fy = zc; d.px = a.x; d.py = zc; DRAG = d
        a.prevSt = a.st; a.act = nil; a.pr = nil; a.cut = Double.nan; a.stk = nil; a.cell = -1; a.sk = nil; a.chain = nil; dropBams(a); a.sx = 1; a.sy = 1; a.ox = 0; a.pvx = 0; a.pvy = 0; a.afterEmerge = nil; a.feetScale = false; a.heart = 0; a.sl = 0; a.fade = 1; a.held = true; a.st = "held"; a.altSave = min(a.alt, 24); a.alt = 0; a.bub = ""; a.vis = true; a.vy = 0
        tHaptic("grab"); host.held()
        addPart("puff", a.x, zy(a.z) - 2, 3)
    }
    func heldStep(_ a: Actor, _ dt: Double) {
        guard let d = DRAG, d.a === a else { a.held = false; return }
        let kk = min(1, (dt <= 0 ? 0.033 : dt) * 16), ox = d.px
        d.px += (d.fx - d.px) * kk; d.py += (d.fy - d.py) * kk
        let vx = d.fx - d.px, zc = clamp((d.py - (g.nearTop + 4)) / (g.floor + stretch - g.nearTop - 4), -0.2, 1.05), gy = zy(zc)
        a.x = clamp(d.px, 6, W - 6); a.z = zc
        a.y = min(-8, (d.py - 26) - gy)                                  // 손가락 위로 떠 있다(손가락이 캐릭터를 가리지 않게)
        a.ang = clamp(-vx * 0.018, -0.4, 0.4) + sin(t * 5.2) * 0.06          // 손가락이 앞서 가면 몸이 뒤로 흔들린다
        if abs(d.px - ox) > 0.4 { a.dir = d.px > ox ? 1 : -1 }
        a.fr = Double(SceneModel.stand(a.id)); a.sq = 0; a.intro = false
    }
    func release() {
        guard let d = DRAG else { return }; DRAG = nil
        releaseActor(d.a)
    }
    func hotFor(_ k: String) -> Double { k == "cotton" ? 6.5 : k == "pose" ? 7 : k == "star" ? 6.5 : k == "dig" ? 7.5 : k == "flip" ? 8 : k == "fly" ? 10 : k == "puddle" ? 12.5 : 3.2 }
    func landOf(_ a: Actor) -> String { let T = hasRes ? res.traits[a.id] : nil; return T?.land ?? "" }
    func releaseActor(_ a: Actor) {
        let h = HH(a), H0y = max(0, -a.y); var gg = 560.0
        a.held = false; a.pinned = true; a.pinX = a.x; a.lastBounce = false; a.landK = landOf(a); a.t0 = t; a.fy0 = a.y; a.vy = 0; a.sx = 1; a.sy = 1
        a.feetScale = false; a.heart = 0; a.sl = 0; a.fade = 1
        tHaptic("release"); hotUntil = t + hotFor(a.landK)
        // s354 (YJ: 떨어뜨릴 때 친구마다 다른 연출): 엔진의 land 값이 연출 갈래를 정한다 — cotton 둘숑(풍선) · pose 뽀푸(지진 착지) · dig 두덩(땅속 이동) · flip 러블(3회전) · fly 독슐(친구 납치 비행) · puddle 챙챙(꼬리 헬리콥터) · tumble 쮸르 · hose 베비히포
        if a.landK == "fly" { a.altStart = H0y; a.y = 0; a.alt = H0y; startAct(a, "carry"); tHaptic("flap"); return }      // 고공낙하 → 친구를 안고 하늘로 → 한 바퀴 → 내려놓기
        if a.landK == "puddle" { a.altStart = H0y; a.y = 0; a.alt = H0y; startAct(a, "heli"); tHaptic("flap"); return }      // 꼬리를 헬리콥터처럼 돌려 하늘을 돌다 천천히 내려와 화낸다
        let flipLike = a.landK == "flip" || a.landK == "tumble"
        if flipLike && H0y < 40 { a.vy = -190 }                                                                                     // 낮게 놓아도 한 바퀴 돌 시간을 번다
        if a.landK == "cotton" || a.landK == "hose" { gg = 150 }
        if flipLike { gg = 400 }
        if a.landK == "flip" { gg = 250 }                                                                                           // 러블: 느긋하게 떠서 화면 위로 벗어나지 않게
        if a.landK == "flip" { a.vy = -max(0, (gg * 1.4 * 1.4 - 2 * H0y) / (2 * 1.4)) }                                             // 러블: 같은 자리에서 앞구르기 3번 할 시간(1.4초 이상)을 번다
        if a.landK == "cotton" && H0y < 50 { a.vy = -80 }                                                                           // 둘숑: 낮게 놓아도 풍선이 부풀 시간을 번다
        a.airT = (abs(min(0, a.vy)) + sqrt(a.vy * a.vy + 2 * gg * H0y)) / gg
        if a.landK == "cotton" || a.landK == "hose" { a.airT = max(0.5, min(1.3, H0y / 60 + 0.3)) }
        if a.landK == "tumble" {                                                                                                    // 죽순이: 잡고 있던 대나무를 공중에 놓친다(주인은 앞구르기)
            let b = Bam(); b.owner = a; b.t0 = t; b.z = a.z; b.x = a.x + Double(a.dir) * h * 0.3; b.y = zy(a.z) + a.y - h * 0.75; b.vx = Double(a.dir) * rnd(22, 46); b.vy = -rnd(40, 95); b.vr = Double(a.dir) * rnd(5, 9)
            bams.append(b); if bams.count > 4 { bams.removeFirst() }
        }
        a.st = "fall"
    }
    func fallStep(_ a: Actor, _ dt0: Double) {
        let dt = dt0 <= 0 ? 0.033 : dt0; let kk = a.landK; let tf = t - a.t0, h = HH(a); var gg = 560.0
        a.vis = true; a.sx = 1; a.sy = 1; a.ox = 0; a.pvx = 0; a.pvy = 0; a.pr = nil; a.cut = Double.nan; a.ang *= 0.8; a.feetScale = false; a.heart = 0; a.sl = 0; a.fade = 1
        if kk == "cotton" {                                                            // 둘숑: 몸이 풍선처럼 3배로 부풀며 천천히 내려온다(발 기준으로 커진다)
            gg = 110; a.vy = min(a.vy, 52); let gp = ease(clamp(tf / 0.95, 0, 1))
            a.sx = 1 + 2 * gp; a.sy = a.sx; a.feetScale = true; a.ang = sin(tf * 3.1) * 0.05 * gp; a.pose = 2; a.cell = 15
            if gp > 0.15 && every2("balfx", 0.2) { ptx("spark", a.x + rnd(-1, 1) * h * 1.2, zy(a.z) + a.y - h * (0.4 + 2 * gp * rnd(0.2, 1)), 1, po().a(-PI, 0).s(4, 10).g(0).l(0.3, 0.5).r(0.9)) }
        }
        else if kk == "flip" {                                                         // 러블: 같은 자리에서 공중 앞구르기 3번
            gg = 250; a.pvy = a.y - h * 0.5; let fp = clamp(tf / max(0.25, a.airT != 0 ? a.airT : 0.5), 0, 1); a.ang = PI2 * 3 * ease(fp); a.cell = fp < 0.1 || fp > 0.9 ? 14 : 5; a.pose = 2                    // 날아오를 땐 점프, 도는 동안은 몸을 동그랗게 만 칸
            if every2("flipfx", 0.18) { ptx("star", a.x, zy(a.z) + a.y - h * 0.5, 1, po().a(-PI, 0).s(6, 14).g(0).l(0.3, 0.5).r(0.8).jx(h * 0.3)) }
        }
        else if kk == "tumble" {                                                       // 죽순이: 버둥 → 몸을 말아 앞으로 한 바퀴 → 웅크려 착지
            gg = 400; a.pvy = -h * 0.5; let p = clamp(tf / max(0.25, a.airT != 0 ? a.airT : 0.5), 0, 1); a.ang = PI2 * ease(clamp((p - 0.14) / 0.72, 0, 1))
            a.cell = p < 0.14 ? 1 : p < 0.86 ? 0 : 2; a.sk = "juksun_nb"; a.pose = -1
        }
        else if kk == "hose" {                                                         // 베비히포: 입에서 땅으로 물대포를 쏘아 물 쿠션으로 사뿐히 내려앉는다
            gg = 150; a.vy = min(a.vy, 85); a.ang = 0; a.cell = 1; a.pose = -1
            let mx = a.x + Double(a.dir) * h * 0.3, my = zy(a.z) + a.y - h * 0.55; pr(a, jetProp(mx, my, mx + Double(a.dir) * 2, zy(a.z)))
            if every2("hosefx", 0.07) { ptx("splash", mx + Double(a.dir) * 2, zy(a.z) - 1, 1, po().a(-PI * 0.95, -PI * 0.05).s(16, 40).g(170).l(0.3, 0.6).jx(5)) }
        }
        else if kk == "star" {                                                         // s415 뽀푸: 노란 별빛이 몸을 감싼 채 활짝 웃으며 내려온다(느긋하게 떠서 별빛이 보이도록)
            gg = 230; a.vy = min(a.vy, 150); a.ang = sin(tf * 2.6) * 0.06; a.pose = 2; a.cell = 15; a.sl = 1; a.slU = ease(clamp(tf / 0.3, 0, 1))
        }
        else if kk == "pose" { a.ang = 0; a.sy = 1.06; a.sx = 0.96; a.pose = 2; a.cell = 11 }                 // 뽀푸: 몸을 쭉 펴고 두 발로 꼿꼿이 떨어진다
        a.vy += gg * dt; a.y += a.vy * dt
        if a.y >= 0 {
            a.y = 0; landFx(a)
            if kk.isEmpty && a.vy > 130 && !a.lastBounce { a.vy = -a.vy * 0.3; a.lastBounce = true; a.sq = 1; return }
            touchdown(a); return
        }
        if a.y < -300 { a.y = -300 }
    }
    func settle(_ a: Actor) {
        a.y = 0; a.ang = 0; a.sq = 0; a.vy = 0; a.alt = a.altSave != 0 ? a.altSave : a.alt
        a.leaving = false; a.born = t; a.life = max(a.life, 14); a.dead = false; a.sx = 1; a.sy = 1; a.pvx = 0; a.pvy = 0; a.pinX = a.x
    }
    func touchdown(_ a: Actor) {
        let kk = a.landK; settle(a)
        tHaptic(kk.isEmpty ? "land" : "land_" + kk)
        if !kk.isEmpty && ACT["L_" + kk] != nil { startAct(a, "L_" + kk) } else { dropEnd(a) }
    }
    func dropEnd(_ a: Actor) {
        settle(a)
        if a.prevSt == "walk" && a.onArrive != nil { a.st = "walk" }                  // 걸어가던 길(승하차 장면의 대표 캐릭터)은 놓은 자리에서 이어서
        else if a.hero { a.st = "stand"; waitNext = t + 0.35 }
        else { nextAct(a) }                                                           // 놓자마자 바로 움직인다(엔진 대본의 다음 동작)
    }

    // ═══ 전용 동작 도구: 물줄기 소품 · 떨어진 대나무 · 놀라 달아나기 ═══
    func every2(_ key: String, _ gap: Double) -> Bool { if let v = evg[key], t - v < gap, v <= t { return false }; evg[key] = t; return true }
    /// (x,y)에서 (x2,y2)까지 뻗는 물줄기(소품). 입에서 땅으로, 또는 입에서 친구에게.
    func jetProp(_ x: Double, _ y: Double, _ x2: Double, _ y2: Double) -> Prop { let p = propAbs("jet", x, y); p.s = x2; p.r = y2; return p }
    func dropBams(_ a: Actor) { for i in stride(from: bams.count - 1, through: 0, by: -1) where bams[i].owner === a { bams.remove(at: i) } }
    func bamOf(_ a: Actor) -> Bam? { for b in bams where b.owner === a && !b.taken { return b }; return nil }
    func stepBams(_ dt: Double) {
        for i in stride(from: bams.count - 1, through: 0, by: -1) {
            let b = bams[i]
            if let ow = b.owner, ow.dead || !actors.contains(where: { $0 === ow }) { bams.remove(at: i); continue }
            if b.taken || t - b.t0 > 40 { bams.remove(at: i); continue }
            if b.landed { continue }
            b.vy += 560 * dt; b.x += b.vx * dt; b.y += b.vy * dt; b.rot += b.vr * dt
            let gy = zy(b.z) - 1.5
            if b.y >= gy {
                b.y = gy
                if b.bounces < 2 && b.vy > 40 { b.vy = -b.vy * 0.38; b.vx *= 0.55; b.vr *= 0.4; b.bounces += 1; addPart("dust", b.x, gy, 2) }
                else { b.landed = true; b.vx = 0; b.vy = 0; b.vr = 0; b.rot = jr(b.rot / PI) * PI + 0.06 }
            }
            b.x = clamp(b.x, 10, W - 10)
        }
    }
    /// 움직일 수 있는 친구인가(잡힘·낙하·착지 연출·퇴장·역 대기 대표·다른 큰 연출 중이면 아니다).
    func freeFor(_ o: Actor?) -> Bool {
        guard let o = o else { return false }
        if o.dead || o.hidden || o.leaving || o.hero || o.held || o.nograb || o.onArrive != nil || !o.vis { return false }
        let s = o.st; if s == "fall" || s == "held" || s == "emerge" || s == "pan" || s == "hidden" { return false }
        return !bigAct(o)
    }
    /// 떨어뜨리기·놀람 같은 큰 연출 중인가(이때는 다른 연출이 끼어들거나 퇴장 시간이 되어도 끊지 않는다).
    func bigAct(_ o: Actor) -> Bool {
        guard o.st == "act", let A = o.act else { return false }; let n = A.n
        return n.hasPrefix("L_") || n == "flee" || n == "flyaway" || n == "carry" || n == "carried" || n == "dizzy" || n == "heli" || n == "rage" || n == "shock"
    }
    /// 물대포를 맞은 친구가 깜짝 놀라 달아난다(src 는 쏜 친구). 못 움직이는 상태는 건드리지 않는다.
    func startle(_ src: Actor, _ o: Actor) { startleK(src, o, "") }
    /// kind: "" 물대포(달아난다) · "scary" 러블의 눈빛(달아난다) · "shock" 뽀푸의 지진(깜짝 놀라 떤다).
    func startleK(_ src: Actor, _ o: Actor, _ kind: String) {
        if o === src || !freeFor(o) { return }
        o.chain = nil; o.pr = nil; o.cut = Double.nan; o.alt = o.kind == "eagle" ? o.alt : 0; o.fearK = kind
        startAct(o, kind == "shock" ? "shock" : "flee"); if let A = o.act { A.fx = src.x }
    }

    // ═══ 버스 안(타고 가는 중) ═══
    func rideStep(_ dt: Double) {
        guard let Rd = ride, let h = hero else { return }
        Rd.cyc = (Rd.cyc + dt).truncatingRemainder(dividingBy: 22)
        let c = Rd.cyc
        let v: Double = c < 4 ? ease(c / 4) : c < 16 ? 1 + sin(c * 0.9) * 0.04 : c < 19 ? 1 - ease((c - 16) / 3) : 0    // 출발 → 달림 → 정차 → 잠깐 섰다가
        Rd.acc = (v - Rd.vPrev) / max(dt, 0.001); Rd.vPrev = v; Rd.speed = v; Rd.scroll += v * dt * 70; Rd.rot += v * dt * 9
        if t > Rd.nextBump { Rd.bump = t; Rd.nextBump = t + rnd(2.5, 5) }
        Rd.stopped = v < 0.02
        if res.nearEnd { if t >= bellAt { bellAt = t + 3.2; h.bub = "띵동!"; h.bubUntil = t + 1.5; Rd.bellT = t } }
        if !h.bub.isEmpty && t > h.bubUntil { h.bub = "" }
    }

    /// 내 버스 번호(엔진 res.line — 고른 번호가 반영된다). 버스 장면이 아니거나 비어 있으면 fallback. 지나가는 다른 차의 번호만 장식으로 아무 번호나 뽑는다(s293).
    func lineNo(_ fallback: String) -> String { hasRes && res.venue == "bus" && !res.line.isEmpty ? res.line : fallback }
    func busLabel() -> String { lineNo(busNo ?? "") }
}
