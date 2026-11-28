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

- 떠 있는 단추(fab): 화면의 `fab{s,icon,act}` 를 본문 아래 가운데에 금색 알약으로 그린다(게시판 '제보 글쓰기'; `ScreenBody` 의 `Fab`/`FabButton`). 안내창(DlgCard) 바깥을 누르면 엔진이 정한 `tap` 행동을 보낸다(없으면 dl.close).
- 서버 지연 안내: 엔진이 HTTP 503 + `delayed:true,retry:[초…]` 화면을 주면 `Net.screen` 이 오류가 아니라 그릴 화면으로 돌려주고(쇼핑), `AutoRetry` 가 그 간격(1~120초, 6번까지)마다 뒤에서 다시 받는다. 단추 `gdm_retry` 는 `Host.handle` 이 받아 `reloadTick` 을 올린다(600ms 안 거듭 누름은 한 번). 통신 자체가 안 돼 탭이 비면 `RetryCard`(안드로이드 ShellCore.errorScreen 과 같은 문구 · 단추, 4·8·16·30초 자동 재시도). 시험: `Tests/RetryTests.swift`.
- 경로 방식 탭(rh.tab.*)·두 칸 단추(btog)도 누르면 새 화면 전에 먼저 켠다(`ButtonNode`, `ChipPick.pickBtn` — 켜진 단추와 모양을 맞바꾸고 0.15초 섞는다; 밀어서 넘길 때도 `light`). 새 화면 판별은 `ChipPick.sig`(탭 · 칩 켜짐 모양)이 바뀔 때 거둔다. 시험: `Tests/ChipPickTests.swift`.
- 정류장 이름 설정(AliasCard)은 이미 있었고 글꼴 13 · 단추 높이 44 · 너비 340 으로 안드로이드와 맞췄다.
- 하단 토스트: 안드로이드는 `toast()` 본문을 비워 아무것도 안 뜬다 → iOS 도 `Host.say` 가 화면에 띄우지 않고 로그만 남긴다(`Host.toastOn` 으로 되돌림).
- 탭을 옮기면 새 화면이 흐림 0.35 → 1 로 240ms 떠오른다(`TabFadeIn`, 소통방 제외 — 안드로이드 fadeIn).
- 입력줄 둥근 아이콘 단추(`inbar.bicon` — 소통방 · 홈 실시간 대화 보내기): 금색 동그라미(지름 bh) + 흰 아이콘 17pt (`InbarNode`).
- 안내창(DlgCard): `fit`(가장 긴 글 줄에 맞춰 너비를 줄임) · `line`(카드 테두리 1pt — 엔진이 줄 때만).
- 흐르는 이름(`text`/`bar` 의 `mq`+`rw`): 지도 역 카드 이름 · 시간표 제목이 오른쪽에 놀이터 칸(rw)을 남기고 한 줄로 흐른다 — 멈춤 1.2초 · 초당 30pt · 끝에서 1.2초 멈췄다 되돌아옴(`Marquee.swift`).
- 지도 2초 꾹 누르기(`tmap.hold:'mp.lp'` · `hms`): 버스 '내 주변' 지도를 움직이지 않고 2초 누르면 `mp.lp.<위도>_<경도>` 를 보내고(`TmapNode.holdBegin`), `MapModel.busPin` 이 정류장 요청의 `bus.pin:[위도,경도]` 로 실어 엔진이 그 주변 100m 정류장을 찾는다. 📍 · 새로고침(`mp.loc/rf/rt`)은 핀을 버린다.
- 안드로이드가 읽는데 iOS 가 아직 안 읽는 화면 값(2026-11-27 점검): (`an` 은 RowAnim 으로 옮김 — 아래 '버튼 줄 전환'), `anchor`(소통방 아래 붙임; ChatTab 이 따로 처리), `fit/fmin/fmax/frh/fo`(엔진이 안 보냄), `ffill/fd/fk`(안 보냄), `grp`(안 보냄), `ix`(뉴스 순번 보조), `lp`(3초 꾹 — 키즈 장소 등록).
- 화면 기억 · 뼈대: `Sources/UI/ScreenCache.swift` — 받은 엔진 화면을 메모리 + 기기 캐시 폴더(7일)에 담아 두었다가 쇼핑 · 소식은 탭을 열 때 옛 화면을 먼저 보이고 새로 받으면 바꾼다(안드로이드 cachePut/showCached). 첫 화면이 오기 전에는 빙글빙글 대신 뼈대(`SkelScreen`: 홈·쇼핑 cards · 노선도 map · 맛집/소식/게시판 list — 안드로이드 skeletonScreen). 게시판(`board`) · 소통방(`chat|방`) · 맛집(`food|동네칸` 약 1km, '전체' 칩만)도 같은 식으로 옛 화면을 먼저 보인다(맛집은 원자료가 다시 올 때까지 '불러오는 중' 화면으로 안 갈아끼움: FoodModel.held). 홈 · 노선도는 눌림이 앞서 받은 상태에 기대서 아직 기억하지 않는다(안드로이드 restoreState 에 해당하는 일이 먼저 필요).

