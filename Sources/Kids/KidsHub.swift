import SwiftUI
import Security

/// 길동무 키즈 연동(부모 앱 쪽) — 안드로이드 KidsHub 의 포팅 1차.
/// ★ 원칙: 앱은 그리기만 한다. 연결 · 화면 · 판단은 모두 키즈 서버(엔진)가 하고, 여기는 인증 · 통신 · 받은 화면 표시만 한다.
///  · 부모 기기 등록(/reg role p) → 자녀 폰의 QR · 시크릿 키로 연결(/p/act v=kl.join, t=키)
///  · 설정 맨 위 줄(/p/setrow) · 팝업 화면(/p/act 가 돌려준 screen) · 자녀 허브(/p/screen?v=hub + /p/wait 긴 대기)
/// 이 폴더(Sources/Kids)는 부모 앱 전용이라 키즈 앱의 vendor.sh 가 가져가지 않는다.
@MainActor
final class KidsHub: ObservableObject {
    static let shared = KidsHub()

    @Published private(set) var linked = false
    @Published private(set) var settingsNodes: [[String: Any]] = []
    @Published var sheet: Screen? = nil
    @Published var sheetOpen = false
    @Published var hub: Screen? = nil
    @Published var hubOpen = false
    @Published var note: String? = nil
    @Published var busy = false
    @Published private(set) var start = false

    private let ud = UserDefaults.standard
    private var cid: String { get { ud.string(forKey: "kid.cid") ?? "" } set { ud.set(newValue, forKey: "kid.cid") } }
    private var waitTask: Task<Void, Never>? = nil
    private var lastRefresh = Date.distantPast

