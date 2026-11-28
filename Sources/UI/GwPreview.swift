import SwiftUI

/// 시험용(`-gwPreview`): 홈 화면 위젯이 그릴 장면을 앱 화면에 그대로 보여 준다 — 위젯은 시뮬레이터 화면에서 바로 찍기 어려워서.
struct GwPreview: View {
    @State private var tick = 0
    var body: some View {
        let now = Date()
        let med = GwPlan.episode(.init(vertical: false, W: 338, H: 158, roam: 40, every: 2.5), seed: 7, prev: nil, t0: 0)
        let sml = GwPlan.episode(.init(vertical: true, W: 158, H: 158, roam: 40, every: 2.5), seed: 11, prev: nil, t0: 0)
        let pick = { (e: [GwPlan.Snap], i: Int) in e[min(i, e.count - 1)] }
        ScrollView {
            VStack(spacing: 14) {
                Text("캐릭터 시계 위젯 미리보기").font(Typo.font(15, bold: true))
                ForEach([0, 6, 12], id: \.self) { i in
                    GwCard(f: GwFrame(items: pick(med.snaps, i).items, geo: med.geo, date: now, white: false)).background(Color(argb: 0xFFF2F2F7)).cornerRadius(22)
                }
                HStack(spacing: 12) {
                    GwCard(f: GwFrame(items: pick(sml.snaps, 8).items, geo: sml.geo, date: now, white: true)).background(Color(argb: 0xFF1C1C1E)).cornerRadius(22)
                    GwCard(f: GwFrame(items: pick(sml.snaps, 0).items, geo: sml.geo, date: now, white: false)).background(Color(argb: 0xFFF2F2F7)).cornerRadius(22)
                }
                if let last = med.snaps.last {
                    GwCard(f: GwFrame(items: last.items, geo: med.geo, date: now, white: true)).background(Color(argb: 0xFF1C1C1E)).cornerRadius(22)
                }
            }.padding(16)
        }.background(Color.gray.opacity(0.25))
    }
}
