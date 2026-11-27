import Foundation
import UIKit
import UserNotifications

/// 출퇴근 브리핑 알림 — 예약과 보내기 (안드로이드 native/shell/CommuteAlarm.java 에 해당).
///
/// ★ 원칙: 언제 울릴지(요일 · 시각 · 앞으로 4주치)는 엔진 POST /commute-alarm(op:occ), 알림 제목·본문(날씨 · 혼잡도 · 추천 · 마무리 멘트)은 엔진 POST /commute-brief 가 정한다.
///   여기는 받은 시각마다 알림을 걸고(앞 14번씩), 알림을 누르면 앱 안 가운데 창에 브리핑을 보이고 [출근하기]/[퇴근하기] 로 경로탐색까지 잇는다.
/// ★ 아이폰의 다른 점: 알림이 울리는 순간 앱이 코드를 돌릴 수 없다(안드로이드는 알람 때 엔진 글을 받아 띄운다). 그래서
///   (1) 가장 가까운 알림(12시간 안)은 앱을 열 때마다 엔진 글을 받아 본문을 채워 다시 걸고, (2) 나머지는 짧은 안내 글로 걸어 두며,
///   (3) 알림을 누르면 그때 엔진 글을 새로 받아 창에 보인다. 그래서 앱을 한 번이라도 열어 두면 4주 창이 계속 이어진다.
@MainActor
enum CommuteAlarm {
    static let maxEach = 14
    private static let kOccFp = "cm_occ_fp", kOccResp = "cm_occ_resp"
    private static var seq = 0
    private static var busSeq = 0

    static weak var host: Host?
    private static var pending: (String, String, String, Bool)? = nil          // 앱이 꺼진 채 알림을 눌러 열렸을 때(종류, 제목, 본문, 새 글인가)

    static func nowMs() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
    static func title(_ kind: String) -> String { kind == "eve" ? "퇴근길 브리핑" : "출근길 브리핑" }
    static let genericBody = "눌러서 오늘의 날씨 · 혼잡도 · 준비물을 확인해 보세요."

    private static func enc(_ s: String) -> String {
        var cs = CharacterSet.alphanumerics; cs.insert(charactersIn: "-_.!~*'()")
        return s.addingPercentEncoding(withAllowedCharacters: cs) ?? s
    }
    /// 설정 하위 화면 주소(cmb · cm …) — pf 는 {"pf":{…}} 모양의 기기 사실.
    static func pageUrl(_ page: String, _ pf: String) -> String {
        Servers.base + "/screen/settings?cap=\(Servers.cap)&p=\(page)&f=" + enc(pf)
    }

    private static func lastGps() -> (Double, Double)? {
        guard let l = LocationStore.shared.last else { return nil }
        return (l.coordinate.latitude, l.coordinate.longitude)
    }

    /// 엔진에서 브리핑 글을 받는다(최대 두 번). 못 받으면 nil.
    static func brief(kind: String, eta: Bool = true) async -> (String, String, String)? {
        let body = CmCore.briefBody(kind: kind, nowMs: nowMs(), gps: lastGps(), eta: eta)
        for _ in 0..<2 {
            let (st, d) = await Net.post(Servers.base + "/commute-brief", body, timeout: 10)
            if st == 200, let t = CmCore.parseBrief(d) { return t }
        }
        return nil
    }

