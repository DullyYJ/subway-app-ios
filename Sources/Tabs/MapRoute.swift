import SwiftUI

/// 버스 노선 상세(안드로이드 MapCore.brRequest/onBr + ShellActivity.brRound): 엔진(part:'br')이 화면을 그리고,
/// 받아 올 공공 API 주소(need)만 앱이 받아 res 에 담아 다시 보낸다.
@MainActor
final class BusRoute: ObservableObject {
    @Published var screen: Screen? = nil
    @Published var busy = false
    var rid = "", no = "", tp = "", src = "", o = "", stnJson = "", via = "", cc = ""
    var sel = -1
    var res: [String: String] = [:]
    var stn: [[String]] = []          // [순번, id, 이름, 번호, 위도, 경도, 방향]
    var pkName = "", pkId = ""
    var msgSame = "", msgS = "", msgE = "", msgToStn = ""
    var me: (Double, Double)? = nil
    private var gen = 0

    func start(stop: [String: Any], route r: [String]) {
        let id = stop["id"] as? String ?? "", s = stop["src"] as? String ?? ""
        rid = r[0]; no = r[1]; tp = r[2]
        src = id.hasPrefix("GG:") || s == "gbis" ? "gbis" : (id.hasPrefix("SEOUL:") || s == "topis" ? "topis" : "")
        o = Json.text(["id": id, "nm": stop["nm"] as? String ?? "", "la": stop["la"] ?? 0, "lo": stop["lo"] ?? 0, "city": stop["city"] as? String ?? ""] as [String: Any])
        stnJson = ""; via = ""; cc = ""; sel = -1; res = [:]; stn = []; screen = nil
        gen += 1
        Task { await run(gen) }
    }
    func stop() { gen += 1; busy = false }
    func refresh() { res = [:]; gen += 1; Task { await run(gen) } }
    func render() { gen += 1; Task { await run(gen) } }
    func pollPositions() { guard !busy, screen != nil else { return }; res.removeValue(forKey: "gp"); res.removeValue(forKey: "tp"); gen += 1; Task { await run(gen) } }

    func request() -> String {
        var b = "{\"cap\":\(Servers.cap),\"f\":{\"part\":\"br\",\"th\":\"dark\",\"br\":{\"rid\":\(Json.q(rid)),\"no\":\(Json.q(no)),\"tp\":\(Json.q(tp)),\"src\":\(Json.q(src))"
        if !o.isEmpty { b += ",\"o\":\(o)" }
        if !cc.isEmpty { b += ",\"cc\":\(Json.q(cc))" }
        if let m = me { b += ",\"me\":[\(m.0),\(m.1)]" }
        if !stnJson.isEmpty { b += ",\"stn\":\(stnJson),\"via\":\(Json.q(via))" }
        b += ",\"sel\":\(sel)"
        if !pkName.isEmpty { b += ",\"pk\":{\"n\":\(Json.q(pkName)),\"i\":\(Json.q(pkId))}" }
        b += ",\"res\":{" + res.map { "\(Json.q($0.key)):\(Json.q($0.value))" }.joined(separator: ",") + "}}}}"
        return b
    }

    private func run(_ g: Int) async {
        busy = true
        defer { if g == gen { busy = false } }
        for round in 0..<6 {
            guard let d = try? await Net.request("POST", Servers.base + "/screen/map", body: request(), timeout: 9) else {
                if screen == nil, round == 0 { try? await Task.sleep(nanoseconds: 600_000_000); if g != gen { return }; continue }
                return
            }
            if g != gen { return }
            let need = read(d)
            if let s = try? Screen.parse(d) { screen = s }
            if need.isEmpty { return }
            let got = await withTaskGroup(of: (String, String).self) { grp -> [(String, String)] in
                for n in need { grp.addTask { (n.0, await MapModel.busGet(n.1)) } }
                var out: [(String, String)] = []
                for await x in grp { out.append(x) }
                return out
            }
            if g != gen { return }
            for (k, v) in got where k.range(of: "^[a-z]{2}$", options: .regularExpression) != nil { res[k] = String(v.prefix(200000)) }
        }
    }

    private func read(_ d: Data) -> [(String, String)] {
        guard let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any], let i = o["info"] as? [String: Any], let b = i["br"] as? [String: Any] else { return [] }
        if let m = b["msg"] as? [String: Any] {
            msgSame = m["same"] as? String ?? ""; msgS = m["s"] as? String ?? ""; msgE = m["e"] as? String ?? ""; msgToStn = m["tostn"] as? String ?? ""
        }
        if let l = b["stn"] as? [[Any]] {
            if stnJson.isEmpty, let data = try? JSONSerialization.data(withJSONObject: l), let s = String(data: data, encoding: .utf8) {
                stnJson = s; via = b["via"] as? String ?? ""; cc = b["cc"] as? String ?? ""; res.removeValue(forKey: "gs"); res.removeValue(forKey: "ts")
            }
            stn = l.compactMap { x in
                guard x.count >= 7 else { return nil }
                return x.prefix(7).map { v in
                    if let n = v as? NSNumber { return n.doubleValue == n.doubleValue.rounded() && abs(n.doubleValue) < 1e12 ? String(n.int64Value) : String(n.doubleValue) }
                    return String(describing: v)
                }
            }
        }
        return (b["need"] as? [[String: Any]] ?? []).prefix(4).compactMap { x in
            guard let k = x["k"] as? String, let u = x["url"] as? String else { return nil }
            return (String(k.prefix(4)), String(u.prefix(600)))
        }
    }
}

