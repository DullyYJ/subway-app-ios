import SwiftUI

private func c6(_ pal: Palette, _ s: String?, _ def: String) -> Color {
    if let s = s, !s.isEmpty, let c = pal.color(s) { return c }
    return pal.color(def) ?? .primary
}
private let cBlue = Color(red: 0, green: 0x66 / 255.0, blue: 1)
private let cSoon = Color(red: 0xE7 / 255.0, green: 0x4C / 255.0, blue: 0x3C / 255.0)

// MARK: 모드 토글(btog) — v=u 밑줄 탭(칸 폭 같음 · 높이 h) / v=p 둥근 단추 + 새로고침(단추 높이 최대 36)
struct BtogNode: View {
    let node: Node; let pal: Palette
    @EnvironmentObject var host: Host
    @ObservedObject private var pick = ChipPick.shared
    private var items: [[String: Any]] { node.d["items"] as? [[String: Any]] ?? [] }
    /// 누른 칸은 새 화면 전에 먼저 켠다(안드로이드 pickBtog).
    private func isOn(_ it: [String: Any]) -> Bool {
        if let p = pick.picks[ChipPick.rowKey(items)], let v = (it["act"] as? [String: Any])?["v"] as? String { return v == p }
        return (it["on"] as? Bool) ?? false
    }
    private func tapItem(_ it: [String: Any]) {
        guard let a = Action(it["act"] as? [String: Any]) else { return }
        if let v = a.v { pick.pick(items: items, v: v) }
        host.handle(a)
    }
    var body: some View {
        let under = (node.str("v") ?? "p") == "u"
        let h = CGFloat(node.num("h", 38))
        let rf = node.d["rf"] as? [String: Any]
        let line = c6(pal, "border", "border")
        return Group {
            if under {
                HStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, it in
                        let on = isOn(it)
                        Button { tapItem(it) } label: {
                            Text(it["label"] as? String ?? "").font(Typo.font(14, bold: true))
                                .foregroundColor(on ? c6(pal, "text", "text") : c6(pal, "sub", "sub"))
                                .frame(maxWidth: .infinity).frame(height: h - 2)
                                .frame(height: h, alignment: .top)
                                .overlay(alignment: .bottom) { if on { Rectangle().fill(c6(pal, "gold", "gold")).frame(height: 2) } }
                        }.buttonStyle(.plain)
                    }
                }
                .frame(height: h).background(c6(pal, "card", "card"))
                .overlay(alignment: .bottom) { Rectangle().fill(line).frame(height: 1) }
            } else {
                let th = min(36, h)
                HStack(spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, it in
                        let on = isOn(it)
                        Button { tapItem(it) } label: {
                            Text(it["label"] as? String ?? "").font(Typo.font(13, bold: true))
                                .foregroundColor(on ? .white : c6(pal, "sub", "sub")).lineLimit(1)
                                .frame(maxWidth: .infinity).frame(height: th)
                                .background(RoundedRectangle(cornerRadius: 12).fill(on ? cBlue : c6(pal, "card", "card")))
                                .overlay(RoundedRectangle(cornerRadius: 11.5).inset(by: 0.5).stroke(on ? cBlue : line, lineWidth: 1))
                        }.buttonStyle(.plain)
                    }
                    if let rf = rf, let lb = rf["label"] as? String {
                        Button { if let a = Action(rf["act"] as? [String: Any]) { host.handle(a) } } label: {
                            Text(lb).font(Typo.font(15)).foregroundColor(c6(pal, "sub", "sub")).frame(width: 38, height: 38)
                                .background(RoundedRectangle(cornerRadius: 12).fill(c6(pal, "card", "card")))
                                .overlay(RoundedRectangle(cornerRadius: 11.5).inset(by: 0.5).stroke(line, lineWidth: 1))
                        }.buttonStyle(.plain)
                    }
                }
                .frame(height: h)
                .frame(maxWidth: .infinity).background(c6(pal, "bg", "bg"))
                .overlay(alignment: .bottom) { Rectangle().fill(line).frame(height: 1) }
            }
        }
    }
}

