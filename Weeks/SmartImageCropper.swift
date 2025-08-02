import UIKit
import Vision

struct SmartImageCropper {
    enum DetectionMethod: String {
        case face, object, attention, geometric
    }

    enum CropStrategy {
        case center, attentionBased, objectBased, faceDetection, hybrid
    }

    static func smartCrop(image: UIImage, completion: @escaping (UIImage?) -> Void) {
        cropToSquare(image: image, completion: completion)
    }

    static func smartCrop(image: UIImage, for sizeType: WidgetSizeType, strategy: CropStrategy = .hybrid, completion: @escaping (UIImage?) -> Void) {
        cropToSquare(image: image, completion: completion)
    }
    private static let timeoutSeconds: TimeInterval = 6.0
    private static func cropToSquare(image: UIImage, completion: @escaping (UIImage?) -> Void) {
        var hasCompleted = false
        let safeCompletion: (UIImage?) -> Void = { result in
            DispatchQueue.main.async {
                guard !hasCompleted else { return }
                hasCompleted = true
                completion(result)
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds) {
            guard !hasCompleted else { return }
            print("🔍 SmartCropper: 超时，使用几何中心")
            let fallback = cropWithGeometricCenter(image: image)
            safeCompletion(fallback)
        }
        detectVisualCenter(in: image) { center, method in
            guard !hasCompleted else { return }
            print("🔍 SmartCropper: 使用 \(method.rawValue) 检测到中心: \(center)")
            let cropped = cropImageToSquare(image: image, center: center)
            safeCompletion(cropped)
        }
    }


    private static func detectVisualCenter(in image: UIImage, completion: @escaping (CGPoint, DetectionMethod) -> Void) {
        let processedImage = preprocess(image)


        detectFaces(in: processedImage, original: image) { faceCenter in
            if let c = faceCenter { completion(c, .face); return }

            detectObjects(in: processedImage, original: image) { objCenter in
                if let c = objCenter { completion(c, .object); return }

                detectAttention(in: processedImage, original: image) { attCenter in
                    if let c = attCenter { completion(c, .attention); return }

                    let center = CGPoint(x: image.size.width / 2, y: image.size.height / 2)
                    completion(center, .geometric)
                }
            }
        }
    }


    private static func preprocess(_ image: UIImage) -> UIImage {
        let maxLength: CGFloat = 1024
        if max(image.size.width, image.size.height) <= maxLength { return image }
        let scale = maxLength / max(image.size.width, image.size.height)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized ?? image
    }

    private static func detectFaces(in processed: UIImage, original: UIImage, completion: @escaping (CGPoint?) -> Void) {
        guard let cg = processed.cgImage else { completion(nil); return }
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
                guard let best = (request.results as? [VNFaceObservation])?.max(by: { $0.boundingBox.width < $1.boundingBox.width }) else {
                    completion(nil); return
                }
                let center = convert(rect: best.boundingBox, processedSize: processed.size, originalSize: original.size)
                completion(center)
            } catch { completion(nil) }
        }
    }

    private static func detectObjects(in processed: UIImage, original: UIImage, completion: @escaping (CGPoint?) -> Void) {
        guard let cg = processed.cgImage else { completion(nil); return }
        let request = VNGenerateObjectnessBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
                guard let obs = request.results?.first as? VNSaliencyImageObservation,
                      let union = obs.salientObjects?.reduce(nil, { acc, next in acc?.union(next.boundingBox) ?? next.boundingBox }) else {
                    completion(nil); return
                }
                let center = convert(rect: union, processedSize: processed.size, originalSize: original.size)
                completion(center)
            } catch { completion(nil) }
        }
    }

    private static func detectAttention(in processed: UIImage, original: UIImage, completion: @escaping (CGPoint?) -> Void) {
        guard let cg = processed.cgImage else { completion(nil); return }
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
                guard let obs = request.results?.first as? VNSaliencyImageObservation,
                      let union = obs.salientObjects?.reduce(nil, { acc, next in acc?.union(next.boundingBox) ?? next.boundingBox }) else {
                    completion(nil); return
                }
                let center = convert(rect: union, processedSize: processed.size, originalSize: original.size)
                completion(center)
            } catch { completion(nil) }
        }
    }

    private static func cropWithGeometricCenter(image: UIImage) -> UIImage? {
        let center = CGPoint(x: image.size.width / 2, y: image.size.height / 2)
        return cropImageToSquare(image: image, center: center)
    }

    private static func cropImageToSquare(image: UIImage, center: CGPoint) -> UIImage? {
        let square = min(image.size.width, image.size.height)
        let half = square / 2
        let clampedX = max(half, min(image.size.width - half, center.x))
        let clampedY = max(half, min(image.size.height - half, center.y))
        let origin = CGPoint(x: clampedX - half, y: clampedY - half)
        let rect = CGRect(origin: origin, size: CGSize(width: square, height: square)).integral
        guard let cg = image.cgImage?.cropping(to: rect.applying(CGAffineTransform(scaleX: image.scale, y: image.scale))) else { return nil }
        let cropped = UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
        return ImageCropper.resizeForWidget(cropped, targetRatio: 1.0)
    }

    private static func convert(rect: CGRect, processedSize: CGSize, originalSize: CGSize) -> CGPoint {
        let converted = CGRect(x: rect.minX * processedSize.width,
                               y: (1 - rect.maxY) * processedSize.height,
                               width: rect.width * processedSize.width,
                               height: rect.height * processedSize.height)
        let center = CGPoint(x: converted.midX, y: converted.midY)
        let scaleX = originalSize.width / processedSize.width
        let scaleY = originalSize.height / processedSize.height
        return CGPoint(x: center.x * scaleX, y: center.y * scaleY)
    }
}