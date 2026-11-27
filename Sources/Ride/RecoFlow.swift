import Foundation
import UIKit
import UserNotifications

/// 하차 7분 전 추천(안드로이드 RideCore.recoBody · recoAd · RecoNotify · ShopRecent · RecoGo 를 한데 옮긴 것).
/// ★ 원칙: 언제 보낼지는 엔진이 정한다 — 탑승 걸음 응답의 reco{fire,arrMs,dest,loc}. 앱은 fire 일 때만 그 값을 POST /reco-text 에 그대로 보내고,
///   돌려받은 글(제목·본문·추천 줄)을 보여 주기만 한다. 앱이 앞에 있으면 팝업(엔진 /screen/dlg kind:reco), 아니면 알림.
enum RecoFlow {
    /// 추천 줄 — 열 곳은 엔진 값(url 이 있으면 쿠팡 상품, 없으면 q/pn/이름으로 카카오맵 검색).
    struct Ad {
        var a = "", b = "", m = "", go = "맛집 보기", url = "", q = "", pn = ""
        var n = false                                  // 가게·상품 없이 글만 있는 추천
        var loc: (Double, Double)? = nil

        /// 지도에서 찾을 말(안드로이드 RideCore.recoQuery): q → pn → 줄 첫머리(" · " 앞).
        var query: String {
            if n { return "" }
            var s = q.trimmingCharacters(in: .whitespaces)
            if s.isEmpty { s = pn.trimmingCharacters(in: .whitespaces) }
            if s.isEmpty { s = (a.components(separatedBy: " · ").first ?? a).trimmingCharacters(in: .whitespaces) }
            return s
        }
    }

    static func str(_ o: Any?, _ max: Int = 600) -> String { String(((o as? String) ?? "").prefix(max)) }

    // MARK: 본문 · 응답 읽기
    /// 엔진 reco → POST /reco-text 본문. fire 가 아니면 nil. 씨앗(무작위 고정)만 도착 시각에서 얻는다(안드로이드 RideCore.recoBody).
    static func body(_ reco: [String: Any], nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) -> String? {
        guard (reco["fire"] as? Bool) == true, let arr = (reco["arrMs"] as? NSNumber)?.int64Value else { return nil }
        var b = "{\"arrMs\":\(arr),\"nowMs\":\(nowMs),\"dest\":\(Json.q(str(reco["dest"], 40))),\"seed\":\(abs(arr / 1000) % 2147483647)"
        if let lo = reco["loc"] as? [String: Any], let la = (lo["lat"] as? NSNumber)?.doubleValue, let ln = (lo["lng"] as? NSNumber)?.doubleValue {
            b += ",\"loc\":{\"lat\":\(la),\"lng\":\(ln)},\"foodPref\":\"server\""
        }
        return b + ",\"aiCopy\":1,\"pickShop\":1}"
    }

    /// /reco-text 응답 → (제목, 본문). 보낼 글이 없으면(시간대 아님 · 오류) nil.
    static func parseText(_ o: [String: Any]) -> (String, String)? {
        guard (o["ok"] as? Bool) == true, (o["slot"] as? String) != "none" else { return nil }
        let t = str(o["title"], 80), b = str(o["body"], 600)
        return t.isEmpty || b.isEmpty ? nil : (t, b)
    }

    /// /reco-text 응답의 ad 줄 → Ad. 줄이 없으면 nil.
    static func parseAd(_ o: [String: Any], loc: (Double, Double)?) -> Ad? {
        guard let ad = o["ad"] as? [String: Any] else { return nil }
        var r = Ad()
        r.a = str(ad["a"], 40); r.b = str(ad["b"], 64); r.m = str(ad["m"], 32)
        if r.a.isEmpty { return nil }
        let shop = (ad["k"] as? String) == "shop"
        r.q = str(ad["q"], 40); r.pn = str(ad["pn"], 40)
        r.go = str(ad["go"], 8)
        if r.go.isEmpty { r.go = shop ? "쿠팡 보기" : "맛집 보기" }
        if shop, let it = o["shopItem"] as? [String: Any] { let u = str(it["u"], 600); if u.hasPrefix("https://") { r.url = u } }
        r.loc = loc
        return r
    }

    /// 가게·상품을 못 골라 글만 온 추천도 팝업에서 보이게 글에서 한 줄을 만든다(안드로이드 RideCore.textAd).
    static func textAd(_ title: String, _ text: String) -> Ad? {
        let t = title.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return nil }
        var r = Ad()
        r.a = String(t.prefix(40))
        r.b = String(text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ").prefix(64))
        r.go = ""; r.n = true
        return r
    }

