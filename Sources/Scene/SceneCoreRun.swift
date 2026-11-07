import Foundation

/// SceneCore 의 실행 구간(안드로이드 SceneCore.java): 엔진 값 받기 · 장소 이동 · 갱신 · TV 전환 · 확장 인사.
let HOST_BG: ARGB = 0xFF9FD0FF
let HOST_RADIUS = 11.0
let TV_BLACK: ARGB = 0xFF04060C

extension SceneCore {
    // ═══ 실행 · 엔진 값 받기 ═══
    func mkWxParts(_ wk: String) -> P {
        let p = P(); let nC: Int
        switch wk { case "cloudy": nC = 5; case "overcast": nC = 7; case "rain": nC = 7; case "snow": nC = 6; case "fog": nC = 4; default: nC = 2 }
        for _ in 0..<nC { p.clouds.append([R.next(), rnd(0.04, 0.3), rnd(0.8, 1.5), rnd(0.5, 1.2)]) }
        if wk == "rain" { for _ in 0..<70 { p.rain.append([R.next(), R.next(), rnd(0.8, 1.3), rnd(5, 9)]) } }
        if wk == "snow" { for _ in 0..<64 { p.snow.append([R.next(), R.next(), rnd(0.45, 1), rnd(0.9, 2.2), R.next() * 6.28]) } }
        for _ in 0..<40 { p.stars.append([R.next(), R.next() * 0.45, R.next() * 6.28, rnd(0.5, 1.3)]) }
        for _ in 0..<3 { p.birds.append([R.next(), rnd(0.1, 0.3), rnd(0.6, 1.1), R.next() * 6.28]) }
        if L.wind > 0 { for _ in 0..<30 { p.wind.append([R.next(), R.next(), rnd(0.6, 1.2), R.next(), R.next() * 6.28]) } }          // 바람이 있을 때만(난수열 그대로 유지)
        return p
    }
    func keyOf(_ Lk: SceneArt.Pal) -> String { "\(Lk.slot)|\(Lk.wk)|\(Lk.season)|\(Lk.place)|w\(Lk.wind)|\(dark)|\(W)|\(H)" }
    func resetBG() {
        bg = SceneArt.buildBG(factory, L, g, dpr, L.season, dark)
        bgKey = keyOf(L); wxP = mkWxParts(L.wk); bgTail = "\(dark)|\(W)|\(H)"
    }
    func boot(_ keepBus: Bool) {
        let bc = css(pickOf(BUS_COLORS)); let bn = pickOf(BUS_NOS); if !keepBus || busNo == nil { busColor = bc; busNo = bn }
        let kk: Double = PH < 150 ? max(0.55, PH / 150) : clamp(min(PH / 190, PW / 200), 1, 2)       // 150px 보다 낮으면 같은 그림을 줄여 그린다
        k = kk; W = PW / kk; H = PH / kk; dpr = dens * kk; g = SceneArt.geom(W, H)
        fade = 0; tv = -1; xf = -1; pan = -1; panBg = nil; panL = nil; panWx = nil; oldTraffic = []; frames = 0; error = nil; prev = nil; running = true
    }
    /// 칸 크기(dp)·화면 밀도·테마를 알려 준다. 바뀌었으면 같은 장면을 새 크기로 다시 만든다.
    func layout(_ pwDp: Double, _ phDp: Double, _ density: Double, _ isDark: Bool) {
        if pwDp < 8 || phDp < 8 { return }
        if laid && running && abs(pwDp - PW) <= 2 && abs(phDp - PH) <= 2 && isDark == dark && abs(density - dens) < 0.01 { return }
        laid = true; PW = pwDp; PH = phDp; dens = density; dark = isDark
        if running && hasRes {
            let m = mode; let keep = res; boot(true); res = keep; hasRes = true; L = SceneArt.paint(res.look); resetBG(); setup(m)
        } else if let l = LAST { apply(l) }
    }
    /// 엔진 답을 받아 그린다. 그릴 게 없으면(mode 없음) 장면을 멈추고 false.
    @discardableResult func apply(_ r0: SceneModel.Res?) -> Bool {
        LAST = r0
        guard let r = r0, !r.mode.isEmpty else { stop(); return false }
        if !laid || !host.ready() { return false }
        if !running { boot(false); res = r; hasRes = true; L = SceneArt.paint(r.look); resetBG(); setup(r.mode) }
        else {
            let modeChanged = mode != r.mode || vk != SceneCore.venueKey(r); res = r; hasRes = true
            let L1 = L, L2 = SceneArt.paint(r.look)
            let keyCh = keyOf(L2) != bgKey
            if keyCh && !modeChanged && mode == "idle" && !reduce && bg != nil && pan < 0 && tv < 0 && "\(dark)|\(W)|\(H)" == bgTail {
                if L2.place != L1.place { startPan(L1, L2) }                                   // 장소가 바뀐다 → 걸어 나가며 배경이 이어 바뀐다
                else { snapshotFade(); L = L2; resetBG() }                                       // 날씨·시간대만 바뀐다 → 서서히 바뀐다
            } else { L = L2; if keyCh { resetBG() } }
            if modeChanged { snapshot(); setup(r.mode) }
            else if mode == "train" { SceneTrain.refresh(self) }
            if mode == "wait" || mode == "alight" { let um = !inside && (L.wk == "rain" || L.wk == "snow"); if let h = hero { h.umb = um } }
        }
        return true
    }
    /// 날씨·시간대가 바뀔 때: 옛 장면 한 장을 찍어 두고 새 장면 위에서 서서히 지운다.
    func snapshotFade() {
        let lay = factory.newLayer(W, H, dpr); prev = lay; paintAll(lay.cv, 0); xf = 0
    }
    /// 장소가 바뀐다: 캐릭터들은 엔진이 정한 쪽(look.pdir)으로 함께 걸어가고(제자리 걸음 + 느슨하게 모여서), 배경은 반대쪽으로 흘러 옛 배경이 새 배경으로 겹쳐 이어진다 — 걸어서 새 장소로 들어가는 느낌.
    func startPan(_ oldL: SceneArt.Pal, _ newL: SceneArt.Pal) {
        dragReset()
        panBg = bg; panL = oldL; panWx = wxP; L = newL; resetBG()
        oldTraffic = traffic; traffic = []                                  // 옛 거리의 차는 옛 배경과 함께 흘러 나간다(새 장소로 넘어오지 않는다)
        panDir = newL.pdir < 0 ? -1 : 1
        var inn: [Actor] = []; var sp = 0.0
        for a in actors where !a.dead && !a.hero && !a.leaving { inn.append(a); sp += max(10, a.spd) }
        sp = inn.isEmpty ? 36 : sp / Double(inn.count)
        panDur = clamp((W - panF()) / (sp * 1.5), PAN_MIN, PAN_MAX)
        inn = inn.enumerated().sorted { p, q in p.element.x != q.element.x ? p.element.x < q.element.x : p.offset < q.offset }.map { $0.element }
        for (i, a) in inn.enumerated() {                                                  // 모여서 함께 걷는다: 왼쪽부터 순서대로 칸을 나눠 서서히 제자리로
            a.held = false; a.leaving = false; a.st = "pan"; a.act = nil; a.onArrive = nil; a.bub = ""; a.stk = nil; a.vis = true; a.hidden = false; a.intro = false; a.y = 0; a.cut = Double.nan
            let want: Double = inn.count == 1 ? W * 0.5 : W * (0.2 + 0.6 * Double(i) / Double(inn.count - 1))
            a.tx = clamp(want, a.w * 0.6, W - a.w * 0.6); a.tz = a.z; a.dir = panDir
            a.boost = clamp(((W - panF()) / panDur) / max(10, a.spd), 1, 2.4)            // 발걸음이 땅 흐르는 속도와 맞는다
        }
        spawnAt = t + 1e9; pan = 0
    }
    func panF() -> Double { min(64, W * 0.2) }                                             // 두 배경이 겹쳐 섞이는 폭
    func panStep(_ dt: Double) {
        pan += dt
        for v in oldTraffic { v.x += Double(v.dir) * v.v * dt; v.rot += Double(v.dir) * v.v * dt * 0.1 }
        if pan >= panDur {
            pan = -1; panBg = nil; panL = nil; panWx = nil; oldTraffic = []; spawnAt = t + rnd(0.9, 2.0)
            for a in actors where a.st == "pan" { a.st = "walk"; a.boost = 0; a.tx = a.x; a.tz = a.z }     // 새 장소에서 평소처럼 이어서 논다
        }
    }
    /// 한 겹 묶음(하늘·먼 건물·가로수·땅)을 ox 만큼 옮겨, 화면 가로 [cx0,cx1] 안에만 alpha 로 그린다. fx 가 참이면 하늘 효과·장소 소품도 함께.
    func drawBgSet(_ c: SceneCv, _ b: SceneArt.Bg, _ pal: SceneArt.Pal, _ wp: P, _ ox: Double, _ cx0: Double, _ cx1: Double, _ alpha: Double, _ fx: Bool) {
        if cx1 - cx0 < 0.5 || alpha <= 0 { return }
        let sb = bg, sl = L, sw = wxP
        bg = b; L = pal; wxP = wp
        defer { bg = sb; L = sl; wxP = sw }
        c.save(); c.beginPath(); c.rect(cx0, 0, cx1 - cx0, H); c.clip(); c.translate(ox, 0)
        if alpha < 1 { c.globalAlpha(alpha) }
        let tw = Double(b.tw)
        c.drawImage(b.sky, 0, 0, W, H); if fx { drawSkyFx(c, t) }
        c.drawImage(b.far, 0, 0, tw, H)
        if fx { SceneFx.drawMid(self, c, b.mid, b.tw) } else { c.drawImage(b.mid, 0, 0, tw, H) }
        c.drawImage(b.gnd, 0, 0, jr(W * dpr), jr(H * dpr), 0, 0, W, H)
        if fx { SceneFx.ambient(self, c, t) }
        c.globalAlpha(1); c.restore()
    }
    /// 이동 중 배경: 옛 배경(전체) 위에 새 배경이 옆에서 겹쳐 들어온다(맞닿는 F 폭은 점점 진하게 섞인다).
    func drawPanBack(_ c: SceneCv) {
        guard let pb = panBg, let pl = panL, let pw = panWx else { return }
        let s = easeIO(pan / panDur), F = panF(), d = Double(panDir), ox0 = panOldX(), ox1 = panNewX(), kk = 2 * s - 1
        drawBgSet(c, pb, pl, pw, ox0, 0, W, 1, true)
        let N = 10
        for i in 0..<N {
            let xm = (Double(i) + 0.5) / Double(N), al = clamp(xm + kk, 0, 1), a0 = Double(i) * F / Double(N), a1 = Double(i + 1) * F / Double(N)
            if al <= 0 { continue }
            if d > 0 { drawBgSet(c, bg, L, wxP, ox1, ox1 + a0, ox1 + a1, al, false) }
            else { drawBgSet(c, bg, L, wxP, ox1, ox1 + W - a1, ox1 + W - a0, al, false) }
        }
        if d > 0 { drawBgSet(c, bg, L, wxP, ox1, ox1 + F, ox1 + W, 1, true) } else { drawBgSet(c, bg, L, wxP, ox1, ox1, ox1 + W - F, 1, true) }
    }
    func drawPanFront(_ c: SceneCv) {
        guard let pl = panL, let pw = panWx else { return }
        let F = panF(), d = Double(panDir), ox0 = panOldX(), ox1 = panNewX()
        let nA = d > 0 ? ox1 + F : ox1, nB = d > 0 ? ox1 + W : ox1 + W - F
        panFrontSeg(c, ox0, pl, pw, max(0, d > 0 ? ox0 : ox1 + W - F), min(W, d > 0 ? ox1 + F : ox0 + W))
        panFrontSeg(c, ox1, L, wxP, max(0, nA), min(W, nB))
    }
    func panFrontSeg(_ c: SceneCv, _ ox: Double, _ pal: SceneArt.Pal, _ wp: P, _ x0: Double, _ x1: Double) {
        if x1 - x0 < 0.5 { return }
        let sl = L, sw = wxP; L = pal; wxP = wp
        defer { L = sl; wxP = sw }
        c.save(); c.beginPath(); c.rect(x0, 0, x1 - x0, H); c.clip(); c.translate(ox, 0); drawWxFront(c, t); c.restore()
    }
    func panOldX() -> Double { -Double(panDir) * (W - panF()) * easeIO(pan / panDur) }
    func panNewX() -> Double { panOldX() + Double(panDir) * (W - panF()) }
    func drawTrafficPan(_ c: SceneCv, _ lane: Int) {
        if pan < 0 || oldTraffic.isEmpty { return }
        let keep = traffic; traffic = oldTraffic
        defer { traffic = keep }
        c.save(); c.translate(panOldX(), 0); drawTraffic(c, lane); c.restore()
    }

