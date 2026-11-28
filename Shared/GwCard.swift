import SwiftUI

/// 위젯 한 장면(그림 목록 + 시계 자리·글). 위젯 타임라인 항목과 앱 안 미리보기가 같이 쓴다.
struct GwFrame {
    var items: [GwDraw]
    var W: Double, H: Double, vertical: Bool
    var clkL: Double, clkT: Double, clkW: Double, clkH: Double, textDp: Double, lineH: Double, dateL: Double, dateT: Double
    var hh: String, mm: String, dateText: String
    var white: Bool            // true: 흰 글씨(어두운 배경) · false: 검은 글씨(밝은 배경)
    var bg: Int { white ? 0xFF1C1C1E : 0xFFF2F2F7 }
}

/// 안드로이드 gdm_widget_{h,v}_{dark,light}.xml 과 같은 층: 날짜 → 시계 → 캐릭터 그림.
struct GwCard: View {
    let f: GwFrame
    var body: some View {
        let col = Color(argb: f.white ? 0xFFFFFFFF : 0xFF111114)
        let dcol = Color(argb: f.white ? 0xFF6B6B73 : 0xFF9A9AA2)
        ZStack(alignment: .topLeading) {
            Text(f.dateText).font(Typo.font(f.dateSp)).foregroundColor(dcol).lineLimit(1).fixedSize()
                .padding(.leading, f.dateL).padding(.top, f.dateT)
                .frame(width: f.W, height: f.H, alignment: .topLeading)
            if f.vertical {
                clockLine(f.hh, col).position(x: f.clkL + f.clkW / 2, y: f.clkT + f.lineH / 2 - 0.07 * f.textDp)
                clockLine(f.mm, col).position(x: f.clkL + f.clkW / 2, y: f.clkT + f.lineH + f.textDp * 0.30 + f.lineH / 2 - 0.07 * f.textDp)
            } else {
                clockLine(f.hh + ":" + f.mm, col).position(x: f.clkL + f.clkW / 2, y: f.clkT + f.clkH / 2 - 0.07 * f.textDp)
            }
            GwStage(items: f.items, W: f.W, H: f.H)
        }
        .frame(width: f.W, height: f.H, alignment: .topLeading)
        .clipped()
    }
    private func clockLine(_ s: String, _ col: Color) -> some View {
        Text(s).font(Typo.font(f.textDp)).monospacedDigit().foregroundColor(col).lineLimit(1).fixedSize()
            .shadow(color: f.white ? .clear : Color.white.opacity(0.4), radius: 3, x: 0, y: 1)
    }
}
extension GwFrame {
    var dateSp: Double { 11 }
    init(items: [GwDraw], geo g: GwGeo, date: Date, white: Bool) {
        let cal = Calendar(identifier: .gregorian)
        let c = cal.dateComponents([.hour, .minute], from: date)
        let df = DateFormatter(); df.locale = Locale(identifier: "ko_KR"); df.dateFormat = "M월 d일 EEEE"
        self.init(items: items, W: g.W, H: g.H, vertical: g.vertical, clkL: g.clkL, clkT: g.clkT, clkW: g.clkW, clkH: g.clkH, textDp: g.textDp, lineH: g.lineH,
                  dateL: g.dateL, dateT: g.dateT, hh: String(format: "%02d", c.hour ?? 0), mm: String(format: "%02d", c.minute ?? 0), dateText: df.string(from: date), white: white)
    }
}

/// 한 번에 이어서 만드는 장면표: 잠든 모습 → (깨어나) 돌아다님 → 잠자리에 듦 → 숨 쉬며 잠 — 안드로이드가 화면 켤 때마다 하는 일을 시각 순서로 미리 펼친다.
/// iOS 위젯은 시간에 맞춰 장면을 갈아 끼우는 것(타임라인)만 되고 100ms 단위로 돌릴 수는 없어서, 2~3초 간격 장면으로 보인다.
enum GwPlan {
    struct Snap { var t: Double; var items: [GwDraw] }
    struct Spec { var vertical: Bool; var W: Double; var H: Double; var roam = 100.0, every = 2.5, bedSec = 22.0, breathSec = 12.0 }

    /// 한 번의 깸(에피소드). 시작 t0 초에서 시작해 장면 목록과 끝난 시각을 돌려준다.
    static func episode(_ sp: Spec, seed: Int64, prev: [String]?, t0: Double) -> (snaps: [Snap], end: Double, set: [String], geo: GwGeo) {
        let g = GwGeo.of(vertical: sp.vertical, W: sp.W, H: sp.H)
        let ids = GwSim.pickSet(seed: seed, prev: prev)
        let sim = GwSim(geo: g, seed: seed, ids: ids)
        sim.asleepNow()
        var out: [Snap] = []; var t = t0
        func snap() { out.append(Snap(t: t, items: GwArt.draw(sim))) }
        func run(_ sec: Double, every: Double) {
            var acc = 0.0, left = sec
            while left > 1e-9 {
                let dt = min(0.1, left); sim.step(dt); left -= dt; t += dt; acc += dt
                if acc >= every - 1e-9 { acc = 0; snap() }
            }
        }
        for _ in 0..<3 { sim.step(0.1) }
        snap()                                   // 자는 모습
        sim.wakeAll(3)
        run(sp.roam, every: sp.every)
        sim.bed(untilTapped: true)
        run(sp.bedSec, every: sp.every)
        sim.snapBed(); sim.snapAsleep()
        run(sp.breathSec, every: 1)
        snap()
        return (out, t, ids, g)
    }
}