    // ───────── 인증(부모 기기 하나에 id · sec 한 쌍) ─────────
    private static func kcGet(_ k: String) -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "kids.parent", kSecAttrAccount as String: k, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }
    @discardableResult private static func kcSet(_ k: String, _ v: String) -> Bool {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "kids.parent", kSecAttrAccount as String: k]
        SecItemDelete(base as CFDictionary)
        var add = base; add[kSecValueData as String] = Data(v.utf8); add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }
    /// 키체인 → (서명 없는 시험 빌드에서 키체인이 막히면) UserDefaults → 없으면 새로 만든다. 한 번 정한 값은 바뀌지 않는다.
    private func credential(_ k: String, make: () -> String) -> String {
        if let v = KidsHub.kcGet(k), !v.isEmpty { return v }
        if let v = ud.string(forKey: "kids.kc." + k), !v.isEmpty { return v }
        let v = make()
        if !KidsHub.kcSet(k, v) { ud.set(v, forKey: "kids.kc." + k) }
        return v
    }
    private lazy var pid: String = credential("id") { "p" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased() }
    private lazy var sec: String = credential("sec") { (0..<16).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined() }
    private var registered: Bool { get { ud.string(forKey: "kid.reg") == "1" } set { ud.set(newValue ? "1" : "0", forKey: "kid.reg") } }

    // ───────── 통신 ─────────
    private func raw(_ method: String, _ path: String, body: [String: Any]? = nil, auth: Bool = true, timeout: TimeInterval = 10) async -> [String: Any]? {
        guard let u = URL(string: Servers.kids + path) else { return nil }
        var r = URLRequest(url: u, timeoutInterval: timeout)
        r.httpMethod = method
        if auth { r.setValue(pid, forHTTPHeaderField: "x-id"); r.setValue(sec, forHTTPHeaderField: "x-sec") }
        if let b = body, let d = try? JSONSerialization.data(withJSONObject: b) { r.httpBody = d; r.setValue("application/json; charset=utf-8", forHTTPHeaderField: "content-type") }
        guard let (d, _) = try? await URLSession.shared.data(for: r), d.count < 600_000 else { return nil }
        return (try? JSONSerialization.jsonObject(with: d)) as? [String: Any]
    }
    private func ensureReg() async -> Bool {
        if registered { return true }
        let o = await raw("POST", "/reg", body: ["id": pid, "sec": sec, "role": "p"], auth: false)
        if (o?["ok"] as? Bool) == true { registered = true; return true }
        return false
    }
    private func call(_ method: String, _ path: String, body: [String: Any]? = nil, timeout: TimeInterval = 10) async -> [String: Any]? {
        guard registered else { return nil }
        return await raw(method, path, body: body, timeout: timeout)
    }
    private func enc(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "" }
    private func screen(_ o: Any?) -> Screen? {
        guard let m = o as? [String: Any], let d = try? JSONSerialization.data(withJSONObject: m) else { return nil }
        return try? Screen.parse(d)
    }

    // ───────── 설정 맨 위 줄 ─────────
    private static let unlinkedRow: [[String: Any]] = [[
        "t": "panel", "pad": [16, 12, 16, 0], "ip": [16, 6, 16, 6], "fill": "card", "line": "border", "r": 14,
        "kids": [["t": "navrow", "title": "길동무 키즈 연결", "sub": "자녀 폰의 QR이나 시크릿 키로 연결해요", "act": ["a": "call", "v": "kl.open"], "size": 14, "top": true]]
    ]]
    /// 설정 화면에 끼울 노드들(연결 전엔 '연결' 한 줄, 연결 뒤엔 엔진이 준 줄들).
    var extraNodes: [[String: Any]] { linked && !settingsNodes.isEmpty ? KidsHub.openRow + settingsNodes : KidsHub.unlinkedRow }
    /// 연결된 뒤 자녀 허브를 여는 줄(안드로이드의 키즈 탭 자리 — 아이폰은 탭 막대가 서버 화면이라 우선 설정 맨 위에 둔다).
    private static let openRow: [[String: Any]] = [[
        "t": "panel", "pad": [16, 12, 16, 0], "ip": [16, 6, 16, 6], "fill": "card", "line": "gold", "r": 14,
        "kids": [["t": "navrow", "title": "자녀 보기", "sub": "자녀의 지금 모습 · 대화 · 미션을 실시간으로 봐요", "act": ["a": "call", "v": "kh.open"], "size": 14, "top": true]]
    ]]

    /// 연결 상태 · 설정 줄을 엔진에 묻는다(20초 안엔 다시 묻지 않는다). 한 번도 연결을 시도하지 않은 기기는 아무것도 보내지 않는다.
    func refreshLink(force: Bool = false) {
        guard registered, force || Date().timeIntervalSince(lastRefresh) > 20 else { return }
        lastRefresh = Date()
        Task {
            guard let o = await call("GET", "/p/setrow?kn=1" + (cid.isEmpty ? "" : "&cid=" + enc(cid))), (o["ok"] as? Bool) == true else { return }
            let nodes = o["nodes"] as? [[String: Any]] ?? []
            settingsNodes = nodes; linked = !nodes.isEmpty; start = (o["start"] as? NSNumber)?.intValue == 1
            if !linked, hubOpen { closeHub() }
        }
    }

    // ───────── 눌림 → 엔진 → 새 화면 ─────────
    /// 화면 안의 입력칸 글을 모은다(NodeView 가 UserDefaults field.<key> 에 적어 둔다).
    private func fields(in s: Screen?) -> [String: String] {
        var out: [String: String] = [:]
        func walk(_ n: Node) {
            if n.t == "field", let k = n.str("key") { out[k] = ud.string(forKey: "field." + k) ?? "" }
            n.kids.forEach(walk)
        }
        s?.head.forEach(walk); s?.body.forEach(walk); s?.foot.forEach(walk)
        return out
    }

    func act(_ v: String, id: String = "", t: String = "") {
        busy = true
        let src = sheetOpen ? sheet : hub
        Task {
            defer { busy = false }
            guard await ensureReg() else { say("연결하지 못했어요. 잠시 뒤에 다시 해 보세요"); return }
            var b: [String: Any] = ["v": v, "cid": cid]
            if !id.isEmpty { b["id"] = id }
            if !t.isEmpty { b["t"] = t }
            b["f"] = fields(in: src)
            guard let o = await call("POST", "/p/act", body: b, timeout: 12) else { say("보내지 못했어요. 연결을 확인해 주세요"); return }
            if (o["ok"] as? Bool) != true { say(o["err"] as? String ?? "처리하지 못했어요"); return }
            if let c = o["cid"] as? String, !c.isEmpty { cid = c }
            let sc = screen(o["screen"])
            let close = (o["close"] as? NSNumber)?.boolValue ?? false
            let notice = o["notice"] as? String ?? "", clear = o["clear"] as? String ?? ""
            if close, !v.hasSuffix(".cancel") { sheetOpen = false }
            if let sc = sc {
                if sc.name == "kids" { hub = sc } else { sheet = sc; sheetOpen = true }
            }
            if !clear.isEmpty { ud.removeObject(forKey: "field." + clear) }
            if !notice.isEmpty { say(notice) }
            if v.hasPrefix("kl."), v != "kl.open", v != "kl.close", v != "kl.scan" { refreshLink(force: true) }
            if (o["hub"] as? NSNumber)?.intValue == 1, hubOpen { await fetchHub() }
        }
    }

    func setStart(_ on: Bool) {
        start = on
        Task { _ = await call("POST", "/p/act", body: ["v": "kl.start", "t": on ? "1" : "0", "cid": cid]); refreshLink(force: true) }
    }

    func say(_ m: String) {
        note = m
        Task { try? await Task.sleep(nanoseconds: 3_000_000_000); if note == m { note = nil } }
    }

    // ───────── 자녀 허브(서버가 준 화면 그대로 · 긴 대기로 실시간) ─────────
    func openHub() {
        hubOpen = true
        waitTask?.cancel()
        waitTask = Task { [weak self] in
            guard let self = self else { return }
            guard await self.ensureReg() else { self.say("연결하지 못했어요"); return }
            var since = 0, fails = 0
            await self.fetchHub()
            while !Task.isCancelled, self.hubOpen {
                let o = await self.call("GET", "/p/wait?v=hub&cid=\(self.enc(self.cid))&since=\(since)", timeout: 30)
                guard let o = o, (o["ok"] as? Bool) == true else {
                    fails += 1
                    try? await Task.sleep(nanoseconds: UInt64(min(12.0, 0.5 * pow(2, Double(min(fails, 5)))) * 1_000_000_000)); continue
                }
                fails = 0
                if (o["gone"] as? Bool) == true || (o["linked"] as? NSNumber)?.intValue == 0 { self.refreshLink(force: true); self.closeHub(); return }
                if let r = (o["rev"] as? NSNumber)?.intValue { since = r }
                if let c = o["cid"] as? String, !c.isEmpty { self.cid = c }
                if let sc = self.screen(o["screen"]) { self.hub = sc }
            }
        }
    }
    func closeHub() { hubOpen = false; waitTask?.cancel(); waitTask = nil }
    private func fetchHub() async {
        if let o = await call("GET", "/p/screen?v=hub&cid=" + enc(cid)), (o["ok"] as? Bool) == true {
            if let c = o["cid"] as? String, !c.isEmpty { cid = c }
            if let sc = screen(o["screen"]) { hub = sc }
        }
    }

    /// 시험 전용(CI 화면 확인): 실행 인자 `-ccMode set` → 연결 팝업(kl.open)을, `-ccMode board` → 자녀 허브를 바로 띄운다. 평소 실행엔 영향 없음.
    func demoFromArgs() async {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-ccMode"), i + 1 < a.count else { return }
        try? await Task.sleep(nanoseconds: 6_000_000_000)
        if a[i + 1] == "set" { act("kl.open") } else if a[i + 1] == "board" { openHub() }
    }

    // ───────── QR → 앱 열기(gildongmu-kids://pair?c=…&k=XXXXX-XXXXX) ─────────
    private static let code = try! NSRegularExpression(pattern: "[A-HJ-NP-Z2-9]{5}-[A-HJ-NP-Z2-9]{5}")
    /// QR 글이나 입력한 글에서 시크릿 키만 뽑는다.
    static func codeOf(_ s: String) -> String? {
        let u = s.uppercased()
        if let c = URLComponents(string: s)?.queryItems?.first(where: { $0.name == "k" })?.value?.uppercased(), c.range(of: code.pattern, options: .regularExpression) != nil { return c }
        guard let m = code.firstMatch(in: u, range: NSRange(u.startIndex..., in: u)), let r = Range(m.range, in: u) else { return nil }
        return String(u[r])
    }
    func join(from url: URL) {
        guard url.scheme == "gildongmu-kids", let c = KidsHub.codeOf(url.absoluteString) else { return }
        act("kl.join", t: c)
    }
}

