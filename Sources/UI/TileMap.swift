import SwiftUI
import UIKit

/// 타일 지도 계산(안드로이드 TileMapCore 이식): 웹 메르카토르 256px 타일, 소수 줌.
struct TMPin { var la = 0.0, lo = 0.0; var k = "s", n = "", name = "", v = "", g = ""; var h = -1 }

enum TM {
    static let T = 256.0, minZoom = 2.0, maxZoom = 19.0, maxLat = 85.0
    static func world(_ z: Double) -> Double { T * pow(2, z) }
    static func xOf(_ lo: Double, _ z: Double) -> Double { (lo + 180) / 360 * world(z) }
    static func yOf(_ la: Double, _ z: Double) -> Double {
        let l = max(-maxLat, min(maxLat, la)) * .pi / 180
        return (1 - log(tan(l) + 1 / cos(l)) / .pi) / 2 * world(z)
    }
    static func loOf(_ x: Double, _ z: Double) -> Double { x / world(z) * 360 - 180 }
    static func laOf(_ y: Double, _ z: Double) -> Double { atan(sinh(.pi * (1 - 2 * y / world(z)))) * 180 / .pi }

    struct View {
        var cla = 37.5665, clo = 126.9780, zoom = 14.0
        var w = 1.0, h = 1.0
        func toScreen(_ la: Double, _ lo: Double) -> CGPoint {
            CGPoint(x: w / 2 + xOf(lo, zoom) - xOf(clo, zoom), y: h / 2 + yOf(la, zoom) - yOf(cla, zoom))
        }
        func toLatLng(_ sx: Double, _ sy: Double) -> (Double, Double) {
            (laOf(yOf(cla, zoom) + sy - h / 2, zoom), loOf(xOf(clo, zoom) + sx - w / 2, zoom))
        }
        mutating func fit(_ pins: [TMPin], pad: Double, minZ: Double, maxZ: Double) {
            guard !pins.isEmpty else { return }
            let minLa = pins.map { $0.la }.min()!, maxLa = pins.map { $0.la }.max()!
            let minLo = pins.map { $0.lo }.min()!, maxLo = pins.map { $0.lo }.max()!
            var z: Double
            if pins.count == 1 || (maxLa - minLa < 1e-6 && maxLo - minLo < 1e-6) { z = min(16, maxZ) }
            else {
                let aw = max(40, w - 2 * pad), ah = max(40, h - 2 * pad)
                let dx0 = (maxLo - minLo) / 360 * T, dy0 = max(1e-9, yOf(minLa, 0) - yOf(maxLa, 0))
                let zx = dx0 < 1e-9 ? maxZ : log2(aw / dx0), zy = log2(ah / dy0)
                z = max(minZ, min(maxZ, min(zx, zy)))
            }
            zoom = z; clo = (minLo + maxLo) / 2; cla = laOf((yOf(minLa, 0) + yOf(maxLa, 0)) / 2, 0)
            clamp()
        }
        mutating func pan(_ dx: Double, _ dy: Double) {
            let cx = xOf(clo, zoom) - dx, cy = yOf(cla, zoom) - dy
            clo = loOf(cx, zoom); cla = laOf(cy, zoom); clamp()
        }
        mutating func zoomBy(_ d: Double, _ fx: Double, _ fy: Double) {
            let at = toLatLng(fx, fy)
            zoom = max(minZoom, min(maxZoom, zoom + d))
            let cx = xOf(at.1, zoom) - (fx - w / 2), cy = yOf(at.0, zoom) - (fy - h / 2)
            clo = loOf(cx, zoom); cla = laOf(cy, zoom); clamp()
        }
        mutating func clamp() {
            zoom = max(minZoom, min(maxZoom, zoom)); cla = max(-maxLat, min(maxLat, cla))
            while clo > 180 { clo -= 360 }
            while clo < -180 { clo += 360 }
        }
        /// {z, x, y, 화면 x, 화면 y, 한 변}
        func tiles() -> [(Int, Int, Int, Double, Double, Double)] {
            var out: [(Int, Int, Int, Double, Double, Double)] = []
            let tz = Int(max(0, min(19, zoom.rounded())))
            let scale = pow(2, zoom - Double(tz)), cwx = xOf(clo, Double(tz)), cwy = yOf(cla, Double(tz))
            let n = 1 << tz
            let x0 = Int(floor((cwx - w / 2 / scale) / T)), x1 = Int(floor((cwx + w / 2 / scale) / T))
            let y0 = Int(floor((cwy - h / 2 / scale) / T)), y1 = Int(floor((cwy + h / 2 / scale) / T))
            let side = (T * scale + 0.49).rounded()
            if y0 > n - 1 || y1 < 0 { return out }
            for ty in max(0, y0)...min(n - 1, y1) {
                for tx in x0...max(x0, x1) {
                    let wx = ((tx % n) + n) % n
                    let sx = (w / 2 + (Double(tx) * T - cwx) * scale).rounded(), sy = (h / 2 + (Double(ty) * T - cwy) * scale).rounded()
                    out.append((tz, wx, ty, sx, sy, side))
                    if out.count >= 60 { return out }
                }
            }
            return out
        }
    }
}

