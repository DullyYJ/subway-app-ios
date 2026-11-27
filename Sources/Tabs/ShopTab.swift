import SwiftUI

/// 쇼핑 탭(안드로이드 ShellActivity.shopDirect 와 같다): 상품 서버(/shop)와 운영 설정(/app-config?k=shop)을 동시에 받아 POST /screen/shop 에 실어 보낸다.
/// 분류 칩(cat 행동)을 누르면 같은 요청을 분류만 바꿔 다시 보낸다. 무엇을 어떻게 그릴지는 모두 엔진이 정한다.
@MainActor
final class ShopModel: ObservableObject {
    @Published var screen: Screen? = nil
    @Published var error: String? = nil
    @Published var cat: String = UserDefaults.standard.string(forKey: "shop.cat") ?? ""
    private var shopRaw: Data? = nil, cfgRaw: Data? = nil
    /// s481: 상품을 누르면 뜨는 확인 카드(엔진 /screen/dlg kind:shopgo). 예 → 쿠팡 주소를 연다 · 아니오 · 바깥 → 닫기. 못 받으면 예전처럼 바로 연다.
    @Published var dlg: Screen? = nil
    private var goUrl: String? = nil, asking = false

    func ask(url: String, name: String, img: String) async {
        guard dlg == nil, !asking else { return }
        asking = true; defer { asking = false }
        let body = "{\"cap\":\(Servers.cap),\"f\":{\"kind\":\"shopgo\",\"n\":\(Json.q(name)),\"i\":\(Json.q(img))}}"
        if let s = try? await Net.screen("/screen/dlg", body: body) { goUrl = url; dlg = s }
        else { Self.openLink(url) }
    }
    func dlgAct(_ v: String) {
        if v == "dl.keep" { return }                                  // 카드 안의 그림을 눌러도 닫지 않는다
        let u = goUrl
        dlg = nil; goUrl = nil
        if v == "dl.ok", let u = u { Self.openLink(u) }
    }
    private static func openLink(_ u: String) { if let url = URL(string: u), url.scheme == "https" { UIApplication.shared.open(url) } }

    func setCat(_ c: String) { cat = c; UserDefaults.standard.set(c, forKey: "shop.cat"); Task { await load(fetch: false) } }

    func load(fetch: Bool = true) async {
        if fetch || shopRaw == nil {
            async let a = try? Net.request("GET", Servers.shop + "/shop", timeout: 11)
            async let b = try? Net.request("GET", Servers.food + "/app-config?k=shop", timeout: 4)
            let (sa, sb) = await (a, b)
            if let sa = sa, Json.isObject(sa) { shopRaw = sa }
            cfgRaw = (sb != nil && Json.isObject(sb!)) ? sb : nil
        }
        guard let shop = shopRaw, let shopText = String(data: shop, encoding: .utf8) else { error = "상품을 받지 못했어요"; return }
        var body = "{\"cap\":\(Servers.cap),\"cat\":\(Json.q(cat))"
        if let loc = LocationStore.shared.rounded { body += ",\"lat\":\(loc.0),\"lng\":\(loc.1)" }
        body += ",\"shop\":\(shopText)"
        if let c = cfgRaw, let t = String(data: c, encoding: .utf8) { body += ",\"cfg\":\(t)" }
        body += "}"
        do { screen = try await Net.screen("/screen/shop", body: body); error = nil }
        catch { self.error = error.localizedDescription }
    }
}

struct ShopTab: View {
    let pal: Palette
    @StateObject private var m = ShopModel()
    @EnvironmentObject var host: Host
    var body: some View {
        ZStack {
            if let s = m.screen { ScreenBody(screen: s, pal: pal, swipe: SwipeCfg(tab: "shop", host: host)) }
            else { (pal.color("bg") ?? Color(.systemBackground)).ignoresSafeArea(); ProgressView() }
            if let e = m.error, m.screen == nil { RetryCard(msg: e, pal: pal) }
            if let d = m.dlg { DlgCard(screen: d, pal: pal) { m.dlgAct($0) } }
        }
        .task { LocationStore.shared.start(); await m.load() }
        .onReceive(host.actPublisher) { x in
            guard x.tab == "shop" else { return }
            if x.a == "cat" { m.setCat(x.v) }
            else if x.a == "open" { Task { await m.ask(url: x.v, name: x.t, img: x.id) } }
            else if x.a == "call", x.v.hasPrefix("dl.") { m.dlgAct(x.v) }
        }
        .onChange(of: host.reloadTick) { _ in Task { await m.load() } }
        .modifier(AutoRetry(delays: m.screen?.retryHint))          // 엔진이 준 "서버 연결 지연" 안내가 떠 있으면 엔진이 정한 간격으로 뒤에서 다시 받는다
    }
}