## 탭 옮기기 · 다시 누르기 (안드로이드 showTab / tabSettle / Debounce.TAP_MS)
- 탭을 옮기면 새 화면이 흐림 0.85 → 1, 아래 4pt → 제자리, 180ms, 곡선 (0.32, 0.72, 0, 1) 로 떠오른다(`TabFadeIn`). 소통방도 같다. 예전 0.35 → 1 은 안드로이드 fadeIn(새 화면이 캐시 없이 올 때)이라 탭 이동과는 다른 것.
- 이미 켜진 탭을 다시 누르면 안드로이드는 showTab 을 다시 돌아 그 탭을 새로 받고 다시 떠오른다 → `Host.call("tab.x")` 가 같은 탭이면 `reloadTick`·`settleTick` 을 올린다.
- 같은 탭 버튼 350ms 안의 거듭 누름은 한 번으로(`TapGate`, 시험 `TapGateTests`).
- 안드로이드의 TAB_GAP_MS(120ms 새로 받기 미루기)는 iOS 에서는 탭을 옮기면 화면이 새로 올라오고 앞 화면의 통신 작업이 취소되므로 따로 두지 않는다.
- 쇼핑 '최근에 보여 준 상품'(ShopRecent)은 이미 `RecoFlow.recentNames/recentAdd/inject` 로 들어 있다(추천 요청에 `shopRecent` 를 싣고, 답의 `shopItem.n` 을 기억).

## 캐릭터 놀이터 (안드로이드 PlayCore.java / PlayView.java)
- 지도 역 팝업의 이름(`text` mq+rw) 오른쪽, 시간표 머리줄(`bar` mq+rw) 제목 오른쪽 빈 칸에서 동물 2~3마리가 논다. 배경 8가지(낮·노을·풀밭·사탕·눈·바다·밤·오로라) 중 하나, 캐릭터별 놀이(강아지 킁킁·응가 / 고양이 나무타기·훌쩍 / 두더지 땅속·삽질 / 올챙이 웅덩이 / 독수리 날기).
- 계산: `Sources/Core/PlayCore.swift`(순수 · 시험 `PlayCoreTests`), 그림: `Sources/UI/PlayView.swift`(`PlayField` = TimelineView 30fps + Canvas 두 겹: 배경은 좌우 20%·위 50% 지우개 mask, 캐릭터는 지우지 않음). 자리는 `MarqueeLabel` 안에서 `PlayCore.popupHost/ttHost` 로 정한다(이름이 길어 90pt 칸이 안 나오면 놀이터 없음).
- 캐릭터 시트는 `RunnerArt`(경로 로딩 캐릭터와 같은 시트)를 쓰고, 16칸을 그릴 크기(화소 3배)로 한 번만 줄여 둔다(`PlaySim.cut`). 시트가 아직 안 읽혔으면 배경만 먼저 논다.
- 팝업 → 시간표: `PlayHub.snap` 에 팝업이 0.5초마다·사라질 때 장면을 적어 두고, 시간표가 그대로 이어받는다(칸 크기가 달라도 위치는 비율).
- 모션 줄이기(손쉬운 사용)가 켜져 있으면 움직이지 않고 첫 장면만 그린다(안드로이드 ANIMATOR_DURATION_SCALE==0 과 같다). 다크는 앱 테마(`theme`) 를 따른다.
- 안드로이드와 다른 점: 놀이터 칸은 이름 노드 안에 겹쳐 그린다(안드로이드는 시트 위에 따로 얹은 View). 아래 줄(노선 알약)과 겹치는 4pt 는 알약 아래로 깔린다.

## 버튼 줄 전환 연출 (안드로이드 ActRowCore / ScreenView.drawRowAnim)
- row 노드의 `an:{k, ms, sq, bg, e:[x1,y1,x2,y2], o:{s, fill, tc}}` — 칸이 셋(모두 button)일 때만. k = push_in · push_out · slide_down · slide_up. `Sources/UI/RowAnim.swift`: `ActRowCore`(수식 · 시험 `RowAnimTests`) + `RowNode`(줄) + `RowAnimOverlay`(최종 모양 위에 가리개 색 `bg` 를 깔고 네 조각 A·B·C·O 를 움직인다. 눌림은 아래 단추가 받는다).
- `sq`(엔진 시계)가 방금(2.5초 안)일 때만 그린다 — 옛 전환은 최종 모양만. 시작 시각은 `sq` 에서 이미 지난 만큼 앞당긴다(안드로이드와 같다). 옛 칸 O 는 셋째 단추 모양에 `o.s`·`o.fill`·`o.tc` 만 바꾼다.

