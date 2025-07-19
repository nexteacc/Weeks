//
//  SmartImageCropper.swift
//  Weeks
//
//  Created by AI Assistant on 7/4/25.
//

import UIKit
import Vision

/// 智能图片裁剪器，使用Vision框架的显著性检测技术
struct SmartImageCropper {
    
    /// 裁剪策略枚举
    enum CropStrategy {
        case center          // 传统中心裁剪
        case attentionBased  // 基于注意力的显著性检测（视觉焦点）
        case objectBased     // 基于对象的显著性检测（前景物体）
        case faceDetection   // 人脸检测（精确定位）
        case hybrid          // 混合策略（基于Vision框架特性的优化组合）
    }
    
    /// 显著区域位置类型
    private enum SalientPosition {
        case center       // 中心区域
        case leftEdge     // 左边缘
        case rightEdge    // 右边缘
        case topEdge      // 上边缘
        case bottomEdge   // 下边缘
        case topLeft      // 左上角
        case topRight     // 右上角
        case bottomLeft   // 左下角
        case bottomRight  // 右下角
    }
    
    /// 扩展向量结构体
    private struct ExpansionVector {
        let left: CGFloat     // 左侧扩展因子
        let right: CGFloat    // 右侧扩展因子
        let top: CGFloat      // 上侧扩展因子
        let bottom: CGFloat   // 下侧扩展因子
    }
    
    /// 智能裁剪图片到指定宽高比
    /// - Parameters:
    ///   - image: 原始图片
    ///   - targetRatio: 目标宽高比
    ///   - strategy: 裁剪策略
    ///   - completion: 完成回调
    static func smartCrop(
        image: UIImage,
        toAspectRatio targetRatio: CGFloat,
        strategy: CropStrategy = .hybrid,
        completion: @escaping (UIImage?) -> Void
    ) {
        // 添加全局超时保护
        var hasCompleted = false
        let timeoutSeconds = 8.0 // 8秒超时
        
        // 创建安全回调函数，确保只调用一次
        let safeCompletion: (UIImage?) -> Void = { result in
            DispatchQueue.main.async {
                if !hasCompleted {
                    hasCompleted = true
                    completion(result)
                }
            }
        }
        
        // 设置全局超时
        DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds) {
            if !hasCompleted {
                print("智能裁剪超时，使用中心裁剪作为兜底")
                let centerResult = ImageCropper.cropCenter(of: image, toAspectRatio: targetRatio)
                safeCompletion(centerResult)
            }
        }
        
