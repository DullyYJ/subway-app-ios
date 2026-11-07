import Foundation

/// 엔진(/scene)이 준 답 + 캐릭터 시트 규격 — 안드로이드 SceneModel.java. 계산은 엔진이 했고, 여기는 받은 값을 담는 그릇일 뿐이다.
enum SceneModel {
    /// 시트 규격(웹 _RC.d3 와 같은 값)
    struct Spec { let fps: Int; let cell, base, ox, lift: Double; let intro, introFps: Int }
    /// ★ 끝에만 덧붙인다(엔진 지하철 객실 장면의 비트 번호가 이 순서)
    static let ORDER = ["dolsom", "lovel", "dudung", "sul", "ppopu", "chaeng", "juksun", "bbosong"]
    static let D3: [String: Spec] = [
        "dolsom": Spec(fps: 19, cell: 86, base: 248.5, ox: 120.8, lift: 0, intro: 0, introFps: 0),
        "lovel": Spec(fps: 11, cell: 88, base: 250, ox: 117.9, lift: 0, intro: 0, introFps: 0),
        "ppopu": Spec(fps: 19, cell: 88, base: 248.5, ox: 120.3, lift: 0, intro: 0, introFps: 0),
        "chaeng": Spec(fps: 15, cell: 88, base: 244.5, ox: 154.5, lift: 12, intro: 0, introFps: 0),
        "sul": Spec(fps: 20, cell: 104, base: 230.5, ox: 131, lift: 0, intro: 0, introFps: 0),
        "dudung": Spec(fps: 13, cell: 106, base: 222.5, ox: 128, lift: 0, intro: 14, introFps: 14),
        "juksun": Spec(fps: 12, cell: 90, base: 247.5, ox: 118.4, lift: 0, intro: 0, introFps: 0),      // 판다 죽순이: 대나무를 든 채 뒤뚱뒤뚱
        "bbosong": Spec(fps: 12, cell: 80, base: 249, ox: 118.5, lift: 0, intro: 0, introFps: 0),       // 아기하마 뽀송: 신발(4종)을 신고 종종
    ]
    /// 다리를 모은 '서 있는' 프레임
    static func stand(_ id: String) -> Int {
        switch id {
        case "dolsom", "ppopu": return 13
        case "lovel": return 10
        case "dudung": return 12
        case "sul": return 13
        case "chaeng": return 4
        default: return 0
        }
    }
    static func kind(_ id: String) -> String {
        switch id {
        case "dolsom", "ppopu": return "dog"
        case "lovel": return "cat"
        case "dudung": return "mole"
        case "chaeng": return "tad"
        case "sul": return "eagle"
        case "juksun": return "panda"
        case "bbosong": return "hippo"
        default: return "dog"
        }
    }

    final class Look {
        var slot = "noon", slotKo = "", wk = "clear", wxKo = "", season = "autumn", emo = "", place = "street", placeKo = ""
        var wxKnown = false, night = false, lit = false, hidesSun = false, hot = false, cold = false, sun = false, bright = false
        var temp = 0.0, wind = 0
        var pdir = 1                    // 장소가 바뀔 때 캐릭터가 걸어 나가는 쪽(엔진이 정한다): +1 오른쪽 · -1 왼쪽
    }
    /// say: 날씨 반응 동작 이름 → 말풍선 글(엔진이 정한 글. 없으면 말풍선 없이 몸짓만)
    final class Traits { var land = ""; var acts: [String] = []; var say: [String: String] = [:] }
    /// 지하철 객실 장면 재료(엔진 sceneTrain): stops[k] = {역에 닿기 직전 타고 있던 친구들, 내리는 친구들, 타는 친구들}(비트 = ORDER 순서)
    final class Train {
        var first = 0, `init` = 0; var line = ""; var names: [String] = []; var stops: [[Int]] = []
        var sayOut: [String] = [], sayIn: [String] = []; var lbNext = "", lbHere = ""
    }
    final class Res {
        var train: Train?
        var ok = false; var mode = "", venue = "", hero = "", hint = "", tag = "", line = ""
        var nearEnd = false, inside = false; var sta = ""; var look = Look(); var cast: [String] = []
        var traits: [String: Traits] = [:]
        var raw = ""
    }

