import Foundation
import CoreGraphics
import UIKit

/// 장면을 그리는 도화지 — 웹 Canvas2D 와 거의 같은 모양(안드로이드 SceneCv.java). 좌표·길이는 모두 '장면 좌표(design px)'.
protocol SceneGrad: AnyObject { @discardableResult func stop(_ pos: Double, _ argb: ARGB) -> SceneGrad }
/// 그림(스프라이트 시트 · 미리 그린 배경 한 장). 크기는 픽셀.
protocol SceneImg: AnyObject { var w: Int { get }; var h: Int { get } }
/// 따로 그려 두는 바탕 그림. cv 는 장면 좌표(w×h)가 dpr 배 촘촘한 픽셀에 대응하는 도화지.
protocol SceneLayer: SceneImg { var cv: SceneCv { get } }

protocol SceneCv: AnyObject {
    func save(); func restore()
    func translate(_ x: Double, _ y: Double); func rotate(_ rad: Double); func scale(_ sx: Double, _ sy: Double)
    func fillStyle(_ argb: ARGB); func fillGrad(_ g: SceneGrad); func strokeStyle(_ argb: ARGB)
    func lineWidth(_ w: Double); func lineCapRound(_ round: Bool)
    /// 이후 그리는 모든 것에 곱해지는 투명도(0~1)
    func globalAlpha(_ a: Double)
    func beginPath(); func moveTo(_ x: Double, _ y: Double); func lineTo(_ x: Double, _ y: Double)
    func quadTo(_ cx: Double, _ cy: Double, _ x: Double, _ y: Double)
    func bezierTo(_ c1x: Double, _ c1y: Double, _ c2x: Double, _ c2y: Double, _ x: Double, _ y: Double)
    func closePath(); func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double)
    /// 시계 방향(화면 y 아래로) a0→a1. Canvas2D arc(…, anticlockwise=false) 와 같다.
    func arc(_ cx: Double, _ cy: Double, _ r: Double, _ a0: Double, _ a1: Double)
    func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ rot: Double, _ a0: Double, _ a1: Double)
    func fill(); func stroke(); func clip(); func fillRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double)
    /// 굵은 글자 크기(장면 px) — 'bold 10px sans-serif'
    func font(_ px: Double)
    /// 가운데 맞춤 · 세로 가운데 기준으로 현재 fillStyle 색 글자를 쓴다.
    func fillTextC(_ s: String, _ x: Double, _ y: Double)
    func measureText(_ s: String) -> Double
    func linear(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) -> SceneGrad
    func radial(_ x0: Double, _ y0: Double, _ r0: Double, _ x1: Double, _ y1: Double, _ r1: Double) -> SceneGrad
    func drawImage(_ img: SceneImg, _ sx: Double, _ sy: Double, _ sw: Double, _ sh: Double, _ dx: Double, _ dy: Double, _ dw: Double, _ dh: Double)
    func drawImage(_ img: SceneImg, _ dx: Double, _ dy: Double, _ dw: Double, _ dh: Double)
    /// 같은 도구로 그릴 수 있는 새 바탕 그림. dpr 만큼 촘촘하게 만든다.
    func newLayer(_ w: Double, _ h: Double, _ dpr: Double) -> SceneLayer
}
extension SceneCv {
    func fillStyle(_ css: String) { fillStyle(SU.css(css)) }
    func strokeStyle(_ css: String) { strokeStyle(SU.css(css)) }
}

// ───────────── CoreGraphics 구현(안드로이드 AndroidCv.java 와 같은 약속) ─────────────
// · arc/ellipse: 이미 그리던 경로가 있으면 현재 점에서 호의 시작점까지 직선으로 잇는다. 한 바퀴는 반바퀴 두 번.
// · globalAlpha 는 색·그라데이션·그림 모두에 곱해진다.
// · 그라데이션은 '곱해진 알파' 기준으로 섞이도록 알파 0 인 멈춤점은 이웃 멈춤점 색을 빌린다(안 그러면 검은 테두리가 낀다).
// 도화지는 y 가 아래로 늘어나는 좌표(SwiftUI Canvas 의 CGContext · 직접 만든 바탕 그림 모두 그렇게 맞춰 쓴다).

final class CGImg: SceneImg {
    let image: CGImage
    init(_ i: CGImage) { image = i }
    var w: Int { image.width }
    var h: Int { image.height }
}

