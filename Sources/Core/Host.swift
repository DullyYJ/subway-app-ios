import SwiftUI
import Combine

/// 화면에서 눌린 행동(Action)을 받아 처리하는 곳. 안드로이드의 ShellActivity 가 하던 일을 단계별로 옮긴다.
/// 1단계: open(https) · tab.* 전환 · set(스위치 저장) · refresh · 나머지는 '아직 연결 안 됨' 안내로 기록한다.
@MainActor
final class Host: ObservableObject {
    @Published var tab: String = UserDefaults.standard.string(forKey: "tab") ?? "home" { didSet { UserDefaults.standard.set(tab, forKey: "tab") } }
    @Published var toast: String? = nil
    @Published var reloadTick = 0
    private var lastRetry = Date.distantPast
    @Published var fieldClear: [String: Int] = [:]
    /// 입력칸 글을 비운다(보낸 뒤) — 칸 화면에도 알려 글자를 지운다.
    func clearField(_ k: String) { UserDefaults.standard.removeObject(forKey: "field." + k); fieldClear[k, default: 0] += 1 }
    @Published var sheet: SheetRoute? = nil
    /// 잠깐 떴다 사라지는 작은 안내 카드(엔진 /screen/dlg kind:pop — 안드로이드 ShellActivity.dlgPopSh). 2.8초 뒤 닫히고, 눌러도 닫힌다. 카드를 못 받으면 토스트로 대신한다.
    @Published var pop: Screen? = nil
    /// 하차 추천 팝업(엔진 /screen/dlg kind:reco — 안드로이드 ShellActivity.recoPop). [맛집·쿠팡 보기]=dl.go → 추천 줄 열기 · [확인]=닫기. 못 띄우면 false(부르는 쪽이 알림으로 대신).
    @Published var reco: Screen? = nil
    private var recoAd: RecoFlow.Ad? = nil
    func showReco(title: String, text: String, ad: RecoFlow.Ad?) async -> Bool {
        guard reco == nil else { return false }
        let go = (ad != nil && !(ad!.a.isEmpty)) ? ad!.go : ""
        let body = "{\"cap\":\(Servers.cap),\"f\":{\"kind\":\"reco\",\"title\":\(Json.q(title)),\"body\":\(Json.q(text)),\"go\":\(Json.q(go)),\"ok\":\"확인\"}}"
        guard let sc = try? await Net.screen("/screen/dlg", body: body) else { return false }
        recoAd = ad; reco = sc
        return true
    }
    func recoAct(_ v: String) {
        let ad = recoAd
        reco = nil; recoAd = nil
        RideLoop.shared.recoDone()
        if v == "dl.go" || v == "dl.ok", let ad = ad { RecoFlow.open(ad) }
    }
    /// 출퇴근 브리핑 창(설정 p=cmb — 안드로이드 ShellActivity.briefLaunch): 알림을 누르면 가운데 창에 글을 보이고 [확인] · [출근하기]/[퇴근하기]. 글은 엔진이 만든 것을 그대로 쓴다.
    @Published var cmb: Screen? = nil
    private var cmbKind = "morn"
    /// 출·퇴근 시각 고르기 팝업(설정 p=cm sub=tp pop) — 설정 화면이 열고 닫는다.
    @Published var cmPop: Screen? = nil
    func cmbOpen(kind: String, title: String, body: String, fresh: Bool) {
        Task {
            var k = kind == "eve" ? "eve" : "morn", t = title, b = body
            if !fresh {                                                  // 미리 걸어 둔 안내 글이면 지금 엔진 글을 새로 받는다
                if let x = await CommuteAlarm.brief(kind: k) { t = x.0; b = x.1; k = x.2 }
                else { b = "브리핑을 받지 못했어요. 잠시 뒤에 다시 열어 주세요." }
            }
            cmbKind = k
            let pf = "{\"pf\":{\"cb\":{\"kind\":\(Json.q(k)),\"title\":\(Json.q(t)),\"body\":\(Json.q(b))}}}"
            if let d = try? await Net.request("GET", CommuteAlarm.pageUrl("cmb", pf), timeout: 9), let sc = try? Screen.parse(d) { cmb = sc }
            else { say(t) }
        }
    }
    /// 위치 정보 이용 안내(엔진 설정 p=locd — 안드로이드 locGate): 처음 위치 권한을 묻기 전에 한 번. [동의]=locd.ok · [거부]=locd.no · 방침 줄=pol.privacy(방침을 보고 돌아오면 다시 안내).
    @Published var locd: Screen? = nil
    func locdOpen() async {
        let url = Servers.base + "/screen/settings?cap=\(Servers.cap)&p=locd"
        if let d = try? await Net.request("GET", url, timeout: 9), let sc = try? Screen.parse(d) { locd = sc }
        else { FirstRun.answer(true) }                                       // 안내를 못 받으면 막지 않는다(기기 창으로 바로)
    }
    func locdAct(_ v: String) {
        if v == "locd.ok" { locd = nil; FirstRun.answer(true) }
        else if v == "locd.no" { locd = nil; FirstRun.answer(false); say("위치 정보 이용에 동의하지 않아 내 위치를 쓸 수 없어요") }
        else if v == "pol.privacy" {
            Task {
                if let d = try? await Net.request("GET", Servers.base + "/screen/settings?cap=\(Servers.cap)&p=polp", timeout: 9), let sc = try? Screen.parse(d) { locd = sc }
            }
        }
        else if v == "pg.back" { Task { await locdOpen() } }                 // 방침을 보다가 돌아오면 안내로
    }
    func cmbAct(_ v: String) {
        cmb = nil
        if v == "cmb.go" { CommuteAlarm.startRoute(kind: cmbKind, host: self) }
    }
    func showPop(_ msg: String, _ sub: String, cls: String = "sh") {
        Task {
            let body = "{\"cap\":\(Servers.cap),\"f\":{\"kind\":\"pop\",\"msg\":\(Json.q(msg)),\"sub\":\(Json.q(sub)),\"cls\":\(Json.q(cls))}}"
            guard let sc = try? await Net.screen("/screen/dlg", body: body) else { say(msg); return }
            pop = sc
            let mine = sc.raw["rev"] as? String
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            if (pop?.raw["rev"] as? String) == mine { pop = nil }
        }
    }
    /// 분류 칩(cat) · 글 펼침(tog) 같은 탭 안의 행동: 켜진 탭이 받아 자기 화면을 다시 그린다.
    struct TabAction { let tab: String; let a: String; let v: String; let id: String; let key: String; var t: String = ""; var on: Bool = false }
    let actPublisher = PassthroughSubject<TabAction, Never>()

