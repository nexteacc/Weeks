//
//  ImageCropper.swift
//  Weeks
//
//  Created by Sheng on 7/4/25.
//


//
//  ImageCropper.swift
//  weekofyear
//
//  Created by Sheng on 7/4/25.
//

import UIKit


struct ImageCropper {
    /// Widget安全的最大像素面积（约为iOS限制的90%）
    private static let maxWidgetPixelArea: CGFloat = 1900000 // ~1378x1378
    
    /// 不同尺寸的宽高比
    static let mediumAspectRatio: CGFloat = 2.13
    static let largeAspectRatio: CGFloat = 1.0
    
    /// 根据 Widget 尺寸类型获取对应的宽高比
    static func aspectRatio(for sizeType: WidgetSizeType) -> CGFloat {
        switch sizeType {
        case .medium:
            return mediumAspectRatio
        case .large:
            return largeAspectRatio
        }
    }
    
    /// 根据 Widget 尺寸类型裁剪图片
    static func cropCenter(of image: UIImage, for sizeType: WidgetSizeType) -> UIImage? {
        let targetRatio = aspectRatio(for: sizeType)
        return cropCenter(of: image, toAspectRatio: targetRatio)
    }
    
    /// 裁剪并缩放UIImage到指定宽高比例，同时确保Widget兼容性
    static func cropCenter(of image: UIImage, toAspectRatio ratio: CGFloat) -> UIImage? {
        let originalSize = image.size
        let originalScale = image.scale
        print("🔍 ImageCropper开始处理:")
        print("   原始尺寸(点): \(originalSize)")
        print("   原始scale: \(originalScale)")
        print("   实际像素: \(originalSize.width * originalScale) x \(originalSize.height * originalScale)")
        print("   实际像素面积: \(Int(originalSize.width * originalScale * originalSize.height * originalScale))")
        
        let originalRatio = originalSize.width / originalSize.height

        var cropRect: CGRect

        if originalRatio > ratio {
            // 图片太宽，裁掉两侧
            let newWidth = originalSize.height * ratio
            let x = (originalSize.width - newWidth) / 2
            cropRect = CGRect(x: x, y: 0, width: newWidth, height: originalSize.height)
        } else {
            // 图片太高，裁掉上下
            let newHeight = originalSize.width / ratio
            let y = (originalSize.height - newHeight) / 2
            cropRect = CGRect(x: 0, y: y, width: originalSize.width, height: newHeight)
        }

        print("   裁剪区域: \(cropRect)")
        
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else { return nil }
        let croppedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        
        print("   裁剪后尺寸(点): \(croppedImage.size)")
        print("   裁剪后实际像素: \(croppedImage.size.width * croppedImage.scale) x \(croppedImage.size.height * croppedImage.scale)")
        
        // 检查是否需要缩放以适应Widget限制
        let result = resizeForWidget(croppedImage, targetRatio: ratio)
        print("   最终结果尺寸(点): \(result?.size ?? CGSize.zero)")
        if let result = result {
            print("   最终结果实际像素: \(result.size.width * result.scale) x \(result.size.height * result.scale)")
        }
        print("🔍 ImageCropper处理完成\n")
        
        return result
    }
    
    /// 将图片缩放到Widget安全尺寸
    private static func resizeForWidget(_ image: UIImage, targetRatio: CGFloat) -> UIImage? {
        let currentSize = image.size
        let currentScale = image.scale
        let currentArea = currentSize.width * currentSize.height
        let actualPixelArea = currentSize.width * currentScale * currentSize.height * currentScale
        
        print("🔧 resizeForWidget检查:")
        print("   当前尺寸(点): \(currentSize)")
        print("   当前scale: \(currentScale)")
        print("   按点计算面积: \(Int(currentArea))")
        print("   实际像素面积: \(Int(actualPixelArea))")
        print("   限制面积: \(Int(maxWidgetPixelArea))")
        
        // 如果当前面积在安全范围内，直接返回
        if currentArea <= maxWidgetPixelArea {
            print("   ❌ 按点计算未超限，跳过缩放")
            return image
        }
        
        print("   ✅ 按点计算超限，开始缩放")
        
        // 计算缩放因子
        let scaleFactor = sqrt(maxWidgetPixelArea / currentArea)
        let newWidth = currentSize.width * scaleFactor
        let newHeight = currentSize.height * scaleFactor
        let newSize = CGSize(width: newWidth, height: newHeight)
        
        print("   缩放因子: \(scaleFactor)")
        print("   新尺寸(点): \(newSize)")
        
        // 创建新的图片上下文 - 强制使用scale=1.0确保点像素1:1对应
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            print("   ❌ 缩放失败，返回原图")
            return image // 如果缩放失败，返回原图
        }
        
        print("   ✅ 缩放成功")
        print("   最终尺寸(点): \(resizedImage.size)")
        print("   最终实际像素: \(resizedImage.size.width * resizedImage.scale) x \(resizedImage.size.height * resizedImage.scale)")
        return resizedImage
    }
}