        switch strategy {
        case .center:
            let result = ImageCropper.cropCenter(of: image, toAspectRatio: targetRatio)
            safeCompletion(result)
            
        case .attentionBased:
            print("使用注意力显著性裁剪策略")
            cropUsingAttentionSaliency(image: image, targetRatio: targetRatio) { result in
                safeCompletion(result)
            }
            
        case .objectBased:
            print("使用对象显著性裁剪策略")
            cropUsingObjectSaliency(image: image, targetRatio: targetRatio) { result in
                safeCompletion(result)
            }
            
        case .faceDetection:
            print("使用人脸检测裁剪策略")
            cropUsingFaceDetection(image: image, targetRatio: targetRatio) { result in
                safeCompletion(result)
            }
            
        case .hybrid:
            print("使用混合裁剪策略")
            // 基于Apple Vision框架特性的优化策略：
            // 1. 人脸检测（精确定位）
            // 2. 对象显著性（前景物体）
            // 3. 注意力显著性（视觉焦点）
            // 4. 中心裁剪（兜底）
            
            // 为每个步骤设置单独的超时
            let stepTimeoutSeconds = 2.5 // 每个步骤2.5秒超时
            
            // 步骤1：人脸检测
            let faceDetectionTimeout = DispatchWorkItem {
                if !hasCompleted {
                    print("人脸检测超时，尝试对象显著性")
                    // 步骤2：对象显著性
                    cropUsingObjectSaliency(image: image, targetRatio: targetRatio) { objectResult in
                        if !hasCompleted && objectResult != nil {
                            print("对象显著性检测成功")
                            safeCompletion(objectResult)
                        } else if !hasCompleted {
                            print("对象显著性检测失败，尝试注意力显著性")
                            // 步骤3：注意力显著性
                            cropUsingAttentionSaliency(image: image, targetRatio: targetRatio) { attentionResult in
                                if !hasCompleted && attentionResult != nil {
                                    print("注意力显著性检测成功")
                                    safeCompletion(attentionResult)
                                } else if !hasCompleted {
                                    print("注意力显著性检测失败，使用中心裁剪")
                                    // 步骤4：中心裁剪（兜底）
                                    let centerResult = ImageCropper.cropCenter(of: image, toAspectRatio: targetRatio)
                                    safeCompletion(centerResult)
                                }
                            }
                        }
                    }
                }
            }
            
            // 开始人脸检测
            cropUsingFaceDetection(image: image, targetRatio: targetRatio) { result in
                // 取消超时任务
                faceDetectionTimeout.cancel()
                
                if !hasCompleted && result != nil {
                    print("人脸检测成功")
                    safeCompletion(result)
                } else if !hasCompleted {
                    print("人脸检测失败，尝试对象显著性")
                    // 步骤2：对象显著性
                    cropUsingObjectSaliency(image: image, targetRatio: targetRatio) { objectResult in
                        if !hasCompleted && objectResult != nil {
                            print("对象显著性检测成功")
                            safeCompletion(objectResult)
                        } else if !hasCompleted {
                            print("对象显著性检测失败，尝试注意力显著性")
                            // 步骤3：注意力显著性
                            cropUsingAttentionSaliency(image: image, targetRatio: targetRatio) { attentionResult in
                                if !hasCompleted && attentionResult != nil {
                                    print("注意力显著性检测成功")
                                    safeCompletion(attentionResult)
                                } else if !hasCompleted {
                                    print("注意力显著性检测失败，使用中心裁剪")
                                    // 步骤4：中心裁剪（兜底）
                                    let centerResult = ImageCropper.cropCenter(of: image, toAspectRatio: targetRatio)
                                    safeCompletion(centerResult)
                                }
                            }
                        }
                    }
                }
            }
            
            // 设置人脸检测超时
            DispatchQueue.global().asyncAfter(deadline: .now() + stepTimeoutSeconds, execute: faceDetectionTimeout)
        }
    }
    
    /// 根据Widget尺寸类型智能裁剪图片
    static func smartCrop(
        image: UIImage,
        for sizeType: WidgetSizeType,
        strategy: CropStrategy = .hybrid,
        completion: @escaping (UIImage?) -> Void
    ) {
        let targetRatio = ImageCropper.aspectRatio(for: sizeType)
        smartCrop(image: image, toAspectRatio: targetRatio, strategy: strategy, completion: completion)
    }
    
    // MARK: - 图片预处理
    
    /// 预处理图片：缩放到合适尺寸以提高检测效率和最终质量
    private static func preprocessImageForDetection(_ image: UIImage) -> UIImage {
        let currentSize = image.size
        let currentScale = image.scale
        let actualPixelArea = currentSize.width * currentScale * currentSize.height * currentScale
        
        // 设定检测用的最佳像素面积（2000x2000左右，既保证检测精度又不会太大）
        let optimalDetectionArea: CGFloat = 4000000 // ~2000x2000
        
        if actualPixelArea <= optimalDetectionArea {
            print("📐 预处理: 图片尺寸合适，无需缩放")
            return image
        }
        
        let scaleFactor = sqrt(optimalDetectionArea / actualPixelArea)
        let newSize = CGSize(
            width: currentSize.width * scaleFactor,
            height: currentSize.height * scaleFactor
        )
        
        print("📐 预处理: 缩放图片用于检测")
        print("   原始尺寸: \(currentSize)")
        print("   检测尺寸: \(newSize)")
        print("   缩放因子: \(scaleFactor)")
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        
        guard let preprocessedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            print("📐 预处理: 缩放失败，使用原图")
            return image
        }
        
        return preprocessedImage
    }
    
    // MARK: - 基于注意力的显著性检测裁剪
    
    private static func cropUsingAttentionSaliency(
        image: UIImage,
        targetRatio: CGFloat,
        completion: @escaping (UIImage?) -> Void
    ) {
        // 预处理图片以提高检测效率
        let processedImage = preprocessImageForDetection(image)
        
        guard let cgImage = processedImage.cgImage else {
            print("🔍 SmartCropper: 无法获取CGImage，回退到中心裁剪")
            completion(nil)
            return
        }
        
        print("🧠 SmartCropper: 开始注意力显著性检测")
        
        let request = VNGenerateAttentionBasedSaliencyImageRequest { request, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("🔍 SmartCropper: 注意力检测失败 - \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let results = request.results as? [VNSaliencyImageObservation],
                      let observation = results.first else {
                    print("🔍 SmartCropper: 注意力检测无结果")
                    completion(nil)
                    return
                }
                
                let croppedImage = cropImageUsingSaliency(
                    originalImage: image,
                    processedImage: processedImage,
                    observation: observation,
                    targetRatio: targetRatio,
                    saliencyType: "注意力"
                )
                
                completion(croppedImage)
            }
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
            } catch {
                print("🔍 SmartCropper: 注意力检测执行失败 - \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    // MARK: - 人脸检测裁剪（专注于人脸，移除有问题的动物检测）
    
    private static func cropUsingFaceDetection(
        image: UIImage,
        targetRatio: CGFloat,
        completion: @escaping (UIImage?) -> Void
    ) {
        // 预处理图片以提高检测效率
        let processedImage = preprocessImageForDetection(image)
        
        guard let cgImage = processedImage.cgImage else {
            print("🔍 SmartCropper: 无法获取CGImage")
            completion(nil)
            return
        }
        
        print("👤 SmartCropper: 开始人脸检测")
        
        // 只进行人脸检测，使用更精确的人脸检测请求
        let faceRequest = VNDetectFaceRectanglesRequest()
        faceRequest.revision = VNDetectFaceRectanglesRequestRevision3 // 使用最新版本
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([faceRequest])
                
                DispatchQueue.main.async {
                    let faceResults = faceRequest.results ?? []
                    
                    if let croppedImage = processFaceDetectionResults(
                        originalImage: image,
                        processedImage: processedImage,
                        faceResults: faceResults,
                        targetRatio: targetRatio
                    ) {
                        completion(croppedImage)
                    } else {
                        print("👤 SmartCropper: 未检测到人脸")
                        completion(nil)
                    }
                }
            } catch {
                print("👤 SmartCropper: 人脸检测执行失败 - \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    // MARK: - 基于对象的显著性检测裁剪
    
    private static func cropUsingObjectSaliency(
        image: UIImage,
        targetRatio: CGFloat,
        completion: @escaping (UIImage?) -> Void
    ) {
        // 预处理图片以提高检测效率
        let processedImage = preprocessImageForDetection(image)
        
        guard let cgImage = processedImage.cgImage else {
            print("🔍 SmartCropper: 无法获取CGImage，回退到中心裁剪")
            completion(nil)
            return
        }
        
        print("🎯 SmartCropper: 开始对象显著性检测")
        
        let request = VNGenerateObjectnessBasedSaliencyImageRequest { request, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("🔍 SmartCropper: 对象检测失败 - \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let results = request.results as? [VNSaliencyImageObservation],
                      let observation = results.first else {
                    print("🔍 SmartCropper: 对象检测无结果")
                    completion(nil)
                    return
                }
                
                let croppedImage = cropImageUsingSaliency(
                    originalImage: image,
                    processedImage: processedImage,
                    observation: observation,
                    targetRatio: targetRatio,
                    saliencyType: "对象"
                )
                
                completion(croppedImage)
            }
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
            } catch {
                print("🔍 SmartCropper: 对象检测执行失败 - \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    // MARK: - 人脸检测结果处理
    
    /// 处理人脸检测结果（专注于人脸，提高精确性）
    private static func processFaceDetectionResults(
        originalImage: UIImage,
        processedImage: UIImage,
        faceResults: [VNFaceObservation],
        targetRatio: CGFloat
    ) -> UIImage? {
        guard !faceResults.isEmpty else {
            return nil
        }
        
        let originalSize = originalImage.size
        let processedSize = processedImage.size
        print("👤 SmartCropper: 处理人脸检测结果")
        print("   检测到 \(faceResults.count) 个人脸")
        print("   原始图片尺寸: \(originalSize)")
        print("   预处理图片尺寸: \(processedSize)")
        
        // 计算缩放比例，用于将预处理图片的坐标映射回原图
        let scaleX = originalSize.width / processedSize.width
        let scaleY = originalSize.height / processedSize.height
        
        // 筛选高置信度的人脸（提高精确性）
        let highConfidenceFaces = faceResults.filter { $0.confidence > 0.5 }
        guard !highConfidenceFaces.isEmpty else {
            print("   所有人脸置信度过低，跳过人脸检测")
            return nil
        }
        
        let detectedRect: CGRect
        
        if highConfidenceFaces.count == 1 {
            let face = highConfidenceFaces[0]
            print("   单个高置信度人脸，置信度: \(face.confidence)")
            // 先转换到预处理图片坐标系，再映射到原图坐标系
            let processedRect = convertVisionRectToUIKit(face.boundingBox, imageSize: processedSize)
            detectedRect = CGRect(
                x: processedRect.origin.x * scaleX,
                y: processedRect.origin.y * scaleY,
                width: processedRect.width * scaleX,
                height: processedRect.height * scaleY
            )
        } else {
            // 多个人脸：选择置信度最高的或合并相近的人脸
            print("   多个高置信度人脸，智能合并处理")
            let bestFace = highConfidenceFaces.max { $0.confidence < $1.confidence }!
            
            // 检查是否有相近的人脸需要合并
            var unionRect = bestFace.boundingBox
            for face in highConfidenceFaces {
                if face != bestFace {
                    let distance = sqrt(pow(face.boundingBox.midX - bestFace.boundingBox.midX, 2) + 
                                      pow(face.boundingBox.midY - bestFace.boundingBox.midY, 2))
                    // 如果人脸距离较近，合并边界框
                    if distance < 0.3 {
                        unionRect = unionRect.union(face.boundingBox)
                        print("     合并相近人脸，置信度: \(face.confidence)")
                    }
                }
            }
            
            // 先转换到预处理图片坐标系，再映射到原图坐标系
            let processedUnionRect = convertVisionRectToUIKit(unionRect, imageSize: processedSize)
            detectedRect = CGRect(
                x: processedUnionRect.origin.x * scaleX,
                y: processedUnionRect.origin.y * scaleY,
                width: processedUnionRect.width * scaleX,
                height: processedUnionRect.height * scaleY
            )
        }
        
        print("   人脸检测区域: \(detectedRect)")
        
        // 使用专门的人脸扩展算法
        let expandedRect = expandFaceRect(detectedRect, in: originalSize, targetRatio: targetRatio, type: "人脸")
        print("   扩展后区域: \(expandedRect)")
        
        // 根据目标宽高比调整裁剪区域
        let finalCropRect = adjustRectForAspectRatio(expandedRect, targetRatio: targetRatio, imageSize: originalSize)
        print("   最终裁剪区域: \(finalCropRect)")
        
        // 执行裁剪（基于原图）
        guard let cgImage = originalImage.cgImage?.cropping(to: finalCropRect) else {
            print("   ❌ 裁剪失败")
            return nil
        }
        
        let croppedImage = UIImage(cgImage: cgImage, scale: originalImage.scale, orientation: originalImage.imageOrientation)
        print("   ✅ 人脸优化裁剪成功")
        print("   裁剪后尺寸: \(croppedImage.size)")
        
        // 应用Widget尺寸限制
        return ImageCropper.resizeForWidget(croppedImage, targetRatio: targetRatio)
    }
    

    
    /// 将Vision坐标系转换为UIKit坐标系
    private static func convertVisionRectToUIKit(_ visionRect: CGRect, imageSize: CGSize) -> CGRect {
        return CGRect(
            x: visionRect.origin.x * imageSize.width,
            y: (1 - visionRect.origin.y - visionRect.height) * imageSize.height,
            width: visionRect.width * imageSize.width,
            height: visionRect.height * imageSize.height
        )
    }
    
    /// 专门针对人脸的智能扩展算法
    private static func expandFaceRect(
        _ rect: CGRect,
        in imageSize: CGSize,
        targetRatio: CGFloat,
        type: String
    ) -> CGRect {
        print("   开始\(type)专用扩展算法")
        
        // 人脸特定的扩展策略
        let faceAreaRatio = (rect.width * rect.height) / (imageSize.width * imageSize.height)
        
        // 根据人脸大小调整扩展因子
        let expansionFactor: CGFloat
        switch faceAreaRatio {
        case 0.3...1.0:   // 大人脸（30%以上）
            expansionFactor = 1.1   // 轻微扩展，保持焦点
        case 0.1...0.3:   // 中等人脸（10%-30%）
            expansionFactor = 1.3   // 适度扩展，包含肩膀/身体
        case 0.05...0.1:  // 小人脸（5%-10%）
            expansionFactor = 1.6   // 较多扩展，包含更多上下文
        default:          // 很小的人脸（<5%）
            expansionFactor = 2.0   // 大量扩展，确保可见性
        }
        
        // 人脸的位置感知扩展
        let position = analyzeFacePosition(rect, in: imageSize)
        let expansionVector = calculateFaceExpansionVector(
            position: position,
            rect: rect,
            imageSize: imageSize,
            targetRatio: targetRatio,
            baseFactor: expansionFactor,
            type: type
        )
        
        return applyExpansionWithBounds(
            rect: rect,
            expansionVector: expansionVector,
            imageSize: imageSize
        )
    }
    
    /// 分析人脸在图片中的位置
    private static func analyzeFacePosition(_ rect: CGRect, in imageSize: CGSize) -> SalientPosition {
        let rectCenterY = rect.midY
        let imageHeight = imageSize.height
        
        // 对于人脸，更关注垂直位置
        if rectCenterY < imageHeight * 0.25 {
            return .topEdge      // 顶部区域（可能需要向下扩展更多）
        } else if rectCenterY > imageHeight * 0.75 {
            return .bottomEdge   // 底部区域（可能需要向上扩展更多）
        } else {
            return .center       // 中心区域（均匀扩展）
        }
    }
    
    /// 计算人脸专用的扩展向量
    private static func calculateFaceExpansionVector(
        position: SalientPosition,
        rect: CGRect,
        imageSize: CGSize,
        targetRatio: CGFloat,
        baseFactor: CGFloat,
        type: String
    ) -> ExpansionVector {
        let currentRatio = rect.width / rect.height
        
        // 人脸的宽高比偏好调整
        let horizontalBias: CGFloat
        let verticalBias: CGFloat
        
        if targetRatio > currentRatio {
            // 需要更宽的区域（包含肩膀/身体）
            horizontalBias = 1.4
            verticalBias = 1.0
        } else {
            // 需要更高的区域（包含头部到胸部）
            horizontalBias = 1.0
            verticalBias = 1.3
        }
        
        switch position {
        case .topEdge:
            // 顶部人脸：主要向下扩展，包含身体
            return ExpansionVector(
                left: baseFactor * horizontalBias,
                right: baseFactor * horizontalBias,
                top: 1.1,  // 顶部少量扩展
                bottom: baseFactor * 1.8 * verticalBias  // 底部大量扩展
            )
            
        case .bottomEdge:
            // 底部人脸：主要向上扩展
            return ExpansionVector(
                left: baseFactor * horizontalBias,
                right: baseFactor * horizontalBias,
                top: baseFactor * 1.5 * verticalBias,
                bottom: 1.1  // 底部少量扩展
            )
            
        default: // .center
            // 中心人脸：均匀扩展，但偏向包含身体
            return ExpansionVector(
                left: baseFactor * horizontalBias,
                right: baseFactor * horizontalBias,
                top: baseFactor * 0.8 * verticalBias,     // 头部上方适度扩展
                bottom: baseFactor * 1.2 * verticalBias   // 身体下方更多扩展
            )
        }
    }
    
    // MARK: - 显著性检测结果处理
    
    private static func cropImageUsingSaliency(
        originalImage: UIImage,
        processedImage: UIImage,
        observation: VNSaliencyImageObservation,
        targetRatio: CGFloat,
        saliencyType: String
    ) -> UIImage? {
        let originalSize = originalImage.size
        let processedSize = processedImage.size
        print("🔍 SmartCropper: 处理\(saliencyType)显著性结果")
        print("   原始图片尺寸: \(originalSize)")
        print("   预处理图片尺寸: \(processedSize)")
        
        // 计算缩放比例，用于将预处理图片的坐标映射回原图
        let scaleX = originalSize.width / processedSize.width
        let scaleY = originalSize.height / processedSize.height
        
        // 获取显著区域
        var salientRect: CGRect
        
        if let salientObjects = observation.salientObjects, !salientObjects.isEmpty {
            // 合并所有显著对象的边界框
            var unionRect = CGRect.zero
            for salientObject in salientObjects {
                let boundingBox = salientObject.boundingBox
                print("   显著对象边界框: \(boundingBox), 置信度: \(salientObject.confidence)")
                
                if unionRect == .zero {
                    unionRect = boundingBox
                } else {
                    unionRect = unionRect.union(boundingBox)
                }
            }
            
            // 转换坐标系（Vision使用左下角为原点，UIKit使用左上角为原点）
            // 先转换到预处理图片坐标系，再映射到原图坐标系
            let processedRect = CGRect(
                x: unionRect.origin.x * processedSize.width,
                y: (1 - unionRect.origin.y - unionRect.height) * processedSize.height,
                width: unionRect.width * processedSize.width,
                height: unionRect.height * processedSize.height
            )
            
            // 映射到原图坐标系
            salientRect = CGRect(
                x: processedRect.origin.x * scaleX,
                y: processedRect.origin.y * scaleY,
                width: processedRect.width * scaleX,
                height: processedRect.height * scaleY
            )
            
            print("   合并后显著区域: \(salientRect)")
        } else {
            // 如果没有检测到显著对象，使用图片中心区域
            print("   未检测到显著对象，使用中心区域")
            let centerSize = min(originalSize.width, originalSize.height) * 0.8
            salientRect = CGRect(
                x: (originalSize.width - centerSize) / 2,
                y: (originalSize.height - centerSize) / 2,
                width: centerSize,
                height: centerSize
            )
        }
        
        // 智能扩展显著区域，根据位置和目标宽高比动态调整
        let expandedRect = expandSalientRect(salientRect, in: originalSize, targetRatio: targetRatio)
        print("   扩展后区域: \(expandedRect)")
        
        // 根据目标宽高比调整裁剪区域
        let finalCropRect = adjustRectForAspectRatio(expandedRect, targetRatio: targetRatio, imageSize: originalSize)
        print("   最终裁剪区域: \(finalCropRect)")
        
        // 执行裁剪（基于原图）
        guard let cgImage = originalImage.cgImage?.cropping(to: finalCropRect) else {
            print("   ❌ 裁剪失败")
            return nil
        }
        
        let croppedImage = UIImage(cgImage: cgImage, scale: originalImage.scale, orientation: originalImage.imageOrientation)
        print("   ✅ \(saliencyType)智能裁剪成功")
        print("   裁剪后尺寸: \(croppedImage.size)")
        
        // 应用Widget尺寸限制
        return ImageCropper.resizeForWidget(croppedImage, targetRatio: targetRatio)
    }
    
    // MARK: - 辅助方法
    
    /// 智能扩展显著区域，根据位置和目标宽高比动态调整
    private static func expandSalientRect(
        _ rect: CGRect,
        in imageSize: CGSize,
        targetRatio: CGFloat
    ) -> CGRect {
        // 分析显著区域的位置特征
        let position = analyzeSalientPosition(rect, in: imageSize)
        
        // 计算基础扩展因子（根据显著区域占比）
        let areaRatio = (rect.width * rect.height) / (imageSize.width * imageSize.height)
        let baseExpansionFactor = calculateBaseExpansionFactor(areaRatio: areaRatio)
        
        // 根据位置和目标宽高比计算方向性扩展
        let expansionVector = calculateExpansionVector(
            position: position,
            rect: rect,
            imageSize: imageSize,
            targetRatio: targetRatio,
            baseFactor: baseExpansionFactor
        )
        
        // 应用扩展并确保边界约束
        return applyExpansionWithBounds(
            rect: rect,
            expansionVector: expansionVector,
            imageSize: imageSize
        )
    }
    
    /// 分析显著区域在图片中的位置类型
    private static func analyzeSalientPosition(_ rect: CGRect, in imageSize: CGSize) -> SalientPosition {
        // 图片中心点坐标
        // centerY 未使用，移除
        let rectCenterX = rect.midX
        let rectCenterY = rect.midY
        
        // 定义边界阈值（距离边缘的比例）
        let edgeThreshold: CGFloat = 0.15 // 15%的边缘区域
        // cornerThreshold 未使用，移除
        
        let leftEdge = imageSize.width * edgeThreshold
        let rightEdge = imageSize.width * (1 - edgeThreshold)
        let topEdge = imageSize.height * edgeThreshold
        let bottomEdge = imageSize.height * (1 - edgeThreshold)
        
        // 判断是否在角落
        if (rectCenterX < leftEdge && rectCenterY < topEdge) {
            return .topLeft
        } else if (rectCenterX > rightEdge && rectCenterY < topEdge) {
            return .topRight
        } else if (rectCenterX < leftEdge && rectCenterY > bottomEdge) {
            return .bottomLeft
        } else if (rectCenterX > rightEdge && rectCenterY > bottomEdge) {
            return .bottomRight
        }
        // 判断是否在边缘
        else if rectCenterX < leftEdge {
            return .leftEdge
        } else if rectCenterX > rightEdge {
            return .rightEdge
        } else if rectCenterY < topEdge {
            return .topEdge
        } else if rectCenterY > bottomEdge {
            return .bottomEdge
        }
        // 否则在中心区域
        else {
            return .center
        }
    }
    
    /// 根据显著区域占比计算基础扩展因子
    private static func calculateBaseExpansionFactor(areaRatio: CGFloat) -> CGFloat {
        switch areaRatio {
        case 0.7...1.0:   // 显著区域很大（70%以上）
            return 1.05   // 只需要很少扩展
        case 0.4...0.7:   // 显著区域中等（40%-70%）
            return 1.15   // 适中扩展
        case 0.2...0.4:   // 显著区域较小（20%-40%）
            return 1.3    // 较多扩展
        default:          // 显著区域很小（<20%）
            return 1.5    // 大量扩展以包含更多上下文
        }
    }
    
    /// 计算方向性扩展向量
    private static func calculateExpansionVector(
        position: SalientPosition,
        rect: CGRect,
        imageSize: CGSize,
        targetRatio: CGFloat,
        baseFactor: CGFloat
    ) -> ExpansionVector {
        let currentRatio = rect.width / rect.height
        
        // 根据目标宽高比调整扩展偏好
        let horizontalBias: CGFloat
        let verticalBias: CGFloat
        
        if targetRatio > currentRatio {
            // 需要更宽的区域
            horizontalBias = 1.2
            verticalBias = 0.9
        } else if targetRatio < currentRatio {
            // 需要更高的区域
            horizontalBias = 0.9
            verticalBias = 1.2
        } else {
            // 比例已经合适
            horizontalBias = 1.0
            verticalBias = 1.0
        }
        
        // 根据位置计算方向性扩展
        switch position {
        case .center:
            // 中心位置：均匀向四周扩展
            return ExpansionVector(
                left: baseFactor * horizontalBias,
                right: baseFactor * horizontalBias,
                top: baseFactor * verticalBias,
                bottom: baseFactor * verticalBias
            )
            
        case .leftEdge:
            // 左边缘：主要向右扩展
            return ExpansionVector(
                left: 1.0,
                right: baseFactor * 1.5 * horizontalBias,
                top: baseFactor * verticalBias,
                bottom: baseFactor * verticalBias
            )
            
        case .rightEdge:
            // 右边缘：主要向左扩展
            return ExpansionVector(
                left: baseFactor * 1.5 * horizontalBias,
                right: 1.0,
                top: baseFactor * verticalBias,
                bottom: baseFactor * verticalBias
            )
            
        case .topEdge:
            // 上边缘：主要向下扩展
            return ExpansionVector(
                left: baseFactor * horizontalBias,
                right: baseFactor * horizontalBias,
                top: 1.0,
                bottom: baseFactor * 1.5 * verticalBias
            )
            
        case .bottomEdge:
            // 下边缘：主要向上扩展
            return ExpansionVector(
                left: baseFactor * horizontalBias,
                right: baseFactor * horizontalBias,
                top: baseFactor * 1.5 * verticalBias,
                bottom: 1.0
            )
            
        case .topLeft:
            // 左上角：向右下扩展
            return ExpansionVector(
                left: 1.0,
                right: baseFactor * 1.8 * horizontalBias,
                top: 1.0,
                bottom: baseFactor * 1.8 * verticalBias
            )
            
        case .topRight:
            // 右上角：向左下扩展
            return ExpansionVector(
                left: baseFactor * 1.8 * horizontalBias,
                right: 1.0,
                top: 1.0,
                bottom: baseFactor * 1.8 * verticalBias
            )
            
        case .bottomLeft:
            // 左下角：向右上扩展
            return ExpansionVector(
                left: 1.0,
                right: baseFactor * 1.8 * horizontalBias,
                top: baseFactor * 1.8 * verticalBias,
                bottom: 1.0
            )
            
        case .bottomRight:
            // 右下角：向左上扩展
            return ExpansionVector(
                left: baseFactor * 1.8 * horizontalBias,
                right: 1.0,
                top: baseFactor * 1.8 * verticalBias,
                bottom: 1.0
            )
        }
    }
    
    /// 应用扩展向量并确保边界约束
    private static func applyExpansionWithBounds(
        rect: CGRect,
        expansionVector: ExpansionVector,
        imageSize: CGSize
    ) -> CGRect {
        // 计算扩展后的边界
        let leftExpansion = rect.width * (expansionVector.left - 1) / 2
        let rightExpansion = rect.width * (expansionVector.right - 1) / 2
        let topExpansion = rect.height * (expansionVector.top - 1) / 2
        let bottomExpansion = rect.height * (expansionVector.bottom - 1) / 2
        
        var expandedRect = CGRect(
            x: rect.origin.x - leftExpansion,
            y: rect.origin.y - topExpansion,
            width: rect.width + leftExpansion + rightExpansion,
            height: rect.height + topExpansion + bottomExpansion
        )
        
        // 边界约束和智能调整
        if expandedRect.minX < 0 {
            let overflow = -expandedRect.minX
            expandedRect.origin.x = 0
            expandedRect.size.width = min(expandedRect.width + overflow, imageSize.width)
        }
        
        if expandedRect.minY < 0 {
            let overflow = -expandedRect.minY
            expandedRect.origin.y = 0
            expandedRect.size.height = min(expandedRect.height + overflow, imageSize.height)
        }
        
        if expandedRect.maxX > imageSize.width {
            let overflow = expandedRect.maxX - imageSize.width
            expandedRect.origin.x = max(0, expandedRect.origin.x - overflow)
            expandedRect.size.width = imageSize.width - expandedRect.origin.x
        }
        
        if expandedRect.maxY > imageSize.height {
            let overflow = expandedRect.maxY - imageSize.height
            expandedRect.origin.y = max(0, expandedRect.origin.y - overflow)
            expandedRect.size.height = imageSize.height - expandedRect.origin.y
        }
        
        return expandedRect
    }
    
    /// 根据目标宽高比调整矩形区域
    private static func adjustRectForAspectRatio(
        _ rect: CGRect,
        targetRatio: CGFloat,
        imageSize: CGSize
    ) -> CGRect {
        let currentRatio = rect.width / rect.height
        
        var adjustedRect = rect
        
        if currentRatio > targetRatio {
            // 当前区域太宽，需要减少宽度或增加高度
            let targetWidth = rect.height * targetRatio
            adjustedRect.size.width = targetWidth
            adjustedRect.origin.x = rect.midX - targetWidth / 2
        } else if currentRatio < targetRatio {
            // 当前区域太高，需要减少高度或增加宽度
            let targetHeight = rect.width / targetRatio
            adjustedRect.size.height = targetHeight
            adjustedRect.origin.y = rect.midY - targetHeight / 2
        }
        
        // 确保调整后的区域不超出图片边界
        adjustedRect.origin.x = max(0, min(adjustedRect.origin.x, imageSize.width - adjustedRect.width))
        adjustedRect.origin.y = max(0, min(adjustedRect.origin.y, imageSize.height - adjustedRect.height))
        adjustedRect.size.width = min(adjustedRect.size.width, imageSize.width - adjustedRect.origin.x)
        adjustedRect.size.height = min(adjustedRect.size.height, imageSize.height - adjustedRect.origin.y)
        
        return adjustedRect
    }
}