    struct SheetRoute: Identifiable { let id = UUID(); let path: String; let body: String?; let title: String }

    /// 안드로이드 ShellCore.TABS 순서가 아니라 서버가 tabs 화면에서 정한다. 여기서는 이름만 안다.
    init() {   // 시험용: `-tab shop` 으로 켜면 그 탭부터 보인다
        let a = CommandLine.arguments
        if let i = a.firstIndex(of: "-tab"), i + 1 < a.count, Host.tabNames.contains(a[i + 1]) { tab = a[i + 1] }
    }

    static let tabNames = ["community", "map", "home", "shop", "food"]

    func handle(_ a: Action) {
        switch a.a {
        case "open":
            // s481 (안드로이드 ShellActivity.shopGo 와 같다): 쇼핑 상품을 누르면 그림과 함께 '쿠팡앱으로 연결하시겠습니까?' 카드를 먼저 띄운다(아니오 / 예)
            if tab == "shop", let u = a.url, let t = a.t, !t.isEmpty { actPublisher.send(TabAction(tab: "shop", a: "open", v: u, id: a.img ?? "", key: "", t: t)); return }
            if let u = a.url, let url = URL(string: u), url.scheme == "https" { UIApplication.shared.open(url) }
        case "refresh":
            reloadTick += 1
        case "cat", "tog":
            actPublisher.send(TabAction(tab: tab, a: a.a, v: a.v ?? "", id: a.id ?? "", key: a.key ?? ""))
        case "set":
            if a.key == "kidsHome" { actPublisher.send(TabAction(tab: "kids", a: "set", v: "", id: "", key: "kidsHome", on: a.on ?? false)) }
            else if tab == "community" { actPublisher.send(TabAction(tab: "community", a: "set", v: "", id: "", key: a.key ?? "", on: a.on ?? false)) }
            else if let k = a.key { UserDefaults.standard.set(a.on ?? false, forKey: "set." + k) }
        case "sel", "web":
            actPublisher.send(TabAction(tab: "community", a: a.a, v: a.v ?? a.url ?? "", id: "", key: a.key ?? ""))
        case "call":
            if a.v == "gdm_retry" {                                        // 서버 지연 안내의 [다시 시도] — 지금 다시 받는다(안드로이드 RETRY_ACT, 600ms 안의 거듭 누름은 한 번으로)
                let now = Date()
                if now.timeIntervalSince(lastRetry) > 0.6 { lastRetry = now; reloadTick += 1 }
                return
            }
            if let v = a.v, locd != nil, v.hasPrefix("locd.") || v == "pol.privacy" || v == "pg.back" { locdAct(v) }
            else if let v = a.v, v.hasPrefix("dl."), reco != nil { recoAct(v) }
            else if let v = a.v, Host.isKidsCall(v) { actPublisher.send(TabAction(tab: "kids", a: "call", v: v, id: a.id ?? "", key: a.key ?? "", t: a.t ?? "")) }
            else if let v = a.v, v.hasPrefix("cmb.") { cmbAct(v) }
            else if let v = a.v, v.hasPrefix("cm.") || v.hasPrefix("pk.") || v.hasPrefix("tp.") { actPublisher.send(TabAction(tab: "community", a: "call", v: v, id: a.id ?? "", key: a.key ?? "")) }
            else if let v = a.v, v.hasPrefix("cc.") || v.hasPrefix("nw.") || v.hasPrefix("ch.") || v == "saveId" || v == "clearId" || v.hasPrefix("pol.") || v.hasPrefix("pg.") || v.hasPrefix("arr.") || v == "errlog" { actPublisher.send(TabAction(tab: "community", a: "call", v: v, id: a.id ?? "", key: a.key ?? "", t: a.t ?? "")) }
            else if let v = a.v, v.hasPrefix("fm.") { actPublisher.send(TabAction(tab: "food", a: "call", v: v, id: a.id ?? "", key: a.key ?? "")) }
            else if let v = a.v, v.hasPrefix("bd.") || v.hasPrefix("wr.") { actPublisher.send(TabAction(tab: "community", a: "call", v: v, id: a.id ?? "", key: a.key ?? "")) }
            else if let v = a.v, v.hasPrefix("mp.") || v.hasPrefix("br.") || v.hasPrefix("mr.") { actPublisher.send(TabAction(tab: "map", a: "call", v: v, id: a.id ?? "", key: a.key ?? "")) }
            else if let v = a.v, v.hasPrefix("dl."), tab == "shop" { actPublisher.send(TabAction(tab: "shop", a: "call", v: v, id: "", key: "")) }
            else if let v = a.v, v.hasPrefix("rt.") || v.hasPrefix("sg.") || v.hasPrefix("bt.") || v.hasPrefix("rh.") || v.hasPrefix("rd.") || v.hasPrefix("dl.") || v.hasPrefix("ai.") || v.hasPrefix("tk.") || v.hasPrefix("share.") || v.hasPrefix("fv.") { actPublisher.send(TabAction(tab: "home", a: "call", v: v, id: a.id ?? "", key: a.key ?? "")) }
            else { call(a.v ?? "") }
        default:
            say("‘\(a.a)’ 행동은 아직 연결되지 않았어요 (v=\(a.v ?? "-"))")
        }
    }