// MARK: 버스 도착 초 카운트다운 기억 — 안드로이드 ScreenView.cdState · markCountdowns · cdRem · cdAge
/// 엔진이 준 남은 초(sec)를 받은 순간부터 1초마다 줄여 그린다. 열쇠 = 정류장|노선|방향|칸. 같은 원본 값(초 · 몇 번째전)이 다시 오면 흐르던 시작점을 이어 가서
/// 숫자가 도로 늘지 않고(공공 API 값은 1분마다 한 번 바뀌는 스냅샷), 값이 바뀌어 온 새 실시간 값은 그 값에서 다시 센다. 노드 자리는 다시 받아도 같아서(`Node.id`) 화면 쪽 상태로는 못 이어 간다 — 그래서 따로 기억한다.
final class BusCd: @unchecked Sendable {
    static let shared = BusCd()
    private struct St { var sec: Double; var t0: Date; var ph: String }
    private var st: [String: St] = [:]
    private var srcAge: TimeInterval = 0, srcUntil = Date.distantPast
    private let lock = NSLock()
    /// 다음에 올리는 화면이 받은 지 몇 초 된 것인지(기억해 둔 옛 화면은 그만큼 이미 흐른 것으로 친다 · 새로 받은 화면은 0).
    func setSourceAge(_ s: TimeInterval) { lock.lock(); srcAge = max(0, s); srcUntil = Date().addingTimeInterval(1.5); lock.unlock() }
    private func ensure(_ key: String, _ sec: Double, _ ph: String, _ now: Date) -> St {
        if let s = st[key], s.sec == sec, s.ph == ph { return s }
        let s = St(sec: sec, t0: now.addingTimeInterval(now < srcUntil ? -srcAge : 0), ph: ph)
        st[key] = s
        if st.count > 400 { st = st.filter { now.timeIntervalSince($0.value.t0) < 600 } }
        return s
    }
    /// 지금 남은 초(0 이하면 '곧 도착' 이거나 이미 지나간 차).
    func rem(_ key: String, sec: Double, ph: String, now: Date = Date()) -> Double {
        lock.lock(); defer { lock.unlock() }
        let s = ensure(key, sec, ph, now); return s.sec - now.timeIntervalSince(s.t0)
    }
    /// 이 칸의 값을 받은 지 몇 초인가.
    func age(_ key: String, sec: Double, ph: String, now: Date = Date()) -> Double {
        lock.lock(); defer { lock.unlock() }
        return now.timeIntervalSince(ensure(key, sec, ph, now).t0)
    }
    static func key(_ stop: String, _ row: [String: Any], _ k: Int) -> String { stop + "|" + (row["no"] as? String ?? "") + "|" + (row["dir"] as? String ?? "") + "|" + String(k) }
    /// 화면 본문의 모든 도착 칸: 가장 빨리 오는 차의 남은 초(없으면 nil) · 엔진이 정한 유통기한(ex)이 지나 '확인 중'이 된 칸이 있는지(안드로이드 minArrRemainSec · arrStale).
    func scan(_ nodes: [Node], now: Date = Date()) -> (minRem: Double?, stale: Bool) {
        var best: Double? = nil, stale = false
        func walk(_ ns: [Node]) -> [Node] { ns.flatMap { $0.t == "bcard" ? [$0] : walk($0.kids) } }          // 카드가 묶음 안에 들어 있어도 찾는다
        for n in walk(nodes) {
            for r in n.d["rows"] as? [[String: Any]] ?? [] {
                for (k, a) in (r["a"] as? [[String: Any]] ?? []).prefix(2).enumerated() {
                    let sec = (a["sec"] as? NSNumber)?.doubleValue ?? 0
                    guard sec > 0 else { continue }
                    let key = Self.key(n.str("k") ?? "", r, k), ph = a["p"] as? String ?? ""
                    let rem = self.rem(key, sec: sec, ph: ph, now: now)
                    if best == nil || rem < best! { best = rem }
                    let ex = (a["ex"] as? NSNumber)?.doubleValue ?? 0
                    if ex > 0, age(key, sec: sec, ph: ph, now: now) > ex { stale = true }
                }
            }
        }
        return (best, stale)
    }
}