final class CGLayer: SceneLayer {
    private(set) var image: CGImage?
    let ctx: CGContext?; let cv: SceneCv; let pw: Int, ph: Int
    init(_ w: Double, _ h: Double, _ dpr: Double) {
        pw = max(1, Int((w * dpr).rounded())); ph = max(1, Int((h * dpr).rounded()))
        let c = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        c?.translateBy(x: 0, y: CGFloat(ph)); c?.scaleBy(x: CGFloat(dpr), y: -CGFloat(dpr))    // y 가 아래로
        ctx = c
        cv = CGCv(c)
    }
    var w: Int { pw }
    var h: Int { ph }
    /// 그린 것을 한 장으로 굳힌다(그림으로 쓰기 전에 한 번).
    func bake() -> CGImage? { if image == nil { image = ctx?.makeImage() }; return image }
}

private final class CGGrad: SceneGrad {
    let radial: Bool; let x0, y0, r0, x1, y1, r1: Double
    var pos: [Double] = [], col: [ARGB] = []
    var built: CGGradient?
    init(radial: Bool, _ x0: Double, _ y0: Double, _ r0: Double, _ x1: Double, _ y1: Double, _ r1: Double) { self.radial = radial; self.x0 = x0; self.y0 = y0; self.r0 = r0; self.x1 = x1; self.y1 = y1; self.r1 = r1 }
    @discardableResult func stop(_ p: Double, _ argb: ARGB) -> SceneGrad { pos.append(p); col.append(argb); built = nil; return self }
    /// 멈춤점이 하나뿐이면 단색, 없으면 투명, 아니면 nil
    var solid: ARGB? { col.count == 1 ? col[0] : col.isEmpty ? 0 : nil }
    func gradient() -> CGGradient? {
        if let b = built { return b }
        var c = col
        for i in 0..<c.count where (c[i] >> 24) & 255 == 0 {      // 알파 0 인 멈춤점은 이웃 색을 빌린다
            var src = -1
            var j = i - 1; while j >= 0 && src < 0 { if (c[j] >> 24) & 255 != 0 { src = c[j] }; j -= 1 }
            j = i + 1; while j < c.count && src < 0 { if (c[j] >> 24) & 255 != 0 { src = c[j] }; j += 1 }
            if src >= 0 { c[i] = src & 0x00FFFFFF }
        }
        var comps: [CGFloat] = []; var locs: [CGFloat] = []
        for i in 0..<c.count {
            let a = c[i]
            comps += [CGFloat((a >> 16) & 255) / 255, CGFloat((a >> 8) & 255) / 255, CGFloat(a & 255) / 255, CGFloat((a >> 24) & 255) / 255]
            locs.append(CGFloat(min(1, max(0, pos[i]))))
        }
        built = CGGradient(colorSpace: CGColorSpaceCreateDeviceRGB(), colorComponents: comps, locations: locs, count: c.count)
        return built
    }
}

final class CGCv: SceneCv {
    private struct St { var fill: ARGB; var stroke: ARGB; var grad: CGGrad?; var lw: Double; var alpha: Double; var font: Double; var round: Bool }
    private var cg: CGContext?
    private var path = CGMutablePath()
    private var has = false
    private var fillArgb: ARGB = 0xFF000000, strokeArgb: ARGB = 0xFF000000
    private var fillG: CGGrad?
    private var lw = 1.0, alpha = 1.0, fontPx = 10.0, round = false
    private var stack: [St] = []

    init(_ c: CGContext?) { cg = c }
    /// 프레임마다 SwiftUI 가 넘겨 주는 CGContext 로 바꿔 끼운다(상태는 처음 값으로).
    func begin(_ c: CGContext) {
        cg = c; stack.removeAll(); fillArgb = 0xFF000000; strokeArgb = 0xFF000000; fillG = nil; lw = 1; alpha = 1; fontPx = 10; round = false; has = false; path = CGMutablePath()
    }

    func save() { cg?.saveGState(); stack.append(St(fill: fillArgb, stroke: strokeArgb, grad: fillG, lw: lw, alpha: alpha, font: fontPx, round: round)) }
    func restore() {
        guard let s = stack.popLast() else { return }
        fillArgb = s.fill; strokeArgb = s.stroke; fillG = s.grad; lw = s.lw; alpha = s.alpha; fontPx = s.font; round = s.round
        cg?.restoreGState()
    }
    func translate(_ x: Double, _ y: Double) { cg?.translateBy(x: x, y: y) }
    func rotate(_ r: Double) { cg?.rotate(by: CGFloat(r)) }
    func scale(_ sx: Double, _ sy: Double) { cg?.scaleBy(x: sx, y: sy) }

