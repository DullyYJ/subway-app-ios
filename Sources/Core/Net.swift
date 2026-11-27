import Foundation

/// 서버 주소(안드로이드 ShellCore 와 같다).
enum Servers {
    static let base = "https://route-v2.phg0643.workers.dev"
    static let kids = "https://gildongmu-kids.phg0643.workers.dev"   // 키즈 서버(워커 이름이 다르면 여기만 고친다)
    static let cap = 29                                            // 앱이 그릴 수 있는 화면 규격 수준(안드로이드 ShellCore.CAP)
}

enum Net {
    struct Failure: Error, LocalizedError { let msg: String; var errorDescription: String? { msg } }

    static func request(_ method: String, _ url: String, body: String? = nil, timeout: TimeInterval = 12) async throws -> Data {
        guard let u = URL(string: url), u.scheme == "https" else { throw Failure(msg: "https 주소만 써요: \(url)") }
        var r = URLRequest(url: u, timeoutInterval: timeout)
        r.httpMethod = method
        if let b = body { r.httpBody = b.data(using: .utf8); r.setValue("application/json", forHTTPHeaderField: "content-type") }
        let (d, resp) = try await URLSession.shared.data(for: r)
        if let h = resp as? HTTPURLResponse, h.statusCode >= 400 { throw Failure(msg: "서버 \(h.statusCode)") }
        return d
    }

    /// 상태 코드를 그대로 돌려주는 POST(4xx 의 이유 글을 읽어야 할 때). 연결이 안 되면 (0, 빈 데이터).
    static func post(_ url: String, _ body: String, timeout: TimeInterval = 9) async -> (Int, Data) {
        guard let u = URL(string: url), u.scheme == "https" else { return (0, Data()) }
        var r = URLRequest(url: u, timeoutInterval: timeout)
        r.httpMethod = "POST"; r.httpBody = body.data(using: .utf8); r.setValue("application/json", forHTTPHeaderField: "content-type")
        guard let (d, resp) = try? await URLSession.shared.data(for: r) else { return (0, Data()) }
        return ((resp as? HTTPURLResponse)?.statusCode ?? 0, d)
    }

    static func screen(_ path: String, method: String = "POST", body: String? = nil) async throws -> Screen {
        guard let u = URL(string: Servers.base + path) else { throw Failure(msg: "주소가 올바르지 않아요") }
        var r = URLRequest(url: u, timeoutInterval: 12)
        r.httpMethod = method
        if method == "POST" { r.httpBody = (body ?? "{\"cap\":\(Servers.cap)}").data(using: .utf8); r.setValue("application/json", forHTTPHeaderField: "content-type") }
        let (d, resp) = try await URLSession.shared.data(for: r)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 200
        // 엔진이 HTTP 503 과 함께 주는 "서버 연결 지연" 안내 화면(delayed:true · retry:[초…])은 오류가 아니라 그릴 화면이다(안드로이드 fetchCond 와 같다)
        if code == 503, let s = try? Screen.parse(d), s.retryHint != nil { return s }
        if code >= 400 { throw Failure(msg: "서버 \(code)") }
        return try Screen.parse(d)
    }
}
