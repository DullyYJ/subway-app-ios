import Foundation
import ActivityKit

/// 엔진이 준 overlay 를 다이내믹 아일랜드 · 잠금화면에 그린다. active 가 아니면 치운다. (안드로이드 RideOverlay 의 iOS 판)
@MainActor
final class LiveRide: ObservableObject {
    static let shared = LiveRide()
    @Published var note = ""
    private var activity: Activity<RideActivityAttributes>?
    private var lastAlert = ""            // 마지막으로 펼쳐 알린 제목(같은 순간에 다시 펼치지 않는다)

    func apply(_ ov: OvState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { note = "이 기기에서는 실시간 현황(Live Activity)이 꺼져 있어요"; return }
        guard ov.active else { end(); return }
        let st = RideActivityAttributes.ContentState(ov)
        let content = ActivityContent(state: st, staleDate: Date().addingTimeInterval(120))
        if let a = activity {
            // 1·2정거장 전과 도착이 새로 되는 순간에는 섬이 저절로 펼쳐진다(iOS: 눌러서 펼치기는 안 되고, 앱이 알림으로 펼친다)
            var cfg: AlertConfiguration? = nil
            if let t = st.alertTitle, t != lastAlert {
                cfg = AlertConfiguration(title: LocalizedStringResource(stringLiteral: t), body: LocalizedStringResource(stringLiteral: st.pillText), sound: .default)
            }
            lastAlert = st.alertTitle ?? ""
            Task { if let cfg = cfg { await a.update(content, alertConfiguration: cfg) } else { await a.update(content) } }
        } else {
            lastAlert = st.alertTitle ?? ""
            do { activity = try Activity.request(attributes: RideActivityAttributes(dest: ov.destName), content: content, pushType: nil); note = "" }
            catch { note = "실시간 현황을 시작하지 못했어요: \(error.localizedDescription)" }
        }
    }

    func end() {
        guard let a = activity else { return }
        activity = nil; lastAlert = ""
        Task { await a.end(nil, dismissalPolicy: .immediate) }
    }
}
