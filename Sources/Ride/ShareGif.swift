import UIKit
import ImageIO

/// 내 위치 공유 움직임 그림(GIF) — 안드로이드 ShareArt.gif. 카드 그림 위에서 내 위치 마커가 숨 쉬듯 깜박이고, 길동무 친구 한 마리(무작위)가 노선선 위를 오간다.
/// 움직임 계획은 ShareAnim, 파일 만들기는 ImageIO(GIF). 못 만들면 nil — 그때는 멈춘 그림으로 보낸다.
enum ShareGif {
    /// base: 마커를 뺀 카드 그림(360×214 pt, 2배) · mk: 마커 자리(카드 좌표) · seed: 같은 값이면 같은 친구 · 같은 움직임.
    static func make(base: UIImage, mk: CGPoint, seed: Int64) -> URL? {
        let an = ShareAnim(seed: seed, lo: 36, hi: 360 - 36, charH: 22)
        guard let sheet = loadSheet(Chars.file(an.id)), let cg = sheet.cgImage else { return nil }
        let cell = cg.width / 4
        if cell < 16 { return nil }
        var cells: [UIImage] = []
        for i in 0..<16 {
            guard let part = cg.cropping(to: CGRect(x: (i % 4) * cell, y: (i / 4) * cell, width: cell, height: cell)) else { return nil }
            cells.append(UIImage(cgImage: part, scale: 1, orientation: .up))
        }
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = base.scale; fmt.opaque = false
        let rend = UIGraphicsImageRenderer(size: base.size, format: fmt)
        let card = UIColor(red: 0x1C / 255.0, green: 0x1C / 255.0, blue: 0x1E / 255.0, alpha: 1)
        let cur = UIColor(red: 0x0A / 255.0, green: 0x84 / 255.0, blue: 1, alpha: 1)
        let k = CGFloat(an.charH * an.cfg[5] / (an.cfg[1] - an.cfg[0]))

        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, "com.compuserve.gif" as CFString, ShareAnim.N, nil) else { return nil }
        CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: 0]] as CFDictionary)
        let fprops = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: Double(ShareAnim.delayCs) / 100.0]] as CFDictionary
        for i in 0..<ShareAnim.N {
            let u = CGFloat(an.pulse[i])
            let img = rend.image { c in
                let g = c.cgContext
                g.interpolationQuality = .high
                base.draw(at: .zero)
                func dot(_ r: CGFloat, _ col: UIColor, _ a: CGFloat) {
                    g.setFillColor(col.withAlphaComponent(max(0, min(1, a))).cgColor)
                    g.fillEllipse(in: CGRect(x: mk.x - r, y: mk.y - r, width: r * 2, height: r * 2))
                }
                dot(13, cur, 56 / 255)                                                       // 가만히 있는 연한 테두리
                dot(8 + 14 * u, cur, 110 * (1 - u) / 255)                                    // 퍼져 나가는 물결
                dot(8, card, 1)
                dot(8, cur, 0.62 + 0.38 * CGFloat(cos(Double(u) * 2 * Double.pi)))           // 깜박이는 점
                g.setStrokeColor(card.cgColor); g.setLineWidth(2.5)
                g.strokeEllipse(in: CGRect(x: mk.x - 8, y: mk.y - 8, width: 16, height: 16))
                // 친구: 걷는 시트의 한 칸 — 발이 선 위에 닿는다
                let cx = CGFloat(an.x[i]), footY = mk.y - 1
                g.saveGState()
                if an.face[i] < 0 { g.translateBy(x: cx, y: 0); g.scaleBy(x: -1, y: 1); g.translateBy(x: -cx, y: 0) }
                let left = cx - CGFloat(an.cfg[2]) * k, top = footY - CGFloat(an.cfg[1]) * k
                cells[an.sheet[i]].draw(in: CGRect(x: left, y: top, width: 256 * k, height: 256 * k))
                g.restoreGState()
            }
            guard let f = img.cgImage else { return nil }
            CGImageDestinationAddImage(dest, f, fprops)
        }
        if !CGImageDestinationFinalize(dest) { return nil }
        return write(data as Data, ext: "gif", seed: seed)
    }

    /// 만들어 둔 프레임들을 GIF 한 덩이로(시험이 쓴다).
    static func encode(_ frames: [CGImage], delayCs: Int) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, "com.compuserve.gif" as CFString, frames.count, nil) else { return nil }
        CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: 0]] as CFDictionary)
        let fp = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: Double(delayCs) / 100.0]] as CFDictionary
        for f in frames { CGImageDestinationAddImage(dest, f, fp) }
        return CGImageDestinationFinalize(dest) ? data as Data : nil
    }

    private static func loadSheet(_ name: String) -> UIImage? {
        guard let u = Bundle.main.url(forResource: name, withExtension: "webp", subdirectory: "chars3d"), let d = try? Data(contentsOf: u) else { return nil }
        return UIImage(data: d)
    }

    /// 임시 폴더에 쓴다(지난 공유 파일은 지운다).
    static func write(_ d: Data, ext: String, seed: Int64) -> URL? {
        let dir = FileManager.default.temporaryDirectory
        for u in (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] where u.lastPathComponent.hasPrefix("gildongmu_") { try? FileManager.default.removeItem(at: u) }
        let u = dir.appendingPathComponent("gildongmu_\(seed).\(ext)")
        do { try d.write(to: u, options: .atomic); return u } catch { return nil }
    }
}
