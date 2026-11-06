import Foundation
import ActivityKit

/// 잠금화면 · 다이내믹 아일랜드(Live Activity)에 보낼 값. 안드로이드 '알약' 오버레이와 같은 뜻 — 모두 엔진 overlay 에서 옮긴 값이고, 계산은 하지 않는다.
/// (ActivityKit 은 한 번에 4KB 까지라 칸 줄은 현위치가 가운데 오는 5칸만 보낸다 — 안드로이드 OvCore.centerPos 와 같다.)
struct RideActivityAttributes: ActivityAttributes {
    struct Cell: Codable, Hashable { var n: String; var t: String; var g: String; var dc: Int; var dk: Int }
    struct ContentState: Codable, Hashable {
        var label: String          // 짧은 상태: 대기 · 이동중 · 정차 · 도착
        var station: String        // 지금 있는 역 이름(도착 때 '명동 도착'으로 보인다)
        var pillText: String       // 엔진이 만든 한 줄(현위치 · 도착 시각)
        var line1: String, line2: String, line3: String
        var banner: String         // 경고 글(1정거장 전 · 2정거장 전 …)
        var alert: Int             // 0 · 1(1정거장 전) · 2(2정거장 전)
        var stateRgb: Int          // 점 색(주황 대기 · 파랑 이동 · 노랑 정차)
        var cells: [Cell]
        var cur: Int               // cells 안의 현위치 번호
        var arrived: Bool
        var rowKind: Int           // 0 없음 · 1 도착 추천 · 2 내릴 준비(환승·하차 직전, 엔진이 정함)
        var rowA: String, rowB: String
        var bg: Int, fg: Int, sub: Int
        var at: Date
    }
    var dest: String
}

extension RideActivityAttributes.ContentState {
    /// 섬 오른쪽 짧은 글: 경고가 있으면 경고, 도착이면 '역이름 도착', 아니면 상태.
    var shortText: String {
        if alert > 0 && !banner.isEmpty { return banner }
        if arrived { return station.isEmpty ? "도착" : "\(station) 도착" }
        return label
    }
    /// 자동으로 펼쳐 알릴 때의 제목(없으면 nil).
    var alertTitle: String? {
        if arrived { return station.isEmpty ? "도착" : "\(station) 도착" }
        if rowKind == 2 && !rowA.isEmpty { return rowA }
        if alert > 0 && !banner.isEmpty { return banner }
        return nil
    }
}

extension RideActivityAttributes.ContentState {
    init(_ v: OvState, now: Date = Date()) {
        let n = v.cells.count
        let lo = n <= 5 ? 0 : min(max(v.cur - 2, 0), n - 5)        // OvCore.centerPos(cur, 0, n)
        let win = n == 0 ? [] : Array(v.cells[lo..<min(n, lo + 5)])
        label = v.arrived ? "도착" : v.waiting ? "대기" : v.moving ? "이동중" : "정차"
        station = v.station
        pillText = v.pillText
        line1 = v.line1; line2 = v.line2; line3 = v.line3; banner = v.banner; alert = v.alert
        stateRgb = v.stateRgb
        cells = win.map { .init(n: $0.n, t: $0.t, g: $0.g, dc: $0.dc, dk: $0.dk) }
        cur = max(0, min(max(0, win.count - 1), v.cur - lo))
        arrived = v.arrived
        rowKind = v.rowKind; rowA = v.rowA; rowB = v.rowB
        bg = v.bg; fg = v.fg; sub = v.sub
        at = now
    }
}