    // MARK: 최근 보여 준 쿠팡 상품(ShopRecent) — 엔진은 상태가 없어서 앱이 이름을 들고 있다가 요청에 실어 보낸다
    static let recentKey = "shop_recent"
    private static let recentMax = 20
    private static let recentTTL: Int64 = 5 * 86400000
    static func recentNames(stored: String, now: Int64) -> [String] {
        var out: [String] = []
        for ln in stored.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let t = ln.firstIndex(of: "\t"), let ts = Int64(ln[ln.startIndex..<t]) else { continue }
            if now - ts > recentTTL || ts > now + 86400000 { continue }
            out.append(String(ln[ln.index(after: t)...]))
            if out.count >= recentMax { break }
        }
        return out
    }
    static func recentAdd(stored: String, name: String, now: Int64) -> String {
        let nm = name.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ").trimmingCharacters(in: .whitespaces)
        if nm.isEmpty { return stored }
        var lines = ["\(now)\t\(nm)"]
        for ln in stored.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let t = ln.firstIndex(of: "\t"), let ts = Int64(ln[ln.startIndex..<t]) else { continue }
            let x = String(ln[ln.index(after: t)...])
            if x == nm || now - ts > recentTTL || ts > now + 86400000 { continue }
            if lines.count >= recentMax { break }
            lines.append(String(ln))
        }
        return lines.joined(separator: "\n")
    }
    /// 요청 본문(JSON 객체 글)에 "shopRecent":[…] 를 덧붙인다. 이미 있거나 기억이 없으면 그대로.
    static func inject(_ body: String, names: [String]) -> String {
        guard !names.isEmpty, !body.contains("\"shopRecent\""), let e = body.lastIndex(of: "}"), body.trimmingCharacters(in: .whitespaces).hasPrefix("{") else { return body }
        let head = String(body[body.startIndex..<e]).trimmingCharacters(in: .whitespaces)
        let arr = "\"shopRecent\":[" + names.map { Json.q($0) }.joined(separator: ",") + "]"
        return head + (head.hasSuffix("{") ? "" : ",") + arr + String(body[e...])
    }

    // MARK: 열 곳(안드로이드 RecoGo.urls)
    /// [앱 주소(비면 없음), 웹 주소].
    static func urls(shopUrl: String, name: String, loc: (Double, Double)?) -> (String, String) {
        if shopUrl.hasPrefix("https://") { return ("", shopUrl) }
        let q = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        let app = "kakaomap://search?q=" + q + (loc.map { "&p=\($0.0),\($0.1)" } ?? "")
        return (app, "https://map.kakao.com/link/search/" + q)
    }

    @MainActor static func open(_ ad: Ad) {
        let q = ad.query
        if q.isEmpty && ad.url.isEmpty { return }
        let (appU, webU) = urls(shopUrl: ad.url, name: q, loc: ad.loc)
        let openWeb = { if let u = URL(string: webU) { UIApplication.shared.open(u) } }
        if !appU.isEmpty, let u = URL(string: appU) { UIApplication.shared.open(u, options: [:]) { ok in if !ok { Task { @MainActor in openWeb() } } } }
        else { openWeb() }
    }

    // MARK: 시험 알림(설정 > 하차 7분 전 추천 — 안드로이드 ShellCore.arrTestBody)
    /// 그 시간대에 드는 한국시간 시각(커피 08:30 · 점심 12:30 · 야식 19:30 · 쇼핑 22:00)을 도착 시각으로, 그 5분 전을 '지금'으로 엔진에 알려 준다. 도착지는 강남역 좌표. 글은 엔진이 만든다.
    nonisolated static func testBody(kind: String, nowMs: Int64) -> String {
        let min: Int64 = kind == "morning" ? 8 * 60 + 30 : (kind == "lunch" ? 12 * 60 + 30 : (kind == "night" ? 19 * 60 + 30 : 22 * 60))
        let kst: Int64 = 9 * 3600000, day: Int64 = 86400000
        let arr = ((nowMs + kst) / day) * day - kst + min * 60000
        return "{\"arrMs\":\(arr),\"nowMs\":\(arr - 5 * 60000),\"dest\":\"강남\",\"seed\":\(abs(nowMs / 1000) % 2147483647),\"loc\":{\"lat\":37.4979,\"lng\":127.0276},\"foodPref\":\"server\",\"aiCopy\":1,\"pickShop\":1}"
    }
    nonisolated static func testKind(_ v: String) -> String? {
        guard v.hasPrefix("arr.t.") else { return nil }
        let k = String(v.dropFirst(6))
        return ["morning", "lunch", "night", "shop"].contains(k) ? k : nil
    }
    /// 상태 확인에 보일 마지막 발송 단계(안드로이드 RideService.recoStage).
    static var stage = "", stageAt: Int64 = 0, sentAt: Int64 = 0

    // MARK: 보내기
    /// /reco-text 를 받아(최대 두 번) 앱이 앞이면 팝업 · 아니면 알림으로 보인다. 보였으면 sent=true(+ 추천 줄), 보낼 글이 없는 시간대면 false.
    @MainActor static func send(body: String, host: Host, loc: (Double, Double)?, notifyOnly: Bool = false) async -> (sent: Bool, ad: Ad?) {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let stored = UserDefaults.standard.string(forKey: recentKey) ?? ""
        let b = inject(body, names: recentNames(stored: stored, now: now))
        for _ in 0..<2 {
            guard let d = try? await Net.request("POST", Servers.base + "/reco-text", body: b, timeout: 9), let o = Json.obj(d) as? [String: Any] else { continue }
            guard let (title, text) = parseText(o) else { stage = "보낼 시간대 아님"; stageAt = now; return (false, nil) }
            let ad = parseAd(o, loc: loc) ?? textAd(title, text)
            await deliver(title: title, text: text, ad: ad, host: host, notifyOnly: notifyOnly)
            stage = notifyOnly ? "시험 알림 보냄" : "바로 받아 보냄"; stageAt = now; sentAt = now
            if let nm = (o["shopItem"] as? [String: Any])?["n"] as? String, !nm.isEmpty {
                UserDefaults.standard.set(recentAdd(stored: stored, name: nm, now: now), forKey: recentKey)
            }
            return (true, ad)
        }
        stage = "받기 실패"; stageAt = now
        return (false, nil)
    }

    @MainActor private static func deliver(title: String, text: String, ad: Ad?, host: Host, notifyOnly: Bool) async {
        if !notifyOnly, UIApplication.shared.applicationState == .active, await host.showReco(title: title, text: text, ad: ad) { return }
        let c = UNMutableNotificationContent()
        c.title = title; c.body = text; c.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "reco", content: c, trigger: nil), withCompletionHandler: nil)
    }
}
