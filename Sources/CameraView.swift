import SwiftUI
import AVFoundation

struct PreviewLayer: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> UIView {
        let v = PreviewUIView(); v.layer.session = session; return v
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        override var layer: AVCaptureVideoPreviewLayer { super.layer as! AVCaptureVideoPreviewLayer }
        override init(frame: CGRect) { super.init(frame: frame); layer.videoGravity = .resizeAspectFill }
        required init?(coder: NSCoder) { fatalError() }
    }
}

struct CameraView: View {
    @StateObject private var cam = CameraModel()
    @State private var pinchBase: CGFloat = 1
    private let presets: [CGFloat] = [0.5, 1, 2, 5, 10, 50, 100]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                PreviewLayer(session: cam.session)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .gesture(MagnificationGesture()
                        .onChanged { cam.setZoom(max(0.5, min(cam.maxZoom, pinchBase * $0))) }
                        .onEnded { _ in pinchBase = cam.zoom })
                    .overlay(alignment: .bottom) { zoomPicker.padding(.bottom, 12) }
                modePicker
                bottomBar
            }
            if cam.isProcessing { ProgressView("AI…").tint(.yellow).padding().background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12)) }
        }
        .onAppear { cam.start() }
    }

    var topBar: some View {
        HStack {
            Image(systemName: "bolt.slash.fill")
            Spacer()
            Button { cam.aiEnhance.toggle() } label: {
                Label("AI", systemImage: "sparkles")
                    .foregroundColor(cam.aiEnhance ? .yellow : .white)
            }
            Spacer()
            Image(systemName: "chevron.compact.down")
        }
        .padding(.horizontal, 24).frame(height: 44).foregroundColor(.white)
    }

    var zoomPicker: some View {
        HStack(spacing: 10) {
            ForEach(presets.filter { $0 <= cam.maxZoom }, id: \.self) { z in
                let active = abs(cam.zoom - z) < 0.05 * z
                Button { cam.setZoom(z); pinchBase = z } label: {
                    Text(active ? "\(fmt(cam.zoom))×" : fmt(z))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(active ? .yellow : .white)
                        .frame(width: active ? 40 : 32, height: active ? 40 : 32)
                        .background(Color.black.opacity(0.5), in: Circle())
                }
            }
        }
    }

    var modePicker: some View {
        HStack(spacing: 22) {
            ForEach(["ВИДЕО", "ФОТО", "ПОРТРЕТ"], id: \.self) { t in
                Text(t).font(.system(size: 13, weight: .semibold))
                    .foregroundColor(t == "ФОТО" ? .yellow : .white)
            }
        }.padding(.vertical, 14)
    }

    var bottomBar: some View {
        HStack {
            Group {
                if let img = cam.lastPhoto {
                    Image(uiImage: img).resizable().scaledToFill()
                } else { Color.gray.opacity(0.3) }
            }
            .frame(width: 52, height: 52).clipShape(RoundedRectangle(cornerRadius: 8))
            Spacer()
            Button(action: cam.capture) {
                ZStack {
                    Circle().stroke(Color.white, lineWidth: 4).frame(width: 74, height: 74)
                    Circle().fill(Color.white).frame(width: 62, height: 62)
                }
            }
            Spacer()
            Image(systemName: "arrow.triangle.2.circlepath.camera")
                .font(.title2).foregroundColor(.white)
                .frame(width: 52, height: 52).background(Color.white.opacity(0.15), in: Circle())
        }
        .padding(.horizontal, 30).padding(.bottom, 20)
    }

    func fmt(_ z: CGFloat) -> String { z < 10 ? String(format: "%.1f", z).replacingOccurrences(of: ".0", with: "") : String(Int(z)) }
}
