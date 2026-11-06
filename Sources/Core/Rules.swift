import Foundation

/// 앱 규칙(욕설 거르기): 판정은 엔진(POST /rules)이 한다. 올려도 되면 "", 안 되면 사용자에게 보일 문구. 엔진이 안 닿으면 막지 않는다(서버도 한 번 더 거른다).
enum Rules {
    static func check(_ kind: String, _ cat: String, _ texts: [String]) async -> String {
        let body = Json.text(["op": "check", "kind": kind, "cat": cat, "texts": texts] as [String: Any])
        guard let d = try? await Net.request("POST", Servers.base + "/rules", body: body, timeout: 6), let o = Json.obj(d) as? [String: Any] else { return "" }
        if (o["ok"] as? Bool) == false { let m = o["msg"] as? String ?? ""; return m.isEmpty ? "등록할 수 없어요" : m }
        return ""
    }

    /// 탄 노선 기록(my_lines): 경로를 확정할 때 이 경로의 노선들을 엔진에 보내 갱신된 목록을 받아 저장한다(안드로이드 RulesCore.applyMyLines).
    static func myLines(_ sec: [String]) async {
        let ud = UserDefaults.standard
        let cur = (ud.string(forKey: "my_lines")?.data(using: .utf8)).flatMap { Json.obj($0) as? [Any] } ?? []
        let body = Json.text(["op": "mylines", "now": Int64(Date().timeIntervalSince1970 * 1000), "my": cur, "sec": sec] as [String: Any])
        guard let d = try? await Net.request("POST", Servers.base + "/rules", body: body, timeout: 8), let o = Json.obj(d) as? [String: Any],
              (o["ok"] as? Bool) == true, let my = o["my"] as? [Any] else { return }
        ud.set(Json.text(my), forKey: "my_lines")
    }
}
