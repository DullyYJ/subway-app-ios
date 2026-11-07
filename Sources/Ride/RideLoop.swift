import Foundation
import CoreLocation
import UserNotifications

/// 탑승 안내 루프(안드로이드 RideService + RideCore 의 iOS 판).
/// ★ 원칙(YJ): "모든 계산은 엔진이 한다. 앱은 그림만 그린다."
///  - 앱은 모은 위치(fixes)와 엔진이 준 state 를 그대로 POST /ride-standby 에 보낸다. state 는 해석하지 않고 들고만 있다.
///  - 돌려받은 overlay 는 다이내믹 아일랜드에, alert 는 알림으로 그리고, nextMs 만큼 쉬었다가 다시 보낸다.
///  - 경로 확정(POST /ride/start)으로 받은 state 를 start(stateJson:) 로 넘기면 시작한다(경로 화면은 다음 단계).
@MainActor
final class RideLoop: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = RideLoop()
    static let stepMin: Double = 2.0, stepMax: Double = 8.0, stepDefault: Double = 5.0
    static let sendFix = 12, maxFix = 60

    @Published private(set) var running = false
    @Published private(set) var last = OvState()
    /// 엔진 overlay.share(내 위치 공유 재료) — 탑승 중이고 재료가 있을 때만. 홈 카드의 [내 위치 공유] 버튼과 공유 그림이 쓴다.
    @Published private(set) var share: [String: Any]? = nil
    var hasShare: Bool { share != nil }
    @Published var note = ""
    /// 결과 카드에 실어 보낼 탑승 사실(안드로이드 RideCore.rideJson / lvJson). 엔진이 준 값을 그대로 옮겨 담을 뿐이다.
    @Published private(set) var rideJson = ""
    @Published private(set) var lvJson = ""
    private var text = "", rowJson = "", dtJson = "", cur = -1, posJson = "null", arrJson = "null", waitJson = ""
    private var pendingAct = ""

    private let mgr = CLLocationManager()
    private var stateJson = ""
    private var fixes: [[Any]] = []          // [시각ms, 위도, 경도, 정확도 또는 null]
    private var lastSentTs: Int64 = 0
    private var task: Task<Void, Never>?

    override init() {
        super.init()
        mgr.delegate = self
        mgr.desiredAccuracy = kCLLocationAccuracyBest
        mgr.distanceFilter = 5
        mgr.activityType = .otherNavigation
    }

    func start(stateJson: String, text: String = "") {
        stop()
        self.stateJson = stateJson; fixes = []; lastSentTs = 0
        self.text = text; rowJson = ""; dtJson = ""; cur = -1; posJson = "null"; arrJson = "null"; waitJson = ""; pendingAct = ""
        rebuild()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        mgr.requestWhenInUseAuthorization()
        mgr.allowsBackgroundLocationUpdates = true            // 다른 앱을 쓰는 동안에도 위치를 받는다(Info.plist UIBackgroundModes: location)
        mgr.pausesLocationUpdatesAutomatically = false
        mgr.showsBackgroundLocationIndicator = true
        mgr.startUpdatingLocation()
        running = true
        task = Task { [weak self] in await self?.loop() }
    }

    func stop() {
        task?.cancel(); task = nil
        mgr.stopUpdatingLocation()
        running = false
        LivePosStore.shared.set("")
        rideJson = ""; lvJson = ""
        LiveRide.shared.end(); share = nil
    }

    /// 탑승 중 캐릭터 장면 재료 { here, boarded, key, nodes[{name,isOrigin,isSub,isBus,lineName}] } — 상태에서 이름·종류만 옮겨 담는다(어떤 장면을 보일지는 엔진이 정한다). 없으면 "".
    var sceneJson: String {
        guard running, let st = (try? JSONSerialization.jsonObject(with: Data(stateJson.utf8))) as? [String: Any],
              let eta = st["eta"] as? [String: Any], let nodes = eta["nodes"] as? [[String: Any]] else { return "" }
        var out: [[String: Any]] = []
        for n in nodes.prefix(80) {
            var r: [String: Any] = ["name": String(((n["name"] as? String) ?? "").prefix(24)), "lineName": String(((n["lineName"] as? String) ?? "").prefix(16))]
            if (n["isOrigin"] as? Bool) == true { r["isOrigin"] = true }
            if (n["isSub"] as? Bool) == true { r["isSub"] = true }
            if (n["isBus"] as? Bool) == true { r["isBus"] = true }
            out.append(r)
        }
        if out.count < 2 { return "" }
        let boarded = st["wait"] == nil && (eta["boarded"] as? Bool) != false
        let res: [String: Any] = ["here": max(0, cur), "boarded": boarded, "key": String(((st["tripSig"] as? String) ?? "").prefix(40)), "nodes": out]
        return js(res)
    }

    /// 경로 카드 오른쪽 칸([탑승] · [환승])을 눌렀다 — 다음 걸음에 act 로 엔진에 알린다(안드로이드 pendingAct).
    func press() { pendingAct = "press" }
    var rowSlot: String { ((try? JSONSerialization.jsonObject(with: Data(rowJson.utf8))) as? [String: Any])?["slot"] as? String ?? "" }
    var rowCan: Bool { (((try? JSONSerialization.jsonObject(with: Data(rowJson.utf8))) as? [String: Any])?["can"] as? Bool) ?? false }

    private func js(_ o: Any?) -> String {
        guard let o = o, !(o is NSNull), JSONSerialization.isValidJSONObject(o), let d = try? JSONSerialization.data(withJSONObject: o), let s = String(data: d, encoding: .utf8) else { return "" }
        return s
    }
    private func q(_ s: String) -> String { js([s]).dropFirst().dropLast().description }
    private func rebuild() {
        LivePosStore.shared.set(running ? posJson : "")
        rideJson = "{\"on\":1,\"text\":\(q(text))" + (dtJson.count > 2 ? ",\"dt\":\(q(text))" : "") + (rowJson.count > 2 ? ",\"row\":\(rowJson)" : "") + "}"
        lvJson = "{\"cur\":\(cur),\"pos\":\(posJson),\"arr\":\(arrJson)\(waitJson)" + (dtJson.count > 2 ? ",\"dt\":\(dtJson)" : "") + "}"
    }
    /// 걸음 응답에서 탑승 사실(상주 글 · 줄 · 위치 · 도착 시각 · 승차 대기)을 옮겨 담는다.
    private func readFacts(_ m: [String: Any]) {
        if let on = m["ongoing"] as? [String: Any], let t = on["text"] as? String { text = t }
        if let rw = m["row"] as? [String: Any] { rowJson = js(rw) } else { rowJson = "" }
        if let c = m["curIdx"] as? NSNumber { cur = c.intValue }
        posJson = (m["pos"] as? [String: Any]).map { js($0) } ?? "null"
        arrJson = (m["arr"] as? [Any]).map { js($0) } ?? "null"
        dtJson = (m["dt"] as? [String: Any]).map { js($0) } ?? ""
        waitJson = ""
        if let st = m["state"] as? [String: Any] {
            if let w = st["wait"] as? [String: Any], let i = (w["i"] as? NSNumber)?.intValue, i >= 1 {
                var b = ",\"wait\":{\"i\":\(i)"
                if let la = (w["lat"] as? NSNumber)?.doubleValue, let lo = (w["lng"] as? NSNumber)?.doubleValue {
                    b += ",\"lat\":\(la),\"lng\":\(lo)"
                    if let me = fixes.last, me.count >= 3, let a = me[1] as? Double, let o = me[2] as? Double { b += ",\"me\":[\(a),\(o)]" }
                }
                waitJson = b + "}"
            } else if let x = st["xw"] as? [String: Any], let i = (x["i"] as? NSNumber)?.intValue, i >= 1 { waitJson = ",\"wait\":{\"i\":\(i)}" }
        }
    }

    // MARK: 위치 모으기
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        let add: [[Any]] = locs.map { l in
            [Int64(l.timestamp.timeIntervalSince1970 * 1000), l.coordinate.latitude, l.coordinate.longitude, l.horizontalAccuracy > 0 ? (Int(l.horizontalAccuracy.rounded()) as Any) : (NSNull() as Any)]
        }
        Task { @MainActor in
            self.fixes.append(contentsOf: add)
            if self.fixes.count > RideLoop.maxFix { self.fixes.removeFirst(self.fixes.count - RideLoop.maxFix) }
        }
    }

    // MARK: 걸음(5초마다)
    /// POST /ride-standby 본문 { nowMs, fixes, state } — 위치는 가장 새 sendFix 개만(안드로이드 RideCore.stepBody).
    func stepBody(now: Date = Date()) -> String? {
        let tail = Array(fixes.suffix(RideLoop.sendFix))
        if let ts = tail.last?.first as? Int64 { lastSentTs = ts }
        var b = RideLoopBody.make(nowMs: Int64(now.timeIntervalSince1970 * 1000), fixes: tail, state: stateJson)
        if !pendingAct.isEmpty { b = String(b.dropLast()) + ",\"act\":\(q(pendingAct))}"; pendingAct = "" }
        return b
    }

    private func loop() async {
        while !Task.isCancelled {
            var wait = RideLoop.stepDefault
            if let body = stepBody() {
                do {
                    let d = try await Net.request("POST", Servers.base + "/ride-standby", body: body)
                    wait = apply(d) ?? wait
                } catch { note = "엔진에 닿지 못했어요: \(error.localizedDescription)" }
            }
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
        }
    }

    private static func shareFrom(_ o: Any?) -> [String: Any]? {
        guard let m = o as? [String: Any], let t = m["text"] as? String, !t.isEmpty, let st = m["stations"] as? [[String: Any]], !st.isEmpty else { return nil }
        return m
    }

    /// 응답을 읽어 그린다. 돌려주는 값은 다음 호출까지 쉬는 초. 읽지 못하면 nil(state 는 그대로 — 다음 호출에 다시 보낸다).
    @discardableResult
    func apply(_ data: Data) -> Double? {
        guard let m = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], m["error"] == nil, let st = m["state"] as? [String: Any],
              let sd = try? JSONSerialization.data(withJSONObject: st), let ss = String(data: sd, encoding: .utf8) else { return nil }
        stateJson = ss
        fixes.removeAll { (($0.first as? Int64) ?? 0) <= lastSentTs }          // 보낸 위치는 지운다(그 뒤 들어온 것은 남긴다)
        readFacts(m); rebuild()
        last = OvState.from(m["overlay"])
        share = Self.shareFrom((m["overlay"] as? [String: Any])?["share"])
        LiveRide.shared.apply(last)
        if let a = m["alert"] as? [String: Any] { notify(a) }
        if (m["done"] as? Bool) == true { stop(); return nil }
        let nx = (m["nextMs"] as? NSNumber)?.doubleValue ?? RideLoop.stepDefault * 1000
        return max(RideLoop.stepMin, min(RideLoop.stepMax, nx / 1000))
    }

    /// 엔진 alert {key, type, title, body, vib} → 알림(같은 key 는 한 번만).
    private var shown = Set<String>()
    private func notify(_ a: [String: Any]) {
        let key = (a["key"] as? String) ?? UUID().uuidString
        guard !shown.contains(key) else { return }
        shown.insert(key)
        let c = UNMutableNotificationContent()
        c.title = (a["title"] as? String) ?? "길동무"
        c.body = (a["body"] as? String) ?? ""
        c.sound = .default
        c.interruptionLevel = .timeSensitive
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: key, content: c, trigger: nil))
    }
}

/// 엔진 요청 본문 { nowMs, fixes, state } 짓기(순수 함수 — 시험한다).
enum RideLoopBody {
    static func make(nowMs: Int64, fixes: [[Any]], state: String) -> String {
        guard let fx = try? JSONSerialization.data(withJSONObject: fixes), let fxs = String(data: fx, encoding: .utf8) else { return "{}" }
        return "{\"nowMs\":\(nowMs),\"fixes\":\(fxs),\"state\":\(state.isEmpty ? "null" : state)}"
    }
}
