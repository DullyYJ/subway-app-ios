# 길동무 iOS — HANDOFF

최종 갱신: 2026-11-27 (안드로이드와 똑같이 맞추기 세션 — 아래 '2026-11-27' 절)

## 한눈에
- 부모 앱: 이 저장소(DullyYJ/subway-app-ios), SwiftUI. 안드로이드 원본은 DullyYJ/subway-app (branch native-shell).
- 키즈 앱: DullyYJ/gildongmu-kids-ios (SwiftUI 1차 완성, 시뮬레이터 실행 확인: 가족대화·퀘스트·홈 장면·설정). CI가 이 저장소를 `parent/`로 받아 tools/vendor.sh로 Core·UI·Scene·chars3d를 복사해 쓴다.
- 원칙: 앱은 그리기만, 계산은 엔진(서버). 화면 JSON은 Cloudflare Worker가 내려준다. 메인 스레드 부하 0.
- 맥이 없으므로 모든 빌드는 GitHub Actions(macos-latest).

## 2026-11-27 안드로이드와 똑같이 맞추기 (YJ: "모든 기능 똑같이 · 맥북 없이 IPA 로 설치해서 시험")
- **IPA**: `.github/workflows/ipa.yml` — main 푸시마다 서명 없는 실기기 IPA 를 만들어 GitHub 릴리스 `ios-latest`(prerelease)에 올린다. `Gildongmu-unsigned.ipa`(위젯 확장 포함) · `Gildongmu-noext.ipa`(확장 뺀 것 — 무료 Apple ID 로 확장 서명이 안 될 때). 윈도우에서 Sideloadly 로 내 Apple ID 서명 후 설치(7일마다 다시, USB 케이블, 개발자 모드 켜기). `gh release view` 는 GraphQL 이 막혀 `gh api repos/DullyYJ/subway-app-ios/releases/tags/ios-latest` 로 확인.
- **서버는 공용**: route-v2 엔진 서버는 안드로이드 · iOS 가 같이 쓴다(YJ: "서버는 최신이니까 건들지마" — 엔진 배포는 요청 없이 하지 않는다).
- 옮긴 것(안드로이드 대응 파일): 쇼핑 상품 누르면 그림 + '쿠팡앱으로 연결하시겠습니까?' 카드(ShellActivity.shopGo → Host.handle open / ShopModel) · 경로 이탈 팝업(rerouteAsk → HomeModel.rerouteAsk) · 잠깐 뜨는 안내 카드(pop → Host.showPop) · 하차 7분 전 추천 흐름 전체(RideCore.recoBody · RecoNotify · ShopRecent · RecoGo → Sources/Ride/RecoFlow.swift, 앱이 앞이면 팝업·아니면 알림) · 중간 환승 버스 고르기(legAsk · busSwap → HomeModel.legAsk · RideLoop.board/busSwap/applySwap) · 출퇴근 브리핑 알림(CmCore · CommuteAlarm → Sources/Core/CmCore.swift · Sources/Ride/CommuteAlarm.swift · SettingsTab 의 cm 패널 · Host.cmb 브리핑 창 · NotifRouter) · 처음 설치 승인 순서(알림 → 위치 안내 locd → 위치 허용; Sources/Core/FirstRun.swift).
- 출퇴근 알림의 아이폰 차이: 알림이 울릴 때 앱이 코드를 못 돌린다(안드로이드는 알람 때 /commute-brief 를 받아 띄움). 그래서 /commute-alarm 이 준 시각마다 로컬 알림(최대 14+14, 식별자 `cm.morn.N`/`cm.eve.N`)을 걸고, 12시간 안의 가장 가까운 알림만 앱을 열 때 엔진 글로 본문을 채운다. 나머지는 짧은 안내 글 → 알림을 누르면 그때 엔진 글을 새로 받아 가운데 창에 보인다(Host.cmbOpen). 앱을 열 때마다(scenePhase active) 4주 창을 다시 민다. '지금 미리보기' 는 `cm.test` 로 1초 뒤 알림.
- 설정 화면 사실: `cm`/`cmi`/`cmh`/`cmf`(CmCore.inlineFacts)/`pgs:["cm"]` 를 실어 엔진이 출퇴근 패널을 설정 화면 안에 펼치게 한다. 장소 입력칸(inbar key `cmp.*`)은 focus/blur/input 을 알리고(NodeView3.InbarNode), 버스정류장 후보는 `/suggest?k=b`(CommuteAlarm.busSearch).
- 시험 인자: `-skipSetup` = 처음 설치 승인(알림·위치 안내)을 건너뜀(CI 화면 찍기용, ios.yml 의 모든 simctl launch 에 붙어 있다).
- 아직 안 옮긴 것(우선순위 순): 화면 동작 대조, 테마·글꼴·여백·애니메이션 화면 대조(스크린샷 나란히), 위젯(안드로이드 6종 · iOS 는 Live Activity 1종), 푸시(APNs — 유료 Apple 계정 필요), 구독(StoreKit — 상품 설정 필요), PerfLog, 개발자 도구(dev 페이지), 갤럭시 전용 안내(sam/ovl/bat — iOS 해당 없음).
- 단위 시험 추가: CmCoreTests · RideSwapTests · ParseTests.testShopCardActionCarriesNameAndImage.

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
2. (완료) 열차 장면 피드(LivePosStore→trainPos/trainClock), 3초 꾹 누르기 인사(SceneOpen+SceneNode 높이 확장). 남음: 혼잡도 카드 2번째 페이지, 실기기 햅틱 확인.
3. 위치·경로 흐름, 탑승 바 → Live Activity/Dynamic Island, APNs(FCM 대체), StoreKit 2(Play Billing 대체), 위젯.
4. 키즈 앱: 지도 탭, 다마고치 동작, APNs, 꾸미기/아이템.
5. 부모 앱 키즈 연동 2차(1차는 아래 '부모 ↔ 키즈 연동'): QR 스캐너(kl.scan), 푸시 토큰 `/p/ft`, 구독 잠금(kg.ok/LOCK_ROW), 호출 팝업(kx.open pop), 자녀 허브를 탭으로(지금은 설정 맨 위 '자녀 보기'), 지도 자녀 마커·`/p/loc`, 자녀 꾸민 모습 `/p/wear`→홈 장면, 가족대화 칸(`v=fam`).