    func fillStyle(_ argb: ARGB) { fillArgb = argb; fillG = nil }
    func fillGrad(_ g: SceneGrad) { fillG = g as? CGGrad }
    func strokeStyle(_ argb: ARGB) { strokeArgb = argb }
    func lineWidth(_ w: Double) { lw = w }
    func lineCapRound(_ r: Bool) { round = r }
    func globalAlpha(_ a: Double) { alpha = a }

    func beginPath() { path = CGMutablePath(); has = false }
    func moveTo(_ x: Double, _ y: Double) { path.move(to: CGPoint(x: x, y: y)); has = true }
    func lineTo(_ x: Double, _ y: Double) { if !has { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }; has = true }
    func quadTo(_ a: Double, _ b: Double, _ x: Double, _ y: Double) { if !has { path.move(to: CGPoint(x: a, y: b)) }; path.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: a, y: b)); has = true }
    func bezierTo(_ a: Double, _ b: Double, _ c: Double, _ d: Double, _ x: Double, _ y: Double) {
        if !has { path.move(to: CGPoint(x: a, y: b)) }
        path.addCurve(to: CGPoint(x: x, y: y), control1: CGPoint(x: a, y: b), control2: CGPoint(x: c, y: d)); has = true
    }
    func closePath() { if has { path.closeSubpath() } }
    func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) { path.addRect(CGRect(x: x, y: y, width: w, height: h)); has = true }
    func arc(_ x: Double, _ y: Double, _ r: Double, _ a0: Double, _ a1: Double) { ellipse(x, y, r, r, 0, a0, a1) }
    func ellipse(_ x: Double, _ y: Double, _ rx: Double, _ ry: Double, _ rot: Double, _ a0: Double, _ a1: Double) {
        var sweep = a1 - a0
        let twoPi = Double.pi * 2
        if sweep >= twoPi - 1e-9 { sweep = twoPi } else { sweep = sweep.truncatingRemainder(dividingBy: twoPi); if sweep < 0 { sweep += twoPi } }
        // 타원 위의 점들을 곡선으로 이어 만든다(회전 포함) — 호를 작은 조각(최대 90도)의 베지어로 나눈다
        let n = max(1, Int(ceil(sweep / (Double.pi / 2))))
        let step = sweep / Double(n)
        let k = 4.0 / 3.0 * tan(step / 4)
        let cr = cos(rot), sr = sin(rot)
        func pt(_ ex: Double, _ ey: Double) -> CGPoint { CGPoint(x: x + ex * cr - ey * sr, y: y + ex * sr + ey * cr) }
        var th = a0
        let start = pt(rx * cos(th), ry * sin(th))
        if has && rot == 0 { path.addLine(to: start) } else if has { path.addLine(to: start) } else { path.move(to: start) }
        for _ in 0..<n {
            let t2 = th + step
            let p0x = rx * cos(th), p0y = ry * sin(th), p3x = rx * cos(t2), p3y = ry * sin(t2)
            let c1 = pt(p0x - k * rx * sin(th), p0y + k * ry * cos(th))
            let c2 = pt(p3x + k * rx * sin(t2), p3y - k * ry * cos(t2))
            path.addCurve(to: pt(p3x, p3y), control1: c1, control2: c2)
            th = t2
        }
        has = true
    }

    private func cgColor(_ argb: ARGB, _ mul: Double) -> CGColor {
        CGColor(red: CGFloat((argb >> 16) & 255) / 255, green: CGFloat((argb >> 8) & 255) / 255, blue: CGFloat(argb & 255) / 255, alpha: CGFloat(Double((argb >> 24) & 255) / 255 * SU.clamp(mul, 0, 1)))
    }
    /// 현재 경로(또는 사각형)를 현재 채움(단색/그라데이션)으로 칠한다
    private func paintFill(_ addShape: (CGContext) -> Void) {
        guard let g = cg else { return }
        if let gr = fillG, gr.solid == nil, let grad = gr.gradient() {
            g.saveGState(); addShape(g); g.clip(); g.setAlpha(CGFloat(SU.clamp(alpha, 0, 1)))
            if gr.radial { g.drawRadialGradient(grad, startCenter: CGPoint(x: gr.x0, y: gr.y0), startRadius: CGFloat(gr.r0), endCenter: CGPoint(x: gr.x1, y: gr.y1), endRadius: CGFloat(max(0.001, gr.r1)), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]) }
            else {
                var ex = gr.x1 - gr.x0, ey = gr.y1 - gr.y0
                if ex * ex + ey * ey < 1e-9 { ey = 1e-3; ex = 0 }
                g.drawLinearGradient(grad, start: CGPoint(x: gr.x0, y: gr.y0), end: CGPoint(x: gr.x0 + ex, y: gr.y0 + ey), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
            g.restoreGState()
        } else {
            let c = fillG?.solid ?? fillArgb
            g.setFillColor(cgColor(c, alpha)); addShape(g); g.fillPath()
        }
    }
    func fill() { let p = path; paintFill { $0.addPath(p) } }
    func fillRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) { paintFill { $0.addRect(CGRect(x: x, y: y, width: w, height: h)) } }
    func stroke() {
        guard let g = cg else { return }
        g.setStrokeColor(cgColor(strokeArgb, alpha)); g.setLineWidth(CGFloat(lw)); g.setLineCap(round ? .round : .butt); g.setLineJoin(.miter); g.setMiterLimit(10)
        g.addPath(path); g.strokePath()
    }
    func clip() { guard let g = cg else { return }; g.addPath(path); g.clip() }

    func font(_ px: Double) { fontPx = px }
    private var uiFont: UIFont { UIFont.boldSystemFont(ofSize: CGFloat(fontPx)) }
    func fillTextC(_ s: String, _ x: Double, _ y: Double) {
        guard let g = cg, !s.isEmpty else { return }
        let f = uiFont, c = fillG?.solid ?? fillArgb
        let attrs: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: UIColor(cgColor: cgColor(c, alpha))]
        let w = (s as NSString).size(withAttributes: attrs).width
        let baseline = y + Double(f.ascender + f.descender) / 2          // 안드로이드: baseline = y - (ascent+descent)/2
        UIGraphicsPushContext(g)
        (s as NSString).draw(at: CGPoint(x: x - Double(w) / 2, y: baseline - Double(f.ascender)), withAttributes: attrs)
        UIGraphicsPopContext()
    }
    func measureText(_ s: String) -> Double { Double((s as NSString).size(withAttributes: [.font: uiFont]).width) }

    func linear(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) -> SceneGrad { CGGrad(radial: false, x0, y0, 0, x1, y1, 0) }
    func radial(_ x0: Double, _ y0: Double, _ r0: Double, _ x1: Double, _ y1: Double, _ r1: Double) -> SceneGrad { CGGrad(radial: true, x0, y0, r0, x1, y1, r1) }

    private func cgImage(_ i: SceneImg) -> CGImage? { (i as? CGImg)?.image ?? (i as? CGLayer)?.bake() }
    func drawImage(_ img: SceneImg, _ sx: Double, _ sy: Double, _ sw: Double, _ sh: Double, _ dx: Double, _ dy: Double, _ dw: Double, _ dh: Double) {
        guard let g = cg, let im = cgImage(img), let part = im.cropping(to: CGRect(x: sx.rounded(), y: sy.rounded(), width: sw.rounded(), height: sh.rounded())) else { return }
        g.saveGState()
        g.setAlpha(CGFloat(SU.clamp(alpha, 0, 1))); g.interpolationQuality = .medium
        g.translateBy(x: dx, y: dy + dh); g.scaleBy(x: 1, y: -1)           // 그림은 위아래를 뒤집어 그려야 똑바로 선다(y 가 아래로 늘어나는 도화지)
        g.draw(part, in: CGRect(x: 0, y: 0, width: dw, height: dh))
        g.restoreGState()
    }
    func drawImage(_ img: SceneImg, _ dx: Double, _ dy: Double, _ dw: Double, _ dh: Double) { drawImage(img, 0, 0, Double(img.w), Double(img.h), dx, dy, dw, dh) }
    func newLayer(_ w: Double, _ h: Double, _ dpr: Double) -> SceneLayer { CGLayer(w, h, dpr) }
}
