import Foundation

/// 내 위치 공유 GIF 의 움직임 계획(순수) — 안드로이드 ShareAnim.java + WidgetSim.cfg.
/// 길동무 친구 한 마리(무작위)가 카드의 노선선 위를 두 점 사이로 오가고, 내 위치 마커는 숨 쉬듯 깜박인다.
/// 프레임 수는 마커 깜박임 주기의 배수라 반복할 때 끊김이 없다. 글과 값(역·시각)은 엔진이 정한 것을 그리기만 하고, 여기는 '장식 움직임'만 계획한다.
struct ShareAnim {
    /// 한 바퀴 프레임 수 · 한 프레임 시간(1/100초) · 마커 깜박임 한 번의 프레임 수.
    static let N = 98, delayCs = 7, pulseLen = 14, pause = 6
    static let order = ["dolsom", "lovel", "dudung", "sul", "ppopu", "chaeng", "juksun", "bbosong"]

    /// 시트(256px 칸 4×4)의 값: [칸 안 머리 위 끝, 발 높이, 몸 가로 중심, 초당 프레임, 띄울 높이(키 58 기준), 몸 높이 비율] (WidgetSim.cfg)
    static func cfg(_ id: String) -> [Double] {
        switch id {
        case "dolsom": return [8, 248.5, 120.8, 19, 0, 1]
        case "lovel": return [8, 249.5, 133, 11, 0, 1]
        case "ppopu": return [8, 248.5, 120.3, 19, 0, 1]
        case "chaeng": return [14, 244.5, 154.5, 15, 6, 0.9]
        case "sul": return [27, 230.5, 131, 20, 16, 0.76]
        case "juksun": return [24.5, 247.5, 118.4, 12, 0, 0.9]
        case "bbosong": return [27, 249, 118.5, 12, 0, 0.86]
        default: return [15, 222.5, 128, 13, 0, 1]
        }
    }

    let id: String
    let cfg: [Double]
    let charH: Double                 // 카드 좌표(360 폭 기준)에서 친구의 키
    let x: [Double]                   // 발 중심 x(카드 좌표)
    let face: [Int]                   // +1 오른쪽 · -1 왼쪽
    let sheet: [Int]                  // 걷는 시트 칸(0~15)
    let pulse: [Double]               // 마커 깜박임 위상 0~1

    /// seed: 같은 값이면 같은 계획. lo/hi: 친구가 오갈 수 있는 x 범위.
    init(seed: Int64, lo: Double, hi: Double, charH: Double) {
        var z = UInt64(bitPattern: seed) &* 0x9E3779B97F4A7C15
        z ^= z >> 31; z = z &* 0xBF58476D1CE4E5B9; z ^= z >> 29          // 이어지는 씨앗도 골고루 흩는다
        var r = PlayRng(seed: z)
        let pick = ShareAnim.order[r.int(ShareAnim.order.count)]
        let c = ShareAnim.cfg(pick)
        let span = max(20, hi - lo), d = min(span, 80 + r.next() * 60)
        var a = lo + r.next() * max(0, span - d), b = a + d
        if r.next() < 0.5 { swap(&a, &b) }                              // 어느 쪽에서 출발할지도 무작위
        let n = ShareAnim.N, pz = ShareAnim.pause
        let leg = (n - 2 * pz) / 2                                      // 편도 걷는 프레임 수
        let sc = charH * c[5] / (c[1] - c[0]), stride = 256 * sc * 0.85 / 16          // 시트 한 칸이 나아가는 거리
        var ph = 0.0, px = a
        let fc = b >= a ? 1 : -1
        var xs = [Double](repeating: 0, count: n), fs = [Int](repeating: 1, count: n), ss = [Int](repeating: 0, count: n), ps = [Double](repeating: 0, count: n)
        for i in 0..<n {
            ps[i] = Double(i % ShareAnim.pulseLen) / Double(ShareAnim.pulseLen)
            let t = i
            var tx: Double, f: Int, walking: Bool
            if t < pz { tx = a; f = fc; walking = false }
            else if t < pz + leg { tx = a + (b - a) * (Double(t - pz + 1) / Double(leg)); f = fc; walking = true }
            else if t < 2 * pz + leg { tx = b; f = -fc; walking = false }
            else { tx = b + (a - b) * (Double(t - 2 * pz - leg + 1) / Double(leg)); f = -fc; walking = true }
            if walking { ph += abs(tx - px) / stride } else { ph = 0 }
            px = tx; xs[i] = tx; fs[i] = f; ss[i] = walking ? ((Int(ph) % 16) + 16) % 16 : 0
        }
        id = pick; cfg = c; self.charH = charH; x = xs; face = fs; sheet = ss; pulse = ps
    }
}
