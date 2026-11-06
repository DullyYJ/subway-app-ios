import Foundation

/// 확인용: 엔진이 보냈는데 아직 그리지 못하는 노드 종류를 Documents/unknown-kinds.txt 에 모은다(CI 가 가져가 빠진 그림을 가려낸다).
enum UnknownKinds {
    private static var seen = Set<String>()
    static func note(_ k: String, _ sample: String) {
        guard !k.isEmpty, seen.insert(k).inserted else { return }
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let f = dir.appendingPathComponent("unknown-kinds.txt")
        let line = k + "\t" + String(sample.prefix(300)) + "\n"
        if let h = try? FileHandle(forWritingTo: f) { h.seekToEndOfFile(); h.write(Data(line.utf8)); try? h.close() } else { try? line.write(to: f, atomically: true, encoding: .utf8) }
    }
    /// 확인용: 받은 화면 원문을 Documents 에 남긴다(CI 가 가져가 안드로이드와 견준다).
    static func dump(_ name: String, _ d: Data) {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        try? d.write(to: dir.appendingPathComponent(name))
    }
}
