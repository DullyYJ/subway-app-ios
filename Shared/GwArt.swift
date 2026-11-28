import SwiftUI
import UIKit

/// 캐릭터 시계 위젯 그림 — 안드로이드 WidgetArt.java 의 포팅. 시뮬레이션 상태 → 그리기 목록(GwDraw) → SwiftUI 로 그린다.
/// 그리기 목록은 값만 들어 있어(그림 데이터 없음) 위젯 타임라인 항목 하나가 아주 작다. 칸 그림은 아래 GwSheets 가 따로 갖고 있다.
struct GwDraw {
    enum Kind {
        case cell(id: String, frame: Int, l: Double, t: Double, r: Double, b: Double, alpha: Double)
        case ellipse(cx: Double, cy: Double, rx: Double, ry: Double, argb: Int)
        case circle(cx: Double, cy: Double, r: Double, argb: Int)
        case poly(xy: [Double], argb: Int)
    }
    var kind: Kind
    var m: CGAffineTransform
}

/// 그리기 명령을 받아 목록으로 적는다(변환 쌓기 포함: save/restore/translate/rotate/scale).
final class GwRecorder {
    private(set) var items: [GwDraw] = []
    private var m = CGAffineTransform.identity
    private var stack: [CGAffineTransform] = []
    func save() { stack.append(m) }
    func restore() { if let t = stack.popLast() { m = t } }
    func translate(_ x: Double, _ y: Double) { m = CGAffineTransform(translationX: x, y: y).concatenating(m) }
    func rotate(_ deg: Double) { m = CGAffineTransform(rotationAngle: deg * .pi / 180).concatenating(m) }
    func scale(_ sx: Double, _ sy: Double) { m = CGAffineTransform(scaleX: sx, y: sy).concatenating(m) }
    func cell(_ id: String, _ frame: Int, _ l: Double, _ t: Double, _ r: Double, _ b: Double, _ alpha: Double) {
        items.append(GwDraw(kind: .cell(id: id, frame: frame, l: l, t: t, r: r, b: b, alpha: alpha), m: m))
    }
    func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ argb: Int) { items.append(GwDraw(kind: .ellipse(cx: cx, cy: cy, rx: rx, ry: ry, argb: argb), m: m)) }
    func circle(_ cx: Double, _ cy: Double, _ r: Double, _ argb: Int) { items.append(GwDraw(kind: .circle(cx: cx, cy: cy, r: r, argb: argb), m: m)) }
    func poly(_ xy: [Double], _ argb: Int) { items.append(GwDraw(kind: .poly(xy: xy, argb: argb), m: m)) }
}

enum GwArt {
    private static func zed(_ s: GwRecorder, _ cx: Double, _ cy: Double, _ h: Double, _ argb: Int) {
        let t = h * 0.42, d = t * 1.5
        s.poly([cx - h, cy - h, cx + h, cy - h, cx + h, cy - h + t, cx - h + d, cy + h - t, cx + h, cy + h - t, cx + h, cy + h,
                cx - h, cy + h, cx - h, cy + h - t, cx + h - d, cy - h + t, cx - h, cy - h + t], argb)
    }
    /// 색(0xRRGGBB 면 불투명, 0xAARRGGBB 면 그 투명도)에 진하기 a(0~1)를 곱한다.
    private static func al(_ argb: Int, _ a: Double) -> Int {
        var a0 = (argb >> 24) & 255; if a0 == 0 { a0 = 255 }
        let aa = Int(Double(a0) * max(0, min(1, a)))
        return (aa << 24) | (argb & 0xFFFFFF)
    }
    private static func sleepScene(_ s: GwRecorder, _ sim: GwSim, _ h: GwSim.House, _ idx: Int) {
        let c = h.owner, g = sim.geo
        let mix = c.mix, goal = min(1, h.a * 0.55)
        let sc = GwSim.sleepCfg(c.id)
        if h.kind != "pond" {
            let sh = max(mix, c.mix < 0.01 ? goal : 0)
            if sh > 0.01 { s.ellipse(h.x, g.ground - 1, h.w * (h.kind == "nest" ? 0.3 : 0.46), g.charH * 0.07, al(0x2E000000, sh)) }
        }
        if mix <= 0.01 { return }
        let cell = sc[0] * g.charH, left = h.x - sc[1] * cell, top = g.ground - sc[2] * cell
        let fr = ((Int((sim.time * sc[3] + Double(idx) * 5).rounded(.down)) % 16) + 16) % 16
        s.cell(c.id + "_sleep", fr, left, top, left + cell, top + cell, mix)
    }

