import Foundation

/// 탑승 엔진의 위치 글(pos.segs 시각표)을 장면 쪽(메인이 아닌 렌더 스레드)이 읽을 수 있게 담아 두는 칸. 앱은 글을 해석하지 않고 그대로 건넨다.
final class LivePosStore: @unchecked Sendable {
    static let shared = LivePosStore()
    private let lock = NSLock(); private var json = ""
    func set(_ s: String) { lock.lock(); json = s; lock.unlock() }
    func get() -> String { lock.lock(); defer { lock.unlock() }; return json }
}
