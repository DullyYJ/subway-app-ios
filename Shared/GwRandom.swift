import Foundation

/// 안드로이드(java.util.Random)와 같은 수열을 내는 난수 — 같은 씨앗이면 위젯 캐릭터가 두 기기에서 같은 걸음을 한다.
struct JRandom {
    private var seed: UInt64
    private static let mask: UInt64 = (1 << 48) - 1
    init(_ s: Int64) { seed = (UInt64(bitPattern: s) ^ 0x5DEECE66D) & Self.mask }
    private mutating func next(_ bits: Int) -> Int32 {
        seed = (seed &* 0x5DEECE66D &+ 0xB) & Self.mask
        return Int32(truncatingIfNeeded: Int64(seed >> UInt64(48 - bits)))
    }
    mutating func nextInt(_ bound: Int) -> Int {
        let b = Int32(bound), m = b &- 1
        var r = next(31)
        if b & m == 0 { return Int((Int64(b) &* Int64(r)) >> 31) }
        var u = r
        while true { r = u % b; if (u &- r &+ m) >= 0 { break }; u = next(31) }
        return Int(r)
    }
    mutating func nextFloat() -> Double { Double(next(24)) / Double(1 << 24) }
    mutating func nextBool() -> Bool { next(1) != 0 }
    /// Collections.shuffle 와 같은 순서.
    mutating func shuffle<T>(_ a: inout [T]) {
        var i = a.count
        while i > 1 { a.swapAt(i - 1, nextInt(i)); i -= 1 }
    }
}
