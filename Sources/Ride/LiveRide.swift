import Foundation
import ActivityKit

/// 엔진이 준 overlay 를 다이내믹 아일랜드 · 잠금화면에 그린다. active 가 아니면 치운다. (안드로이드 RideOverlay 의 iOS 판)
@MainActor
final class LiveRide: ObservableObject {
    static let shared = LiveRide()
    @Published var note = ""
    private var activity: Activity<RideActivityAttributes>?
    private var lastVibeAt: Int64 = 0       // 마지막으로 진동을 울린 경고 시각(같은 경고는 한 번만)
    private var lastAlert = ""            // 마지막으로 펼쳐 알린 제목(같은 순간에 다시 펼치지 않는다)

    func apply(_ ov: OvState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { note = "이 기기에서는 실시간 현황(Live Activity)이 꺼져 있어요"; return }
        guard ov.active else { end(); return }
        vibrate(ov)
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

    /// 안드로이드와 같다: 엔진이 경고 단계(alert)를 켰고 설정이 허용했고(alertVibe) 새 경고(alertAt)일 때 한 번만 — 20초 지난 묵은 경고는 울리지 않는다.
    /// (앱이 화면에 떠 있을 때의 진동이다. 잠금·백그라운드에서는 위 알림 소리/진동이 대신한다.)
    private func vibrate(_ ov: OvState) {
        guard ov.alert > 0, ov.alertVibe, ov.alertAt > 0, ov.alertAt != lastVibeAt else { return }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        guard now - ov.alertAt < 20000 else { return }
        lastVibeAt = ov.alertAt
        SceneHapticPlayer.shared.play(ov.alert == 1 ? "alert1" : "alert2")
    }

    func end() {
        guard let a = activity else { return }
        activity = nil; lastAlert = ""; lastVibeAt = 0
        Task { await a.end(nil, dismissalPolicy: .immediate) }
    }
}