extension MapModel {
    func openRoute(_ v: String) {
        let p = v.split(separator: ".").map(String.init)
        guard p.count == 3, p[1] != "p", let si = Int(p[1]), let ri = Int(p[2]),
              si >= 0, si < stops.count, let rl = rts[si], ri >= 0, ri < rl.count, !rl[ri][0].isEmpty else { return }
        route.pkName = pkBusName; route.pkId = pkBusId
        route.me = gps
        route.start(stop: stops[si], route: rl[ri])
        routeOpen = true
    }
    func closeRoute() { route.stop(); routeOpen = false }

    func brAct(_ v: String, host: Host) {
        let home = HomeModel.shared
        let r = route
        if v == "br.x" { closeRoute(); return }
        if v == "br.rf" { r.refresh(); return }
        if v == "br.cx" { home.pickRestore(pkBusName); pkBusName = ""; pkBusId = ""; r.pkName = ""; r.pkId = ""; r.sel = -1; r.render(); return }
        if v == "br.st" {
            guard !pkBusName.isEmpty else { return }
            closeRoute(); cat("m:subway"); if !r.msgToStn.isEmpty { host.say(r.msgToStn) }; return
        }
        if v == "br.ss" {
            guard r.sel >= 0, r.sel < r.stn.count else { return }
            if home.isRiding { closeRoute(); return }
            let s = r.stn[r.sel]
            home.pickSnap()
            home.setPlace(HomeModel.START, type: "bus", name: s[2], line: "", lat: Double(s[4]) ?? 0, lng: Double(s[5]) ?? 0)
            pkBusName = s[2]; pkBusId = s[1]; r.pkName = s[2]; r.pkId = s[1]; r.sel = -1
            let t = MapModel.fill(r.msgS, s[2]); if !t.isEmpty { host.say(t) }
            r.render(); return
        }
        if v.hasPrefix("br.p."), let i = Int(v.dropFirst(5)), i >= 0, i < r.stn.count {
            let s = r.stn[i]
            if !pkBusName.isEmpty {
                if pkBusId.isEmpty ? pkBusName == s[2] : pkBusId == s[1] { if !r.msgSame.isEmpty { host.say(r.msgSame) }; return }
                if home.isRiding { closeRoute(); return }
                home.setPlace(HomeModel.DEST, type: "bus", name: s[2], line: "", lat: Double(s[4]) ?? 0, lng: Double(s[5]) ?? 0)
                home.pickDone(); pkBusName = ""; pkBusId = ""
                let msg = MapModel.fill(r.msgE, s[2])
                closeRoute(); host.tab = "home"
                if !msg.isEmpty { host.say(msg) }
                if home.bothSet { Task { try? await Task.sleep(nanoseconds: 400_000_000); home.searchRoute(host: host) } }
                return
            }
            r.sel = i; r.render()
        }
    }
}

/// 노선 상세 시트(가득 찬 아래서 올라오는 판) — 10초마다 위치만 새로 받는다.
struct RouteSheet: View {
    @ObservedObject var route: BusRoute
    let pal: Palette
    var onClose: () -> Void
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { onClose() }
            Group {
                if let s = route.screen { ScreenBody(screen: s, pal: pal) }
                else { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
            }
            .frame(maxWidth: 520).frame(maxHeight: .infinity)
            .padding(.top, 44)
            .background(pal.color("card") ?? .black)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
            .padding(.top, 44)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                route.pollPositions()
            }
        }
    }
}

/// 정류장 이름 설정(별명) 카드
struct AliasCard: View {
    let edit: MapModel.AliasEdit
    let pal: Palette
    let maxLen: Int
    var onSave: (String) -> Void
    var onClose: () -> Void
    @State private var text = ""
    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { onClose() }
            VStack(alignment: .leading, spacing: 0) {
                Text("정류장 이름 설정").font(Typo.font(15, bold: true)).foregroundColor(pal.color("text") ?? .white)
                Text(edit.name).font(Typo.font(12)).foregroundColor(pal.color("sub") ?? .gray).padding(.top, 4).padding(.bottom, 12)
                TextField("예: 출근, 퇴근, 친구집", text: $text).font(Typo.font(14))
                    .foregroundColor(pal.color("text") ?? .white).padding(11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(pal.color("bg") ?? .black))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(pal.color("border2") ?? .gray, lineWidth: 1))
                    .onChange(of: text) { if $0.count > maxLen { text = String($0.prefix(maxLen)) } }
                HStack(spacing: 8) {
                    if !edit.cur.isEmpty { btn("삭제", Color(red: 1, green: 0.357, blue: 0.357), nil, 1) { onSave("") } }
                    btn("취소", pal.color("sub") ?? .gray, nil, 1) { onClose() }
                    btn("저장", Color(red: 0x12 / 255.0, green: 0x12 / 255.0, blue: 0x14 / 255.0), pal.color("gold") ?? .yellow, 2) { onSave(text) }
                }.padding(.top, 14)
            }
            .padding(EdgeInsets(top: 20, leading: 18, bottom: 18, trailing: 18))
            .background(RoundedRectangle(cornerRadius: 16).fill(pal.color("card") ?? .black))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(pal.color("border") ?? .gray, lineWidth: 1))
            .padding(.horizontal, 28).frame(maxWidth: 420)
        }
        .onAppear { text = edit.cur }
    }
    private func btn(_ t: String, _ fg: Color, _ bg: Color?, _ w: CGFloat, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Text(t).font(Typo.font(14, bold: true)).foregroundColor(fg).frame(maxWidth: .infinity).frame(height: 42)
                .background(RoundedRectangle(cornerRadius: 10).fill(bg ?? .clear))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(bg == nil ? (pal.color("border2") ?? .gray) : .clear, lineWidth: 1))
        }.buttonStyle(.plain).layoutPriority(w)
    }
}