    /// 길동무 키즈 서버 화면의 행동 이름(kl. · kh. · kg. · kr. · kq. · kx. · kn. · km. · kpg. …) — 처리는 Sources/Kids 가 한다(키즈 앱에는 그 폴더가 없어 여기서는 이름만 가린다).
    static func isKidsCall(_ v: String) -> Bool {
        guard v.first == "k", let dot = v.firstIndex(of: ".") else { return false }
        let n = v.distance(from: v.startIndex, to: dot)
        return (2...3).contains(n) && v[v.index(after: v.startIndex)..<dot].allSatisfy { $0 >= "a" && $0 <= "z" }
    }

    func call(_ v: String) {
        if v.hasPrefix("tab.") {
            let t = String(v.dropFirst(4))
            if Host.tabNames.contains(t) { tab = t }
            return
        }
        if v.hasPrefix("fm.") { actPublisher.send(TabAction(tab: "food", a: "call", v: v, id: "", key: "")); return }
        if v.hasPrefix("bd.") { actPublisher.send(TabAction(tab: "community", a: "call", v: v, id: "", key: "")); return }
        say("call ‘\(v)’ 는 아직 연결되지 않았어요")
    }

    func say(_ m: String) {
        toast = m
        Task { try? await Task.sleep(nanoseconds: 2_500_000_000); if self.toast == m { self.toast = nil } }
    }
}
