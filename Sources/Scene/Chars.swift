import Foundation

/// 캐릭터 시트 파일 이름 규칙(순수 계산) — 안드로이드 Chars.java.
/// 시트 열쇠: "<id>"(걷기) · "<id>_pose"(자세) · "<id>_act"(전용 동작) · "<id>_sleep" · "dudung_intro".
/// 뽀송(bbosong)은 신발을 자주 갈아 신어 시트가 신발마다 따로 있다(bbosong_0 … bbosong_3, bbosong_0_pose …) — 지금 신은 신발 번호를 붙인 파일을 읽는다.
enum Chars {
    /// 신발이 바뀌는 시간 간격(20분).
    static let SHOE_MS: Int64 = 20 * 60 * 1000
    /// 뽀송의 신발 종류 수(흰 운동화 · 노란 장화 · 보라 메리제인 · 민트 하이탑).
    static let SHOES = 4

    private static func floorDiv(_ a: Int64, _ b: Int64) -> Int64 { let q = a / b; return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q }
    private static func floorMod(_ a: Int64, _ b: Int64) -> Int64 { ((a % b) + b) % b }

    /// 지금 시각(ms)의 신발 번호(0..<SHOES). 이어지는 두 칸은 늘 다른 신발이다.
    static func shoe(_ nowMs: Int64) -> Int {
        let b = floorDiv(nowMs, SHOE_MS)
        let blk = floorDiv(b, Int64(SHOES))
        let i = Int(floorMod(b, Int64(SHOES)))
        var p = perm(blk)
        if p[0] == perm(blk - 1)[SHOES - 1] { p.swapAt(0, 1) }
        return p[i]
    }
    static func shoe() -> Int { shoe(Int64(Date().timeIntervalSince1970 * 1000)) }
    private static func perm(_ blk: Int64) -> [Int] {
        var p = Array(0..<SHOES)
        var h = UInt64(bitPattern: blk)
        var i = SHOES - 1
        while i > 0 {
            h = h &* 0x9E3779B97F4A7C15 &+ 0x7F4A7C15; h ^= (h >> 29); h = h &* 0xBF58476D1CE4E5B9; h ^= (h >> 32)
            let j = Int(floorMod(Int64(bitPattern: h), Int64(i + 1)))
            p.swapAt(i, j)
            i -= 1
        }
        return p
    }
    static func hasShoes(_ id: String) -> Bool { id == "bbosong" }

    /// 시트 열쇠 → chars3d 폴더 안 파일 이름(확장자 없음).
    static func file(_ key: String, _ nowMs: Int64) -> String {
        if key == "bbosong" { return "bbosong_\(shoe(nowMs))" }
        if key == "bbosong_pose" { return "bbosong_\(shoe(nowMs))_pose" }
        if key == "bbosong_act" { return "bbosong_\(shoe(nowMs))_act" }
        return key
    }
    static func file(_ key: String) -> String { file(key, Int64(Date().timeIntervalSince1970 * 1000)) }
}
