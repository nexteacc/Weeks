//
//  ImageCropper.swift
//  Weeks
//
//  Created by Sheng on 7/4/25.
//

import UIKit


struct ImageCropper {
    /// Maximum safe pixel area for Widget (iOS Widget limitation)
    private static let maxWidgetPixelArea: CGFloat = 1900000 // ~1378x1378
    
    /// Aspect ratio for the only supported Widget size (large)
    private static let largeAspectRatio: CGFloat = 1.0

    /// Get aspect ratio – legacy parameter kept for compatibility
    static func aspectRatio(for sizeType: WidgetSizeType) -> CGFloat {
        return largeAspectRatio // medium 已弃用，统一使用 large 比例 1:1
    }
    
    /// Crop image based on Widget size type
    static func cropCenter(of image: UIImage, for sizeType: WidgetSizeType) -> UIImage? {
        let targetRatio = aspectRatio(for: sizeType)
        return cropCenter(of: image, toAspectRatio: targetRatio)
    }
    
    /// Crop and scale UIImage to specified aspect ratio while ensuring Widget compatibility
    static func cropCenter(of image: UIImage, toAspectRatio ratio: CGFloat) -> UIImage? {
        let originalSize = image.size
        let originalScale = image.scale
        print("🔍 ImageCropper processing started:")
        print("   Original size (points): \(originalSize)")
        print("   Original scale: \(originalScale)")
        print("   Actual pixels: \(originalSize.width * originalScale) x \(originalSize.height * originalScale)")
        print("   Actual pixel area: \(Int(originalSize.width * originalScale * originalSize.height * originalScale))")
        
        let originalRatio = originalSize.width / originalSize.height

        var cropRect: CGRect

        if originalRatio > ratio {
            // Image is too wide, crop the sides
            let newWidth = originalSize.height * ratio
            let x = (originalSize.width - newWidth) / 2
            cropRect = CGRect(x: x, y: 0, width: newWidth, height: originalSize.height)
        } else {
            // Image is too tall, crop top and bottom
            let newHeight = originalSize.width / ratio
            let y = (originalSize.height - newHeight) / 2
            cropRect = CGRect(x: 0, y: y, width: originalSize.width, height: newHeight)
        }

        print("   Crop area: \(cropRect)")
        
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else { return nil }
        let croppedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        
        print("   Size after cropping (points): \(croppedImage.size)")
        print("   Actual pixels after cropping: \(croppedImage.size.width * croppedImage.scale) x \(croppedImage.size.height * croppedImage.scale)")
        
        // Check if scaling is needed to fit Widget limitations
        let result = resizeForWidget(croppedImage, targetRatio: ratio)
        print("   Final result size (points): \(result?.size ?? CGSize.zero)")
        if let result = result {
            print("   Final result actual pixels: \(result.size.width * result.scale) x \(result.size.height * result.scale)")
        }
        print("🔍 ImageCropper processing completed\n")
        
        return result
    }
    
    /// Scale image to Widget safe size
    static func resizeForWidget(_ image: UIImage, targetRatio: CGFloat) -> UIImage? {
        let currentSize = image.size
        let currentScale = image.scale
        let currentArea = currentSize.width * currentSize.height
        let actualPixelArea = currentSize.width * currentScale * currentSize.height * currentScale
        
        print("🔧 resizeForWidget check:")
        print("   Current size (points): \(currentSize)")
        print("   Current scale: \(currentScale)")
        print("   Area calculated by points: \(Int(currentArea))")
        print("   Actual pixel area: \(Int(actualPixelArea))")
        print("   Area limit: \(Int(maxWidgetPixelArea))")
        
        // If current area is within safe range, return directly
        if currentArea <= maxWidgetPixelArea {
            print("   ❌ Not exceeding limit by point calculation, skipping scaling")
            return image
        }
        
        print("   ✅ Exceeding limit by point calculation, starting scaling")
        
        // Calculate scaling factor
        let scaleFactor = sqrt(maxWidgetPixelArea / currentArea)
        let newWidth = currentSize.width * scaleFactor
        let newHeight = currentSize.height * scaleFactor
        let newSize = CGSize(width: newWidth, height: newHeight)
        
        print("   Scaling factor: \(scaleFactor)")
        print("   New size (points): \(newSize)")
        
        // Create new image context - force scale=1.0 to ensure 1:1 point-to-pixel mapping
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            print("   ❌ Scaling failed, returning original image")
            return image // If scaling fails, return the original image
        }
        
        print("   ✅ Scaling successful")
        print("   Final size (points): \(resizedImage.size)")
        print("   Final actual pixels: \(resizedImage.size.width * resizedImage.scale) x \(resizedImage.size.height * resizedImage.scale)")
        return resizedImage
    }
}