// MARK: 버스 정류장 카드(bcard) — 안드로이드 bcardLayout / drawBcard 치수(머리 위 16 · 아래 12 · 노선 줄 위아래 11 · 모서리 18)
struct BcardNode: View {
    let node: Node; let pal: Palette
    @EnvironmentObject var host: Host

    private func act(_ k: String) -> Action? { Action(node.d[k] as? [String: Any]) }
    private let bell = "M12 22c1.1 0 2-.9 2-2h-4c0 1.1.9 2 2 2zm6-6v-5c0-3.07-1.64-5.64-4.5-6.32V4c0-.83-.67-1.5-1.5-1.5s-1.5.67-1.5 1.5v.68C7.63 5.36 6 7.92 6 11v5l-2 2v1h16v-1l-2-2z"

    /// 초 카운트다운(받은 뒤 흐른 만큼 줄인 값): 59초 이하는 '○초', 그 위는 '○분 ○○초', 0 이하는 '곧 도착'.
    private func cd(_ sec: Double) -> String {
        let s = Int(sec.rounded())
        if s <= 0 { return "곧 도착" }
        if s < 60 { return "\(s)초" }
        let m = s / 60, r = s % 60
        return "\(m)분 \(r < 10 ? "0\(r)" : "\(r)")초"
    }

