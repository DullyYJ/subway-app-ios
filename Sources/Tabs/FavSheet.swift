import SwiftUI

/// 경로 즐겨찾기 시트(안드로이드 FavCore + ShellActivity.openFavSheet/loadFav/favAct).
/// 등록·삭제 규칙과 화면은 엔진(/screen/fav)이 정하고, 앱은 저장된 목록을 보내고 돌려받은 새 목록을 저장한다.
@MainActor
final class FavModel: ObservableObject {
    @Published var open = false
    @Published var screen: Screen? = nil
    struct Go { var sName = "", sLine = "", dName = "", dLine = ""; var sLa = 0.0, sLo = 0.0, dLa = 0.0, dLo = 0.0 }
    private var go: [Go] = []
    private var op = ""                                  // '' · quick · new · del:<i> · pick:<s|d>:<j>
    private var fn = "", fs = "", fd = "", fact = ""
    private var seq = 0
    private let ud = UserDefaults.standard

    private var listJson: String {
        let s = ud.string(forKey: "mk_favorites") ?? "[]"
        return s.count > 1 && s.count < 8000 && s.hasPrefix("[") && s.hasSuffix("]") ? s : "[]"
    }
    private func fieldText(_ k: String) -> String? { ud.string(forKey: "field." + k) }
    private func sync() {
        if let v = fieldText("fvn") { fn = v }
        if let v = fieldText("fvs") { fs = v }
        if let v = fieldText("fvd") { fd = v }
    }

    func show(cur: (String, String, String, String)) {
        for k in ["fvn", "fvs", "fvd"] { ud.removeObject(forKey: "field." + k) }
        fn = ""; fs = ""; fd = ""; fact = ""; op = ""; screen = nil; open = true
        self.cur = cur
        Task { await load() }
    }
    private var cur: (String, String, String, String) = ("", "", "", "")
    func close() { open = false; seq += 1 }

    private func request() -> String {
        var b = "{\"cap\":\(Servers.cap),\"f\":{\"list\":\(listJson),\"th\":\"dark\""
        if !cur.0.isEmpty && !cur.1.isEmpty { b += ",\"cur\":{\"s\":\(Json.q(cur.0)),\"d\":\(Json.q(cur.1)),\"sl\":\(Json.q(cur.2)),\"dl\":\(Json.q(cur.3))}" }
        b += ",\"form\":{\"n\":\(Json.q(fn)),\"s\":\(Json.q(fs)),\"d\":\(Json.q(fd)),\"act\":\(Json.q(fact))}"
        if op == "quick" { b += ",\"op\":{\"k\":\"quick\"}" }
        else if op == "new" { b += ",\"op\":{\"k\":\"new\"}" }
        else if op.hasPrefix("pick:") { let p = op.split(separator: ":").map(String.init); if p.count == 3 { b += ",\"op\":{\"k\":\"pick\",\"w\":\(Json.q(p[1])),\"j\":\(p[2])}" } }
        else if op.hasPrefix("del:") { b += ",\"op\":{\"k\":\"del\",\"i\":\(op.dropFirst(4))}" }
        op = ""
        return b + "}}"
    }

    var hostRef: Host? = nil
    func load() async {
        seq += 1; let my = seq
        guard let d = try? await Net.request("POST", Servers.base + "/screen/fav", body: request(), timeout: 9) else {
            if my == seq, screen == nil { hostRef?.say("즐겨찾기를 받지 못했어요"); open = false }
            return
        }
        if my != seq || !open { return }
        read(d)
        if let s = try? Screen.parse(d) { screen = s }
    }
    private func read(_ d: Data) {
        go = []
        guard let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any], let i = o["info"] as? [String: Any] else { return }
        if let l = i["list"], let data = try? JSONSerialization.data(withJSONObject: l), let s = String(data: data, encoding: .utf8) { ud.set(s, forKey: "mk_favorites") }
        if let m = i["msg"] as? String, !m.isEmpty { hostRef?.say(m) }
        if let f = i["form"] as? [String: Any] {
            fn = f["n"] as? String ?? ""; fs = f["s"] as? String ?? ""; fd = f["d"] as? String ?? ""
            let a = f["act"] as? String ?? ""; fact = a == "s" || a == "d" ? a : ""
        }
        for x in i["go"] as? [Any] ?? [] {
            var g = Go()
            if let m = x as? [String: Any], let s = m["s"] as? [Any], let d = m["d"] as? [Any], s.count >= 4, d.count >= 4 {
                g.sName = String(describing: s[0]); g.sLine = String(describing: s[1]); g.sLa = (s[2] as? NSNumber)?.doubleValue ?? 0; g.sLo = (s[3] as? NSNumber)?.doubleValue ?? 0
                g.dName = String(describing: d[0]); g.dLine = String(describing: d[1]); g.dLa = (d[2] as? NSNumber)?.doubleValue ?? 0; g.dLo = (d[3] as? NSNumber)?.doubleValue ?? 0
            }
            go.append(g)
        }
    }

    /// 눌림. fv.go.<i> 는 그 즐겨찾기로 경로 찾기.
    func act(_ v: String, host: Host, home: HomeModel) {
        hostRef = host
        if v == "fv.close" { close(); return }
        if v == "fv.new" { sync(); op = "new"; Task { await load() }; return }
        if v == "fv.add" { op = "quick"; Task { await load() }; return }
        if v.range(of: "^fv\\.pick\\.[sd]\\.[0-9]$", options: .regularExpression) != nil {
            sync()
            let p = v.split(separator: ".").map(String.init)
            op = "pick:\(p[2]):\(p[3])"; Task { await load() }; return
        }
        if v.hasPrefix("fv.del."), let i = Int(v.dropFirst(7)), i >= 0, i < 20 { op = "del:\(i)"; Task { await load() }; return }
        if v.hasPrefix("fv.go."), let i = Int(v.dropFirst(6)), i >= 0, i < go.count, !go[i].sName.isEmpty {
            let g = go[i]
            close()
            if home.isRiding { host.say("탑승 안내 중에는 바꿀 수 없어요"); return }
            home.setPlace(HomeModel.START, type: "subway", name: g.sName, line: g.sLine, lat: g.sLa, lng: g.sLo)
            home.setPlace(HomeModel.DEST, type: "subway", name: g.dName, line: g.dLine, lat: g.dLa, lng: g.dLo)
            home.clearRoute()
            host.tab = "home"
            home.searchRoute(host: host)
        }
    }

    /// 출발·도착 입력칸 이벤트: 그 칸을 '쓰는 중'으로 하고 후보를 다시 받는다.
    func fieldEvent(key: String, value: String, kind: String, host: Host) {
        guard open, key == "fvs" || key == "fvd", kind != "blur" else { return }
        let v = String(value.prefix(30))
        if key == "fvs" { fs = v } else { fd = v }
        fact = key == "fvs" ? "s" : "d"
        sync(); if key == "fvs" { fs = v } else { fd = v }
        hostRef = host
        Task {
            if kind == "edit" { try? await Task.sleep(nanoseconds: 350_000_000) }
            await load()
        }
    }
}

struct FavSheet: View {
    @ObservedObject var fav: FavModel
    let pal: Palette
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.82).ignoresSafeArea().onTapGesture { fav.close() }
            Group {
                if let s = fav.screen { ScreenBody(screen: s, pal: pal) }
                else { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
            }
            .frame(maxWidth: 520).frame(maxHeight: .infinity)
            .background(pal.color("card") ?? .black)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
            .padding(.top, 10)
        }
        .transition(.move(edge: .bottom))
    }
}
