import SwiftUI

/// 소식(뉴스) 방식(안드로이드 ShellCore.NewsRows + openNewsById): 원자료 두 곳(/newsfeed · /news/all)을 받아 기사 줄로 묶어 POST /screen/news 에 보낸다.
/// 분류 · 거르기 · 중복 정리는 엔진이 하고 앱은 모양만 맞춘다. 기사를 누르면 엔진이 만든 상세(detail)를 시트로 보인다.
struct NewsRow { var title = "", link = "", source = "", ts: Int64 = 0, cat = "", desc = "" }

@MainActor
final class NewsModel: ObservableObject {
    @Published var screen: Screen? = nil
    @Published var error: String? = nil
    @Published var detail: NewsDetail? = nil
    private var rows: [NewsRow] = []
    static let maxRows = 900
    var cat: String { UserDefaults.standard.string(forKey: "news_cat") ?? "전체" }

    struct NewsDetail: Identifiable { let id = UUID(); var title = "", meta = "", body = "", notice = "", btn = "", cat = "", src = "", close = "닫기", link = ""; var bodyEmpty = false, open = false }

    static func squash(_ s: String) -> String { s.filter { !$0.isWhitespace } }
    static func decode(_ s: String) -> String {
        guard s.contains("&") else { return s }
        var out = "", i = s.startIndex
        while i < s.endIndex {
            let c = s[i]
            if c != "&" { out.append(c); i = s.index(after: i); continue }
            if let e = s[i...].firstIndex(of: ";"), s.distance(from: i, to: e) <= 9 {
                let t = String(s[s.index(after: i)..<e]); var r: String? = nil
                switch t {
                case "amp": r = "&"; case "lt": r = "<"; case "gt": r = ">"; case "quot": r = "\""; case "apos": r = "'"; case "nbsp": r = " "
                default:
                    if t.hasPrefix("#") {
                        let n = t.hasPrefix("#x") || t.hasPrefix("#X") ? Int(t.dropFirst(2), radix: 16) : Int(t.dropFirst(1))
                        if let n = n, n > 0, let u = Unicode.Scalar(n) { r = String(Character(u)) }
                    }
                }
                if let r = r { out += r; i = s.index(after: e); continue }
            }
            out.append(c); i = s.index(after: i)
        }
        return out
    }

    private func build(_ a: Data?, _ b: Data?) {
        rows = []; var seen = Set<String>()
        func add(_ o: Any, _ srv: String) {
            guard rows.count < NewsModel.maxRows, let m = o as? [String: Any] else { return }
            let title = NewsModel.decode(m["title"] as? String ?? "").split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            if title.isEmpty || !seen.insert(NewsModel.squash(title)).inserted { return }
            var desc = NewsModel.decode(m["desc"] as? String ?? ""); if desc.count > 240 { desc = String(desc.prefix(240)) }
            let ts = (m["ts"] as? NSNumber)?.int64Value ?? 0
            rows.append(NewsRow(title: title, link: m["link"] as? String ?? "", source: NewsModel.decode(m["source"] as? String ?? "").trimmingCharacters(in: .whitespaces), ts: ts, cat: srv.isEmpty ? (m["cat"] as? String ?? "") : srv, desc: desc))
        }
        if let a = a, let o = Json.obj(a) as? [String: Any], (o["ok"] as? Bool) == true, let items = o["items"] as? [Any] { for it in items { add(it, "") } }
        if let b = b, let o = Json.obj(b) as? [String: Any], (o["ok"] as? Bool) == true, let cats = o["cats"] as? [String: Any] {
            for (k, v) in cats { if let l = v as? [Any] { for it in l { add(it, k) } } }
        }
    }
    private func listJson() -> String {
        "[" + rows.map { r in "[\(Json.q(r.title)),\"\",\"\",\(r.ts),\(Json.q(r.cat)),\(Json.q(String(r.desc.prefix(120))))]" }.joined(separator: ",") + "]"
    }
    private func rowJson(_ r: NewsRow) -> String { "[\(Json.q(r.title)),\(Json.q(r.link)),\(Json.q(r.source)),\(r.ts),\(Json.q(r.cat)),\(Json.q(r.desc))]" }

    func load(fetch: Bool = true) async {
        if fetch || rows.isEmpty {
            async let a: Data? = try? await Net.request("GET", Servers.board + "/newsfeed", timeout: 8)
            async let b: Data? = try? await Net.request("GET", Servers.news + "/news/all?per=100", timeout: 10)
            let (da, db) = await (a, b)
            build(da, db)
        }
        let body = "{\"cap\":\(Servers.cap),\"f\":{\"cat\":\(Json.q(cat))},\"n\":\(listJson())}"
        do { screen = try await Net.screen("/screen/news", body: body); error = nil }
        catch { if screen == nil { self.error = "소식을 받지 못했어요" } }
    }
    func setCat(_ c: String) { guard !c.isEmpty, c.count < 20 else { return }; UserDefaults.standard.set(c, forKey: "news_cat"); Task { await load(fetch: false) } }