/// 키즈 팝업 · 허브를 앱 위에 띄운다. 서버가 준 화면을 NodeView 로 그리고, 눌림은 모두 KidsHub.act 로 보낸다.
struct KidsHubLayer: ViewModifier {
    let pal: Palette
    @ObservedObject var hub = KidsHub.shared
    @EnvironmentObject var host: Host
    func body(content: Content) -> some View {
        content
            .onReceive(host.actPublisher) { x in
                guard x.tab == "kids" else { return }
                if x.a == "set", x.key == "kidsHome" { hub.setStart(x.on); return }
                if x.v == "kh.open" { hub.openHub(); return }
                if x.v == "kl.close" || x.v == "kh.close" { hub.sheetOpen = false; if x.v == "kh.close" { hub.closeHub() }; return }
                hub.act(x.v, id: x.id, t: x.t)
            }
            .onOpenURL { hub.join(from: $0) }
            .task { hub.refreshLink(force: true); await hub.demoFromArgs() }
            .sheet(isPresented: $hub.sheetOpen) {
                KidsPanel(pal: pal, screen: hub.sheet, onClose: { hub.sheetOpen = false }).environmentObject(host)
            }
            .fullScreenCover(isPresented: $hub.hubOpen) {
                KidsPanel(pal: pal, screen: hub.hub, onClose: { hub.closeHub() }).environmentObject(host)
            }
    }
}

private struct KidsPanel: View {
    let pal: Palette
    let screen: Screen?
    let onClose: () -> Void
    @ObservedObject var hub = KidsHub.shared
    var body: some View {
        ZStack(alignment: .bottom) {
            if let s = screen { ScreenBody(screen: s, pal: pal) }
            else { (pal.color("bg") ?? Color(.systemBackground)).ignoresSafeArea(); ProgressView() }
            VStack {
                HStack { Spacer(); Button(action: onClose) { Text("닫기").font(Typo.font(13, bold: true)).foregroundColor(pal.color("sub") ?? .gray).padding(.horizontal, 14).padding(.vertical, 8) } }
                Spacer()
            }
            if let n = hub.note {
                Text(n).font(Typo.font(12, bold: true)).foregroundColor(.white).padding(10).background(Color.black.opacity(0.8)).cornerRadius(10).padding(.bottom, 16)
            }
        }
    }
}

extension View {
    func kidsHubLayer(pal: Palette) -> some View { modifier(KidsHubLayer(pal: pal)) }
}