    /// 장면이 바뀔 때 옛 장면을 한 장 찍어 두고 서서히 사라지게 한다
    func snapshot() {
        xf = -1; if reduce { prev = nil; tv = -1; return }                                  // 움직임 줄이기: 전환 연출 없이 바로 바뀐다
        let lay = factory.newLayer(W, H, dpr); prev = lay; paintAll(lay.cv, 0); tv = 0
    }
    func stop() { dragReset(); hotUntil = 0; running = false; actors = []; prev = nil; fade = 0; tv = -1; xf = -1; pan = -1; panBg = nil; panL = nil; panWx = nil; oldTraffic = [] }
    func isRunning() -> Bool { running }
    func last() -> SceneModel.Res? { LAST }
    func tag() -> String { running && hasRes ? res.tag : "" }
    func designW() -> Double { W }
    func designH() -> Double { H }
    /// 지하철 객실 쪽에 탑승 엔진의 위치 글(pos: segs 시각표)과 지금 시각(ms)을 알려 준다.
    func trainPos(_ posJson: String) { SceneTrain.feedPos(self, posJson) }
    func trainClock(_ nowMs: Int64) { SceneTrain.feedClock(self, nowMs) }

    func update(_ dt0: Double) {
        if !running { return }
        var dt = dt0
        if reduce { dt = 0 }
        dt = min(0.1, max(0, dt)); dtLast = dt; t += dt; frames += 1
        if tv >= 0 { tv += dt; if tv >= TV_T { tv = -1; prev = nil } }
        if xf >= 0 { xf += dt; if xf >= XF_T { xf = -1; if tv < 0 { prev = nil } } }
        if pan >= 0 { panStep(dt) }
        // 꾹 누르기: 정해진 시간이 지나면 잡힌다
        if let pd = PEND, t - pd.t0 >= LONGPRESS { grab() }
        if mode == "train" { SceneTrain.step(self, dt) }
        else if mode != "ride" {
            stepTraffic(dt)
            if L.wk == "rain" && R.next() < dt * 14 { let rp = Ripple(); rp.x = rnd(4, W - 4); rp.y = rnd(g.nearTop + 6, g.floor); rp.t0 = t; ripples.append(rp); if ripples.count > 14 { ripples.removeFirst() } }
            if mode == "wait" { waitManage() } else if mode == "alight" { alightManage(dt) }
            if hello != nil { helloManage() }
            else if mode == "idle" || mode == "alight" { idleManage() }
            var i = 0
            while i < actors.count {
                let a = actors[i]; i += 1
                if a.hidden { continue }
                if a.held { heldStep(a, dt); continue }
                if a.st == "hidden" { continue }
                stepActor(a, dt)
                if L.cold && a.vis && a.st != "fall" && R.next() < dt * 0.3 {                    // 추운 날: 걷는 중에도 가끔 입김이 난다(그림만 — 추운지는 엔진 look.cold)
                    let hh = HH(a); let hd = SceneActs.headOf(a, hh)
                    ptx("breath", a.x + Double(a.dir) * (hd[0] + hh * 0.1), feetY(a) - liftOf(a) + hd[1] + hh * 0.1, 1, po().a(a.dir > 0 ? -0.5 : PI + 0.5, a.dir > 0 ? -0.2 : PI + 0.2).s(8, 14).g(-6).l(0.9, 1.3).r(1))
                }
            }
            if let d = DRAG, !actors.contains(where: { $0 === d.a }) { dragReset() }
            stepBams(dt)
        } else { rideStep(dt) }
    }
    func paintAll(_ c: SceneCv, _ dt: Double) {
        let shA: Double = t < shkEnd ? shkAmp * pow((shkEnd - t) / shkDur, 1.6) : 0
        if shA > 0.05 {                                                                           // s354 땅이 흔들린다 — 가장자리가 비지 않게 아주 조금 키워 그린다
            let cx = W / 2, cy = (H + stretch) / 2, zm = 1 + shA * 2.4 / max(60, H)
            c.save(); c.translate(cx + sin(t * 83) * shA, cy + cos(t * 71) * shA * 0.7); c.scale(zm, zm); c.translate(-cx, -cy)
        }
        if mode == "train" { SceneTrain.draw(self, c) } else if mode == "ride" { drawRide(c) } else { drawStreet(c, dt) }
        if shA > 0.05 { c.restore() }
        if t - dkT < 0.12 && mode != "ride" && mode != "train" { drawDim(c) }
        if t < flEnd { let fa = flAmt * pow((flEnd - t) / flDur, 1.5); if fa > 0.01 { c.fillStyle(rgba(flR, flG, flB, fa)); c.fillRect(0, 0, W, H + stretch) } }
        if dark { c.fillStyle("rgba(8,12,28,.10)"); c.fillRect(0, 0, W, H + stretch) }
    }
    /// s354 러블: 가운데(러블)만 밝고 주변이 어두워지며 두 눈에서 노란 빛이 난다.
    func drawDim(_ c: SceneCv) {
        let al = clamp(dkAmt, 0, 1), R0 = max(W, H) * 0.95
        if al > 0.01 {
            let dg = c.radial(dkX, dkY, TH * 0.55, dkX, dkY, R0).stop(0, rgba(4, 6, 18, 0)).stop(0.18, rgba(4, 6, 18, 0.08 * al)).stop(1, rgba(4, 6, 18, 0.9 * al))
            c.fillGrad(dg); c.fillRect(0, 0, W, H + stretch)
        }
        let ea = clamp(eyeAmt, 0, 1)
        if ea > 0.01 {
            let fl = 0.88 + 0.12 * sin(t * 17)
            for i in 0..<2 {
                let ex = i == 0 ? eyeX1 : eyeX2, ey = i == 0 ? eyeY1 : eyeY2
                let gg = c.radial(ex, ey, 0, ex, ey, eyeR * 3.2).stop(0, rgba(255, 244, 120, 0.95 * ea * fl)).stop(0.22, rgba(255, 214, 40, 0.6 * ea * fl)).stop(1, rgba(255, 190, 0, 0))
                c.fillGrad(gg); c.beginPath(); c.arc(ex, ey, eyeR * 3.2, 0, PI2); c.fill()
                c.fillStyle(rgba(255, 252, 200, ea)); c.beginPath(); c.ellipse(ex, ey, eyeR * 0.55, eyeR * 0.95, 0, 0, PI2); c.fill()
            }
            let mx = (eyeX1 + eyeX2) / 2, my = (eyeY1 + eyeY2) / 2                              // 눈 앞으로 번지는 빛줄기
            let bg2 = c.linear(mx, my, mx + eyeDir * eyeR * 16, my).stop(0, rgba(255, 220, 60, 0.34 * ea * fl)).stop(1, rgba(255, 220, 60, 0))
            c.fillGrad(bg2); c.beginPath(); c.moveTo(mx, my - eyeR * 0.7); c.lineTo(mx + eyeDir * eyeR * 16, my - eyeR * 5); c.lineTo(mx + eyeDir * eyeR * 16, my + eyeR * 5); c.lineTo(mx, my + eyeR * 0.7); c.closePath(); c.fill()
        }
    }
    // ═══ TV 전원 전환 ═══
    //   꺼짐(0.30초): 옛 장면이 위아래로 납작해져 하얀 선이 되고, 선이 좌우로 줄어 점이 된다.
    //   암전(0.08초): 점이 깜빡이며 사라진다.   켜짐(0.42초): 점→가로선이 번지고, 선이 위아래로 열리며 새 장면이 하얗게 번쩍이다 제 밝기로 돌아온다.
    func tvDraw(_ c: SceneCv) {
        let cx = W / 2, cy = H / 2
        c.fillStyle(TV_BLACK); c.fillRect(0, 0, W, H)
        if tv < TV_OFF {
            let a = tv / TV_OFF; var sx = 1.0, sy = 1.0
            if a < 0.72 { sy = 1 - 0.985 * eIn(a / 0.72) } else { sy = 0.015; sx = 1 - eIn((a - 0.72) / 0.28) }
            if let pv = prev { c.save(); c.translate(cx, cy); c.scale(max(sx, 0.001), max(sy, 0.001)); c.drawImage(pv, -W / 2, -H / 2, W, H); c.restore() }
            let rw = max(sx * W, 2.5), rh = max(sy * H, 2)
            c.globalAlpha(clamp(0.12 + 0.88 * a * a, 0, 1)); c.fillStyle(0xFFFFFFFF); c.fillRect(cx - rw / 2, cy - rh / 2, rw, rh); c.globalAlpha(1)
        } else if tv < TV_OFF + TV_HOLD {
            let kk = 1 - (tv - TV_OFF) / TV_HOLD
            c.globalAlpha(clamp(kk, 0, 1)); c.fillStyle(0xFFFFFFFF); c.fillRect(cx - 1.25, cy - 1, 2.5, 2); c.globalAlpha(1)
        } else {
            let b = (tv - TV_OFF - TV_HOLD) / TV_ON
            if b < 0.22 {
                let rw = max(W * eOut(b / 0.22), 2.5)
                c.fillStyle(0xFFFFFFFF); c.fillRect(cx - rw / 2, cy - 1, rw, 2)
            } else {
                let p = (b - 0.22) / 0.78, rh = max(H * eOut(p), 2)
                c.save(); rr(c, 0, cy - rh / 2, W, rh, 0); c.clip()
                paintAll(c, dtLast); dtLast = 0
                c.globalAlpha(clamp(0.9 * (1 - p) * (1 - p), 0, 1)); c.fillStyle(0xFFFFFFFF); c.fillRect(0, cy - rh / 2, W, rh); c.globalAlpha(1)
                c.restore()
                c.globalAlpha(clamp(0.9 * (1 - p), 0, 1)); c.fillStyle(0xFFFFFFFF); c.fillRect(0, cy - rh / 2 - 1, W, 2); c.fillRect(0, cy + rh / 2 - 1, W, 2); c.globalAlpha(1)
            }
        }
    }
    /// 한 프레임을 그린다. c 의 바닥 변환은 '화면 픽셀' 그대로(여기서 장면 좌표로 확대한다).
    func render(_ c: SceneCv) {
        if !running || bg == nil { return }
        c.save(); c.scale(dpr, dpr)
        // 웹에서는 호스트 div(.cong-scene)의 CSS 가 하던 일: 연파랑 바탕(#9fd0ff)과 둥근 모서리. 네이티브는 캔버스가 직접 한다.
        rr(c, 0, 0, W, H + stretch, HOST_RADIUS); c.clip()
        if tv >= 0 {
            tvDraw(c)
        } else {
            c.fillStyle(HOST_BG); c.fillRect(0, 0, W, H + stretch)
            paintAll(c, dtLast); dtLast = 0
            if xf >= 0, let pv = prev { c.globalAlpha(clamp(1 - xf / XF_T, 0, 1)); c.drawImage(pv, 0, 0, W, H); c.globalAlpha(1) }
        }
        c.restore()
    }

