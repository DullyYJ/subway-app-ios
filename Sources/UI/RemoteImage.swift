import SwiftUI
import UIKit

/// 쇼핑 그림: 한 번 받은 그림은 메모리에 두고(다시 그려도 깜빡이지 않는다) 화면이 오면 미리 받아 둔다(안드로이드 ScreenView.ImageBank.warm · imageUrls).
final class ImageStore: @unchecked Sendable {
    static let shared = ImageStore()
    private let cache: NSCache<NSURL, UIImage> = { let c = NSCache<NSURL, UIImage>(); c.totalCostLimit = 60 * 1024 * 1024; return c }()
    private let lock = NSLock()
    private var inflight = Set<URL>()

    func cached(_ u: URL) -> UIImage? { cache.object(forKey: u as NSURL) }

    func load(_ u: URL) async -> UIImage? {
        if let i = cached(u) { return i }
        var r = URLRequest(url: u, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
        r.setValue("image/*", forHTTPHeaderField: "Accept")
        guard let (d, resp) = try? await URLSession.shared.data(for: r), (resp as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
              let img = UIImage(data: d) else { return nil }
        cache.setObject(img, forKey: u as NSURL, cost: d.count)
        return img
    }

    /// 화면에 들어 있는 그림 주소(img: http…)를 뽑는다 — 최대 n 개.
    static func urls(in raw: Any, limit: Int = 240) -> [URL] {
        var out: [URL] = [], seen = Set<String>()
        func walk(_ x: Any) {
            if out.count >= limit { return }
            if let d = x as? [String: Any] {
                if let s = d["img"] as? String, s.hasPrefix("http"), seen.insert(s).inserted, let u = URL(string: s) { out.append(u) }
                for (_, v) in d where v is [String: Any] || v is [Any] { walk(v) }
            } else if let a = x as? [Any] { for v in a { walk(v) } }
        }
        walk(raw)
        return out
    }

    /// 아직 없는 그림을 낮은 우선순위로 두 개씩 받아 둔다(이미 받는 중이거나 있는 것은 건너뛴다).
    func warm(_ urls: [URL]) {
        let todo: [URL] = {
            lock.lock(); defer { lock.unlock() }
            return urls.filter { cached($0) == nil && inflight.insert($0).inserted }
        }()
        if todo.isEmpty { return }
        Task.detached(priority: .utility) { [self] in
            await withTaskGroup(of: Void.self) { g in
                var it = todo.makeIterator(), running = 0
                while let u = it.next() {
                    if running >= 2 { _ = await g.next(); running -= 1 }
                    g.addTask { _ = await self.load(u); self.finish(u) }
                    running += 1
                }
            }
        }
    }
    private func finish(_ u: URL) { lock.lock(); inflight.remove(u); lock.unlock() }
}

/// URL 그림 — 메모리에 있으면 첫 그림부터 바로 보인다. 못 받으면 자리 표시를 그대로 둔다.
struct RemoteImage<Placeholder: View, Content: View>: View {
    let url: URL
    let placeholder: () -> Placeholder
    let content: (Image) -> Content
    @State private var img: UIImage?
    init(url: URL, @ViewBuilder placeholder: @escaping () -> Placeholder, @ViewBuilder content: @escaping (Image) -> Content) {
        self.url = url; self.placeholder = placeholder; self.content = content
        _img = State(initialValue: ImageStore.shared.cached(url))
    }
    var body: some View {
        Group {
            if let i = img { content(Image(uiImage: i)) } else { placeholder() }
        }
        .task(id: url) { if img == nil, let i = await ImageStore.shared.load(url) { img = i } }
    }
}
