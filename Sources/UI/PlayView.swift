import SwiftUI
import UIKit

/// 캐릭터 놀이터 그림(웹 _RC.playStart 의 canvas — 역 팝업 · 시간표 시트의 이름 옆 빈 칸) — 안드로이드 PlayView.java.
/// 계산은 모두 PlayCore 가 하고 여기는 그리기만 한다.
/// ① 캐릭터 16프레임은 '그릴 크기'로 한 번만 줄여 뒤에서 만들어 둔다(PlaySim). 시트가 아직 안 읽혔으면 배경만 먼저 논다.
/// ② 배경(하늘 · 장식 · 바닥 · 나무 · 웅덩이)은 한 겹으로 그리고 가장자리(좌우 20% · 위 50%)를 투명하게 지운다(mask) → 시트 바탕과 자연스럽게 섞인다. 캐릭터는 그 위에 지우지 않고 그린다.
/// ③ 30fps. 화면에서 사라지면 멈춘다. 순수 장식 — 만져지지 않는다(아래 화면의 단추 누르기를 막지 않는다).

/// 역 팝업에서 놀던 장면을 시간표로 이어 주는 쪽지(웹 playSnap).
enum PlayHub {
    static var snap: PlayCore.Snap? = nil
}

enum PlayKind { case popup, tt }

final class PlaySim: ObservableObject {
    let play: PlayCore.Play
    let dark: Bool, reduce: Bool, kind: PlayKind
    var frames: [[UIImage]] = []           // 캐릭터마다 16장(그릴 크기)
    var framesIn: [[UIImage]] = []         // 두더지는 솟는 장면 하나 더(나머지는 빈 줄)
    private var last: Date? = nil
    private var acc = 0.0, snapAt = 0.0
    private var building = false

    init(w: Double, h: Double, dark: Bool, reduce: Bool, kind: PlayKind) {
        self.dark = dark; self.reduce = reduce; self.kind = kind
        let snap: PlayCore.Snap? = kind == .tt ? PlayHub.snap : nil          // 시간표로 올라오면 팝업에서 놀던 그대로
        if kind == .popup { PlayHub.snap = nil }
        play = PlayCore.Play(wc: w, hc: h, snap: snap, rng: PlayRng(seed: UInt64.random(in: 1...UInt64.max)))
        RunnerArt.warm(first: play.cs.first?.id ?? "dolsom")
    }

    /// 그림 박자마다 부른다. 같은 시각으로 거듭 불러도 한 번만 흐른다.
    func advance(_ now: Date) {
        guard let l = last else { last = now; return }
        let d = now.timeIntervalSince(l)
        if d <= 0 { return }
        last = now
        if reduce { return }
        acc += min(0.05, d)
        if acc >= 0.030 {
            play.tick(acc); acc = 0
            if kind == .popup && play.t - snapAt > 0.5 { snapAt = play.t; PlayHub.snap = play.snap() }
        }
    }
    func leave() { if kind == .popup { PlayHub.snap = play.snap() } }

