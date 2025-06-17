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
    /// 裁剪 UIImage 到指定宽高比例（例如 2:1）
    static func cropCenter(of image: UIImage, toAspectRatio ratio: CGFloat) -> UIImage? {
        let originalSize = image.size
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

        guard let cgImage = image.cgImage?.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}
