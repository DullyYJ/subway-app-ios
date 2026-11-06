import SwiftUI
import UIKit
import Compression

/// 네이티브 노선도 데이터(metro_native.bin, 형식 GMN1)를 읽는다 — 안드로이드 MetroMapData 와 같은 형식.
/// 이 파일은 SVG 에 이미 있던 도형 · 글자 위치를 읽을 뿐이다. 경로 · 시간 계산은 하지 않는다.
final class MetroData {
    static let kPath: UInt8 = 0, kGlyph: UInt8 = 1, kLabel: UInt8 = 2
    var svgW: CGFloat = 0, svgH: CGFloat = 0
    var bg: UInt32 = 0xFFFFFFFF
    var strings: [String] = []
    var shCmd: [[UInt8]] = [], shCoord: [[Float]] = []
    var clipShape: [Int] = []
    var nOp = 0
    var kind: [UInt8] = [], clip: [Int] = [], bbox: [Float] = []
    var opShape: [Int] = [], opEo: [Bool] = [], opFlags: [UInt8] = [], opMatrix: [[Float]?] = []
    var opFill: [UInt32] = [], opStroke: [UInt32] = [], opSw: [Float] = [], opDash: [[Float]] = []
    var opX: [Float] = [], opY: [Float] = []
    var lbName: [Int] = [], lbAlt: [Int] = [], lbTb: [Float] = [], lbInstStart: [Int] = [], lbInstCount: [Int] = []
    var inShape: [Int] = [], inFill: [UInt32] = [], inX: [Float] = [], inY: [Float] = [], inEn: [Bool] = [], inEo: [Bool] = []
    var filterName: [String] = [], filterState: [[UInt8]] = []
    var labelOps: [Int] = []
    private var labelKey: [String] = []
    private var pathCache: [Int: CGPath] = [:]
    private let lock = NSLock()               // 타일은 여러 스레드에서 그린다

    /// gzip 껍질을 벗겨 날 DEFLATE 를 풀고(Compression 은 헤더 없는 DEFLATE 만 받는다) 파싱한다.
    static func load(gz: Data) -> MetroData? {
        guard gz.count > 18, gz[0] == 0x1f, gz[1] == 0x8b else { return nil }
        var p = 10
        let flg = gz[3]
        if flg & 4 != 0 { let xl = Int(gz[p]) | Int(gz[p + 1]) << 8; p += 2 + xl }
        if flg & 8 != 0 { while p < gz.count, gz[p] != 0 { p += 1 }; p += 1 }
        if flg & 16 != 0 { while p < gz.count, gz[p] != 0 { p += 1 }; p += 1 }
        if flg & 2 != 0 { p += 2 }
        let body = gz.subdata(in: p..<(gz.count - 8))
        guard let raw = try? (body as NSData).decompressed(using: .zlib) as Data else { return nil }
        return MetroData(raw: raw)
    }