    private static func num(_ o: Any?) -> Int { (o as? NSNumber).map { Int($0.doubleValue.rounded()) } ?? 0 }
    private static func str(_ o: Any?, _ d: String) -> String { o as? String ?? d }
    private static func bool(_ o: Any?) -> Bool { (o as? NSNumber)?.boolValue ?? false }

    static func parse(_ json: String) -> Res {
        let m = (json.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]) ?? [:]
        let r = Res()
        r.raw = json
        r.ok = bool(m["ok"])
        r.mode = str(m["mode"], ""); r.venue = str(m["venue"], ""); r.hero = str(m["hero"], "")
        r.hint = str(m["hint"], ""); r.tag = str(m["tag"], ""); r.line = str(m["line"], "")
        r.nearEnd = bool(m["nearEnd"]); r.inside = bool(m["inside"]); r.sta = str(m["sta"], "")
        if let l = m["look"] as? [String: Any] {
            let k = r.look
            k.slot = str(l["slot"], "noon"); k.slotKo = str(l["slotKo"], ""); k.wk = str(l["wk"], "clear")
            k.wxKo = str(l["wxKo"], ""); k.season = str(l["season"], "autumn"); k.emo = str(l["emo"], "")
            k.wxKnown = bool(l["wxKnown"]); k.night = bool(l["night"]); k.lit = bool(l["lit"]); k.hidesSun = bool(l["hidesSun"])
            k.temp = (l["temp"] as? NSNumber)?.doubleValue ?? 0
            k.place = str(l["place"], "street"); k.placeKo = str(l["placeKo"], "")
            k.hot = bool(l["hot"]); k.cold = bool(l["cold"]); k.sun = bool(l["sun"]); k.bright = bool(l["bright"])
            if let w = (l["wind"] as? NSNumber)?.intValue { k.wind = max(0, min(2, w)) }
            if let p = (l["pdir"] as? NSNumber)?.intValue, p < 0 { k.pdir = -1 } else { k.pdir = 1 }
        }
        if let tm = m["train"] as? [String: Any] {
            let tr = Train()
            tr.first = num(tm["first"]); tr.`init` = num(tm["init"]); tr.line = str(tm["line"], "")
            if let no = tm["names"] as? [Any] { tr.names = no.map { $0 as? String ?? "" } }
            if let so = tm["stops"] as? [Any] {
                for x in so {
                    var v = [0, 0, 0]
                    if let l = x as? [Any] { for i in 0..<min(3, l.count) { v[i] = num(l[i]) } }
                    tr.stops.append(v)
                }
            }
            if let sm = tm["say"] as? [String: Any] {
                tr.sayOut = (sm["out"] as? [Any] ?? []).compactMap { $0 as? String }
                tr.sayIn = (sm["in"] as? [Any] ?? []).compactMap { $0 as? String }
            }
            if let lb = tm["lb"] as? [Any], lb.count >= 2 { tr.lbNext = str(lb[0], ""); tr.lbHere = str(lb[1], "") }
            r.train = tr
        }
        r.cast = (m["cast"] as? [Any] ?? []).compactMap { $0 as? String }
        if let to = m["traits"] as? [String: Any] {
            for (k, v) in to {
                guard let t = v as? [String: Any] else { continue }
                let tr = Traits()
                tr.land = str(t["land"], "")
                tr.acts = (t["acts"] as? [Any] ?? []).compactMap { $0 as? String }
                if let so = t["say"] as? [String: Any] { for (sk, sv) in so { if let s = sv as? String { tr.say[sk] = s } } }
                r.traits[k] = tr
            }
        }
        return r
    }
}
