import SwiftUI

/// 엔진(/ride-standby)이 정한 '떠 있는 안내(overlay)' 값을 읽는다 — 안드로이드 OvCore.fromMap 의 포팅.
/// ★ 원칙: 글 · 색 · 점 모양 · 현위치 칸 · 경고 단계는 모두 엔진이 정한 값이다. 여기는 JSON 을 모델로 옮길 뿐 계산하지 않는다.
struct OvCell: Hashable {
    var n = "", t = "", g = ""
    var gp = false, hasL = false, hasR = false
    var gc = 0xFF8E8E93, lc = 0xFF8E8E93, rc = 0xFF8E8E93, dc = 0xFF0A84FF, dk = 1
}

struct OvState {
    var active = false, moving = false, pre = false, alertVibe = false
    var line1 = "", line2 = "", line3 = "", pill = "", pillTxt = "", banner = "", destName = ""
    var alert = 0, cur = 0, base = 0
    var alertAt: Int64 = 0                  // 경고 단계가 켜진/바뀐 시각(ms, 엔진이 줌) — 새 경고인지 가리는 데 쓴다
    var cells: [OvCell] = []
    var hasTheme = false
    var bg = 0xFF1C1C1E, fg = 0xFFF2F2F7, sub = 0xFF8E8E93
    var rsSt = "hidden", rsBt = "", rsK = "", rsNm = ""
    var rsEnd = false
    var rsKick = "", rsMode = "", rsChip = ""            // 앱 탑승 시트(RsSheet)가 그릴 값 — 모두 엔진이 정한다
    var rsCbg = 0xFF0A84FF, rsCfg = 0xFFFFFFFF
    var rsBar = -1.0                                      // 출발 뒤 줄어드는 막대(0~1), 없으면 -1
    var rowKind = 0, rowA = "", rowB = ""

    // 안드로이드 OvCore 상수: 승차 대기 주황 · 달리는 중 파랑 · 역에 서 있는 동안 노랑
    static let cWait = 0xFFF0A500, cMove = 0xFF0A84FF, cStop = 0xFFFFD60A

    /// "#rgb" · "#rrggbb" · "#aarrggbb" → 0xAARRGGBB, 못 읽으면 def.
    static func color(_ o: Any?, _ def: Int) -> Int {
        guard let s0 = o as? String else { return def }
        let s = s0.trimmingCharacters(in: .whitespaces)
        guard s.hasPrefix("#") else { return def }
        let h = String(s.dropFirst())
        guard let v = UInt64(h, radix: 16) else { return def }
        switch h.count {
        case 3: let r = Int((v >> 8) & 15) * 17, g = Int((v >> 4) & 15) * 17, b = Int(v & 15) * 17; return 0xFF000000 | r << 16 | g << 8 | b
        case 6: return 0xFF000000 | Int(v)
        case 8: return Int(v)
        default: return def
        }
    }
    private static func str(_ o: Any?, _ max: Int) -> String {
        guard let s = o as? String else { return "" }
        return s.count > max ? String(s.prefix(max)) : s
    }
    private static func int(_ o: Any?) -> Int? {
        guard let n = o as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() else { return nil }
        return n.intValue
    }
    private static func flag(_ o: Any?) -> Bool { (o as? NSNumber)?.boolValue ?? false }

    /// 엔진 overlay 객체 → 모델. 객체가 아니거나 active 가 아니면 active=false 인 빈 모델.
    static func from(_ o: Any?) -> OvState {
        var v = OvState()
        guard let m = o as? [String: Any] else { return v }
        v.line1 = str(m["line1"], 60); v.line2 = str(m["line2"], 60); v.line3 = str(m["line3"], 60)
        v.pill = str(m["pill"], 40); v.pillTxt = str(m["pillTxt"], 60); v.banner = str(m["banner"], 60); v.destName = str(m["destName"], 40)
        v.alertVibe = flag(m["alertVibe"])
        v.active = flag(m["active"]) && !v.line1.isEmpty
        v.moving = flag(m["moving"]); v.pre = flag(m["pre"])
        v.alert = max(0, min(2, int(m["alert"]) ?? 0))
        v.base = max(0, int(m["base"]) ?? 0)
        if let n = m["alertAt"] as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() { v.alertAt = n.int64Value }
        if let cs = m["cells"] as? [[String: Any]] {
            for cm in cs.prefix(150) {
                var c = OvCell()
                c.n = str(cm["n"], 24); c.t = str(cm["t"], 8); c.g = str(cm["g"], 14)
                c.gp = flag(cm["gp"]); c.gc = color(cm["gc"], c.gc)
                c.hasL = ((cm["lc"] as? String)?.isEmpty == false); c.lc = color(cm["lc"], c.lc)
                c.hasR = ((cm["rc"] as? String)?.isEmpty == false); c.rc = color(cm["rc"], c.rc)
                c.dc = color(cm["dc"], c.dc)
                c.dk = max(0, min(3, int(cm["dk"]) ?? 1))
                v.cells.append(c)
            }
        }
        v.cur = max(0, min(max(0, v.cells.count - 1), int(m["cur"]) ?? 0))
        if let t = m["theme"] as? [String: Any] {
            v.hasTheme = true; v.bg = color(t["bg"], v.bg); v.fg = color(t["fg"], v.fg); v.sub = color(t["sub"], v.sub)
        }
        if let r = m["rs"] as? [String: Any] {
            v.rsSt = str(r["st"], 10); v.rsBt = str(r["bt"], 12); v.rsK = str(r["k"], 40); v.rsNm = str(r["nm"], 24); v.rsEnd = flag(r["end"])
            if v.rsSt.isEmpty { v.rsSt = "hidden" }
            v.rsKick = str(r["kick"], 48); v.rsMode = str(r["mode"], 4); v.rsChip = str(r["chip"], 16)
            v.rsCbg = color(r["cbg"], v.rsCbg); v.rsCfg = color(r["cfg"], v.rsCfg)
            if let n = r["bar"] as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() { v.rsBar = max(-1, min(1, n.doubleValue)) }
        }
        if let g = m["getoff"] as? [String: Any], flag(g["on"]), !str(g["a"], 30).isEmpty {
            v.rowKind = 2; v.rowA = str(g["a"], 30); v.rowB = str(g["b"], 60)
        } else if let g = m["reco"] as? [String: Any], flag(g["on"]), !str(g["a"], 40).isEmpty {
            v.rowKind = 1; v.rowA = str(g["a"], 40); v.rowB = str(g["b"], 64)
        }
        return v
    }

