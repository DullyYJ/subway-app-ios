import Foundation

/// 개발용: 엔진이 내려 주는 overlay 모양의 견본 값으로 다이내믹 아일랜드가 어떻게 그려지는지 본다(경로 화면이 연결되기 전의 시험용).
/// 값은 엔진 형식 그대로라 실제로는 같은 자리에 엔진 응답이 들어간다.
enum DemoOverlay {
    static let kinds = ["moving", "wait", "alert2", "alert1", "arrived"]

    static func json(_ kind: String) -> [String: Any] {
        let names = ["서울역", "시청", "을지로입구", "을지로3가", "충무로", "명동", "회현"]
        let times = ["14:02", "14:04", "14:06", "14:08", "14:10", "14:12", "14:14"]
        var cells: [[String: Any]] = []
        for i in 0..<names.count { cells.append(["n": names[i], "t": times[i], "g": i == 2 ? "2호선" : "", "dc": "#1d9bf0", "dk": 1]) }
        var o: [String: Any] = [
            "active": true, "line1": "을지로입구 → 명동", "line2": "명동까지 3정거장 · 6분", "destName": "명동", "pill": "이동중",
            "pillTxt": "현위치 을지로입구 · 도착 14:12", "moving": true, "cur": 2, "base": 0, "cells": cells, "alert": 0, "banner": "",
            "theme": ["bg": "#1C1C1E", "fg": "#F2F2F7", "sub": "#8E8E93"], "rs": ["st": "hidden"],
        ]
        switch kind {
        case "wait": o["moving"] = false; o["rs"] = ["st": "wait", "k": "승차 대기"]; o["pillTxt"] = "을지로입구 승차 대기 · 2분"
        case "alert2": o["alert"] = 2; o["banner"] = "2정거장 전"; o["cur"] = 4; o["pillTxt"] = "곧 내려요 · 충무로"
        case "alert1": o["alert"] = 1; o["banner"] = "1정거장 전"; o["cur"] = 5; o["pillTxt"] = "다음 정거장에서 내려요"
        case "arrived": o["moving"] = false; o["cur"] = 5; o["pillTxt"] = "명동 도착"; o["rs"] = ["st": "board", "end": true, "bt": "안내 종료"]
        default: break
        }
        return o
    }
}