    var body: some View {
        let near = (node.str("mode") ?? "near") == "near"
        let on = node.bool("on")
        let name = node.str("nm") ?? "", alias = node.str("al") ?? ""
        let main = alias.isEmpty ? name : alias
        let badge = node.str("n") ?? "", dist = node.str("dist") ?? ""
        let lm = node.str("lm") ?? ""
        let big = node.num("fv", 0) > 0
        let rows = node.d["rows"] as? [[String: Any]] ?? []
        let text = c6(pal, "text", "text"), sub = c6(pal, "sub", "sub"), border = c6(pal, "border", "border"), border2 = c6(pal, "border2", "border2")
        let msg = (node.str("ld") ?? "").isEmpty ? (node.str("em") ?? "") : (node.str("ld") ?? "")
        let radius: CGFloat = 18
        return VStack(spacing: 0) {
            // 머리
            HStack(alignment: .top, spacing: 8) {
                if !badge.isEmpty {
                    Text(badge).font(Typo.font(11, bold: true)).foregroundColor(.white)
                        .frame(width: 21, height: 21).background(Circle().fill(cBlue))
                        .padding(.trailing, -1)
                }
                VStack(alignment: .leading, spacing: 0) {
                    LinedText(s: main, size: 17, bold: true, lh: 1.3, color: text)
                    if !alias.isEmpty { Text(name).font(Typo.font(11, bold: true)).foregroundColor(sub).lineLimit(1) }
                    if !lm.isEmpty { Text("(\(lm) 방향)").font(Typo.font(11, bold: true)).foregroundColor(c6(pal, "gold", "gold")).lineLimit(1) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 8) {
                    if act("edit") != nil {
                        Text("✏️").font(Typo.font(12)).opacity(0.55).frame(width: 18, height: 22)
                            .contentShape(Rectangle()).onTapGesture { if let a = act("edit") { host.handle(a) } }
                    }
                    if !near, act("map") != nil {
                        Text("🗺️").font(Typo.font(13)).opacity(0.7).frame(width: 19, height: 22)
                            .contentShape(Rectangle()).onTapGesture { if let a = act("map") { host.handle(a) } }
                    }
                    if act("star") != nil {
                        Text(near ? (big ? "★" : "☆") : "×").font(Typo.font(near ? 16 : 20))
                            .foregroundColor(near && big ? c6(pal, "gold", "gold") : sub)
                            .frame(width: near ? 24 : 20, height: 22)
                            .contentShape(Rectangle()).onTapGesture { if let a = act("star") { host.handle(a) } }
                    }
                    if near, !dist.isEmpty {
                        Text(dist).font(Typo.font(11)).foregroundColor(sub).padding(.horizontal, 9).frame(height: 20)
                            .background(RoundedRectangle(cornerRadius: 11).fill(c6(pal, "bg", "bg")))
                    }
                }
                .fixedSize()
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 12)

            // 노선 줄 / 안내 글
            if !rows.isEmpty {
                TimelineView(.periodic(from: .now, by: 1)) { tl in
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                            let arr = (r["a"] as? [[String: Any]] ?? []).prefix(2)
                            let hasBell = ((r["bell"] as? NSNumber)?.intValue ?? 0) > 0
                            let dir = r["dir"] as? String ?? ""
                            HStack(alignment: .center, spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r["no"] as? String ?? "").font(Typo.font(17, bold: true)).foregroundColor(c6(pal, r["c"] as? String, "#0066FF")).lineLimit(1)
                                    if !dir.isEmpty { Text(dir).font(Typo.font(11, bold: true)).foregroundColor(sub).lineLimit(1) }
                                }
                                .frame(maxWidth: 150, alignment: .leading)
                                Spacer(minLength: 4)
                                VStack(alignment: .trailing, spacing: 3) {
                                    ForEach(Array(arr.enumerated()), id: \.offset) { k, a in
                                        let sec = (a["sec"] as? NSNumber)?.doubleValue ?? 0
                                        let counting = sec > 0, p = a["p"] as? String ?? ""
                                        let ck = BusCd.key(node.str("k") ?? "", r, k)
                                        let rem = counting ? BusCd.shared.rem(ck, sec: sec, ph: p, now: tl.date) : 0
                                        // 엔진이 정한 유통기한(ex)이 지났으면 낡은 '곧 도착 4번째전' 대신 '확인 중'(옅게) — 안드로이드 s461
                                        let ex = (a["ex"] as? NSNumber)?.doubleValue ?? 0, xs = a["xs"] as? String ?? ""
                                        let staleNow = counting && ex > 0 && !xs.isEmpty && BusCd.shared.age(ck, sec: sec, ph: p, now: tl.date) > ex
                                        let soon = staleNow ? false : counting ? rem <= 60 : ((a["soon"] as? NSNumber)?.intValue ?? 0) > 0
                                        HStack(spacing: 6) {
                                            if !p.isEmpty && !staleNow { Text(p).font(Typo.font(11, bold: true)).foregroundColor(sub) }
                                            Text(staleNow ? xs : counting ? cd(rem) : (a["s"] as? String ?? "")).font(Typo.font(14, bold: true)).foregroundColor(staleNow ? sub : soon ? cSoon : text)
                                        }
                                        .frame(height: 14 * 1.3)
                                    }
                                }
                                if hasBell { SVGIcon(d: bell).fill(sub.opacity(0.55)).frame(width: 22, height: 22) }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            .overlay(alignment: .top) { Rectangle().fill(border2).frame(height: 1).padding(.horizontal, 1) }
                            .contentShape(Rectangle())
                            .onTapGesture { if let a = Action(r["act"] as? [String: Any]) { host.handle(a) } }
                        }
                    }
                }
            } else if !msg.isEmpty {
                HStack {
                    Text(msg).font(Typo.font(13)).foregroundColor(sub)
                    Spacer()
                    if act("rt") != nil, !(node.str("em") ?? "").isEmpty {
                        Text("다시 시도 ›").font(Typo.font(13, bold: true)).foregroundColor(Color(red: 0x2F / 255.0, green: 0x7C / 255.0, blue: 0xF6 / 255.0))
                            .onTapGesture { if let a = act("rt") { host.handle(a) } }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .overlay(alignment: .top) { Rectangle().fill(border).frame(height: 1) }
            }
        }
        .padding(1)
        .background(RoundedRectangle(cornerRadius: radius).fill(c6(pal, "card", "card")))
        .overlay(RoundedRectangle(cornerRadius: radius - 0.5).inset(by: 0.5).stroke(on ? cBlue : border, lineWidth: 1))
        .overlay { if on { RoundedRectangle(cornerRadius: radius + 1).inset(by: -1).stroke(Color(red: 0, green: 0.4, blue: 1).opacity(0.2), lineWidth: 2) } }
        .clipShape(RoundedRectangle(cornerRadius: radius))
        .contentShape(Rectangle())
        .onTapGesture { if let a = act("act") { host.handle(a) } }
    }
}
