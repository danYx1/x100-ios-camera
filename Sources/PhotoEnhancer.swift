import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

/// Улучшение фото. Шаги:
/// 1) Auto-adjust (экспозиция, баланс белого, тени/света, насыщенность) от Apple
/// 2) Шумоподавление — сильнее при большом зуме
/// 3) Super-resolution через CoreML (если добавлена модель), иначе Lanczos + резкость
final class PhotoEnhancer {
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    func enhance(_ image: UIImage, zoom: CGFloat) -> UIImage {
        guard let cg = image.cgImage else { return image }
        var ci = CIImage(cgImage: cg).oriented(CGImagePropertyOrientation(image.imageOrientation))

        // 1) Auto-enhance
        let filters = ci.autoAdjustmentFilters()
        for f in filters { f.setValue(ci, forKey: kCIInputImageKey); ci = f.outputImage ?? ci }

        // 2) Denoise (чем больше зум, тем больше шума)
        let nr = CIFilter.noiseReduction()
        nr.inputImage = ci
        nr.noiseLevel = Float(min(0.06, 0.01 + zoom * 0.0005))
        nr.sharpness = 0.6
        ci = nr.outputImage ?? ci

        // 3) Super-resolution
        if let sr = SuperResolution.shared.upscale(ci, context: context) {
            ci = sr
        } else {
            let lz = CIFilter.lanczosScaleTransform()
            lz.inputImage = ci; lz.scale = zoom > 10 ? 1.5 : 1.0; lz.aspectRatio = 1
            ci = lz.outputImage ?? ci
        }

        // Адаптивная резкость
        let sh = CIFilter.unsharpMask()
        sh.inputImage = ci
        sh.radius = Float(min(4, 1.2 + zoom * 0.03))
        sh.intensity = Float(min(1.0, 0.5 + zoom * 0.01))
        ci = sh.outputImage ?? ci

        guard let out = context.createCGImage(ci, from: ci.extent) else { return image }
        return UIImage(cgImage: out)
    }
}

/// Заглушка под CoreML-модель (Real-ESRGAN / SwinIR, сконвертированная через coremltools).
/// Добавьте RealESRGAN.mlmodel в проект и реализуйте инференс здесь.
final class SuperResolution {
    static let shared = SuperResolution()
    func upscale(_ image: CIImage, context: CIContext) -> CIImage? {
        // TODO: let model = try VNCoreMLModel(for: RealESRGAN().model)
        //       прогнать image тайлами 256x256 и склеить результат
        return nil
    }
}

private extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up; case .down: self = .down
        case .left: self = .left; case .right: self = .right
        case .upMirrored: self = .upMirrored; case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored; case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