    static func draw(_ sim: GwSim) -> [GwDraw] {
        let s = GwRecorder(); let g = sim.geo
        let shadow = 0x2E000000
        let u = g.charH / 34
        for p in sim.poops {
            let age = sim.time - p.born, a1 = age > 6.4 ? max(0, (8 - age) / 1.6) : 1, sc0 = age < 0.2 ? age / 0.2 : 1
            if a1 <= 0.01 || sc0 <= 0.01 { continue }
            let a = Int(a1 * 255) << 24
            s.save(); s.translate(p.x, p.y); s.scale(u * sc0, u * sc0)
            s.ellipse(0, -1.4, 4.4, 2.4, a | 0x7D4F26)
            s.ellipse(0.2, -3.6, 3.3, 2, a | 0x8F5D2D)
            s.poly([-1.6, -4.8, 0.4, -9, 1.6, -5.2], a | 0xA56D37)
            s.ellipse(-1.4, -3.9, 0.9, 0.5, (Int(a1 * 112) << 24) | 0xFFFFFF)
            s.restore()
        }
        for (hi, h) in sim.houses.enumerated() { sleepScene(s, sim, h, hi) }
        let order = sim.cs.sorted { $0.y < $1.y }          // 발이 아래에 있는 것(앞)을 나중에
        for c in order {
            if c.alpha <= 0.01 { continue }
            let f = c.cfg
            let charH = g.charH * f[5], sc = charH / (f[1] - f[0])
            let lift = f[4] * g.charH / 58
            let cx = c.x, footY = c.y - c.off - lift
            if c.st != GwSim.HANG && c.home == nil {
                let k = max(0.5, 1 - c.off / (g.charH * 0.6))
                s.ellipse(cx, c.y - 1, g.charH * 0.42 * k, g.charH * 0.07 * k, shadow)
            }
            s.save()
            if c.st == GwSim.HANG {
                let py = footY - (f[1] - f[0]) * sc
                s.translate(cx, py); s.rotate(c.rot); s.translate(-cx, -py)
            } else if c.rot != 0 {
                s.translate(cx, footY); s.rotate(c.rot); s.translate(-cx, -footY)
            }
            if c.sq > 0 || c.sx != 0 { s.translate(cx, footY); s.scale(1 + c.sx, 1 - c.sq); s.translate(-cx, -footY) }
            if c.face < 0 { s.translate(cx, 0); s.scale(-1, 1); s.translate(-cx, 0) }
            let left = cx - f[2] * sc, top = footY - f[1] * sc, sz = 256 * sc
            s.cell(c.id, ((c.frame % 16) + 16) % 16, left, top, left + sz, top + sz, c.alpha)
            s.restore()
        }
        var i = 0
        for c in sim.cs {
            if c.zz > 0.02, let home = c.home {
                let sc = GwSim.sleepCfg(c.id)
                let cell = sc[0] * g.charH, ax = home.x - sc[1] * cell + sc[4] * cell, ay = g.ground - sc[2] * cell + sc[5] * cell, charH = g.charH
                for k in 0..<3 {
                    let p = (sim.time * 0.42 + Double(k) / 3 + Double(i) * 0.29).truncatingRemainder(dividingBy: 1)
                    let za = c.zz * min(1, p / 0.18) * min(1, (1 - p) / 0.4)
                    let hh = (1.5 + 2.2 * p) * u
                    var zx = ax + (charH * 0.06 + p * charH * 0.30) + sin(p * 6.3 + Double(k)) * 0.8 * u, zy = ay - p * charH * 0.7
                    zx = max(hh + 1, min(g.W - hh - 1, zx)); zy = max(hh + 1, zy)
                    zed(s, zx + 0.5 * u, zy + 0.5 * u, hh, al(0x46000000, za))
                    zed(s, zx, zy, hh, al(0xFF8A96FF, za))
                }
            }
            i += 1
        }
        for p in sim.sparks {
            let a1 = max(0, 1 - p.age / p.life)
            let a = Int(a1 * 255) << 24
            if p.type == 1 {
                let r = 2.4 * u
                s.circle(p.x - r * 0.55, p.y, r * 0.62, a | 0xFF5C8A); s.circle(p.x + r * 0.55, p.y, r * 0.62, a | 0xFF5C8A)
                s.poly([p.x - r * 1.12, p.y + r * 0.25, p.x + r * 1.12, p.y + r * 0.25, p.x, p.y + r * 1.6], a | 0xFF5C8A)
            } else if p.type == 2 {
                let k = p.age / p.life, rr = (1.1 + 1.9 * k) * u; let da = Int(a1 * 0.55 * 255) << 24
                s.circle(p.x, p.y, rr, da | 0xD8CEBF); s.circle(p.x + rr * 0.9, p.y - rr * 0.3, rr * 0.7, da | 0xD8CEBF)
            } else { s.circle(p.x, p.y, 1.5 * u, a | 0xFFE58A) }
        }
        return s.items
    }
}