## 부모 ↔ 키즈 연동
- 서버: Cloudflare Worker `gildongmu-kids`(D1). 부모는 `/p/*`, 아이는 `/c/*`. 연결 상태 변화는 long-wait로 즉시 반영.
- 부모 iOS 1차(Sources/Kids/KidsHub.swift, 부모 전용 폴더라 키즈 vendor 가 안 가져감): 부모 기기 등록(`/reg` role p, 키체인→UserDefaults 대체), `Host.handle` 이 `k..` 형 행동(kl. kh. kg. kr. kq. kx. kn. km. …)을 actPublisher tab "kids" 로 넘기면 KidsHubLayer 가 `/p/act` 로 보내고 돌려준 screen 을 시트로 그린다(화면 이름이 `kids` 면 허브). 허브는 `/p/screen?v=hub` + `/p/wait` 긴 대기. 설정 맨 위 줄은 `/p/setrow?kn=1`(연결 전엔 '길동무 키즈 연결' 한 줄), '개발자 도구' 카드 위에 끼움(SettingsView.withKids). 연결은 `/p/act v=kl.join t=키`, QR 은 `gildongmu-kids://pair?k=XXXXX-XXXXX`(project.yml CFBundleURLTypes + onOpenURL). 입력칸 글은 UserDefaults `field.<key>` 에서 모아 `f` 로 보냄. Host.swift 는 키즈 vendor 에도 가므로 타입 의존 없이 이름 판별(isKidsCall)만 한다.
- 부모 iOS 1차 검증(CI #91): 시뮬레이터에서 등록→`/p/act kl.open`→서버 연결 팝업(kidlink)이 그대로 그려짐 확인(screenshot-tab-community-set.png). 시험 인자: `-ccMode set` = 연결 팝업 자동 열기, `-ccMode board` = 허브 열기(연결된 자녀가 없으면 서버가 linked:0 을 줘서 곧바로 닫히는 게 정상). 허브 실화면·QR 연결은 자녀 앱과 짝지어 시험해야 함. 시작 크래시 교훈: ViewModifier 가 @EnvironmentObject 를 읽으면 `.environmentObject()` 보다 안쪽에 붙일 것.
- iOS 제약: 오버레이 불가 → Live Activity + 로컬 알림. 백그라운드 위치 "항상 허용"은 심사 사유서 필요.
- 엔진 워커 파일(engine/route-v2-worker.ascii.js)이 바뀌면 최신본을 전달하고 Cloudflare route-v2에 붙여넣기를 안내한다.

## 공유 코드 주의
- 키즈가 vendor로 가져가는 UI/Core 파일이 부모의 다른 폴더(Shared, Tabs)에 있는 타입을 쓰면 키즈 typecheck가 깨진다. 예: Color(argb:)는 Shared/Overlay.swift → 키즈에 KidsColor.swift로 복제, Core/Rules.swift는 vendor에서 제외. 공유 쪽에 새 의존을 넣을 때 키즈 typecheck도 확인할 것.
- SceneView: 장면 JSON이 화면보다 늦게 와도 적용되도록 onChange 새 값(j)을 쓴다. SceneDriver.diag()는 시험 실행 진단용.
- ios.yml은 concurrency(cancel-in-progress)로 겹친 빌드를 취소한다.

## 작업 방법 (이 세션에서 검증됨)
- git push는 프록시에서 막힘 → Chrome에서 GitHub 웹 업로드(`/upload/main/<dir>`)로 푸시. file_upload는 프로젝트 폴더나 스크래치패드 경로만 허용. 커밋 후 저장소 루트로 리다이렉트될 때까지 이동 금지.
- 빠른 검사: Actions "Scene typecheck"(~30초, Sources/Scene/** 푸시 시). 전체 빌드 "iOS build (simulator)"(~11–20분, 스크린샷은 ios-ci-out 브랜치).
- 오류 보기: 잡 페이지에서 실패 단계를 펼쳐 텍스트 읽기.
- 커밋 꼬리말: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` + `Claude-Session: …`.

## 2026-11-27 (이어서) 좌우 밀기 · 고정 머리/꼬리 · 칩 먼저 켜기
- `Sources/UI/EngineSwipe.swift`: 안드로이드 SwipeCore + ScreenView mode 9 + ShellActivity.commSwipe 이식. 엔진이 화면에 담은 `sw{l,r,lh,rh,lc,rc,k,t}` 가 넘길 곳을 정하고(앱은 계산 없음), 창에 붙인 가로 팬 인식기가 몸짓을 알아본다(32pt 이상 또는 520pt/s 쓸기 · 고무줄 88pt · 나가기 0.11초 · 들어오기 56pt/0.34초 · 안 오면 450ms 뒤 제자리). 입력칸 · 가로로 밀리는 줄 · 시트 위에서 시작한 몸짓은 무시. `news_cat`(lc/rc) 먼저 켜기. 홈은 경로가 있고 탑승 중이 아닐 때만.
- 켜진 곳: 쇼핑 · 맛집 · 노선도 본문 · 소식 · 게시판 · 소통방 · 홈(경로 결과). 시험: `Tests/SwipeCoreTests.swift`.
- `ScreenBody`: 머리(head)는 위에 고정 · 꼬리(foot)는 아래에 고정 · 본문만 스크롤(전에는 머리가 같이 스크롤됐고 꼬리는 안 그려졌다).
- `Sources/UI/ChipPick.swift`: 칩(cat)을 누르거나 밀어서 칸을 넘기면 새 화면 전에 그 칩을 먼저 켠다(안드로이드 pickChip/lightChip). 새 화면이 오면 거둔다. 경로 방식 탭(rh.tab.*) 먼저 켜기(pickRtab)는 아직.
- 서버는 건드리지 않았다(사용자 지시 "서버는 최신이니까 건들지마").
- 경로 탐색 로딩 카드(rload): 경로를 찾는 동안 가운데 카드(엔진 /screen/dlg kind:rload — 뛰어가는 캐릭터)를 띄우고 결과가 그려지면 닫는다(`HomeModel.rload`). 처음 한 번은 미리 받아 두고(prefetch), 못 받았으면 그때는 카드 없이.
- 하차 7분 전 추천 시험(설정 > 하차 7분 전 추천 > 시험 알림 · 상태 확인): `pgs` 에 `arr` 추가, `pg.arr` → 하위 시트(엔진 p=arr), `arr.t.<morning|lunch|night|shop>` → `RecoFlow.testBody` 로 /reco-text 를 받아 알림(앱이 앞이어도 팝업이 아니라 알림), `arr.stat` → 마지막 발송 단계 · 남은 시간(RideLoop.recoInfo) 표시.
- 아래로 당겨 새로고침: 맛집 · 노선도(버스) 본문(`ScreenBody(onPull:)` → `.refreshable`). 안드로이드는 스프링 모양이지만 iOS 표준 당기기를 쓴다.
- 설정 화면은 '알림·편의 기능' 메뉴 모양이 아니라 예전 긴 화면 모양이다: 엔진이 notif+conv 가 pgs 에 있어야 메뉴 모양으로 그리는데, conv 팝업에 위젯 · 다른 앱 위에 표시 · 백그라운드 유지(안드로이드 전용) 줄이 고정으로 들어 있어 iOS 에서는 동작 없는 줄이 생긴다. 서버를 바꾸지 말라는 지시라 이대로 둔다(서버가 pgs 로 conv 줄을 걸러 주게 되면 메뉴 모양으로).