## 내 위치 공유 GIF (안드로이드 ShareAnim / ShareArt.gif / GifEnc)
- 마커를 뺀 카드 그림(`ShareCardView.hideMarker`) 위에서 마커가 깜박이고(물결 · 점), 친구 한 마리(무작위)가 노선선 위를 오간다. 98프레임 · 프레임당 0.07초 · 반복. 계획 `Sources/Core/ShareAnim.swift`(시험 `ShareAnimTests`), 그리기·GIF 쓰기 `Sources/Ride/ShareGif.swift`(ImageIO). 못 만들면 정지 그림으로 보낸다.
- 공유창에는 글 + GIF 파일(임시 폴더 `gildongmu_<ts>.gif`)을 실어 보낸다. 마커 자리는 `ShareCardView.markerPos`.

## 화면 기억 · 떠오름 · 팝업 높이 (2026-11-28)
- 맨 위 문구(`hdr`)와 아래 탭 막대(`tabs|탭`)도 `ScreenCache` 에 담아 옛 화면을 먼저 보인다(`RemoteScreenInline.cacheKey`). 탭 막대는 앱을 켜면 다른 탭 것도 미리 받아 두고(`RootView.prefetchTabBars`, 안드로이드 prefetchTabs), 이번 실행에서 10분 안에 받은 것은 다시 안 받는다(`ScreenCache.fresh`). 맨 위 문구는 켤 때 · 10분마다만 받는다(전에는 화면이 다시 그려질 때마다 받았다).
- 뼈대 → 진짜 화면이 처음 올라올 때 흐림 0.35 → 1, 240ms(`Sources/UI/ArrivalFade.swift` — `.transition(.arrival)` + `.arrivalFade(화면 있나)`; 홈 · 쇼핑 · 소식 · 게시판 · 맛집 · 노선도). 옛 화면을 먼저 보인 경우와 소통방은 안 쓴다(안드로이드 fadeIn 과 같다).
- 팝업처럼 내용 높이로 줄어드는 자리에서는 `ScreenBody(eager: true)`(게으른 쌓기가 높이를 못 재서 납작해진다). 시간표 팝업은 화면 62% 높이로 고정하고 목록이 그 안을 채운다(전에는 첫 줄만 보이고 잘렸다 — CI 캡처 screenshot-map-tt-1.png 로 발견).
- 노선도(`maph|모드|지역|칩` · `mapb|모드|지역|칩[|주변/즐겨찾기|위치칸 0.001°≈110m]`)도 옛 화면을 먼저 보인다(`MapModel.useCache`). 방식 · 지역 · 칩 · 주변/즐겨찾기를 바꿀 때도 본 적 있는 칸이면 먼저 올린다. 버스 본문은 받은 지 10분 안일 때만(안드로이드 BUS_FRESH_MS), 정류장을 골라 펼친 화면 · 덜 받은 화면(info.bus.need 남음)은 안 담는다. 캐시 화면을 올릴 때 `readInfo` 도 다시 돌려 눌림 번호표(stops · rts · rs)를 맞춘다.
- 커뮤니티 칩 줄(`cchips|방식`)과 설정(`settings|<저장값 지문>` — 안드로이드 settingsKey 와 같은 생각: facts 가 같을 때만 기억한 화면을 보인다)도 옛 화면을 먼저, 설정은 뼈대(list) · 떠오름까지.
- 주의: `SwipeArea` 는 `Color.clear` 위에 내용을 얹는 틀이라 스스로 높이가 없다 → `fixedSize(vertical:)` 로 내용 높이에 맞추는 팝업에서 `ScreenBody` 를 그대로 쓰면 납작해진다. 팝업은 `ScreenBody(eager: true)`(SwipeArea 를 거치지 않음) 또는 DlgCard 처럼 직접 쌓는다. 시험 인자 `-mapStn 강남 [-mapTt 1]` 로 CI 가 역 팝업 · 시간표 캡처를 남긴다(screenshot-map-stn-1/2 · map-tt-1) — 놀이터(캐릭터) 장면도 거기서 확인.
- 홈: 켠 직후 빈 홈(입력 없음 · 경로 없음 · 안내 아님)이면 마지막으로 받은 빈 홈(`home|idle`)을 먼저 보이고 새로 받으면 바꾼다(`HomeModel.idle`). 경로가 있거나 글자를 넣은 홈은 눌림이 그 상태에 기대므로 기억하지 않는다(안드로이드 restoreState 에 해당하는 일이 있어야 함).
- 켠 뒤 4초 지나 아직 안 본 탭의 화면(쇼핑 · 소식 · 게시판)을 미리 받아 `ScreenCache` 에 둔다(`RootView.prefetchScreens`, 안드로이드 prefetchTabs). 맛집은 위치가 필요해서, 소통방은 롱폴이라 제외.