    private func nowMs() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }

    /// 시트가 다 읽혔으면 뒤에서 프레임을 만든다.
    func buildIfReady() {
        if building || !frames.isEmpty { return }
        var sheets: [UIImage] = []
        for c in play.cs {
            guard let s = RunnerArt.get(RunnerCore.file(c.id, nowMs())) else { return }
            sheets.append(s)
        }
        var introSheet: UIImage? = nil
        if play.cs.contains(where: { $0.kind == "mole" }) {
            guard let i = RunnerArt.get("dudung_intro") else { return }
            introSheet = i
        }
        building = true
        let scales: [Double] = play.cs.map { $0.D.cell / 256 * $0.k }
        let isMole: [Bool] = play.cs.map { $0.kind == "mole" }
        let sh = sheets, intro = introSheet
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var a: [[UIImage]] = [], b: [[UIImage]] = []
            for (i, s) in sh.enumerated() {
                a.append(PlaySim.cut(s, scales[i]))
                if isMole[i], let it = intro { b.append(PlaySim.cut(it, scales[i])) } else { b.append([]) }
            }
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.frames = a; self.framesIn = b; self.building = false
                self.objectWillChange.send()
            }
        }
    }

    /// 256px 칸 16장을 그릴 크기(pt = 256 × sc0, 화소 3배)로 줄여 담는다(웹의 'high' 보간과 같은 결과).
    static func cut(_ sheet: UIImage, _ sc0: Double) -> [UIImage] {
        guard let cg = sheet.cgImage else { return [] }
        let cell = cg.width / 4
        if cell < 4 { return [] }
        let pt = CGFloat(max(8.0 / 3.0, 256 * sc0))
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 3; fmt.opaque = false
        let r = UIGraphicsImageRenderer(size: CGSize(width: pt, height: pt), format: fmt)
        var out: [UIImage] = []
        for i in 0..<16 {
            guard let part = cg.cropping(to: CGRect(x: (i % 4) * cell, y: (i / 4) * cell, width: cell, height: cell)) else { out.append(UIImage()); continue }
            let ui = UIImage(cgImage: part, scale: 1, orientation: .up)
            out.append(r.image { c in
                c.cgContext.interpolationQuality = .high
                ui.draw(in: CGRect(x: 0, y: 0, width: pt, height: pt))
            })
        }
        return out
    }
}

/// 놀이터 칸 하나(크기 w × h pt). 부르는 쪽이 자리를 정한다.
struct PlayField: View {
    @StateObject private var sim: PlaySim
    init(w: CGFloat, h: CGFloat, dark: Bool, reduce: Bool, kind: PlayKind) {
        _sim = StateObject(wrappedValue: PlaySim(w: Double(w), h: Double(h), dark: dark, reduce: reduce, kind: kind))
    }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: sim.reduce)) { tl in
            ZStack {
                Canvas { ctx, _ in
                    sim.advance(tl.date)
                    sim.buildIfReady()
                    var g = ctx
                    PlayDraw.world(&g, sim)
                }
                .mask(PlayMask.horizontal)
                .mask(PlayMask.vertical)
                Canvas { ctx, _ in
                    var g = ctx
                    PlayDraw.actors(&g, sim)
                }
            }
        }
        .onDisappear { sim.leave() }
        .allowsHitTesting(false)
    }
}

/// 가장자리 지우개: 좌우 20% · 위 50% 가 투명하게(smoothstep 근사 0, .16, .5, .84, 1).
enum PlayMask {
    private static let a: [Double] = [0, 0.157, 0.502, 0.843, 1]
    static var horizontal: LinearGradient {
        var st: [Gradient.Stop] = []
        for (i, v) in a.enumerated() { st.append(Gradient.Stop(color: Color.black.opacity(v), location: Double(i) * 0.05)) }
        for (i, v) in a.enumerated().reversed() { st.append(Gradient.Stop(color: Color.black.opacity(v), location: 1 - Double(i) * 0.05)) }
        return LinearGradient(stops: st, startPoint: .leading, endPoint: .trailing)
    }
    static var vertical: LinearGradient {
        var st: [Gradient.Stop] = []
        for (i, v) in a.enumerated() { st.append(Gradient.Stop(color: Color.black.opacity(v), location: Double(i) * 0.125)) }
        st.append(Gradient.Stop(color: Color.black, location: 1))
        return LinearGradient(stops: st, startPoint: .top, endPoint: .bottom)
    }
}

