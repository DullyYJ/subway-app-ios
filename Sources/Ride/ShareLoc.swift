import SwiftUI
import UIKit

/// 내 위치 공유(안드로이드 ShellActivity.shareLoc + ShareArt.draw): 엔진이 overlay.share 로 준 재료를 카드 그림 + 글로 만들어 공유창(카카오톡 등)으로 보낸다.
/// 그림은 안드로이드 ShareArt 의 정지 그림(360×214, 2배)과 같은 배치 — 움직이는 GIF 는 다음 단계.
enum ShareLoc {
    @MainActor
    static func present(host: Host) {
        guard let sh = RideLoop.shared.share else { host.say("경로를 먼저 탐색해 주세요"); return }
        let text = sh["text"] as? String ?? ""
        let card = ShareCardView(d: ShareCardData(sh))
        let r = ImageRenderer(content: card)
        r.scale = 2
        var items: [Any] = [text]
        if let img = r.uiImage { items.append(img) }
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        guard let root = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first?.rootViewController else { return }
        var top = root
        while let p = top.presentedViewController { top = p }
        vc.popoverPresentationController?.sourceView = top.view
        vc.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 1, height: 1)
        top.present(vc, animated: true)
    }

    /// 그림에 그릴 칸: 값 ≥ 0 이면 역 번호, 값 < 0 이면 -(건너뛴 역 수). 출발 · 도착 · 지금 역과 그 앞뒤만.
    static func slots(_ n: Int, _ hit: Int) -> [Int] {
        if n <= 0 { return [] }
        var want = [Bool](repeating: false, count: n)
        let h = max(0, min(n - 1, hit))
        want[0] = true; want[n - 1] = true; want[h] = true
        if h - 1 >= 0 { want[h - 1] = true }
        if h + 1 < n { want[h + 1] = true }
        var out: [Int] = []; var prev = -1
        for i in 0..<n where want[i] {
            if prev >= 0 && i - prev > 1 { out.append(-(i - prev - 1)) }
            out.append(i); prev = i
        }
        return out
    }
}

struct ShareCardData {
    var lbT = "", lbA = "", lbR = "", from = "", cur = "", to = "", arr = "", rem = "", foot = ""
    var names: [String] = [], times: [String] = []
    var hit = 0
    init(_ m: [String: Any]) {
        func s(_ k: String) -> String { m[k] as? String ?? "" }
        if let lb = m["lb"] as? [String: Any] { lbT = lb["t"] as? String ?? ""; lbA = lb["a"] as? String ?? ""; lbR = lb["r"] as? String ?? "" }
        from = s("from"); cur = s("cur"); to = s("to"); arr = s("arr"); rem = s("rem"); foot = s("foot")
        for x in m["stations"] as? [[String: Any]] ?? [] {
            let n = x["n"] as? String ?? ""
            if n.isEmpty { continue }
            names.append(n); times.append(x["t"] as? String ?? "")
        }
        let n = names.count
        hit = max(0, min(max(0, n - 1), (m["hit"] as? NSNumber)?.intValue ?? 0))
    }
}

struct ShareCardView: View {
    let d: ShareCardData
    private let W: CGFloat = 360, H: CGFloat = 214
    private let card = Color(red: 0x1C / 255.0, green: 0x1C / 255.0, blue: 0x1E / 255.0)
    private let border = Color(white: 1, opacity: 0.12)
    private let text = Color.white, sub = Color(white: 0.6)
    private let acc = Color(red: 0, green: 0x90 / 255.0, blue: 0xD2 / 255.0), cur = Color(red: 0x0A / 255.0, green: 0x84 / 255.0, blue: 1)

    var body: some View {
        let slots = ShareLoc.slots(d.names.count, d.hit)
        let x0: CGFloat = 18, x1 = W - 18, ly: CGFloat = 138
        let step = slots.count > 1 ? (x1 - x0 - 40) / CGFloat(slots.count - 1) : 0
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18).fill(card)
            RoundedRectangle(cornerRadius: 18).stroke(border, lineWidth: 1)
            t(d.lbT, 11, false, sub).frame(width: W - 36, alignment: .leading).position(x: 18 + (W - 36) / 2, y: 26 - 4)
            t(d.from + " - " + d.cur + " - " + d.to, 14, true, text).frame(width: W - 36, alignment: .leading).position(x: 18 + (W - 36) / 2, y: 48 - 5)
            t(d.lbA + d.arr, 12, false, sub).frame(width: W - 36, alignment: .leading).position(x: 18 + (W - 36) / 2, y: 68 - 4)
            t(d.lbR + d.rem, 26, true, acc).frame(width: W - 36, alignment: .leading).position(x: 18 + (W - 36) / 2, y: 100 - 9)
            Path { p in p.move(to: CGPoint(x: x0, y: ly)); p.addLine(to: CGPoint(x: x1, y: ly)) }
                .stroke(acc.opacity(0.55), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            ForEach(Array(slots.enumerated()), id: \.offset) { k, sl in
                let x = slots.count > 1 ? x0 + 20 + step * CGFloat(k) : (x0 + x1) / 2
                if sl < 0 {
                    Rectangle().fill(card).frame(width: 34, height: 18).position(x: x, y: ly)
                    t("··· \(-sl)", 11, true, sub).position(x: x, y: ly)
                } else {
                    let passed = sl < d.hit, isCur = sl == d.hit
                    if isCur {
                        Circle().fill(cur.opacity(0.22)).frame(width: 26, height: 26).position(x: x, y: ly)
                        Circle().fill(cur).frame(width: 16, height: 16).overlay(Circle().stroke(card, lineWidth: 2.5)).position(x: x, y: ly)
                    } else {
                        Circle().fill(card).frame(width: 12, height: 12)
                            .overlay(Circle().stroke((passed ? sub.opacity(0.6) : acc), lineWidth: 2.5)).position(x: x, y: ly)
                    }
                    t(d.names[sl], 11, isCur, isCur ? cur : text).opacity(passed ? 0.55 : 1).frame(width: 80).position(x: x, y: ly - 22)
                    t(d.times[sl], 10, false, sub).opacity(passed ? 0.55 : 1).frame(width: 60).position(x: x, y: ly + 30)
                }
            }
            t(d.foot, 10, false, sub).frame(width: W - 36, alignment: .leading).position(x: 18 + (W - 36) / 2, y: H - 18 - 3)
        }
        .frame(width: W, height: H)
    }
    private func t(_ s: String, _ size: CGFloat, _ bold: Bool, _ c: Color) -> some View {
        Text(s).font(Typo.font(size, bold: bold)).foregroundColor(c).lineLimit(1).minimumScaleFactor(0.6)
    }
}
