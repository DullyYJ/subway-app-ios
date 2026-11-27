import Foundation

/// 같은 버튼을 짧은 시간 안에 거듭 누르면 한 번으로 본다(안드로이드 Debounce.gate · TAP_MS 350ms).
/// 시계를 넣을 수 있어 시험에서는 가짜 시계로 돌린다. 한 스레드(주 스레드)에서만 부른다.
struct TapGate {
    static let tapMs: Int64 = 350          // 같은 탭 버튼 연타를 한 번으로 보는 시간
    private var last: [String: Int64] = [:]

    /// 처음이면 true. 같은 key 가 ms 안에 다시 오면 false(그 눌림은 막힌다).
    mutating func pass(_ key: String, now: Int64, ms: Int64 = TapGate.tapMs) -> Bool {
        if let t = last[key], now - t < ms, now >= t { return false }
        last[key] = now
        return true
    }
}