    /// 접힌 알약에 보일 글: 엔진이 만든 한 줄 → 이동 중 문구 → 현위치 칸 이름 → 첫 줄.
    var pillText: String {
        if !pillTxt.isEmpty { return pillTxt }
        if !pill.isEmpty { return pill }
        if !cells.isEmpty, cur < cells.count, !cells[cur].n.isEmpty { return cells[cur].n }
        return line1
    }
    /// 지금 있는 역 이름(엔진이 칸에 준 현위치 칸 이름, 없으면 목적지) — 도착 때 함께 보인다.
    var station: String { cells.indices.contains(cur) && !cells[cur].n.isEmpty ? cells[cur].n : destName }
    /// 앱 탑승 시트가 보일 상태인가(올라온 시트 · 기록 직후 되돌리기 · 대기 알약) — 안드로이드 OvCore.rsShown.
    var rsShown: Bool { !rsEnd && (rsSt == "board" || rsSt == "wait" || rsSt == "undo") }
    var waiting: Bool { !rsEnd && (rsSt == "wait" || rsSt == "board") }
    var arrived: Bool { rsSt == "board" && rsEnd && !rsBt.isEmpty }
    /// 현재 칸 점 · 알약 점 색(안드로이드 stateRgb).
    var stateRgb: Int { waiting ? OvState.cWait : moving ? OvState.cMove : OvState.cStop }
}

extension Color {
    init(argb: Int) {
        self.init(.sRGB, red: Double((argb >> 16) & 255) / 255, green: Double((argb >> 8) & 255) / 255, blue: Double(argb & 255) / 255, opacity: Double((argb >> 24) & 255) / 255)
    }
}

/// 경고 테두리(안드로이드 OvCore.spinMs · glow · ringAlpha 와 같은 값). 한 바퀴 시간: 2정거장 전 6초 · 1정거장 전 1.1초.
/// iOS 라이브 액티비티는 계속 돌며 그릴 수 없어서, 갱신될 때마다 빛의 머리가 그 시각만큼 옮겨 간 자리에 서도록 한다.
enum OvRing {
    static func spinMs(_ alert: Int) -> Double { alert == 1 ? 1100 : (alert == 2 ? 6000 : 0) }
    static let glowTail = 0.34, glowBase = 0.30
    static func glow(_ pos: Double, _ head: Double) -> Double {
        var d = head - pos; d -= d.rounded(.down)
        if d >= glowTail { return 0 }
        let t = 1 - d / glowTail
        return t * t
    }
    static func ringAlpha(_ pos: Double, _ head: Double) -> Double { glowBase + (1 - glowBase) * glow(pos, head) }
    /// 시각 → 빛의 머리 위치(0~1).
    static func head(_ alert: Int, at: Date) -> Double {
        let ms = spinMs(alert); guard ms > 0 else { return 0 }
        let t = at.timeIntervalSince1970 * 1000
        return (t.truncatingRemainder(dividingBy: ms)) / ms
    }
    static let rainbow: [Int] = [0xFFFF3B30, 0xFFFF9500, 0xFFFFD60A, 0xFF34C759, 0xFF00C7BE, 0xFF0A84FF, 0xFFAF52DE, 0xFFFF2D92, 0xFFFF3B30]
    static func rainbowAt(_ f: Double) -> Int {
        let x = f * 8, i = min(7, max(0, Int(x))), t = x - Double(i)
        let a = rainbow[i], b = rainbow[i + 1]
        func ch(_ sh: Int) -> Int { Int((Double((a >> sh) & 255) * (1 - t) + Double((b >> sh) & 255) * t).rounded(.down)) }
        return 0xFF000000 | ch(16) << 16 | ch(8) << 8 | ch(0)
    }
}
