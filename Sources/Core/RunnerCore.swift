import Foundation
import UIKit

/// 경로 탐색 로딩의 "뛰어가는 캐릭터" 계산(안드로이드 RunnerCore.java 와 같은 값·같은 식) + 신발 번호(Chars.java).
/// 시간으로부터 "어느 캐릭터의 몇 번째 칸을 어디에 그릴까"만 정한다. 글(제목·안내)은 엔진이 정한다.
enum RunnerCore {
    static let order = ["dolsom", "lovel", "dudung", "sul", "ppopu", "chaeng", "juksun", "bbosong"]
    static let trackH: CGFloat = 98, wheelTrackW: CGFloat = 150, wheelTrackH: CGFloat = 26
    static let ttlGap: CGFloat = 8, ttlH: CGFloat = 19, subGap: CGFloat = 4, subH: CGFloat = 14
    static let totalH: CGFloat = trackH + ttlGap + ttlH + subGap + subH

    struct Spec { let n = 16; let fps: Int; let cell, base, ox, T, sh, lift: Double; let intro, introFps: Int; let x0: Double }
    static func spec(_ id: String) -> Spec? {
        switch id {
        case "dolsom": return Spec(fps: 19, cell: 86, base: 248.5, ox: 120.8, T: 2.7, sh: 0.34, lift: 0, intro: 0, introFps: 0, x0: 0)
        case "lovel": return Spec(fps: 11, cell: 88, base: 250, ox: 117.9, T: 3.4, sh: 0.34, lift: 0, intro: 0, introFps: 0, x0: 0)
        case "ppopu": return Spec(fps: 19, cell: 88, base: 248.5, ox: 120.3, T: 2.3, sh: 0.34, lift: 0, intro: 0, introFps: 0, x0: 0)
        case "chaeng": return Spec(fps: 15, cell: 88, base: 244.5, ox: 154.5, T: 3.2, sh: 0.2, lift: 12, intro: 0, introFps: 0, x0: 0)
        case "sul": return Spec(fps: 20, cell: 104, base: 230.5, ox: 131, T: 2.6, sh: 0.2, lift: 0, intro: 0, introFps: 0, x0: 0)
        case "dudung": return Spec(fps: 13, cell: 106, base: 222.5, ox: 128, T: 3.5, sh: 0.34, lift: 0, intro: 14, introFps: 14, x0: 0.16)
        case "juksun": return Spec(fps: 12, cell: 90, base: 247.5, ox: 118.4, T: 3.9, sh: 0.34, lift: 0, intro: 0, introFps: 0, x0: 0)
        case "bbosong": return Spec(fps: 12, cell: 80, base: 249, ox: 118.5, T: 3.6, sh: 0.34, lift: 0, intro: 0, introFps: 0, x0: 0)
        default: return nil
        }
    }

    /// 시각(ms)에서 정해지는 0 이상 1 미만의 값(같은 시각이면 같은 값).
    static func unit(_ ms: Int64) -> Double {
        var x = UInt64(bitPattern: ms) &* 0x9E3779B97F4A7C15
        x ^= x >> 32; x = x &* 0xD6E8FEB86659FD93; x ^= x >> 32
        return Double(x & 0xFFFF_FFFF) / 4294967296.0
    }
    /// 방금 나온 것(prev)이 아닌 캐릭터 하나.
    static func pick(_ prev: String, _ r: Double) -> String {
        let a = order.filter { $0 != prev }
        let i = Int(floor(max(0, min(0.999999, r)) * Double(a.count)))
        return a[min(a.count - 1, i)]
    }

    struct Frame { var id = ""; var intro = false; var done = false; var idx = 0; var x: CGFloat = 0; var shadowX: CGFloat = 0; var u = 0.0 }
    /// tMs = 이 캐릭터가 나온 지 지난 시간(ms), wc = 달리는 칸 너비.
    static func at(_ id: String, _ tMs: Int64, _ wc: CGFloat) -> Frame {
        var f = Frame(); f.id = id
        guard let d = spec(id) else { f.done = true; return f }
        let t = Double(max(0, tMs)) / 1000, ti = d.intro > 0 ? Double(d.intro) / Double(d.introFps) : 0
        f.intro = t < ti
        let tw = max(0, t - ti); f.u = tw / d.T; f.done = f.u >= 1
        if d.intro > 0 { let x0 = Double(wc) * d.x0; f.x = CGFloat(f.intro ? x0 : x0 + f.u * (Double(wc) + d.cell * 0.5 - x0)) }
        else { f.x = CGFloat(-d.cell * 0.45 + f.u * (Double(wc) + d.cell * 0.9)) }
        f.idx = f.intro ? min(d.intro - 1, Int(floor(t * Double(d.introFps)))) : Int(floor(tw * Double(d.fps))) % d.n
        f.shadowX = f.x
        return f
    }

