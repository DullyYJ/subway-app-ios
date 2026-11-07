# 길동무 iOS — HANDOFF

최종 갱신: 2026-11-07 (Claude Sonnet 5.5 인계 세션)

## 한눈에
- 부모 앱: 이 저장소(DullyYJ/subway-app-ios), SwiftUI. 안드로이드 원본은 DullyYJ/subway-app (branch native-shell).
- 키즈 앱: DullyYJ/gildongmu-kids-ios (아직 빈 저장소). 부모 앱의 장면 엔진을 그대로 재사용할 예정.
- 원칙: 앱은 그리기만, 계산은 엔진(서버). 화면 JSON은 Cloudflare Worker가 내려준다. 메인 스레드 부하 0.
- 맥이 없으므로 모든 빌드는 GitHub Actions(macos-latest).

## 장면 엔진 이식 (Sources/Scene)
안드로이드 SceneCore(Java)를 1:1로 Swift로 옮겼다. 전부 타입체크 통과.

| 파일 | 역할 |
|---|---|
| SceneCv / SceneUtil / SceneModel / SceneArt / ScenePlaces / ScenePlatform | 그리기 프로토콜(CGCv=CoreGraphics), 헬퍼, 모델, 배경·장소 |
| SceneCore / SceneCoreDraw / SceneCoreRun / SceneFx | 엔진 본체(배치·그리기·실행·효과) |
| SceneActs / SceneActs2 / SceneActs3 | 캐릭터 동작 전체(개·강아지·고양이·두더지·독수리·올챙이·판다·하마·날씨·낙하 등) + CELLS 표 |
| SceneTrain | 지하철 객실 장면(승객·문·LED·벤치) |
| SceneHello | 3초 꾹 누르기 인사 대본(Plan), JavaRandom(java.util.Random 동일 수열) |
| Chars | 신발 20분 회전, 시트 키 |
| SceneHaptics | Core Haptics 표 + 플레이어 |
| SceneDriver | 싱글톤. NSRecursiveLock으로 엔진 진입점 보호, 시트(webp) 로드, 터치·레이아웃·프레임 |
| SceneView | SwiftUI Canvas(비동기) + UIKit 터치층 + 태그 캡슐 |

연결 지점: `Sources/UI/NodeView7.swift`의 `SceneNode`(kind "scene")가 `SceneView(json: node.str("sc"))`를 그린다.
캐릭터 시트: `Resources/chars3d`(webp 43장). project.yml이 폴더 리소스로 번들한다.

변환 규칙 메모: Java `%`(double)=truncatingRemainder, Math.round=`jr`, 32비트 int 해시는 Int32 wrapping(`hsh`/`javaHash`), `A_(S,name,dur,ini,step,end)` 클로저 시그니처 유지, `mkGfx`.

## 검증 현황
- 2026-11-07 전체 빌드(0a223ce) 성공, ios-ci-out/screenshot-1.png 에서 홈 '길동무 친구들' 장면(밤 도로·버스·자동차·캐릭터·말풍선) 실제 렌더 확인.
- 주의: 푸시가 겹치면 ios-ci-out 이 먼저 끝난 빌드로 덮어쓰이니, 커밋 라벨("ios CI 결과 <해시>")이 방금 푸시한 해시인지 확인할 것.

## 남은 일 (우선순위)
1. 밝은 모드(낮) 장면·터치·햅틱 확인(screenshot-2-dark 등).
2. 열차 장면 피드(trainPos/trainClock) 연결, 3초 꾹 누르기 → SceneHello.Plan(엔진 대본) 연결, 혼잡도 카드 2번째 페이지.
3. 위치·경로 흐름, 탑승 바 → Live Activity/Dynamic Island, APNs(FCM 대체), StoreKit 2(Play Billing 대체), 위젯.
4. 키즈 앱 시작: 부모 앱 장면 엔진 재사용(quietAuto, wearHook), 서버 `gildongmu-kids`(/p/* 부모, /c/* 아이, 장기 대기 /c/wait /p/wait).

## 부모 ↔ 키즈 연동
- 서버: Cloudflare Worker `gildongmu-kids`(D1). 부모는 `/p/*`, 아이는 `/c/*`. 연결 상태 변화는 long-wait로 즉시 반영.
- iOS 제약: 오버레이 불가 → Live Activity + 로컬 알림. 백그라운드 위치 "항상 허용"은 심사 사유서 필요.
- 엔진 워커 파일(engine/route-v2-worker.ascii.js)이 바뀌면 최신본을 전달하고 Cloudflare route-v2에 붙여넣기를 안내한다.

## 작업 방법 (이 세션에서 검증됨)
- git push는 프록시에서 막힘 → Chrome에서 GitHub 웹 업로드(`/upload/main/<dir>`)로 푸시. file_upload는 프로젝트 폴더나 스크래치패드 경로만 허용. 커밋 후 저장소 루트로 리다이렉트될 때까지 이동 금지.
- 빠른 검사: Actions "Scene typecheck"(~30초, Sources/Scene/** 푸시 시). 전체 빌드 "iOS build (simulator)"(~11–20분, 스크린샷은 ios-ci-out 브랜치).
- 오류 보기: 잡 페이지에서 실패 단계를 펼쳐 텍스트 읽기.
- 커밋 꼬리말: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` + `Claude-Session: …`.
