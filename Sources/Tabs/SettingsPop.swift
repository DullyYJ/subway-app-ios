import SwiftUI
import UserNotifications
import ActivityKit

/// 설정 '알림 · 편의 기능' 가운데 팝업(안드로이드 ShellActivity.openSetPage · ShellCore.popFacts)의 iOS 쪽 손질.
/// 글 · 스위치 · 순서는 모두 엔진(settings.js settingsPageNotif · settingsPageConv)이 만든다 — 여기서는 iOS 에 없는 것만 다듬는다:
///  · '백그라운드 유지'(배터리 최적화)는 iOS 에 없는 설정이라 줄을 뺀다.
///  · '다른 앱 위에 표시'는 iOS 에서 잠금 화면 · 다이내믹 아일랜드의 실시간 현황(Live Activity)이라 그 말로 바꾼다.
///  · 위젯 추가는 앱이 대신 할 수 없어 아이폰 방식의 안내 화면(gwGuide)을 따로 보인다.
enum SetPop {
    /// 실시간 현황을 사용자가 꺼 두었는가(꺼 두기 = "1"). 기본은 켜짐 — 안드로이드는 처음 꺼 두고 안내로 켜게 하지만 iOS 는 기기 설정(실시간 현황 허용)이 이미 한 겹 더 있다.
    nonisolated static let ovlOffKey = "ovl_ios_off"
    nonisolated static func ovlOn(_ ud: UserDefaults = .standard) -> Bool { ud.string(forKey: ovlOffKey) != "1" }

    /// 팝업 기기 사실(안드로이드 ShellCore.popFacts 와 같은 모양). sam · samw · ig 는 iOS 에 없는 것이라 0.
    nonisolated static func facts(np: [String: Int], denied: Bool, ovl: Bool, granted: Bool, rl: Bool) -> String {
        let n = ["arrive", "transfer", "arrive_reco"].map { "\"\($0)\":\(np[$0] ?? 1)" }.joined(separator: ",")
        return "{\"np\":{\(n)},\"npd\":\(denied ? 1 : 0),\"ovl\":\(ovl ? 1 : 0),\"gr\":\(granted ? 1 : 0),\"sup\":1,\"sam\":0,\"samw\":0,\"ig\":0,\"rl\":\(rl ? 1 : 0)}"
    }

    /// 팝업 바깥 틀: 가운데 · 너비 min(화면−44, 400) · 모서리 20 · 바탕 card · 바깥 흐림 0.68 · 바깥을 누르면 닫힘 — 안드로이드 Dialog 와 같은 값(DlgCard 가 그린다).
    nonisolated static func frame(_ s: Screen) -> Screen {
        var raw = s.raw
        raw["dlg"] = ["w": 400, "mx": 22, "dim": 0.68, "r": 20, "maxh": 0.9, "fill": "card", "tap": ["v": "pg.back"]] as [String: Any]
        return Screen(name: s.name, head: s.head, body: s.body, foot: s.foot, bg: s.bg, raw: raw)
    }

    /// 편의 기능 팝업(conv)을 iOS 에 맞게: 백그라운드 유지 줄을 빼고, 오버레이 줄의 글을 실시간 현황 말로 바꾼다.
    nonisolated static func adaptConv(_ s: Screen, ovl: Bool, granted: Bool) -> Screen {
        var out: [[String: Any]] = []
        for n in s.body {
            let ks = n.d["kids"] as? [[String: Any]] ?? []
            if n.t == "panel", ks.contains(where: { ($0["t"] as? String) == "toggle" && ($0["key"] as? String) == "bg" }) { continue }
            if n.t == "panel", ks.contains(where: { ($0["t"] as? String) == "toggle" && ($0["key"] as? String) == "ovl" }) {
                var d = n.d
                d["kids"] = ks.map { k -> [String: Any] in
                    guard (k["key"] as? String) == "ovl" else { return k }
                    var t = k
                    t["title"] = "잠금 화면 · 다이내믹 아일랜드에 표시"
                    t["sub"] = "탑승 안내 중 현재역 · 남은시간을 잠금 화면과 다이내믹 아일랜드에 띄워요. 광고는 넣지 않아요.\n" + ovlStatus(on: ovl, granted: granted)
                    return t
                }
                out.append(d)
            } else { out.append(n.d) }
        }
        let body = out.enumerated().map { Node(d: $1, id: "body\($0)") }
        return Screen(name: s.name, head: s.head, body: body, foot: s.foot, bg: s.bg, raw: s.raw)
    }
    nonisolated static func ovlStatus(on: Bool, granted: Bool) -> String {
        if !on { return "꺼져 있어요" }
        return granted ? "사용 중 · 탑승 안내 중에 잠금 화면과 다이내믹 아일랜드에 표시돼요" : "권한이 필요해요 · 설정 > 길동무 > 실시간 현황에서 허용해 주세요"
    }