/// OSM 타일 받기(메모리 캐시). 받으면 tick 이 올라가 지도가 다시 그려진다.
@MainActor
final class TileLoader: ObservableObject {
    static let shared = TileLoader()
    @Published var tick = 0
    private let cache = NSCache<NSString, UIImage>()
    private var busy = Set<String>()
    private var failed = Set<String>()
    private lazy var session: URLSession = {
        let c = URLSessionConfiguration.default
        c.httpAdditionalHeaders = ["User-Agent": "Gildongmu-iOS/1.0 (+https://gildongmu.app)"]
        c.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: c)
    }()
    init() { cache.countLimit = 400 }
    func peek(_ z: Int, _ x: Int, _ y: Int) -> UIImage? {
        let k = "\(z)/\(x)/\(y)"
        if let i = cache.object(forKey: k as NSString) { return i }
        if !busy.contains(k) && !failed.contains(k), let u = URL(string: "https://tile.openstreetmap.org/\(k).png") {
            busy.insert(k)
            Task { [session] in
                let img = (try? await session.data(from: u)).flatMap { UIImage(data: $0.0) }
                await MainActor.run {
                    self.busy.remove(k)
                    if let img = img { self.cache.setObject(img, forKey: k as NSString); self.tick += 1 } else { self.failed.insert(k) }
                }
            }
        }
        return nil
    }
}

private let tmStop = Color(red: 0, green: 0x66 / 255.0, blue: 1)
private let tmFocus = Color(red: 0xE8 / 255.0, green: 0x48 / 255.0, blue: 0x2E / 255.0)
private let tmMe = Color(red: 1, green: 0x9F / 255.0, blue: 0x0A / 255.0)
private let tmFrom = Color(red: 0x2B / 255.0, green: 0x7C / 255.0, blue: 1)
private let tmBg = Color(red: 0xE8 / 255.0, green: 0xEE / 255.0, blue: 0xF4 / 255.0)

private func tmParse(_ pts: [[String: Any]]) -> [TMPin] {
    var out: [TMPin] = []
    for p in pts {
        guard let la = (p["la"] as? NSNumber)?.doubleValue, let lo = (p["lo"] as? NSNumber)?.doubleValue else { continue }
        if abs(la) > 85 || abs(lo) > 180 || (la == 0 && lo == 0) { continue }
        var q = TMPin(); q.la = la; q.lo = lo
        let k = p["k"] as? String ?? "s"; q.k = ["m", "f", "a", "b"].contains(k) ? k : "s"
        q.n = p["n"] as? String ?? ""; q.name = p["l"] as? String ?? ""; q.v = p["v"] as? String ?? ""; q.g = p["g"] as? String ?? ""
        if let h = (p["h"] as? NSNumber)?.intValue, h >= 0, h <= 359 { q.h = h }
        out.append(q); if out.count >= 40 { break }
    }
    return out
}