/// 캐릭터 시트(256px 칸 4×4)를 한 번 읽어 칸마다 작게 줄여 둔다 — 위젯은 쓸 수 있는 메모리가 작아서 큰 시트는 바로 놓는다.
enum GwSheets {
    private static var cache: [String: [CGImage]] = [:]
    private static let lock = NSLock()
    static let cellPx = 160
    static func file(_ id: String) -> String { id == "bbosong" ? "bbosong_0" : id }
    static func cell(_ id: String, _ frame: Int) -> CGImage? {
        lock.lock(); defer { lock.unlock() }
        if let a = cache[id] { return a.indices.contains(frame) ? a[frame] : nil }
        let arr = load(file(id))
        cache[id] = arr
        return arr.indices.contains(frame) ? arr[frame] : nil
    }
    private static func load(_ name: String) -> [CGImage] {
        guard let u = Bundle.main.url(forResource: name, withExtension: "webp", subdirectory: "chars3d"), let d = try? Data(contentsOf: u),
              let cg = UIImage(data: d)?.cgImage else { return [] }
        let cw = cg.width / 4, ch = cg.height / 4
        var out: [CGImage] = []
        for i in 0..<16 {
            guard let part = cg.cropping(to: CGRect(x: (i % 4) * cw, y: (i / 4) * ch, width: cw, height: ch)),
                  let ctx = CGContext(data: nil, width: cellPx, height: cellPx, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { out.append(cg); continue }
            ctx.interpolationQuality = .high
            ctx.draw(part, in: CGRect(x: 0, y: 0, width: cellPx, height: cellPx))
            out.append(ctx.makeImage() ?? part)
        }
        return out
    }
}

/// 그리기 목록을 SwiftUI 로 그린다(위젯 · 앱 미리보기 공용). 좌표는 위젯 왼쪽 위 기준 pt.
struct GwStage: View {
    let items: [GwDraw]; let W: Double; let H: Double
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, it in piece(it) }
        }
        .frame(width: W, height: H, alignment: .topLeading)
    }
    @ViewBuilder private func piece(_ it: GwDraw) -> some View {
        switch it.kind {
        case let .cell(id, frame, l, t, r, b, alpha):
            if let cg = GwSheets.cell(id, frame) {
                Image(decorative: cg, scale: 1).resizable().interpolation(.high)
                    .frame(width: max(1, r - l), height: max(1, b - t))
                    .position(x: (l + r) / 2, y: (t + b) / 2)
                    .opacity(alpha).transformEffect(it.m)
            }
        case let .ellipse(cx, cy, rx, ry, argb):
            Ellipse().fill(Color(argb: argb)).frame(width: max(0.1, rx * 2), height: max(0.1, ry * 2)).position(x: cx, y: cy).transformEffect(it.m)
        case let .circle(cx, cy, r, argb):
            Circle().fill(Color(argb: argb)).frame(width: max(0.1, r * 2), height: max(0.1, r * 2)).position(x: cx, y: cy).transformEffect(it.m)
        case let .poly(xy, argb):
            Path { p in
                guard xy.count >= 6 else { return }
                p.move(to: CGPoint(x: xy[0], y: xy[1]))
                var i = 2
                while i + 1 < xy.count { p.addLine(to: CGPoint(x: xy[i], y: xy[i + 1])); i += 2 }
                p.closeSubpath()
            }.fill(Color(argb: argb)).frame(width: W, height: H, alignment: .topLeading).transformEffect(it.m)
        }
    }
}
