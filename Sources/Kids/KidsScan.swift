import SwiftUI
import VisionKit

/// 자녀 폰의 QR 을 찍어 시크릿 키를 읽는다(안드로이드 kl.scan 의 포팅). 읽은 글을 해석하는 것은 KidsHub.codeOf · 서버(kl.join)이고, 여기는 카메라로 글을 읽어 건네기만 한다.
/// 시뮬레이터처럼 카메라가 없거나 권한이 없으면 안내 글만 보이고 키를 직접 입력하면 된다.
struct KidsScanView: View {
    let pal: Palette
    let onCode: (String) -> Void
    let onClose: () -> Void
    private var ok: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }
    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            if ok { KidsScanner(onCode: onCode).ignoresSafeArea() }
            else {
                VStack(spacing: 8) {
                    Text("이 기기에서는 QR 을 찍을 수 없어요").font(Typo.font(15, bold: true)).foregroundColor(.white)
                    Text("카메라 권한을 허용했는지 확인하거나, 자녀 폰의 시크릿 키(XXXXX-XXXXX)를 직접 입력해 주세요.").font(Typo.font(12)).foregroundColor(.white.opacity(0.7)).multilineTextAlignment(.center)
                }.padding(24).frame(maxHeight: .infinity)
            }
            HStack {
                Text("자녀 폰의 QR 을 비춰 주세요").font(Typo.font(13, bold: true)).foregroundColor(.white)
                Spacer()
                Button(action: onClose) { Text("닫기").font(Typo.font(14, bold: true)).foregroundColor(.white).padding(.horizontal, 14).padding(.vertical, 8).background(Color.white.opacity(0.18)).clipShape(Capsule()) }
            }.padding(16)
        }
    }
}

private struct KidsScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let v = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])], qualityLevel: .balanced, recognizesMultipleItems: false, isHighFrameRateTrackingEnabled: false, isPinchToZoomEnabled: true, isGuidanceEnabled: true, isHighlightingEnabled: true)
        v.delegate = context.coordinator
        return v
    }
    func updateUIViewController(_ v: DataScannerViewController, context: Context) {
        if !v.isScanning { DispatchQueue.main.async { try? v.startScanning() } }
    }
    func makeCoordinator() -> Coord { Coord(onCode) }
    final class Coord: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        private var done = false
        init(_ f: @escaping (String) -> Void) { onCode = f }
        func dataScanner(_ s: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !done else { return }
            for case .barcode(let b) in items {
                if let p = b.payloadStringValue, KidsHub.codeOf(p) != nil { done = true; s.stopScanning(); onCode(p); return }
            }
        }
    }
}