/// 타일 지도(tmap): 핀 · 번호 · 이름표 · 확대 단추 · 안내 글. 핀은 엔진이 정하고 앱은 타일을 받아 그리기만 한다.
struct TmapNode: View {
    let node: Node; let pal: Palette
    @EnvironmentObject var host: Host
    @ObservedObject private var loader = TileLoader.shared
    @State private var vw = TM.View()
    @State private var sig = ""
    @State private var focus = -1
    @State private var label = false
    @State private var dragBase: TM.View? = nil
    @State private var pinchBase: TM.View? = nil
    @State private var winH: CGFloat = UIScreen.main.bounds.height

    private var pins: [TMPin] { tmParse(node.d["pts"] as? [[String: Any]] ?? []) }
    private var live: Bool { node.num("live", 0) > 0 }
    private var height: CGFloat {
        var th = CGFloat(node.num("h", 200))
        let hv = node.num("hv", 0)
        if hv > 0 {
            th = winH * CGFloat(hv) / 100
            let mn = node.num("hmin", 0), mx = node.num("hmax", 0)
            if mn > 0 { th = max(th, CGFloat(mn)) }
            if mx > 0 { th = min(th, CGFloat(mx)) }
        }
        return th
    }
    private var radius: CGFloat { CGFloat(node.num("r", 12)) }

    private func path() -> [CGPoint] {
        (node.d["line"] as? [[Any]] ?? []).compactMap { a in
            guard a.count >= 2, let la = (a[0] as? NSNumber)?.doubleValue, let lo = (a[1] as? NSNumber)?.doubleValue else { return nil }
            return CGPoint(x: la, y: lo)
        }
    }

    private func setup(_ size: CGSize) {
        let ps = pins
        let key = "\(size.width)x\(size.height)|" + ps.map { "\($0.la),\($0.lo),\($0.k),\($0.n)" }.joined(separator: "|")
        if key == sig { return }
        sig = key
        var v = TM.View(); v.w = Double(size.width); v.h = Double(size.height)
        let fpad = node.num("fp", 0)
        if fpad > 0 && !live {
            var all = ps; for q in path() { var p = TMPin(); p.la = Double(q.x); p.lo = Double(q.y); all.append(p) }
            let mz = node.num("fz", 0) > 0 ? node.num("fz", 17) : 17
            v.fit(all, pad: fpad, minZ: 1, maxZ: mz)
            if all.count == 1 { v.zoom = 17 } else { v.zoom = min(mz, max(1, floor(v.zoom + 1e-6))) }
        } else if live {
            v.fit(ps, pad: 36, minZ: 1, maxZ: 17)
            if ps.count == 1 { v.zoom = 17 } else { v.zoom = max(1, floor(v.zoom + 1e-6)) }
        } else {
            v.fit(ps, pad: 34, minZ: 3, maxZ: 17)
        }
        vw = v
        let foc = Int(node.num("foc", -1))
        focus = foc < ps.count ? foc : -1
        label = false
        if live, focus >= 0, focus < ps.count { vw.cla = ps[focus].la; vw.clo = ps[focus].lo; vw.clamp() }
    }

