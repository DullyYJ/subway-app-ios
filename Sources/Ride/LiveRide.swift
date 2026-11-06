import Foundation
import ActivityKit

/// 엔진이 준 overlay 를 다이내믹 아일랜드 · 잠금화면에 그린다. active 가 아니면 치운다. (안드로이드 RideOverlay 의 iOS 판)
@MainActor
final class LiveRide: ObservableObject {
    static let shared = LiveRide()
    @Published var note = ""
    private var activity: Activity<RideActivityAttributes>?

    func apply(_ ov: OvState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { note = "이 기기에서는 실시간 현황(Live Activity)이 꺼져 있어요"; return }
        guard ov.active else { end(); return }
        let content = ActivityContent(state: RideActivityAttributes.ContentState(ov), staleDate: Date().addingTimeInterval(120))
        if let a = activity {
            Task { await a.update(content) }
        } else {
            do { activity = try Activity.request(attributes: RideActivityAttributes(dest: ov.destName), content: content, pushType: nil); note = "" }
            catch { note = "실시간 현황을 시작하지 못했어요: \(error.localizedDescription)" }
        }
    }

    func end() {
        guard let a = activity else { return }
        activity = nil
        Task { await a.end(nil, dismissalPolicy: .immediate) }
    }
}
