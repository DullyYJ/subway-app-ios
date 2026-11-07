import SwiftUI

/// 확인용(-nodeDemo): 새로 옮긴 노드들을 견본 값으로 그려 CI 캡처로 모양을 확인한다. 평소에는 쓰이지 않는다.
enum NodeDemo {
    static var on: Bool { CommandLine.arguments.contains("-nodeDemo") }
    static var page: Int { if let i = CommandLine.arguments.firstIndex(of: "-nodeDemo"), i + 1 < CommandLine.arguments.count, let n = Int(CommandLine.arguments[i + 1]) { return n }; return 1 }

    static let json1 = """
    {"ok":true,"screen":"demo","body":[
     {"t":"brh","no":"472","tp":"간선버스","c":"#0068b7","act":{"a":"call","v":"br.close"},"bact":{"a":"call","v":"br.refresh"}},
     {"t":"brt","a":"강남역","b":"서울역","tag":"상행","tk":"up","chips":[{"s":"배차 8분","k":"on"},{"s":"내 정류장 3개 전","k":"me"},{"s":"막차 23:40","k":""}]},
     {"t":"brsec","k":"up","s":"서울역","tag":"상행"},
     {"t":"brs","k":"up","i":0,"nm":"강남역","id":"22001","fl":"f","lab":"기점","act":{"a":"call","v":"br.s0"}},
     {"t":"brs","k":"up","i":1,"nm":"역삼역","id":"22002","mk":"bus","notes":[{"s":"3분 후 도착","k":"on"}],"act":{"a":"call","v":"br.s1"}},
     {"t":"brs","k":"up","i":2,"nm":"선릉역","id":"22003","here":1,"mk":"me","notes":[{"s":"내 위치","k":"me"}],"act":{"a":"call","v":"br.s2"}},
     {"t":"brs","k":"up","i":3,"nm":"삼성역","id":"22004","ar":1,"ps":"p","lab":"환승","act":{"a":"call","v":"br.s3"}},
     {"t":"brturn","s":"회차 ↻"},
     {"t":"brsec","k":"down","s":"강남역","tag":"하행"},
     {"t":"brs","k":"down","i":4,"nm":"서울역","id":"22010","fl":"l","ps":"s","lab":"종점","act":{"a":"call","v":"br.s4"}}
    ]}
    """
    static let json3 = """
    {"ok":true,"screen":"demo3","body":[
     {"t":"runner","ttl":"경로를 찾고 있어요","sub":"잠시만 기다려 주세요","pad":[16,40,16,0]}
    ]}
    """
    static let json2 = """
    {"ok":true,"screen":"demo2","body":[
     {"t":"chart","ttl":"시간대별 혼잡","src":"서울교통공사","pk":"피크 08시","bh":112,"ci":9,"co":"#ffffff","pc":"gold","bars":[
       {"h":"0","v":0,"o":true},{"h":"5","v":20,"c":"#34c759","a":0.7},{"h":"6","v":40,"c":"#34c759","a":0.8},{"h":"7","v":70,"c":"#ffcc00"},{"h":"8","v":98,"c":"#ff3b30"},{"h":"9","v":80,"c":"#ff9500"},{"h":"10","v":50,"c":"#34c759","u":true},{"h":"11","v":42,"c":"#34c759"},{"h":"12","v":55,"c":"#ffcc00"},{"h":"13","v":45,"c":"#34c759"},{"h":"14","v":38,"c":"#34c759"},{"h":"15","v":40,"c":"#34c759"}]},
     {"t":"pickl","key":"pk1","vis":3,"h":38,"rows":[{"a":"지하철","b":"07:42 출발","c":"32분","on":true,"act":{"a":"call","v":"pk.0"}},{"a":"버스","b":"07:50 출발","c":"41분","act":{"a":"call","v":"pk.1"}},{"a":"도보+지하철","b":"07:46 출발","c":"38분","act":{"a":"call","v":"pk.2"}},{"a":"택시","b":"바로 출발","c":"24분","act":{"a":"call","v":"pk.3"}}],"pad":[16,10,16,0]},
     {"t":"pickl","key":"pk2","fold":true,"vis":3,"h":38,"rows":[{"a":"지하철","b":"07:42 출발","c":"32분","on":true,"act":{"a":"call","v":"pk.0"}},{"a":"버스","b":"07:50 출발","c":"41분","act":{"a":"call","v":"pk.1"}}],"pad":[16,10,16,0]},
     {"t":"search","hint":"정류장·노선 검색","badge":"버","max":340,"act":{"a":"search","tpl":"https://example.com/?q={q}","empty":"https://example.com/"},"pad":[16,14,16,0]},
     {"t":"runner","ttl":"경로를 찾고 있어요","sub":"잠시만 기다려 주세요","pad":[16,10,16,0]},
     {"t":"gauge","s":"강남","txt":"72%","v":72,"c":"#ff9500","pad":[16,10,16,0]},
     {"t":"cgh","lab":"지하철","nm":"강남","meta":"2호선 · 평일 저녁","st":"혼잡","sc":"#ff9500","pad":[16,10,16,0]},
     {"t":"cars","ttl":"칸별 혼잡","cells":[{"n":"1","l":"여유","p":"20%","c":"#34c759"},{"n":"2","l":"보통","p":"50%","c":"#ffcc00"},{"n":"3","l":"혼잡","p":"85%","c":"#ff3b30"},{"n":"4","l":"보통","p":"55%","c":"#ffcc00"}],"pad":[16,10,16,0]},
     {"t":"lpills","items":[{"s":"2호선","c":"#00a84d"},{"s":"신분당선","c":"#d4003b","num":"1"},{"s":"9호선","c":"#bb8336"}],"pad":[16,10,16,0]},
     {"t":"lbar","ttl":"불러오는 중","sub":"조금만요","pad":[16,10,16,0]},
     {"t":"skel","kind":"list","rows":2,"pad":[16,10,16,0]}
    ]}
    """
}

struct NodeDemoView: View {
    let pal: Palette
    var body: some View {
        let s = try? Screen.parse(Data((NodeDemo.page == 3 ? NodeDemo.json3 : NodeDemo.page == 2 ? NodeDemo.json2 : NodeDemo.json1).utf8))
        ZStack {
            (pal.color("bg") ?? .black).ignoresSafeArea()
            if let s = s { ScreenBody(screen: s, pal: pal) } else { Text("견본 읽기 실패").foregroundColor(.red) }
        }
    }
}