    var body: some View {
        let h = height, ps = pins
        GeometryReader { geo in
            let size = CGSize(width: geo.size.width, height: h)
            ZStack(alignment: .topLeading) {
                Canvas { ctx, sz in draw(ctx, sz, ps) }
                    .frame(width: size.width, height: h)
                if live { chrome(size) }
            }
            .frame(width: size.width, height: h)
            .background(tmBg)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .contentShape(Rectangle())
            .modifier(TmGestures(live: live, vw: $vw, dragBase: $dragBase, pinchBase: $pinchBase, tap: { tap($0, size, ps) }))
            .overlay(alignment: .bottom) { if node.num("bl", 0) > 0 { Rectangle().fill(pal.color("border") ?? .gray).frame(height: 1) } }
            .onAppear { setup(size) }
            .onChange(of: geo.size.width) { _ in setup(CGSize(width: geo.size.width, height: h)) }
            .onChange(of: pins.map { "\($0.la),\($0.lo),\($0.k),\($0.n)" }.joined()) { _ in setup(size) }
            .onChange(of: node.num("foc", -1)) { f in
                let i = Int(f); focus = i < ps.count ? i : -1; label = false
                if live, focus >= 0 { vw.cla = ps[focus].la; vw.clo = ps[focus].lo; vw.clamp() }
            }
        }
        .frame(height: h)
    }

    // MARK: 누름
    private func tap(_ pt: CGPoint, _ size: CGSize, _ ps: [TMPin]) {
        if live {
            let bsz: CGFloat = 30, bm: CGFloat = 10, bx = size.width - bm - bsz, by = size.height - bm - 2 * bsz
            if pt.x >= bx && pt.x < bx + bsz && pt.y >= by && pt.y < by + 2 * bsz {
                var v = vw; v.zoomBy(pt.y < by + bsz ? 1 : -1, v.w / 2, v.h / 2); vw = v; return
            }
            var best = -1; var bd = 24.0
            for (i, p) in ps.enumerated() where p.k != "m" {
                let s = vw.toScreen(p.la, p.lo), d = hypot(Double(s.x - pt.x), Double(s.y - pt.y))
                if d < bd { bd = d; best = i }
            }
            if best >= 0 {
                focus = best; label = true
                if !ps[best].v.isEmpty { host.handle(.call(ps[best].v)) }
                return
            }
            label = false
            return
        }
        if let a = Action(node.d["act"] as? [String: Any]) { host.handle(a) }
    }

    // MARK: 그림
    private func draw(_ ctx: GraphicsContext, _ sz: CGSize, _ ps: [TMPin]) {
        var v = vw; v.w = Double(sz.width); v.h = Double(sz.height)
        for t in v.tiles() {
            if let img = loader.peek(t.0, t.1, t.2) {
                ctx.draw(Image(uiImage: img), in: CGRect(x: t.3, y: t.4, width: t.5, height: t.5))
            }
        }
        drawRoute(ctx, v)
        // 정류장·장소 → 고른 핀 → 내 위치
        for pass in 0..<3 {
            for (i, p) in ps.enumerated() {
                let isMe = p.k == "m", isF = (live && i == focus) || p.k == "f"
                if pass == 0 && (isMe || isF) { continue }
                if pass == 1 && (isMe || !isF) { continue }
                if pass == 2 && !isMe { continue }
                let s = v.toScreen(p.la, p.lo)
                if s.x < -40 || s.y < -40 || s.x > sz.width + 40 || s.y > sz.height + 40 { continue }
                if isMe { drawMe(ctx, s, p.h) }
                else if p.k == "a" || p.k == "b" { drawEnd(ctx, s, p.n.isEmpty ? (p.k == "a" ? "출발" : "도착") : p.n, p.k == "a" ? tmFrom : tmFocus) }
                else { drawPin(ctx, s, p.n, isF) }
            }
        }
        if label, live, focus >= 0, focus < ps.count, !ps[focus].name.isEmpty {
            let s = v.toScreen(ps[focus].la, ps[focus].lo)
            drawLabel(ctx, CGPoint(x: s.x, y: s.y - 22), ps[focus].name, sz.width)
        }
        // 출처
        let t = Text("© OpenStreetMap").font(.system(size: 9)).foregroundColor(Color(white: 0.27))
        let tw = Typo.width("© OpenStreetMap", 9, false) + 8
        ctx.fill(Path(CGRect(x: sz.width - tw, y: sz.height - 14, width: tw, height: 14)), with: .color(.white.opacity(0.7)))
        ctx.draw(t, at: CGPoint(x: sz.width - tw / 2, y: sz.height - 7), anchor: .center)
        // 안내 글
        if live, let hint = node.str("hint"), !hint.isEmpty {
            let g = Gradient(colors: [.black.opacity(0), .black.opacity(0.45)])
            ctx.fill(Path(CGRect(x: 0, y: sz.height - 26, width: sz.width, height: 26)),
                     with: .linearGradient(g, startPoint: CGPoint(x: 0, y: sz.height - 26), endPoint: CGPoint(x: 0, y: sz.height)))
            ctx.draw(Text(hint).font(Typo.font(11, bold: true)).foregroundColor(.white), at: CGPoint(x: sz.width / 2, y: sz.height - 12), anchor: .center)
        }
    }