    private init?(raw: Data) {
        var r = Reader(raw)
        guard raw.count > 4, raw[0] == 0x47, raw[1] == 0x4D, raw[2] == 0x4E, raw[3] == 0x31 else { return nil }
        r.p = 4
        svgW = CGFloat(r.f32()); svgH = CGFloat(r.f32()); bg = r.u32()
        let ns = Int(r.u32())
        for _ in 0..<ns { let l = Int(r.u16()); strings.append(String(decoding: raw[r.p..<(r.p + l)], as: UTF8.self)); r.p += l }
        let nsh = Int(r.u32())
        for _ in 0..<nsh {
            let nc = Int(r.u32()), nf = Int(r.u32())
            shCmd.append(Array(raw[r.p..<(r.p + nc)])); r.p += nc
            var f = [Float](); f.reserveCapacity(nf)
            for _ in 0..<nf { f.append(r.f32()) }
            shCoord.append(f)
        }
        let ncl = Int(r.u16())
        for _ in 0..<ncl { clipShape.append(Int(r.u32())) }
        let n = Int(r.u32()); nOp = n
        kind = [UInt8](repeating: 0, count: n); clip = [Int](repeating: -1, count: n); bbox = [Float](repeating: 0, count: 4 * n)
        opShape = [Int](repeating: 0, count: n); opEo = [Bool](repeating: false, count: n); opFlags = [UInt8](repeating: 0, count: n)
        opMatrix = [[Float]?](repeating: nil, count: n); opFill = [UInt32](repeating: 0, count: n); opStroke = [UInt32](repeating: 0, count: n)
        opSw = [Float](repeating: 0, count: n); opDash = [[Float]](repeating: [], count: n); opX = [Float](repeating: 0, count: n); opY = [Float](repeating: 0, count: n)
        lbName = [Int](repeating: 0, count: n); lbAlt = [Int](repeating: -1, count: n); lbTb = [Float](repeating: 0, count: 4 * n)
        lbInstStart = [Int](repeating: 0, count: n); lbInstCount = [Int](repeating: 0, count: n)
        var nl = 0
        for i in 0..<n {
            kind[i] = r.u8(); let c = Int16(bitPattern: r.u16()); clip[i] = Int(c)
            for k in 0..<4 { bbox[4 * i + k] = r.f32() }
            switch kind[i] {
            case MetroData.kPath:
                opShape[i] = Int(r.u32())
                let fl = r.u8(); opFlags[i] = fl
                if fl & 1 != 0 { var m = [Float](); for _ in 0..<6 { m.append(r.f32()) }; opMatrix[i] = m }
                if fl & 2 != 0 { opFill[i] = r.u32() }
                if fl & 4 != 0 { opStroke[i] = r.u32(); opSw[i] = r.f32() }
                let nd = Int(r.u8()); var dash = [Float](); for _ in 0..<nd { dash.append(r.f32()) }; opDash[i] = dash
            case MetroData.kGlyph:
                let sv = r.u32(); opShape[i] = Int(sv & 0x7FFF_FFFF); opEo[i] = sv & 0x8000_0000 != 0
                opX[i] = r.f32(); opY[i] = r.f32(); opFill[i] = r.u32()
            case MetroData.kLabel:
                lbName[i] = Int(r.u32()); let alt = Int32(bitPattern: r.u32()); lbAlt[i] = Int(alt)
                for k in 0..<4 { lbTb[4 * i + k] = r.f32() }
                let cnt = Int(r.u16())
                lbInstStart[i] = inShape.count; lbInstCount[i] = cnt
                for _ in 0..<cnt {
                    let sv = r.u32(); inShape.append(Int(sv & 0x7FFF_FFFF)); inEo.append(sv & 0x8000_0000 != 0)
                    inX.append(r.f32()); inY.append(r.f32()); inFill.append(r.u32()); inEn.append(r.u8() != 0)
                }
                nl += 1
            default: return nil
            }
        }
        let nf = Int(r.u8())
        for _ in 0..<nf {
            filterName.append(strings[Int(r.u32())])
            filterState.append(Array(raw[r.p..<(r.p + n)])); r.p += n
        }
        guard r.p == raw.count else { return nil }
        for i in 0..<n where kind[i] == MetroData.kLabel {
            labelOps.append(i); labelKey.append(String(strings[lbName[i]].filter { !$0.isWhitespace }))
        }
    }

    func filterIndex(_ name: String) -> Int { filterName.firstIndex(of: name) ?? 0 }

    /// 도형 번호 → CGPath(M · L · C · Z). 한 번 만든 것은 둔다.
    func path(_ s: Int) -> CGPath {
        lock.lock(); if let p = pathCache[s] { lock.unlock(); return p }; lock.unlock()
        let m = CGMutablePath(), cmd = shCmd[s], f = shCoord[s]
        var k = 0
        for c in cmd {
            switch c {
            case 0: m.move(to: CGPoint(x: CGFloat(f[k]), y: CGFloat(f[k + 1]))); k += 2
            case 1: m.addLine(to: CGPoint(x: CGFloat(f[k]), y: CGFloat(f[k + 1]))); k += 2
            case 2: m.addCurve(to: CGPoint(x: CGFloat(f[k + 4]), y: CGFloat(f[k + 5])), control1: CGPoint(x: CGFloat(f[k]), y: CGFloat(f[k + 1])), control2: CGPoint(x: CGFloat(f[k + 2]), y: CGFloat(f[k + 3]))); k += 6
            default: m.closeSubpath()
            }
        }
        lock.lock(); pathCache[s] = m; lock.unlock()
        return m
    }