    // MARK: 예약
    /// 설정에 맞게 알림을 다시 건다. 꺼져 있으면 모두 지운다.
    static func reschedule() async {
        seq += 1
        let my = seq
        let center = UNUserNotificationCenter.current()
        let old = await center.pendingNotificationRequests().map { $0.identifier }.filter { $0.hasPrefix("cm.") && $0 != "cm.test" }
        if !old.isEmpty { center.removePendingNotificationRequests(withIdentifiers: old) }
        guard CmCore.on() else { return }
        let st = await center.notificationSettings()
        if st.authorizationStatus == .notDetermined { _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge]) }

        let now = nowMs()
        let fp = CmCore.occBody(0), ud = UserDefaults.standard
        var resp: String? = nil
        let (code, d) = await Net.post(Servers.base + "/commute-alarm", CmCore.occBody(now), timeout: 8)
        if code == 200, !d.isEmpty, let s = String(data: d, encoding: .utf8) { resp = s; ud.set(fp, forKey: kOccFp); ud.set(s, forKey: kOccResp) }
        if resp == nil, fp == (ud.string(forKey: kOccFp) ?? "") { resp = ud.string(forKey: kOccResp) }       // 못 받아도 같은 설정의 마지막 답에서 앞으로 남은 시각을 쓴다
        guard let r = resp, !r.isEmpty, my == seq else { return }
        let data = Data(r.utf8)

        for kind in ["morn", "eve"] {
            let at = CmCore.parseOcc(data, kind: kind, max: maxEach).filter { $0 > now }
            if at.isEmpty { continue }
            var fresh: (String, String, String)? = nil
            if at[0] - now <= 12 * 3600 * 1000 { fresh = await brief(kind: kind) }          // 가장 가까운 알림은 엔진 글을 미리 받아 둔다
            guard my == seq else { return }
            for (i, t) in at.enumerated() {
                let c = UNMutableNotificationContent()
                let isFresh = i == 0 && fresh != nil
                c.title = isFresh ? fresh!.0 : title(kind)
                c.body = isFresh ? fresh!.1 : genericBody
                c.sound = .default
                c.userInfo = ["cm": kind, "t": c.title, "b": c.body, "fresh": isFresh]
                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: Date(timeIntervalSince1970: Double(t) / 1000))
                let req = UNNotificationRequest(identifier: "cm.\(kind).\(i)", content: c, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
                try? await center.add(req)
            }
        }
    }

    /// 앱이 앞으로 올 때: 켜져 있으면 알림 창을 다시 민다(가까운 알림 본문도 새로).
    static func refresh() {
        guard CmCore.on() else { return }
        Task { await reschedule() }
    }

    // MARK: 미리보기
    /// '지금 미리보기': 출근/퇴근 어느 브리핑인지와 글은 엔진이 정해(kind:auto) 알림으로 한 번 띄운다.
    static func sendPreview(host: Host) async {
        let center = UNUserNotificationCenter.current()
        let st = await center.notificationSettings()
        if st.authorizationStatus == .notDetermined { _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge]) }
        let after = await center.notificationSettings()
        if after.authorizationStatus == .denied { host.say("알림이 꺼져 있어요. 설정 > 길동무 > 알림을 켜 주세요"); return }
        let tb = await brief(kind: "auto") ?? ("출퇴근 브리핑", "브리핑을 받지 못했어요. 앱에서 확인해 보세요.", "morn")
        let c = UNMutableNotificationContent()
        c.title = tb.0; c.body = tb.1; c.sound = .default
        c.userInfo = ["cm": tb.2, "t": tb.0, "b": tb.1, "fresh": true]
        try? await center.add(UNNotificationRequest(identifier: "cm.test", content: c, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)))
    }

    // MARK: 알림을 눌러 열림
    /// 알림을 눌렀다(또는 앞에서 울렸다) — 앱 안 가운데 창에 브리핑을 보인다. 앱 화면이 아직 없으면 적어 두었다가 화면이 생기면 띄운다.
    static func opened(kind: String, title: String, body: String, fresh: Bool) {
        if let h = host { h.cmbOpen(kind: kind, title: title, body: body, fresh: fresh) } else { pending = (kind, title, body, fresh) }
    }
    static func attach(_ h: Host) {
        host = h
        if let p = pending { pending = nil; h.cmbOpen(kind: p.0, title: p.1, body: p.2, fresh: p.3) }
    }

    // MARK: 출근하기 / 퇴근하기
    /// 설정한 출발·도착을 엔진이 찾아 준 좌표로 넣고 곧바로 경로탐색 — 그 뒤는 경로탐색 그대로.
    static func startRoute(kind: String, host: Host) {
        let home = HomeModel.shared
        if home.isRiding { host.say("탑승 안내 중에는 바꿀 수 없어요"); return }
        host.say("출퇴근 경로를 찾는 중이에요")
        Task {
            let (st, d) = await Net.post(Servers.base + "/commute-brief", CmCore.briefBody(kind: kind, nowMs: nowMs(), gps: nil), timeout: 12)
            guard st == 200, let rt = CmCore.parseRoute(d) else { host.say("출퇴근 장소를 먼저 설정해 주세요 (설정 > 출퇴근 브리핑)"); return }
            home.setPlace(HomeModel.START, type: rt.0.bus ? "bus" : "subway", name: rt.0.name, line: "", lat: rt.0.lat, lng: rt.0.lng)
            home.setPlace(HomeModel.DEST, type: rt.1.bus ? "bus" : "subway", name: rt.1.name, line: "", lat: rt.1.lat, lng: rt.1.lng)
            home.clearRoute()
            host.tab = "home"
            try? await Task.sleep(nanoseconds: 400_000_000)
            home.searchRoute(host: host)
        }
    }

    // MARK: 장소 입력칸의 버스정류장 후보
    /// 글자 q 로 버스정류장을 찾아 CmCore 에 넣는다. 그 사이 글이 바뀌었으면 버린다. 넣었으면 true.
    static func busSearch(_ q: String) async -> Bool {
        busSeq += 1
        let my = busSeq
        let t = q.trimmingCharacters(in: .whitespaces)
        guard t.count >= 2 else { return false }
        var data: Data? = try? await Net.request("GET", Servers.base + "/suggest?k=b&q=\(enc(t))", timeout: 5)
        if data == nil || data!.isEmpty {
            let direct = Servers.bus + "/tago?url=" + enc("https://apis.data.go.kr/1613000/BusSttnInfoInqireService/getSttnNoList?serviceKey=&nodeNm=\(enc(t))&_type=json")
            data = try? await Net.request("GET", direct, timeout: 6)
        }
        guard my == busSeq else { return false }
        var names: [String] = [], geo: [(Double, Double)] = []
        if let d = data, let o = Json.obj(d) as? [String: Any],
           let items = (((o["response"] as? [String: Any])?["body"] as? [String: Any])?["items"]) as? [String: Any] {
            let it = items["item"]
            let l: [[String: Any]] = (it as? [[String: Any]]) ?? ((it as? [String: Any]).map { [$0] } ?? [])
            for m in l {
                let nm = (m["nodenm"] as? String) ?? (m["nodeNm"] as? String) ?? ""
                let la = num(m["gpslati"] ?? m["gpsLati"]), lo = num(m["gpslong"] ?? m["gpsLong"])
                if !nm.isEmpty, la != 0, lo != 0 { names.append(nm); geo.append((la, lo)) }
            }
        }
        guard CmCore.shared.inl else { return false }
        CmCore.shared.setBus(names, geo)
        return true
    }
    private static func num(_ v: Any?) -> Double {
        if let n = v as? NSNumber { return n.doubleValue }
        if let s = v as? String, let d = Double(s) { return d }
        return 0
    }
}

/// 알림 센터 대리자: 앞에서도 알림 배너를 보이고, 출퇴근 브리핑 알림을 누르면 앱 안 브리핑 창을 연다.
final class NotifRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotifRouter()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let kind = (info["cm"] as? String) ?? ""
        let t = (info["t"] as? String) ?? "", b = (info["b"] as? String) ?? ""
        let fresh = (info["fresh"] as? Bool) ?? false
        completionHandler()
        if !kind.isEmpty { Task { @MainActor in CommuteAlarm.opened(kind: kind, title: t, body: b, fresh: fresh) } }
    }
}
