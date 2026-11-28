import WidgetKit
import SwiftUI

/// 캐릭터 시계 홈 화면 위젯 — 안드로이드 '길동무 캐릭터 시계'(가로 · 세로 × 블랙 · 화이트)의 iOS 판.
/// 움직임 · 배치 · 그림은 Shared/Gw*.swift(안드로이드 WidgetSim · WidgetGeo · WidgetArt 의 포팅)이고, 여기는 그 장면을 시각표(타임라인)로 펼쳐 놓는다.
/// ★ iOS 위젯은 앱처럼 계속 그릴 수 없다 — 미리 만든 장면을 시각에 맞춰 갈아 끼울 뿐이라 2~3초 간격으로 움직여 보인다(안드로이드는 0.1초).
struct GwEntry: TimelineEntry { let date: Date; let frame: GwFrame }

struct GwProvider: TimelineProvider {
    let white: Bool
    private func spec(_ ctx: Context) -> GwPlan.Spec {
        let s = ctx.displaySize
        return GwPlan.Spec(vertical: ctx.family == .systemSmall, W: Double(s.width), H: Double(s.height))
    }
    func placeholder(in context: Context) -> GwEntry { entry(context, roamSec: 8, pick: 2) }
    func getSnapshot(in context: Context, completion: @escaping (GwEntry) -> Void) { completion(entry(context, roamSec: 14, pick: 5)) }
    private func entry(_ ctx: Context, roamSec: Double, pick: Int) -> GwEntry {
        var sp = spec(ctx); sp.roam = roamSec
        let now = Date()
        let ep = GwPlan.episode(sp, seed: Int64(now.timeIntervalSince1970 / 60), prev: nil, t0: 0)
        let s = ep.snaps[min(pick, ep.snaps.count - 1)]
        return GwEntry(date: now, frame: GwFrame(items: s.items, geo: ep.geo, date: now, white: white))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GwEntry>) -> Void) {
        let sp = spec(context)
        let now = Date()
        let total = 15 * 60.0, every = 5 * 60.0                      // 15분치를 한 번에 — 5분마다 한 번씩 깨어 돌아다닌다
        var entries: [GwEntry] = []
        var prev: [String]? = nil
        var k = 0
        while Double(k) * every < total {
            let start = Double(k) * every
            let ep = GwPlan.episode(sp, seed: Int64(now.timeIntervalSince1970 / 60) &+ Int64(k), prev: prev, t0: start)
            prev = ep.set
            for s in ep.snaps {
                let d = now.addingTimeInterval(s.t)
                entries.append(GwEntry(date: d, frame: GwFrame(items: s.items, geo: ep.geo, date: d, white: white)))
            }
            // 잠든 동안에도 분이 바뀌면 시계 글자는 새로 그린다(같은 그림, 분만 갱신)
            if let last = ep.snaps.last {
                let nextStart = Double(k + 1) * every
                var m = (floor((now.timeIntervalSince1970 + ep.end) / 60) + 1) * 60 - now.timeIntervalSince1970
                while m < nextStart && m < total {
                    let d = now.addingTimeInterval(m)
                    entries.append(GwEntry(date: d, frame: GwFrame(items: last.items, geo: ep.geo, date: d, white: white)))
                    m += 60
                }
            }
            k += 1
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(total))))
    }
}

struct GwEntryView: View {
    let e: GwEntry
    var body: some View {
        GwCard(f: e.frame)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gwBackground(Color(argb: e.frame.bg))
            .widgetURL(URL(string: "gildongmu://tab/community"))      // 안드로이드와 같다: 위젯을 누르면 앱이 열려 커뮤니티 탭으로 간다
    }
}

extension View {
    @ViewBuilder func gwBackground(_ c: Color) -> some View {
        if #available(iOS 17.0, *) { self.containerBackground(c, for: .widget) } else { self.background(c) }
    }
}

struct GwClockWidget: Widget {
    let kind: String; let white: Bool
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GwProvider(white: white)) { e in GwEntryView(e: e) }
            .configurationDisplayName(white ? "캐릭터 시계 · 흰 글씨" : "캐릭터 시계 · 검은 글씨")
            .description("시계 위를 길동무 캐릭터들이 돌아다녀요. 쉴 땐 각자 집에서 잡니다.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