    private func drawRoute(_ ctx: GraphicsContext, _ v: TM.View) {
        let pts = path()
        guard pts.count >= 2 else { return }
        var p = Path()
        let sc = pts.map { v.toScreen(Double($0.x), Double($0.y)) }
        p.move(to: sc[0]); for s in sc.dropFirst() { p.addLine(to: s) }
        let col = Color(red: 0xF0 / 255.0, green: 0x78 / 255.0, blue: 0x30 / 255.0)
        ctx.stroke(p, with: .color(col.opacity(0.95)), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [2, 9]))
    }

    private func drawPin(_ ctx: GraphicsContext, _ s: CGPoint, _ n: String, _ focus: Bool) {
        let r: CGFloat = focus ? 16.25 : 13
        ctx.fill(Path(ellipseIn: CGRect(x: s.x - r - 1, y: s.y + 1.5 - r - 1, width: 2 * r + 2, height: 2 * r + 2)), with: .color(.black.opacity(0.2)))
        let c = CGRect(x: s.x - r, y: s.y - r, width: 2 * r, height: 2 * r)
        ctx.fill(Path(ellipseIn: c), with: .color(focus ? tmFocus : tmStop))
        ctx.stroke(Path(ellipseIn: c), with: .color(.white), lineWidth: 2)
        if !n.isEmpty { ctx.draw(Text(n).font(Typo.font(n.count > 2 ? 10 : 12, bold: true)).foregroundColor(.white), at: s, anchor: .center) }
    }

    private func drawMe(_ ctx: GraphicsContext, _ s: CGPoint, _ heading: Int) {
        ctx.fill(Path(ellipseIn: CGRect(x: s.x - 8.7, y: s.y + 1.2 - 8.7, width: 17.4, height: 17.4)), with: .color(.black.opacity(0.3)))
        ctx.fill(Path(ellipseIn: CGRect(x: s.x - 7.5, y: s.y - 7.5, width: 15, height: 15)), with: .color(.white))
        if heading >= 0 {
            var a = Path(); a.move(to: CGPoint(x: 0, y: -20)); a.addLine(to: CGPoint(x: 7, y: -10.5)); a.addLine(to: CGPoint(x: -7, y: -10.5)); a.closeSubpath()
            let t = CGAffineTransform(translationX: s.x, y: s.y).rotated(by: CGFloat(heading) * .pi / 180)
            let pa = a.applying(t)
            ctx.stroke(pa, with: .color(.white), style: StrokeStyle(lineWidth: 4, lineJoin: .round))
            ctx.fill(pa, with: .color(tmMe))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: s.x - 5.5, y: s.y - 5.5, width: 11, height: 11)), with: .color(tmMe))
    }

    private func drawEnd(_ ctx: GraphicsContext, _ s: CGPoint, _ text: String, _ color: Color) {
        let dr: CGFloat = 6.5
        ctx.fill(Path(ellipseIn: CGRect(x: s.x - dr - 1, y: s.y - 2 * dr + 1.2 - 1, width: 2 * dr + 2, height: 2 * dr + 2)), with: .color(.black.opacity(0.3)))
        ctx.fill(Path(ellipseIn: CGRect(x: s.x - dr, y: s.y - 2 * dr, width: 2 * dr, height: 2 * dr)), with: .color(.white))
        ctx.fill(Path(ellipseIn: CGRect(x: s.x - dr + 2, y: s.y - 2 * dr + 2, width: 2 * dr - 4, height: 2 * dr - 4)), with: .color(color))
        let tw = Typo.width(text, 11, true), px: CGFloat = 8, ph: CGFloat = 17, bottom = s.y - 15
        let r = CGRect(x: s.x - tw / 2 - px, y: bottom - ph, width: tw + 2 * px, height: ph)
        ctx.fill(Path(roundedRect: r.offsetBy(dx: 0, dy: 1), cornerRadius: 10), with: .color(.black.opacity(0.3)))
        ctx.fill(Path(roundedRect: r, cornerRadius: 10), with: .color(color))
        ctx.draw(Text(text).font(Typo.font(11, bold: true)).foregroundColor(.white), at: CGPoint(x: r.midX, y: r.midY), anchor: .center)
    }

    private func drawLabel(_ ctx: GraphicsContext, _ at: CGPoint, _ text: String, _ vw: CGFloat) {
        let tw = Typo.width(text, 12, true), padX: CGFloat = 9, h: CGFloat = 24
        let l = max(4, min(vw - tw - 2 * padX - 4, at.x - tw / 2 - padX))
        let r = CGRect(x: l, y: at.y - h, width: tw + 2 * padX, height: h)
        ctx.fill(Path(roundedRect: r, cornerRadius: 8), with: .color(.white.opacity(0.9)))
        ctx.draw(Text(text).font(Typo.font(12, bold: true)).foregroundColor(Color(red: 0x1A / 255.0, green: 0x25 / 255.0, blue: 0x33 / 255.0)), at: CGPoint(x: r.midX, y: r.midY), anchor: .center)
    }

    // 확대·축소 단추(오른쪽 아래 30px 두 칸)
    private func chrome(_ size: CGSize) -> some View {
        VStack(spacing: 0) {
            Text("+").font(Typo.font(18, bold: true)).frame(width: 30, height: 30)
            Rectangle().fill(Color(white: 0.8)).frame(height: 1)
            Text("\u{2212}").font(Typo.font(18, bold: true)).frame(width: 30, height: 29)
        }
        .foregroundColor(Color(white: 0.2))
        .background(RoundedRectangle(cornerRadius: 4).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(.black.opacity(0.2), lineWidth: 2))
        .frame(width: 30, height: 60)
        .position(x: size.width - 10 - 15, y: size.height - 10 - 30)
        .allowsHitTesting(false)
    }
}

private struct TmGestures: ViewModifier {
    let live: Bool
    @Binding var vw: TM.View
    @Binding var dragBase: TM.View?
    @Binding var pinchBase: TM.View?
    let tap: (CGPoint) -> Void
    func body(content: Content) -> some View {
        if live {
            content
                .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                    if abs(g.translation.width) < 4 && abs(g.translation.height) < 4 && dragBase == nil { return }
                    if dragBase == nil { dragBase = vw }
                    var v = dragBase!; v.pan(Double(g.translation.width), Double(g.translation.height)); vw = v
                }.onEnded { g in
                    let moved = dragBase != nil
                    dragBase = nil
                    if !moved { tap(g.location) }
                })
                .simultaneousGesture(MagnificationGesture().onChanged { s in
                    if pinchBase == nil { pinchBase = vw }
                    var v = pinchBase!; v.zoomBy(log2(Double(s)), v.w / 2, v.h / 2); vw = v
                }.onEnded { _ in pinchBase = nil })
        } else {
            content.onTapGesture { tap(.zero) }
        }
    }
}