enum PlayDraw {
    private static func C(_ rgb: UInt32, _ a: Double = 1) -> Color {
        Color(.sRGB, red: Double((rgb >> 16) & 255) / 255, green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255, opacity: max(0, min(1, a)))
    }
    /// 0xAARRGGBB
    private static func A(_ v: UInt32) -> Color {
        Color(.sRGB, red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255, opacity: Double(v >> 24) / 255)
    }
    private static func oval(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> Path { Path(ellipseIn: CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)) }
    private static func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Path { Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)) }
    /// 반원(위쪽 또는 아래쪽 절반의 부채꼴).
    private static func half(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, upper: Bool) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: cx + rx * (upper ? -1 : 1), y: cy))
        let n = 24
        for i in 1...n {
            let a = Double.pi * Double(i) / Double(n)
            let s = CGFloat(sin(a)), c = CGFloat(cos(a))
            p.addLine(to: CGPoint(x: cx + rx * (upper ? -c : c), y: cy + ry * (upper ? -s : s)))
        }
        p.closeSubpath()
        return p
    }
    private static func f(_ v: Double) -> CGFloat { CGFloat(v) }
    private static func wrap(_ a: Double, _ b: Double) -> Double { let r = fmod(a, b); return r < 0 ? r + b : r }

    // ───────── 배경 ─────────
    static func world(_ g: inout GraphicsContext, _ s: PlaySim) {
        let pl = s.play, dark = s.dark, sc = pl.sc
        let W = f(pl.W), H = f(pl.H), gy = f(pl.gy), FY = f(pl.fy), t = pl.t
        let cl = dark ? sc.d : sc.p
        g.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)),
               with: .linearGradient(Gradient(stops: [Gradient.Stop(color: C(cl[0]), location: 0), Gradient.Stop(color: C(cl[1]), location: 0.55), Gradient.Stop(color: C(cl[2]), location: 1)]),
                                     startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: H)))
        deco(&g, pl, dark)
        g.fill(Path(CGRect(x: 0, y: gy - 1, width: W, height: H - gy + 1)), with: .color(C(dark ? sc.g[1] : sc.g[0])))              // 바닥 띠
        if sc.deco == "meadow" {
            var grass = Path()
            var gx: CGFloat = 5
            while gx < W { grass.move(to: CGPoint(x: gx - 2, y: gy)); grass.addLine(to: CGPoint(x: gx, y: gy - 4)); grass.addLine(to: CGPoint(x: gx + 2, y: gy)); grass.closeSubpath(); gx += 13 }
            g.fill(grass, with: .color(A(dark ? 0xFF1F6A4C : 0xFF6CC28A)))
        }
        if sc.deco == "snow" { g.fill(Path(CGRect(x: 0, y: gy - 2, width: W, height: 2)), with: .color(A(dark ? 0xFFC4D4E8 : 0xFFFFFFFF))) }
        if let po = pl.pond { drawPond(&g, po, FY, t, dark) }
        if let tr = pl.tree { drawTree(&g, tr, sc.deco, FY, dark) }
        for o in pl.poops { drawPoop(&g, o, t, FY, dark) }
        for c in pl.cs where c.kind == "mole" && c.st == "hidden" {                    // 땅속 두더지: 움직이는 흙두둑
            let wob = f(sin(t * 9) * 0.6), x = f(c.x)
            g.fill(half(x, FY, 8, 3.4 + wob * 0.3, upper: true), with: .color(A(dark ? 0xFF6B4A33 : 0xFF8A5F3D)))
            g.fill(half(x - 2, FY - 0.6, 3, 1.4, upper: true), with: .color(A(dark ? 0xFF7D5A40 : 0xFFA2744C)))
        }
    }

    private static func cloud(_ g: inout GraphicsContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ a: Double) {
        var p = Path()
        p.addEllipse(in: CGRect(x: x - r * 1.5, y: y - r * 0.62, width: r * 3, height: r * 1.24))
        p.addEllipse(in: CGRect(x: x - r * 0.7 - r * 0.8, y: y + r * 0.1 - r * 0.5, width: r * 1.6, height: r))
        p.addEllipse(in: CGRect(x: x + r * 0.75 - r * 0.85, y: y + r * 0.12 - r * 0.5, width: r * 1.7, height: r))
        g.fill(p, with: .color(C(0xFFFFFF, a)))
    }

    private static func deco(_ g: inout GraphicsContext, _ pl: PlayCore.Play, _ dark: Bool) {
        let d = pl.sc.deco, W = pl.W, H = pl.H, gy = pl.gy, t = pl.t
        let parts = pl.parts
        switch d {
        case "clouds":
            if !dark {
                g.fill(circle(f(W * 0.8), 28, 7), with: .color(A(0xE6FFE28C)))
                g.fill(circle(f(W * 0.8), 28, 12), with: .color(A(0x4DFFE28C)))
            } else {
                g.fill(circle(f(W * 0.8), 28, 6), with: .color(A(0xD9FFF4C8)))
                g.fill(circle(f(W * 0.8 + 2.5), 26.5, 5.4), with: .color(A(0xE60E203C)))
            }
            for q in parts {
                let x = wrap(q.x * (W + 60) + t * 5 * q.v, W + 60) - 30
                cloud(&g, f(x), f(20 + q.y * (H * 0.3)), f(6 + q.s * 3), dark ? 0.16 : 0.9)
            }
        case "sunset":
            g.fill(half(f(W * 0.78), f(gy), f(H * 0.3), f(H * 0.3), upper: true), with: .color(A(dark ? 0x80FFAA78 : 0xF2FFEEBE)))
            let col = A(dark ? 0xB3FFE6D2 : 0x8C78506E)
            for q in parts {
                let x = f(wrap(q.x * (W + 40) + t * 14 * q.v, W + 40) - 20)
                let y = f(24 + q.y * 14 + sin(t * 2 + q.ph) * 2), fl = f(sin(t * 7 + q.ph) * 2.2)
                var p = Path()
                p.move(to: CGPoint(x: x - 4, y: y + fl))
                p.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x - 1.5, y: y - 2))
                p.addQuadCurve(to: CGPoint(x: x + 4, y: y + fl), control: CGPoint(x: x + 1.5, y: y - 2))
                g.stroke(p, with: .color(col), style: StrokeStyle(lineWidth: 1.2, lineCap: .butt))
            }
        case "meadow":
            for (i, q) in parts.enumerated() {
                let x = f(wrap(q.x * W + sin(t * 0.8 * q.v + q.ph) * 26 + W, W))
                let y = f(22 + q.y * H * 0.4 + sin(t * 2.2 + q.ph) * 4)
                let wing = f(abs(sin(t * 9 + q.ph)) * 3 + 0.8)
                let col = (i & 1) != 0 ? A(dark ? 0xFFFFD27A : 0xFFFF9BB8) : A(dark ? 0xFF9FD8FF : 0xFFFFC46B)
                var l = g
                l.translateBy(x: x - 2, y: y); l.rotate(by: .radians(-0.5))
                l.fill(oval(-wing, -2.2, wing, 2.2), with: .color(col))
                var r = g
                r.translateBy(x: x + 2, y: y); r.rotate(by: .radians(0.5))
                r.fill(oval(-wing, -2.2, wing, 2.2), with: .color(col))
            }
        case "petals":
            let col = A(dark ? 0xBFFFAAD2 : 0xCCFF8CBE)
            for q in parts {
                let y = f(wrap(q.y * H + t * 9 * q.v, H + 8) - 4), x = f(wrap(q.x * W + sin(t * 1.3 + q.ph) * 8 + W, W))
                var p = g
                p.translateBy(x: x, y: y); p.rotate(by: .radians(t * q.v + q.ph))
                p.fill(oval(-3.4 * f(q.s), -1.8 * f(q.s), 3.4 * f(q.s), 1.8 * f(q.s)), with: .color(col))
            }
        case "snow":
            let col = A(dark ? 0xD9FFFFFF : 0xE696B9E1)
            for q in parts {
                let y = f(wrap(q.y * H + t * 13 * q.v, H + 4) - 2), x = f(wrap(q.x * W + sin(t + q.ph) * 5 + W, W))
                g.fill(circle(x, y, 1.2 * f(q.s)), with: .color(col))
            }
        case "sea":
            for i in 0..<3 {
                let col = dark ? C(0xA0DCFF, 0.28 - Double(i) * 0.07) : C(0xFFFFFF, 0.8 - Double(i) * 0.2)
                var p = Path()
                var x = 0.0
                while x <= W {
                    let y = H * (0.46 + Double(i) * 0.13) + sin(x / 11 + t * (1.6 + Double(i) * 0.4) + Double(i)) * 2.2
                    if x == 0 { p.move(to: CGPoint(x: f(x), y: f(y))) } else { p.addLine(to: CGPoint(x: f(x), y: f(y))) }
                    x += 4
                }
                g.stroke(p, with: .color(col), style: StrokeStyle(lineWidth: 1.4))
            }
            let col = A(dark ? 0x80B4E6FF : 0xBFFFFFFF)
            for q in parts {
                let y = f(H - wrap(q.y * H + t * 8 * q.v, H)), x = f(q.x * W + sin(t * 2 + q.ph) * 2)
                g.fill(circle(x, y, 1 + f(q.s) * 0.7), with: .color(col))
            }
        case "night":
            for q in parts {
                let tw = 0.45 + 0.55 * abs(sin(t * q.v * 1.6 + q.ph))
                g.fill(circle(f(q.x * W), f(3 + q.y * (H * 0.62)), 0.7 + f(q.s) * 0.45), with: .color(C(dark ? 0xFFFFEB : 0xFFFFFF, dark ? tw : tw * 0.95)))
            }
            let mx = f(W * 0.8)
            g.fill(circle(mx, 28, 7), with: .color(A(dark ? 0xFFFFF3C4 : 0xFFFFFBE6)))
            g.fill(circle(mx + 3, 26, 6.2), with: .color(A(dark ? 0xFF1A1650 : 0xFFD6CFFF)))
            let sp = fmod(t, 9) / 1.4
            if sp < 1 {
                var p = Path()
                p.move(to: CGPoint(x: f(W * 0.2 + sp * W * 0.4), y: f(4 + sp * 14)))
                p.addLine(to: CGPoint(x: f(W * 0.2 + sp * W * 0.4 - 10), y: f(4 + sp * 14 - 5)))
                g.stroke(p, with: .color(C(0xFFFFFF, 1 - sp)), style: StrokeStyle(lineWidth: 1.3))
            }
        case "aurora":
            for i in 0..<3 {
                let col: UInt32 = dark ? (i == 0 ? 0x4750FFBE : i == 1 ? 0x427AA0FF : 0x38DC78FF) : (i == 0 ? 0x4D5ADCB4 : i == 1 ? 0x478AAAFF : 0x40E68CFF)
                var p = Path()
                p.move(to: CGPoint(x: 0, y: 0))
                var x = 0.0
                while x <= W {
                    p.addLine(to: CGPoint(x: f(x), y: f(H * (0.22 + Double(i) * 0.1) + sin(x / 26 + t * (0.7 + Double(i) * 0.3) + Double(i) * 2) * 5)))
                    x += 6
                }
                p.addLine(to: CGPoint(x: f(W), y: 0))
                p.closeSubpath()
                g.fill(p, with: .color(A(col)))
            }
            for q in parts {
                let tw2 = 0.4 + 0.6 * abs(sin(t * q.v + q.ph))
                g.fill(circle(f(q.x * W), f(4 + q.y * H * 0.5), 0.8), with: .color(C(0xFFFFFF, dark ? tw2 : tw2 * 0.9)))
            }
        default: break
        }
    }

    private static func drawTree(_ g: inout GraphicsContext, _ tr: PlayCore.Tree, _ d: String, _ FY: CGFloat, _ dark: Bool) {
        let x = f(tr.x), th = f(tr.th), ty = th * 0.55
        let trunk = A(dark ? 0xFF6B4F3A : 0xFF9A7352)
        let can: Color
        if d == "snow" { can = A(dark ? 0xFF9BB4D0 : 0xFFE6F1FF) }
        else if d == "petals" || d == "sunset" { can = A(dark ? 0xFFA85A86 : 0xFFFFB3D1) }
        else if d == "night" || d == "aurora" { can = A(dark ? 0xFF2B3F7A : 0xFF8DA0E8) }
        else if d == "sea" { can = A(dark ? 0xFF2F8A62 : 0xFF5FC98A) }
        else { can = A(dark ? 0xFF2F7A55 : 0xFF7FD68F) }
        g.fill(Path(CGRect(x: x - 2.2, y: FY - th, width: 4.4, height: th + 1)), with: .color(trunk))
        var br = Path()
        br.move(to: CGPoint(x: x, y: FY - ty + 3)); br.addLine(to: CGPoint(x: x - 11, y: FY - ty - 3))
        br.move(to: CGPoint(x: x, y: FY - ty + 3)); br.addLine(to: CGPoint(x: x + 11, y: FY - ty - 3))
        g.stroke(br, with: .color(trunk), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))                    // 쉬어 가는 가지
        if d == "sea" {
            for k in -2...2 {
                let fk = CGFloat(k)
                var p = Path()
                p.move(to: CGPoint(x: x, y: FY - th))
                p.addQuadCurve(to: CGPoint(x: x + fk * 12, y: FY - th + 3 + abs(fk) * 2), control: CGPoint(x: x + fk * 8, y: FY - th - 9 + abs(fk) * 1.5))
                g.stroke(p, with: .color(can), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
        } else {
            g.fill(circle(x, FY - th - 4, 11), with: .color(can))
            g.fill(circle(x - 9, FY - th + 3, 8), with: .color(can))
            g.fill(circle(x + 9, FY - th + 3, 8), with: .color(can))
        }
    }

    private static func drawPond(_ g: inout GraphicsContext, _ po: PlayCore.Pond, _ FY: CGFloat, _ t: Double, _ dark: Bool) {
        let x = f(po.x), rx = f(po.rx)
        g.fill(oval(x - rx, FY + 1.2 - 4.4, x + rx, FY + 1.2 + 4.4), with: .color(A(dark ? 0xFF245F8C : 0xFF6FC2EE)))
        for i in 0..<2 {
            let ph = fmod(t * 0.5 + Double(i) * 0.5, 1)
            let cx = x + (i != 0 ? rx * 0.3 : -rx * 0.35)
            let ex = rx * 0.3 * f(ph) + 2, ey = 1.6 * f(ph) + 0.4
            g.stroke(oval(cx - ex, FY + 1.2 - ey, cx + ex, FY + 1.2 + ey), with: .color(C(dark ? 0xAADCFF : 0xFFFFFF, (dark ? 0.55 : 0.85) * (1 - ph))), style: StrokeStyle(lineWidth: 1))
        }
    }

    private static func drawPoop(_ g: inout GraphicsContext, _ o: PlayCore.Poop, _ t: Double, _ FY: CGFloat, _ dark: Bool) {
        let age = t - o.born
        let al = age > 6.4 ? max(0, (8 - age) / 1.6) : 1.0
        let s0 = age < 0.2 ? f(age / 0.2) : 1
        var l = g
        l.translateBy(x: f(o.x), y: FY); l.scaleBy(x: s0, y: s0)
        l.fill(oval(-4.4, -1.4 - 2.4, 4.4, -1.4 + 2.4), with: .color(C(0x7D4F26, al)))
        l.fill(oval(0.2 - 3.3, -3.6 - 2, 0.2 + 3.3, -3.6 + 2), with: .color(C(0x8F5D2D, al)))
        var tip = Path()
        tip.move(to: CGPoint(x: -1.6, y: -4.8)); tip.addQuadCurve(to: CGPoint(x: 1.6, y: -5.2), control: CGPoint(x: 0.4, y: -9)); tip.closeSubpath()
        l.fill(tip, with: .color(C(0xA56D37, al)))
        var hi = l
        hi.translateBy(x: -1.4, y: -3.9); hi.rotate(by: .radians(-0.4))
        hi.fill(oval(-0.9, -0.5, 0.9, 0.5), with: .color(C(0xFFFFFF, 0.45 * al)))
        if age < 3 {                                                                                          // 모락모락 김
            let col = C(dark ? 0xDCE6C8 : 0x78825A, (dark ? 0.55 : 0.5) * al * (1 - age / 3) * 0.8)
            for q in [-1.0, 1.0] {
                var p = Path()
                p.move(to: CGPoint(x: f(q * 2), y: -9))
                p.addQuadCurve(to: CGPoint(x: f(q * 2 - 1), y: -15), control: CGPoint(x: f(q * 2 + 2), y: f(-12 + sin(t * 5 + q))))
                l.stroke(p, with: .color(col), style: StrokeStyle(lineWidth: 0.9))
            }
        }
    }

    // ───────── 캐릭터 · 물 앞면 · 알갱이 ─────────
    static func actors(_ g: inout GraphicsContext, _ s: PlaySim) {
        let pl = s.play, dark = s.dark
        let W = f(pl.W), FY = f(pl.fy), t = pl.t
        let order = pl.cs.indices.sorted { (a, b) in pl.cs[a].k != pl.cs[b].k ? pl.cs[a].k < pl.cs[b].k : a < b }          // k 오름차순(안쪽이 먼저)
        for ci in order {
            let c = pl.cs[ci]
            if !c.vis { continue }
            let set = c.useIntro && ci < s.framesIn.count && !s.framesIn[ci].isEmpty ? s.framesIn[ci] : (ci < s.frames.count ? s.frames[ci] : [])
            let idx = pl.frameIdx(c)
            if set.count < 16 || idx < 0 || idx >= set.count { continue }
            let D = c.D
            let sc = D.cell / 256 * c.k
            let lift = c.kind == "eagle" ? 0.0 : D.lift * c.k * 0.6
            let high = max(0, -c.y)
            if !c.clip {                                                                                      // 그림자(높이 뜨면 작고 옅게)
                let rx = f(c.w * 0.2 * max(0.45, 1 - high / 60))
                g.fill(oval(f(c.x) - rx, FY + 1 - 2.6, f(c.x) + rx, FY + 1 + 2.6), with: .color(C(0x000000, D.sh * 0.5 * max(0.2, 1 - high / 40))))
            }
            var l = g
            if c.clip { l.clip(to: Path(CGRect(x: 0, y: 0, width: W, height: FY + 1.5))) }
            l.translateBy(x: f(c.x + c.jit), y: FY + 1 + f(c.y) - f(lift))
            l.scaleBy(x: c.dir < 0 ? -1 : 1, y: 1)
            if c.rot != 0 { l.rotate(by: .radians(c.rot)) } else if c.ang != 0 { l.rotate(by: .radians(c.ang)) }
            if c.sq != 0 { l.scaleBy(x: 1 + f(c.sq) * 0.35, y: 1 - f(c.sq)) }
            let size = f(256 * sc)
            l.draw(Image(uiImage: set[idx]).interpolation(.high), in: CGRect(x: -f(D.ox * sc), y: -f(D.base * sc), width: size, height: size))
            if c.st == "rest" || c.st == "perch" {                                                            // 쉬는 중: 머리 위로 표시가 떠오른다
                let ph = fmod((t - c.t0) * 0.9, 1)
                let tx = Text(pl.sc.mark).font(.system(size: f(8 + ph * 3), weight: .bold)).foregroundColor(C(dark ? 0xFFF6D8 : 0x6B6FA8, 1 - ph))
                g.draw(tx, at: CGPoint(x: f(c.x + c.w * 0.22), y: FY + f(c.y) - f(c.bodyH * 0.95) - f(ph * 9)), anchor: .bottom)
            }
        }
        if let po = pl.pond {                                                                                 // 물 앞면(잠긴 느낌)
            let x = f(po.x), rx = f(po.rx * 0.97)
            g.fill(half(x, FY + 2.6, rx, 3, upper: false), with: .color(A(dark ? 0x80245F8C : 0x806FC2EE)))
        }
        for q in pl.pt {                                                                                      // 물보라 · 별 · 흙
            let a = 1 - q.age / q.life
            let rgb: UInt32
            switch q.kind {
            case .splash: rgb = dark ? 0x9BD4FF : 0x4FB0EA
            case .star: rgb = 0xFFE58A
            case .dirt: rgb = dark ? 0x8A6240 : 0x7A5230
            }
            g.fill(circle(f(q.x), f(q.y), q.kind == .star ? 1.5 : 1.3), with: .color(C(rgb, a)))
        }
    }
}
