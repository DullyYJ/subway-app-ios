import Foundation

/// 탭마다 직접 받는 원자료 서버(안드로이드 ShellCore · FoodCore 와 같은 주소). 계산은 엔진이 하고, 앱은 받아서 실어 보내기만 한다.
extension Servers {
    static let shop = "https://gildongmu-shop.phg0643.workers.dev"
    static let food = "https://gildongmu-food.phg0643.workers.dev"
    static let board = "https://board-writer.phg0643.workers.dev"
    static let news = "https://gentle-lab-7e47subway-api.phg0643.workers.dev"
    static let bus = "https://gildongmu-bus.phg0643.workers.dev"
}

enum Json {
    /// 값을 JSON 글로(키 순서를 지켜 사람이 읽기 쉽게 — 엔진은 순서에 상관하지 않는다).
    static func text(_ o: Any) -> String {
        guard JSONSerialization.isValidJSONObject(o), let d = try? JSONSerialization.data(withJSONObject: o), let s = String(data: d, encoding: .utf8) else { return "null" }
        return s
    }
    static func obj(_ data: Data) -> Any? { try? JSONSerialization.jsonObject(with: data) }
    /// JSON 글 안의 값이 객체(딕셔너리)인지.
    static func isObject(_ data: Data) -> Bool { obj(data) is [String: Any] }
    static func q(_ s: String) -> String { text([s]).dropFirst().dropLast().description }
}