    /// 화면 한 점(SVG 좌표)에서 눌린 라벨(손가락 여유 tol). 숨겨진 라벨은 누를 수 없다.
    func hitLabel(x: CGFloat, y: CGFloat, tol: CGFloat, filter: Int) -> Int {
        let st = filterState[max(0, min(filter, filterState.count - 1))]
        var best = -1; var bestD = CGFloat.greatestFiniteMagnitude, bestC = CGFloat.greatestFiniteMagnitude
        for op in labelOps where st[op] != 0 {
            let tx = CGFloat(lbTb[4 * op]), ty = CGFloat(lbTb[4 * op + 1]), tw = CGFloat(lbTb[4 * op + 2]), th = CGFloat(lbTb[4 * op + 3])
            let dx = x < tx ? tx - x : (x > tx + tw ? x - (tx + tw) : 0), dy = y < ty ? ty - y : (y > ty + th ? y - (ty + th) : 0)
            let dd = (dx * dx + dy * dy).squareRoot()
            if dd > tol { continue }
            let cx = tx + tw / 2 - x, cy = ty + th / 2 - y, cc = cx * cx + cy * cy
            if dd < bestD - 1e-4 || (abs(dd - bestD) <= 1e-4 && cc <= bestC) { best = op; bestD = dd; bestC = cc }
        }
        return best
    }
    func labelName(_ op: Int) -> String { strings[lbName[op]] }

    private struct Reader {
        let d: Data; var p = 0
        init(_ d: Data) { self.d = d }
        mutating func u8() -> UInt8 { defer { p += 1 }; return d[p] }
        mutating func u16() -> UInt16 { defer { p += 2 }; return UInt16(d[p]) | UInt16(d[p + 1]) << 8 }
        mutating func u32() -> UInt32 { defer { p += 4 }; return UInt32(d[p]) | UInt32(d[p + 1]) << 8 | UInt32(d[p + 2]) << 16 | UInt32(d[p + 3]) << 24 }
        mutating func f32() -> Float { Float(bitPattern: u32()) }
    }
}

private func cgColor(_ argb: UInt32, state: Int) -> CGColor {
    var a = Double((argb >> 24) & 255) / 255
    if state < 255 { a *= Double(state) / 255 }
    return CGColor(red: Double((argb >> 16) & 255) / 255, green: Double((argb >> 8) & 255) / 255, blue: Double(argb & 255) / 255, alpha: a)
}

/// 타일로 그리는 노선도 면: 보이는 조각(rect)만 문서 순서대로 그린다(안드로이드 MetroRenderer 와 같은 규칙).
final class MetroTiledView: UIView {
    var data: MetroData? { didSet { setNeedsDisplay() } }
    var filter = 0 { didSet { if oldValue != filter { layer.contents = nil; setNeedsDisplay() } } }
    var scaleBase: CGFloat = 1            // 내용 한 칸(SVG 단위)이 화면에서 차지하는 점 수(맞춤 배율)
    var currentZoom: CGFloat = 1

    override class var layerClass: AnyClass { CATiledLayer.self }
    override init(frame: CGRect) {
        super.init(frame: frame)
        if let t = layer as? CATiledLayer { t.levelsOfDetail = 4; t.levelsOfDetailBias = 3; t.tileSize = CGSize(width: 512, height: 512) }
        backgroundColor = .white
        contentScaleFactor = UIScreen.main.scale
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let d = data, let ctx = UIGraphicsGetCurrentContext() else { return }
        let sc = scaleBase
        ctx.setFillColor(cgColor(d.bg, state: 255)); ctx.fill(rect)
        ctx.saveGState()
        ctx.scaleBy(x: sc, y: sc)
        let vx0 = Float(rect.minX / sc), vy0 = Float(rect.minY / sc), vx1 = Float(rect.maxX / sc), vy1 = Float(rect.maxY / sc)
        let st = d.filterState[max(0, min(filter, d.filterState.count - 1))]
        let ptPerSvg = ctx.ctm.a / UIScreen.main.scale                 // SVG 한 칸이 화면에서 차지하는 점 수(확대 반영)
        let lod = ptPerSvg < 0.4                                       // 작게 볼 땐 영문 글자를 건너뛴다(어차피 안 읽힌다)
        var cur = -1
        for i in 0..<d.nOp {
            let state = Int(st[i])
            if state == 0 { continue }
            let b = 4 * i
            if d.bbox[b + 2] < vx0 || d.bbox[b] > vx1 || d.bbox[b + 3] < vy0 || d.bbox[b + 1] > vy1 { continue }
            let c = d.clip[i]
            if c != cur {
                if cur >= 0 { ctx.restoreGState() }
                if c >= 0 { ctx.saveGState(); ctx.addPath(d.path(d.clipShape[c])); ctx.clip() }
                cur = c
            }
            switch d.kind[i] {
            case MetroData.kPath:
                let fl = d.opFlags[i]
                ctx.saveGState()
                if let m = d.opMatrix[i] { ctx.concatenate(CGAffineTransform(a: CGFloat(m[0]), b: CGFloat(m[1]), c: CGFloat(m[2]), d: CGFloat(m[3]), tx: CGFloat(m[4]), ty: CGFloat(m[5]))) }
                if fl & 2 != 0 {
                    ctx.addPath(d.path(d.opShape[i])); ctx.setFillColor(cgColor(d.opFill[i], state: state))
                    ctx.fillPath(using: fl & 8 != 0 ? .evenOdd : .winding)
                }
                if fl & 4 != 0 {
                    ctx.addPath(d.path(d.opShape[i])); ctx.setStrokeColor(cgColor(d.opStroke[i], state: state)); ctx.setLineWidth(CGFloat(d.opSw[i]))
                    ctx.setLineCap(fl & 16 != 0 ? .round : .butt); ctx.setLineJoin(fl & 16 != 0 ? .round : .miter)
                    let dash = d.opDash[i]
                    if dash.isEmpty { ctx.setLineDash(phase: 0, lengths: []) } else { ctx.setLineDash(phase: 0, lengths: dash.map { CGFloat($0) }) }
                    ctx.strokePath()
                }
                ctx.restoreGState()
            case MetroData.kGlyph:
                ctx.saveGState(); ctx.translateBy(x: CGFloat(d.opX[i]), y: CGFloat(d.opY[i]))
                ctx.addPath(d.path(d.opShape[i])); ctx.setFillColor(cgColor(d.opFill[i], state: state)); ctx.fillPath(using: d.opEo[i] ? .evenOdd : .winding)
                ctx.restoreGState()
            default:
                let a = d.lbInstStart[i], n = d.lbInstCount[i]
                for k in a..<(a + n) {
                    if lod && d.inEn[k] { continue }
                    ctx.saveGState(); ctx.translateBy(x: CGFloat(d.inX[k]), y: CGFloat(d.inY[k]))
                    ctx.addPath(d.path(d.inShape[k])); ctx.setFillColor(cgColor(d.inFill[k], state: state)); ctx.fillPath(using: d.inEo[k] ? .evenOdd : .winding)
                    ctx.restoreGState()
                }
            }
        }
        if cur >= 0 { ctx.restoreGState() }
        ctx.restoreGState()
    }
}