    // 바퀴(시트를 못 읽는 동안의 대신)
    static func wheelPhase(_ tMs: Int64) -> CGFloat { CGFloat(Double(max(0, tMs) % 1300) / 1300) }
    static func wheelX(_ tMs: Int64, _ trackW: CGFloat) -> CGFloat { -24 + wheelPhase(tMs) * (trackW + 24) }
    static func wheelRot(_ tMs: Int64) -> CGFloat { wheelPhase(tMs) * 1080 }

    // 말줄임표 점 3개(1.4초 · 점마다 0.2초씩 늦게: 0→1(40%)→0(80%))
    static func dotAlpha(_ tMs: Int64, _ i: Int) -> Double {
        let t = tMs - 200 * Int64(i)
        if t < 0 { return 0 }
        let p = Double(t % 1400) / 1400
        if p < 0.4 { return p / 0.4 }
        if p < 0.8 { return 1 - (p - 0.4) / 0.4 }
        return 0
    }

    // 뽀송의 신발(Chars.java): 20분마다 바뀌고, 4칸씩 묶어 4종을 한 번씩 섞어 신는다(이어진 두 칸은 늘 다른 신발)
    static let shoeMs: Int64 = 20 * 60 * 1000
    private static func perm(_ blk: Int64) -> [Int] {
        var p = [0, 1, 2, 3]; var h = UInt64(bitPattern: blk)
        for i in stride(from: 3, to: 0, by: -1) {
            h = h &* 0x9E3779B97F4A7C15 &+ 0x7F4A7C15; h ^= (h >> 29); h = h &* 0xBF58476D1CE4E5B9; h ^= (h >> 32)
            let j = Int(Int64(bitPattern: h) .floorMod(Int64(i + 1)))
            p.swapAt(i, j)
        }
        return p
    }
    static func shoe(_ nowMs: Int64) -> Int {
        let b = nowMs.floorDiv(shoeMs), blk = b.floorDiv(4), i = Int(b.floorMod(4))
        var p = perm(blk)
        if p[0] == perm(blk - 1)[3] { p.swapAt(0, 1) }
        return p[i]
    }
    /// 시트 열쇠 → 파일 이름
    static func file(_ key: String, _ nowMs: Int64) -> String { key == "bbosong" ? "bbosong_\(shoe(nowMs))" : key }
}

private extension Int64 {
    func floorDiv(_ d: Int64) -> Int64 { let q = self / d; return (self % d != 0 && (self < 0) != (d < 0)) ? q - 1 : q }
    func floorMod(_ d: Int64) -> Int64 { let m = self % d; return (m != 0 && (m < 0) != (d < 0)) ? m + d : m }
}

/// 달리는 캐릭터 시트(256px 칸 4×4 · webp)를 뒤에서 읽어 쥔다. 없으면 nil(바퀴로 대신).
enum RunnerArt {
    private static let lock = NSLock()
    private static var cache: [String: UIImage] = [:]
    private static var loading = Set<String>()
    static func get(_ file: String) -> UIImage? { lock.lock(); defer { lock.unlock() }; return cache[file] }
    static func warm(first: String) {
        var keys = [RunnerCore.file(first, nowMs())]
        for k in RunnerCore.order { let f = RunnerCore.file(k, nowMs()); if !keys.contains(f) { keys.append(f) } }
        keys.append("dudung_intro")
        for f in keys {
            lock.lock(); let skip = cache[f] != nil || loading.contains(f); if !skip { loading.insert(f) }; lock.unlock()
            if skip { continue }
            DispatchQueue.global(qos: .userInitiated).async {
                var img: UIImage? = nil
                if let u = Bundle.main.url(forResource: f, withExtension: "webp", subdirectory: "chars3d"), let d = try? Data(contentsOf: u) { img = UIImage(data: d) }
                lock.lock(); loading.remove(f); if let i = img { cache[f] = i }; lock.unlock()
            }
        }
    }
    private static func nowMs() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
}
