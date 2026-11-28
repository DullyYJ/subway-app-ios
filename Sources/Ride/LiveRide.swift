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
        let enabled = ActivityAuthorizationInfo().areActivitiesEnabled
        if ov.active { vibrate(ov) }          // 진동은 실시간 현황을 꺼 둬도 울린다(안드로이드 진동은 오버레이 표시와 따로)
        guard SetPop.ovlOn() else { note = "설정에서 실시간 현황 표시를 꺼 두었어요"; end(); return }          // 설정 > 편의 기능 > 표시 스위치(안드로이드 '다른 앱 위에 표시')
        guard enabled else { note = "이 기기에서는 실시간 현황(Live Activity)이 꺼져 있어요"; return }
        guard ov.active else { end(); return }
        adopt()
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

    /// 앱이 꺼졌다 다시 켜져도(탑승 중) 남아 있는 실시간 현황은 이어 쓴다 — 새로 또 만들면 잠금화면에 같은 카드가 겹쳐 쌓인다. 둘 이상이면 나머지는 치운다.
    private func adopt() {
        let all = Activity<RideActivityAttributes>.activities
        if activity == nil, let f = all.first(where: { $0.activityState == .active }) ?? all.first { activity = f }
        for x in all where x.id != activity?.id { Task { await x.end(nil, dismissalPolicy: .immediate) } }
    }

    func end() {
        let all = Activity<RideActivityAttributes>.activities          // 이 객체가 모르는(앱 재시작 전의) 것까지 모두
        activity = nil; lastAlert = ""; lastVibeAt = 0
        guard !all.isEmpty else { return }
        Task { for a in all { await a.end(nil, dismissalPolicy: .immediate) } }
    }
}