/// 노선도: 두 손가락으로 확대 · 한 손가락으로 이동 · 역 글자를 누르면 onStation(역 이름).
struct MetroMapView: UIViewRepresentable {
    let data: MetroData
    let filter: Int
    let onStation: (String) -> Void

    func makeUIView(context: Context) -> UIScrollView {
        let sv = UIScrollView()
        sv.delegate = context.coordinator
        sv.showsHorizontalScrollIndicator = false; sv.showsVerticalScrollIndicator = false
        sv.bouncesZoom = true; sv.backgroundColor = .white
        let v = MetroTiledView(frame: .zero)
        v.data = data
        sv.addSubview(v)
        context.coordinator.content = v; context.coordinator.scroll = sv
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        sv.addGestureRecognizer(tap)
        return sv
    }

    func updateUIView(_ sv: UIScrollView, context: Context) {
        context.coordinator.parent = self
        guard let v = context.coordinator.content else { return }
        // 처음 한 번: 화면 폭에 맞춘다(내용 한 칸 = 화면 폭 / SVG 폭)
        if v.frame.isEmpty, sv.bounds.width > 0 {
            let fit = sv.bounds.width / data.svgW
            v.scaleBase = fit
            v.frame = CGRect(x: 0, y: 0, width: data.svgW * fit, height: data.svgH * fit)
            sv.contentSize = v.frame.size
            sv.minimumZoomScale = 1; sv.maximumZoomScale = 8
            sv.contentOffset = CGPoint(x: max(0, (v.frame.width - sv.bounds.width) / 2), y: max(0, (v.frame.height - sv.bounds.height) / 2))
        }
        let fi = filter
        if v.filter != fi { v.filter = fi }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: MetroMapView
        weak var content: MetroTiledView?
        weak var scroll: UIScrollView?
        init(_ p: MetroMapView) { parent = p }
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { content }
        @objc func tapped(_ g: UITapGestureRecognizer) {
            guard let v = content, let sv = scroll else { return }
            let pt = g.location(in: v)                                  // 내용 좌표(확대 반영)
            let z = max(sv.zoomScale, 0.001)
            let sx = pt.x / v.scaleBase, sy = pt.y / v.scaleBase
            let op = parent.data.hitLabel(x: sx, y: sy, tol: 14 / (v.scaleBase * z), filter: parent.filter)
            if op >= 0 { parent.onStation(parent.data.labelName(op)) }
        }
    }
}