    /// 기사 고유 id(링크, 없으면 제목)로 상세를 연다 — 목록이 바뀐 뒤에 눌러도 같은 기사.
    func open(id: String, title: String, host: Host) {
        var idx = rows.firstIndex { id == $0.link || ($0.link.isEmpty && id == $0.title) || (!id.hasPrefix("http") && NewsModel.squash(id) == NewsModel.squash($0.title)) }
        if idx == nil, !title.isEmpty { idx = rows.firstIndex { NewsModel.squash($0.title) == NewsModel.squash(title) } }
        let row: String, link: String
        if let i = idx { row = rowJson(rows[i]); link = rows[i].link }
        else { let url = id.hasPrefix("http"); row = "[\(Json.q(title.isEmpty ? (url ? "" : id) : title)),\(Json.q(url ? id : "")),\"\",0,\"\",\"\"]"; link = url ? id : "" }
        Task {
            guard let d = try? await Net.request("POST", Servers.base + "/screen/news", body: "{\"cap\":\(Servers.cap),\"d\":\(row)}", timeout: 8),
                  let o = Json.obj(d) as? [String: Any], let m = o["detail"] as? [String: Any], let t = m["title"] as? String, !t.isEmpty else { host.say("기사 내용을 받지 못했어요"); return }
            var dt = NewsDetail(); dt.title = t; dt.meta = m["meta"] as? String ?? ""
            let desc = m["desc"] as? String ?? "", empty = m["empty"] as? String ?? ""
            dt.body = desc.isEmpty ? empty : desc; dt.bodyEmpty = desc.isEmpty
            dt.notice = m["notice"] as? String ?? ""; dt.btn = m["btn"] as? String ?? ""; dt.cat = m["cat"] as? String ?? ""; dt.src = m["src"] as? String ?? ""
            if let c = m["close"] as? String, !c.isEmpty { dt.close = c }
            dt.link = link; dt.open = (m["open"] as? NSNumber)?.intValue == 1 && link.hasPrefix("https://")
            detail = dt
        }
    }
}

struct NewsView: View {
    let pal: Palette
    @StateObject private var m = NewsModel()
    @EnvironmentObject var host: Host
    var body: some View {
        ZStack {
            if let s = m.screen { ScreenBody(screen: s, pal: pal) }
            else { (pal.color("bg") ?? Color(.systemBackground)).ignoresSafeArea(); ProgressView() }
            if let e = m.error, m.screen == nil { Text(e).font(Typo.font(12)).foregroundColor(pal.color("sub") ?? .gray) }
            if let d = m.detail { NewsDetailSheet(d: d, pal: pal) { m.detail = nil } }
        }
        .task { await m.load() }
        .onReceive(host.actPublisher) { x in
            guard x.tab == "community" else { return }
            if x.a == "cat" { m.setCat(x.v) }
            else if x.a == "call", x.v.hasPrefix("nw."), !x.id.isEmpty { m.open(id: x.id, title: x.t, host: host) }
        }
        .onChange(of: host.reloadTick) { _ in Task { await m.load() } }
    }
}

/// 기사 상세: 분류 칩 · 제목 18 · 시각 12 · 요약 14 · 출처 안내 11 · [원문 보기] · 닫기 (안드로이드 showDetail)
struct NewsDetailSheet: View {
    let d: NewsModel.NewsDetail
    let pal: Palette
    var close: () -> Void
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { close() }
            VStack(spacing: 0) {
                Capsule().fill(pal.color("border2") ?? .gray).frame(width: 36, height: 4).padding(.bottom, 16)
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if !d.cat.isEmpty {
                            Text(d.cat).font(Typo.font(11, bold: true)).foregroundColor(pal.color("ongold") ?? .black).padding(.horizontal, 9).padding(.vertical, 3)
                                .background(RoundedRectangle(cornerRadius: 6).fill(pal.color("gold") ?? .yellow)).padding(.bottom, 10)
                        }
                        Text(d.title).font(Typo.font(18, bold: true)).foregroundColor(pal.color("text") ?? .white).lineSpacing(4).padding(.bottom, 8)
                        if !d.meta.isEmpty { Text(d.meta).font(Typo.font(12)).foregroundColor(pal.color("sub") ?? .gray).padding(.bottom, 16) }
                        Text(d.body).font(Typo.font(14)).foregroundColor(d.bodyEmpty ? (pal.color("sub") ?? .gray) : (pal.color("text") ?? .white)).lineSpacing(6).padding(.bottom, 8)
                        if !d.notice.isEmpty {
                            Text(d.notice).font(Typo.font(11)).foregroundColor(pal.color("sub") ?? .gray).lineSpacing(4).padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 9).fill(pal.color("card2") ?? .gray.opacity(0.2)))
                        }
                    }
                }
                if d.open, !d.btn.isEmpty {
                    Button { if let u = URL(string: d.link) { UIApplication.shared.open(u) } } label: {
                        Text(d.btn).font(Typo.font(14, bold: true)).foregroundColor(pal.color("ongold") ?? .black).frame(maxWidth: .infinity).frame(height: 46)
                            .background(RoundedRectangle(cornerRadius: 12).fill(pal.color("gold") ?? .yellow))
                    }.buttonStyle(.plain).padding(.top, 14)
                }
                Button { close() } label: {
                    Text(d.close).font(Typo.font(14, bold: true)).foregroundColor(pal.color("sub") ?? .gray).frame(maxWidth: .infinity).frame(height: 44)
                }.buttonStyle(.plain)
            }
            .padding(EdgeInsets(top: 12, leading: 20, bottom: 16, trailing: 20))
            .frame(maxWidth: 520).frame(maxHeight: UIScreen.main.bounds.height * 0.8)
            .fixedSize(horizontal: false, vertical: true)
            .background(pal.color("card") ?? .black)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
        }
        .transition(.move(edge: .bottom))
    }
}