    /// 캐릭터 시계 위젯 안내(안드로이드 'gw' 화면의 iOS 판): 앱이 홈 화면에 위젯을 대신 올릴 수 없어서, 올리는 방법과 아이폰 위젯이 안드로이드와 다른 점을 알려 준다.
    nonisolated static func gwGuide() -> Screen {
        func text(_ s: String, size: Double = 12, bold: Bool = false, color: String = "sub", mt: Double = 0, mb: Double = 0) -> [String: Any] {
            ["t": "text", "s": s, "size": size, "bold": bold, "color": color, "lh": 1.5, "pad": [0, mt, 0, mb]]
        }
        let back: [String: Any] = ["t": "button", "s": "‹ 설정", "size": 14, "h": 42, "r": 12, "bold": true, "fill": "card", "line": "border", "tc": "text", "pad": [14, 12, 14, 0], "act": ["a": "call", "v": "pg.back"]]
        let steps = "1. 홈 화면의 빈 곳을 길게 눌러요.\n2. 왼쪽 위의 + 를 눌러요.\n3. 목록에서 '길동무'를 찾아 '캐릭터 시계 · 검은 글씨' 또는 '흰 글씨'를 골라요.\n4. 작은 크기는 세로형 · 중간 크기는 가로형이에요. [위젯 추가]를 누르면 끝!"
        let panel: [String: Any] = ["t": "panel", "pad": [16, 8, 16, 0], "ip": [16, 16, 16, 16], "fill": "card", "line": "border", "r": 14, "kids": [
            ["t": "text", "s": "캐릭터 시계 위젯", "size": 15, "bold": true, "color": "text", "pad": [0, 0, 0, 4], "lh": 1.3] as [String: Any],
            text("평소엔 캐릭터들이 각자 집에서 자고 있다가, 시계 주변을 돌아다니며 놀아요. 아래 순서로 홈 화면에 올려 주세요.", mb: 10),
            ["t": "box", "s": steps, "size": 12, "lh": 1.7, "color": "text", "fill": "bg", "line": "border", "r": 10, "ip": [12, 10, 12, 10], "pad": [0, 0, 0, 10]] as [String: Any],
            text("아이폰 위젯은 앱처럼 계속 그릴 수 없어서 캐릭터가 2~3초 간격으로 움직여 보여요. 위젯을 누르면 길동무가 열려 커뮤니티 탭으로 가요.", mb: 0)
        ]]
        let body = [back, panel, ["t": "spacer", "h": 28] as [String: Any]].enumerated().map { Node(d: $1, id: "body\($0)") }
        return Screen(name: "settings", head: [], body: body, foot: [], bg: "bg", raw: ["ok": true, "screen": "settings"])
    }
}

/// 설정 하위 화면(안드로이드 openSetPage 의 전체 화면 Dialog): 창 전체를 palette bg 로 덮고, 엔진 화면(맨 위 '‹ 설정' 단추 = pg.back)을 그린다.
/// 열릴 때 아래에서 56 떠오르며 0→1 로 나타난다(안드로이드 slideIn: 340ms · 곡선 0.32,0.72,0,1). 닫을 땐 바로 사라진다. 아이폰답게 왼쪽 가장자리를 오른쪽으로 쓸어도 닫는다.
struct SetSubPage: View {
    let screen: Screen?
    let pal: Palette
    @EnvironmentObject var host: Host
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduce
    var body: some View {
        ZStack {
            (pal.color("bg") ?? Color(.systemBackground)).ignoresSafeArea()
            if let s = screen { ScreenBody(screen: s, pal: pal) } else { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
            Color.clear.frame(width: 22).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).contentShape(Rectangle())          // 왼쪽 가장자리 쓸기
                .gesture(DragGesture(minimumDistance: 12).onEnded { v in
                    if v.translation.width > 70 && abs(v.translation.height) < v.translation.width * 0.6 { host.actPublisher.send(Host.TabAction(tab: "community", a: "call", v: "pg.back", id: "", key: "")) }
                })
        }
        .opacity(shown || reduce ? 1 : 0).offset(y: shown || reduce ? 0 : 56)
        .onAppear { withAnimation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.34)) { shown = true } }
    }
}
