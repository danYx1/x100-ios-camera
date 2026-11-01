import AVFoundation
import SwiftUI
import Photos

final class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var device: AVCaptureDevice?

    @Published var zoom: CGFloat = 1.0
    @Published var maxZoom: CGFloat = 100
    @Published var lastPhoto: UIImage?
    @Published var aiEnhance = true
    @Published var isProcessing = false

    private let enhancer = PhotoEnhancer()

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { ok in
            guard ok else { return }
            DispatchQueue.global(qos: .userInitiated).async { self.configure() }
        }
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        // Virtual device = автоматическое переключение объективов (0.5x / 1x / 3x-5x)
        let dev = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        guard let dev, let input = try? AVCaptureDeviceInput(device: dev),
              session.canAddInput(input), session.canAddOutput(output) else { return }
        session.addInput(input)
        session.addOutput(output)
        output.maxPhotoQualityPrioritization = .quality
        session.commitConfiguration()
        device = dev
        DispatchQueue.main.async {
            // Реальный максимум зависит от модели iPhone
            self.maxZoom = min(100, dev.maxAvailableVideoZoomFactor)
        }
        session.startRunning()
    }

    /// zoom в "iPhone-единицах": 1.0 = основная камера (на ultra-wide устройствах 0.5 = factor 1.0)
    func setZoom(_ value: CGFloat) {
        guard let device else { return }
        let base: CGFloat = device.deviceType == .builtInWideAngleCamera ? 1 : 2 // 2 = переход 0.5x -> 1x у виртуальных камер
        let factor = max(device.minAvailableVideoZoomFactor,
                         min(value * (base == 2 ? 2 : 1), device.maxAvailableVideoZoomFactor))
        do {
            try device.lockForConfiguration()
            device.ramp(toVideoZoomFactor: factor, withRate: 8)
            device.unlockForConfiguration()
            DispatchQueue.main.async { self.zoom = value }
        } catch {}
    }

    func capture() {
        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = .quality
        output.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let img = UIImage(data: data) else { return }
        DispatchQueue.main.async { self.isProcessing = true }
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.aiEnhance ? self.enhancer.enhance(img, zoom: self.zoom) : img
            UIImageWriteToSavedPhotosAlbum(result, nil, nil, nil)
            DispatchQueue.main.async {
                self.lastPhoto = result
                self.isProcessing = false
            }
        }
    }
}