    // ═══ 카드 확장 인사(s340, YJ: "3초 꾹 누르면 카드가 배경 그대로 2배로 늘어나고 나머지 친구들이 나와 인사한 뒤 남을 친구만 남고 들어간다") ═══
    //   카드의 평소 장면 그대로(같은 SceneCore) 아래 인도만 늘어난다 — 하늘 · 먼 도시 · 길 · 차 · 버스 · 날씨 · 지금 나와 있던 친구는 끊김 없이 이어진다.
    //   시간 · 자리 · 차례 · 인사 글은 엔진 대본(SceneHello.Plan)이 정한다. 손님 친구는 자기 걸음(걷기 · 달리기 · 날기)으로 양쪽 가장자리에서 들어오고 두덩은 땅에서 솟는다.
    final class HelloRun {
        let p: SceneHello.Plan; var t0 = 0.0; var idAt: [String?] = []; var rank: [Int] = []; var leaving = false
        var seat: [String: Int] = [:]; var arrive: [String: Double] = [:], sayAt: [String: Double] = [:]
        var said = Set<String>(), guests = Set<String>(), free = Set<String>()
        var queue: [Actor] = []; var queueAt: [Double] = []
        init(_ p: SceneHello.Plan) { self.p = p }
    }
    func helloActive() -> Bool { hello != nil }
    /// 확장 인사가 시작된 뒤 지난 ms(없으면 -1).
    func helloMs() -> Double { hello == nil ? -1 : (t - hello!.t0) * 1000 }
    /// 확장 인사를 일찍 끝낸다: 손님은 바로 나가고 카드는 줄어든다.
    func helloSkip() { if let h = hello, helloMs() < Double(h.p.leave) { h.t0 = t - Double(h.p.leave) / 1000.0 } }
    func helloStop() { hello = nil; stretch = 0 }
    /// 확장 인사를 시작한다(같은 장면 그대로 — 새 장면을 만들지 않는다). 평소 장면(idle)이 아니거나 대본이 틀리면 false.
    /// 지금 나와 있는 친구는 자리로 걸어가고(가까운 자리부터), 나머지 친구는 양쪽 가장자리에서 들어온다. 길의 차 · 버스 · 날씨는 그대로 이어진다.
    func startHello(_ p: SceneHello.Plan, _ seed: Int64) -> Bool {
        if !running || mode != "idle" || pan >= 0 || !SceneHello.ok(p) || W <= 0 { return false }
        let h = HelloRun(p); h.t0 = t; h.rank = SceneHello.rank(p)
        dragReset()
        let n = p.chars.count; var idAt = [String?](repeating: nil, count: n); var used = [Bool](repeating: false, count: n); var have = Set<String>()
        for i in 0..<actors.count {                                                    // 지금 나와 있는 친구: 가까운 빈 자리로
            let o = actors[i]; if o.dead || o.hero || o.leaving || o.hidden || have.contains(o.id) || SceneModel.D3[o.id] == nil { continue }
            var known = false; for c0 in p.chars where c0 == o.id { known = true }; if !known { continue }
            var best = -1; var bd = 1e18
            for s in 0..<n where !used[s] { let dx = o.x / W - p.sx[s], dz = o.z - p.sz[s], d = dx * dx + dz * dz * 0.5; if d < bd { bd = d; best = s } }
            if best < 0 { continue }
            used[best] = true; idAt[best] = o.id; have.insert(o.id)
            let a = mkActor(o.id, o.x, o.z, o.dir); a.st = "walk"; a.vis = true; actors[i] = a
            a.tx = clamp(p.sx[best], 0.05, 0.95) * W; a.tz = clamp(p.sz[best], 0, 1); a.life = 1e9; a.born = t; a.boost = p.boost; h.seat[a.id] = best
        }
        var gi = 0; let rndSeats = SceneHello.seats(p, seed); var next = 0
        for id in rndSeats {                                                           // 나머지 친구(손님): 남은 자리에 무작위로
            if have.contains(id) || SceneModel.D3[id] == nil { continue }
            while next < n && used[next] { next += 1 }
            if next >= n { break }
            let si = next; used[si] = true; idAt[si] = id
            let sx = clamp(p.sx[si], 0.05, 0.95) * W, sz = clamp(p.sz[si], 0, 1)
            let left = sx < W * 0.5; let a = mkActor(id, 0, sz, left ? 1 : -1); h.guests.insert(id)
            if id == "dudung" && a.D.intro > 0 && host.intro() != nil { a.x = sx; a.st = "emerge" }
            else { a.x = left ? -a.w * 0.9 : W + a.w * 0.9; a.st = "walk" }
            a.tx = sx; a.tz = sz; a.life = 1e9; a.born = t; a.boost = p.boost; h.seat[id] = si
            h.queue.append(a)
            if id == "dudung" { h.queueAt.append(700.0) } else { h.queueAt.append(200.0 + Double(gi) * 140.0); gi += 1 }
        }
        h.idAt = idAt; hello = h; return true
    }
    func helloSettle(_ a: Actor) {                                          // 자리에 닿았다/동작이 끝났다 → 서서 인사를 기다린다(잠자는 칸은 앉아 쉰다)
        guard let h = hello else { return }
        a.dir = a.x < W * 0.5 ? 1 : -1; a.tx = a.x; a.tz = a.z; a.afterEmerge = nil; a.onArrive = nil
        if h.arrive[a.id] == nil { h.arrive[a.id] = t }
        if h.p.rest { a.st = "rest"; a.t0 = t; a.until = t + 1e6 } else { a.st = "stand" }
    }
    func helloManage() {
        guard let h = hello else { return }; let p = h.p; let ms = (t - h.t0) * 1000
        for i in stride(from: h.queue.count - 1, through: 0, by: -1) where ms >= h.queueAt[i] {                                   // 손님 입장(차례로 · 두덩은 땅에서 솟는다)
            let a = h.queue.remove(at: i); h.queueAt.remove(at: i)
            if a.st == "emerge" { a.t0 = t; a.until = t + Double(a.D.intro) / Double(a.D.introFps) }
            actors.append(a)
        }
        for i in stride(from: actors.count - 1, through: 0, by: -1) where actors[i].dead { actors.remove(at: i) }
        for a in actors {
            guard let si = h.seat[a.id], !a.leaving else { continue }
            let ar = h.arrive[a.id]
            if let ar = ar, !h.said.contains(a.id), ms >= max(Double(p.greet) + Double(h.rank[si]) * Double(p.step), (ar - h.t0) * 1000 + 200) {       // 자리에 선 친구만, 자기 차례에 한 번 인사
                h.said.insert(a.id); h.sayAt[a.id] = ms
                if let txt = p.say[a.id] { say(a, txt, Double(p.bubble) / 1000.0) }
                if !p.rest && a.st == "stand" { a.st = "hop"; a.t0 = t; a.until = t + 0.7; a.lastCyc = nil }
            }
            if let sa = h.sayAt[a.id], ms >= sa + Double(p.bubble), !a.bub.isEmpty { a.bub = "" }           // 앉아 쉬는 칸은 말풍선을 스스로 안 지우므로 여기서
        }
        if !h.leaving && ms >= Double(p.leave) {                                                                              // 손님은 양쪽으로 걸어 나가고, 남을 친구는 다시 평소처럼
            h.leaving = true
            for a in actors {
                a.bub = ""
                if h.guests.contains(a.id) { a.leaving = true; a.st = "walk"; a.tx = a.x < W / 2 ? -a.w * 1.1 : W + a.w * 1.1; a.tz = a.z; a.onArrive = nil; a.act = nil; a.boost = p.boost }
                else { h.free.insert(a.id); a.boost = 0; a.life = rnd(15, 26); a.born = t; startAct(a, nextName(a)) }
            }
        }
    }

    // ═══ 시험용 ═══
    func debugPlay(_ id: String, _ name: String, _ solo: Bool) -> Bool {
        if !running { return false }
        var a: Actor? = nil; for o in actors where o.id == id && !o.leaving { a = o }
        if a == nil { a = mkActor(id, W * 0.5, 0.62, 1); a!.born = t; actors.append(a!) }
        let ac = a!; ac.life = 1e9; ac.leaving = false
        if solo { actors = [ac]; spawnAt = t + 1e9; gfx = []; pt = []; ac.x = W * 0.5; ac.z = 0.62 }
        startAct(ac, name); return true
    }
    func debugTick(_ sec: Double) { let n = Int(jr(sec * 30)); for _ in 0..<n { update(1.0 / 30) } }
    /// 시험용 상태 요약: id|st|act|land|x|z|vis ; …
    func debugInfo() -> String {
        var b = "\(mode)#\(frames)#\(error ?? "")#"
        for a in actors { b += "\(a.id)|\(a.st)|\(a.act?.n ?? "")|\(a.landK)|\(Int(jr(a.x)))|\(jr(a.z * 100) / 100)|\(a.vis ? 1 : 0)|\(a.held ? 1 : 0);" }
        return b
    }
}
