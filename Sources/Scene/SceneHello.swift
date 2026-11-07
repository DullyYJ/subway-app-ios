import Foundation

/// 홈 '길동무 친구들' 카드를 3초 꾹 누르면(s340, YJ) 카드가 배경 그대로 세로 2배로 슬라이드로 늘어나고,
/// 나머지 친구들이 나와 시간대 인사를 한 뒤 남을 친구들만 남고 들어가며 카드가 다시 줄어든다 — 안드로이드 SceneHello.java.
/// 이 파일은 그 '대본'을 다루는 순수 계산이다. 시간 · 자리 · 차례 · 인사 글은 모두 엔진이 정했다 — 앱 코드에는 글도 숫자도 없다.
enum SceneHello {
    final class Plan {
        var expand = 650, greet = 2300, step = 380, bubble = 900, leave = 5900, collapse = 6150, end = 6800
        var boost = 2.2
        var sx: [Double] = [], sz: [Double] = []
        var order: [Int] = []
        var chars: [String] = []
        var say: [String: String] = [:]
        var rest = false
        var slot = ""
    }

    /// 엔진 대본이 쓸 만한가: 자리 수 = 차례 수 = 친구 수, 모든 친구에게 인사 글이 있고, 시간이 앞뒤가 맞다.
    static func ok(_ p: Plan?) -> Bool {
        guard let p = p, p.chars.count >= 3, p.sx.count == p.chars.count, p.sz.count == p.sx.count, p.order.count == p.sx.count else { return false }
        for c in p.chars { guard let s = p.say[c], !s.isEmpty else { return false } }
        var seen = [Bool](repeating: false, count: p.order.count)
        for o in p.order { if o < 0 || o >= seen.count || seen[o] { return false }; seen[o] = true }
        return p.expand > 0 && p.collapse > p.leave && p.end > p.collapse && Double(p.greet) >= Double(p.expand) * 0.5 && p.leave > p.greet && p.step > 0 && p.bubble > 0
    }

    /// smootherstep(6u⁵−15u⁴+10u³): 처음과 끝의 속도 · 가속이 모두 0 이라 늘어나기 시작할 때와 멈출 때 끊김이 없다.
    static func smoother(_ u0: Double) -> Double { let u = max(0, min(1, u0)); return u * u * u * (u * (u * 6 - 15) + 10) }

    /// 카드가 늘어난 정도 0~1: 처음 expand ms 동안 늘고, collapse 부터 end 까지 줄어든다.
    static func ext(_ p: Plan, _ ms: Double) -> Double {
        if ms <= 0 { return 0 }
        if ms < Double(p.expand) { return smoother(ms / Double(p.expand)) }
        if ms < Double(p.collapse) { return 1 }
        if ms >= Double(p.end) { return 0 }
        return 1 - smoother((ms - Double(p.collapse)) / Double(p.end - p.collapse))
    }

    static func done(_ p: Plan, _ ms: Double) -> Bool { ms >= Double(p.end) }

    /// 자리마다 누가 서는지(자리 번호 → 친구 id). 무작위지만 같은 seed 면 같다(자바 Random + Collections.shuffle 와 같은 수열).
    static func seats(_ p: Plan, _ seed: Int64) -> [String] {
        var pool = p.chars
        let mul = Int64(bitPattern: 0x9E3779B97F4A7C15)
        let rnd = JavaRandom(seed &* mul &+ 0x1234567)
        var i = pool.count
        while i > 1 { let j = rnd.nextInt(i); pool.swapAt(i - 1, j); i -= 1 }
        return pool
    }

    /// 자리 번호 → 인사 차례(0 이 첫째).
    static func rank(_ p: Plan) -> [Int] { var r = [Int](repeating: 0, count: p.order.count); for i in 0..<p.order.count { r[p.order[i]] = i }; return r }
}

/// java.util.Random 과 같은 수열(선형 합동 생성기) — 같은 seed 면 안드로이드와 같은 자리 배치가 나온다.
final class JavaRandom {
    private var seed: Int64
    private static let mask: Int64 = (1 << 48) - 1
    init(_ s: Int64) { seed = (s ^ 0x5DEECE66D) & JavaRandom.mask }
    private func next(_ bits: Int) -> Int32 {
        seed = (seed &* 0x5DEECE66D &+ 0xB) & JavaRandom.mask
        return Int32(truncatingIfNeeded: seed >> Int64(48 - bits))
    }
    func nextInt(_ bound: Int) -> Int {
        let b = Int32(bound); let m = b &- 1
        var r = next(31)
        if (b & (0 &- b)) == b { return Int((Int64(b) &* Int64(r)) >> 31) }
        var u = r; r = u % b
        while u &- r &+ m < 0 { u = next(31); r = u % b }
        return Int(r)
    }
}
