import Foundation

/// 엔진 대본(open.json)에서 '지금 시간대에 맞는 카드 확장 인사 대본'(SceneHello.Plan)만 꺼낸다 — 안드로이드 OpenCore.parse/slotFor/helloFor 중 인사에 쓰는 부분.
/// 시간 · 자리 · 차례 · 인사 글은 모두 대본이 정한다. 이 파일은 읽어서 건넬 뿐이다.
enum SceneOpen {
    private struct Slot { var id = ""; var h0 = 0.0, h1 = 0.0; var say: [String: String] = [:]; var rest = false }
    private struct Script { var chars: [String] = []; var slots: [Slot] = []; var base: SceneHello.Plan? }

    private static let lock = NSLock()
    private static var cached: Script?? = nil

    private static func num(_ o: Any?, _ d: Double) -> Double { (o as? NSNumber)?.doubleValue ?? d }

    private static func load() -> Script? {
        lock.lock(); defer { lock.unlock() }
        if let c = cached { return c }
        var out: Script? = nil
        if let u = Bundle.main.url(forResource: "open", withExtension: "json"), let d = try? Data(contentsOf: u),
           let m = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] { out = parse(m) }
        cached = .some(out)
        return out
    }

    private static func parse(_ m: [String: Any]) -> Script? {
        var sc = Script()
        sc.chars = (m["chars"] as? [Any])?.compactMap { $0 as? String } ?? []
        guard let sl = m["slots"] as? [[String: Any]], !sl.isEmpty else { return nil }
        for s in sl {
            var x = Slot(); x.id = (s["id"] as? String) ?? ""; x.h0 = num(s["h0"], 0); x.h1 = num(s["h1"], 0)
            if let h = s["hello"] as? [String: Any] {
                if let sy = h["say"] as? [String: Any] { for (k, v) in sy { if let t = v as? String { x.say[k] = t } } }
                x.rest = (h["rest"] as? Bool) ?? false
            }
            sc.slots.append(x)
        }
        if let h = m["hello"] as? [String: Any], let t = h["t"] as? [String: Any], let so = h["seats"] as? [Any], let oo = h["order"] as? [Any] {
            let p = SceneHello.Plan()
            p.expand = Int(num(t["expand"], Double(p.expand))); p.greet = Int(num(t["greet"], Double(p.greet))); p.step = Int(num(t["step"], Double(p.step))); p.bubble = Int(num(t["bubble"], Double(p.bubble)))
            p.leave = Int(num(t["leave"], Double(p.leave))); p.collapse = Int(num(t["collapse"], Double(p.collapse))); p.end = Int(num(t["end"], Double(p.end))); p.boost = num(t["boost"], p.boost)
            for (i, q) in so.enumerated() {
                guard let qm = q as? [String: Any] else { return sc }
                p.sx.append(num(qm["x"], 0.5)); p.sz.append(num(qm["z"], 0.5))
                p.order.append(i < oo.count ? Int(num(oo[i], Double(i))) : 0)
            }
            p.chars = sc.chars
            sc.base = p
        }
        return sc
    }

    /// 시(0~24 실수)가 속한 칸. 칸 범위는 [h0, h1) · 자정을 넘기는 칸은 h0 > h1. 어디에도 안 맞으면 첫 칸.
    private static func slotFor(_ sc: Script, _ hour: Double) -> Slot {
        let h = (hour.truncatingRemainder(dividingBy: 24) + 24).truncatingRemainder(dividingBy: 24)
        for s in sc.slots { if s.h0 < s.h1 ? (h >= s.h0 && h < s.h1) : (h >= s.h0 || h < s.h1) { return s } }
        return sc.slots[0]
    }

    /// 지금 칸에 맞춘 인사 대본. 대본이 없거나 모양이 안 맞으면 nil(앱은 아무것도 안 한다).
    static func helloNow(_ date: Date = Date()) -> SceneHello.Plan? {
        guard let sc = load(), let b = sc.base else { return nil }
        let c = Calendar.current
        let hour = Double(c.component(.hour, from: date)) + Double(c.component(.minute, from: date)) / 60
        let s = slotFor(sc, hour)
        let p = SceneHello.Plan()
        p.expand = b.expand; p.greet = b.greet; p.step = b.step; p.bubble = b.bubble; p.leave = b.leave; p.collapse = b.collapse; p.end = b.end; p.boost = b.boost
        p.sx = b.sx; p.sz = b.sz; p.order = b.order; p.chars = b.chars; p.say = s.say; p.rest = s.rest; p.slot = s.id
        return SceneHello.ok(p) ? p : nil
    }
}
