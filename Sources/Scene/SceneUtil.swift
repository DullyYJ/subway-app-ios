import Foundation

/// 장면 그림에 쓰는 작은 도구들(수학·색·둥근 사각형·시드 난수) — 안드로이드 SceneUtil.java 와 같은 값·같은 식.
/// 색은 0xAARRGGBB 를 0 이상의 Int 로 쥔다(안드로이드의 부호 있는 int 와 비트가 같다).
typealias ARGB = Int

enum SU {
    static let PI = Double.pi, PI2 = Double.pi * 2

    static func clamp(_ v: Double, _ a: Double, _ b: Double) -> Double { v < a ? a : v > b ? b : v }
    static func ease(_ u0: Double) -> Double { let u = clamp(u0, 0, 1); return u * u * (3 - 2 * u) }

    // ── 색 ──
    private static var cssCache: [String: ARGB] = [:]
    private static let lock = NSLock()
    /// '#rgb' '#rrggbb' 'rgba(r,g,b,a)' 'rgb(r,g,b)' → 0xAARRGGBB (웹 글자 그대로 옮겨 쓰기 위한 것, 결과는 저장해 둔다)
    static func css(_ s: String) -> ARGB {
        lock.lock(); defer { lock.unlock() }
        if let v = cssCache[s] { return v }
        let t = s.trimmingCharacters(in: .whitespaces)
        var r: ARGB = 0xFF000000
        if t.hasPrefix("#") {
            var h = String(t.dropFirst())
            if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
            r = 0xFF000000 | (Int(h, radix: 16) ?? 0)
        } else if let p = t.firstIndex(of: "("), let q = t.lastIndex(of: ")") {
            let f = t[t.index(after: p)..<q].split(separator: ",").map { Double($0.trimmingCharacters(in: .whitespaces)) ?? 0 }
            let a = f.count > 3 ? f[3] : 1
            r = rgba(Int(f[0]), Int(f[1]), Int(f[2]), a)
        }
        cssCache[s] = r
        return r
    }
    static func rgba(_ r: Int, _ g: Int, _ b: Int, _ a: Double) -> ARGB {
        let al = Int((clamp(a, 0, 1) * 255).rounded())
        return (al << 24) | (c255(r) << 16) | (c255(g) << 8) | c255(b)
    }
    private static func c255(_ v: Int) -> Int { v < 0 ? 0 : v > 255 ? 255 : v }
    /// 색의 투명도에 a 를 곱한다.
    static func mulA(_ argb: ARGB, _ a: Double) -> ARGB {
        let al = Int((Double((argb >> 24) & 255) * clamp(a, 0, 1)).rounded())
        return (al << 24) | (argb & 0xFFFFFF)
    }
    static func mix(_ a: ARGB, _ b: ARGB, _ t: Double) -> ARGB {
        let ar = (a >> 16) & 255, ag = (a >> 8) & 255, ab = a & 255, br = (b >> 16) & 255, bg = (b >> 8) & 255, bb = b & 255
        return 0xFF000000 | (rnd255(Double(ar) + Double(br - ar) * t) << 16) | (rnd255(Double(ag) + Double(bg - ag) * t) << 8) | rnd255(Double(ab) + Double(bb - ab) * t)
    }
    static func mix(_ a: String, _ b: String, _ t: Double) -> ARGB { mix(css(a), css(b), t) }
    static func mix(_ a: ARGB, _ b: String, _ t: Double) -> ARGB { mix(a, css(b), t) }
    private static func rnd255(_ v: Double) -> Int { Int(clamp(v.rounded(), 0, 255)) }
    static func shade(_ a: ARGB, _ k: Double) -> ARGB { k >= 0 ? mix(a, 0xFFFFFFFF, k) : mix(a, 0xFF000000, -k) }
    static func shade(_ a: String, _ k: Double) -> ARGB { shade(css(a), k) }

    /// 둥근 사각형 경로
    static func rr(_ c: SceneCv, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r0: Double) {
        let r = min(r0, min(w / 2, h / 2))
        c.beginPath(); c.moveTo(x + r, y); c.lineTo(x + w - r, y); c.quadTo(x + w, y, x + w, y + r); c.lineTo(x + w, y + h - r)
        c.quadTo(x + w, y + h, x + w - r, y + h); c.lineTo(x + r, y + h); c.quadTo(x, y + h, x, y + h - r); c.lineTo(x, y + r); c.quadTo(x, y, x + r, y); c.closePath()
    }

    // ── 시드 난수(배경 그림이 같은 날씨·시간대면 늘 같은 모양이 되게) — 웹의 mulberry 와 같은 수열 ──
    final class Seeded {
        private var a: UInt32
        init(_ seed: Int) { a = UInt32(truncatingIfNeeded: seed) }
        func next() -> Double { r() }
        func r() -> Double {
            a = a &+ 0x6D2B79F5
            var t = a ^ (a >> 15); t = t &* (1 | a)
            var u = t ^ (t >> 7); u = u &* (61 | t)
            t = (t &+ u) ^ t
            return Double(t ^ (t >> 14)) / 4294967296.0
        }
        func r(_ lo: Double, _ hi: Double) -> Double { lo + r() * (hi - lo) }
        func pick(_ n: Int) -> Int { Int(floor(r() * Double(n))) % n }
    }
}

// ── 이식한 그림 코드가 안드로이드 원본처럼 짧게 부를 수 있게 하는 전역 줄임말 ──
let PI = Double.pi, PI2 = Double.pi * 2
@inline(__always) func clamp(_ v: Double, _ a: Double, _ b: Double) -> Double { SU.clamp(v, a, b) }
@inline(__always) func ease(_ u: Double) -> Double { SU.ease(u) }
@inline(__always) func css(_ s: String) -> ARGB { SU.css(s) }
@inline(__always) func rgba(_ r: Int, _ g: Int, _ b: Int, _ a: Double) -> ARGB { SU.rgba(r, g, b, a) }
@inline(__always) func mulA(_ c: ARGB, _ a: Double) -> ARGB { SU.mulA(c, a) }
@inline(__always) func mix(_ a: ARGB, _ b: ARGB, _ t: Double) -> ARGB { SU.mix(a, b, t) }
@inline(__always) func mix(_ a: String, _ b: String, _ t: Double) -> ARGB { SU.mix(a, b, t) }
@inline(__always) func mix(_ a: ARGB, _ b: String, _ t: Double) -> ARGB { SU.mix(a, b, t) }
@inline(__always) func shade(_ a: ARGB, _ k: Double) -> ARGB { SU.shade(a, k) }
@inline(__always) func shade(_ a: String, _ k: Double) -> ARGB { SU.shade(a, k) }
@inline(__always) func rr(_ c: SceneCv, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r: Double) { SU.rr(c, x, y, w, h, r) }

/// 자바 String.hashCode() 와 같은 값(UTF-16 단위 31 진 해시, 32비트 감김) — 같은 장소 이름이면 같은 시드가 되게.
func javaHash(_ s: String) -> Int {
    var h: Int32 = 0
    for u in s.utf16 { h = h &* 31 &+ Int32(u) }
    return Int(h)
}
