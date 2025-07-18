//
//  ImageMetadata.swift
//  Weeks
//
//  Created by Sheng on 7/5/25.
//


import Foundation
import UIKit
import WidgetKit

// Widget 尺寸类型枚举
enum WidgetSizeType: String, Codable {
    case medium
    case large
}

// 图片元数据结构
struct ImageMetadata: Codable {
    let id: String // UUID 字符串
    let addedDate: Date // 添加时间
    let order: Int // 顺序号
    let sizeType: WidgetSizeType // Widget 尺寸类型
}

// 图片管理器
class ImageManager {
    // 单例模式
    static let shared = ImageManager()
    
    // App Group 标识符
    private let appGroupIdentifier = "group.com.nextbigtoy.weeks"
    
    // 最大图片数量限制
    private let maxImageCount = 30
    
    // 私有初始化方法
    private init() {}
    
    // 获取共享容器 URL
    private func getSharedContainerURL() -> URL? {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }
    
    // 获取图片存储目录
    private func getImagesDirectoryURL(for sizeType: WidgetSizeType) -> URL? {
        guard let containerURL = getSharedContainerURL() else { return nil }
        let imagesURL = containerURL.appendingPathComponent("Images/\(sizeType.rawValue)", isDirectory: true)
        
        // 确保目录存在
        if !FileManager.default.fileExists(atPath: imagesURL.path) {
            do {
                try FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)
            } catch {
                print("创建图片目录失败: \(error)")
                return nil
            }
        }
        
        return imagesURL
    }
    
    // 已删除兼容旧版本的getImagesDirectoryURL()方法
    
    // 获取元数据文件 URL
    private func getMetadataFileURL(for sizeType: WidgetSizeType) -> URL? {
        guard let containerURL = getSharedContainerURL() else { return nil }
        return containerURL.appendingPathComponent("metadata_\(sizeType.rawValue).json")
    }
    
    // 已删除兼容旧版本的getMetadataFileURL()方法
    
    // 保存图片（为所有尺寸保存独立图片）
    func saveImage(_ image: UIImage) -> String? {
        // 为 medium 尺寸保存图片
        let mediumID = saveImageWithoutReload(image, for: .medium)
        
        // 为 large 尺寸保存图片
        _ = saveImageWithoutReload(image, for: .large)
        
        // 延迟刷新Widget，确保文件系统操作完成
        // 使用更长的延迟时间
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            WidgetCenter.shared.reloadAllTimelines()
            
            // 添加二次刷新机制，确保 Widget 能够正确更新
            // 特别是对于 large 尺寸的 Widget
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        
        // 返回 medium 尺寸的图片 ID（与原有逻辑保持一致）
        return mediumID
    }
    
    // 为指定尺寸保存图片
    private func saveImageWithoutReload(_ image: UIImage, for sizeType: WidgetSizeType) -> String? {
        // 检查是否达到最大数量限制
        if getImageMetadataList(for: sizeType).count >= maxImageCount {
            return nil
        }
        
        // 生成 UUID
        let imageID = UUID().uuidString
        
        // 根据尺寸类型裁剪图片
        let croppedImage = ImageCropper.cropCenter(of: image, for: sizeType)
        guard let croppedImage = croppedImage,
              let imageData = croppedImage.jpegData(compressionQuality: 0.8) else { return nil }
        
        // 获取对应尺寸的图片目录
        guard let imagesDirectory = getImagesDirectoryURL(for: sizeType) else { return nil }
        let imageURL = imagesDirectory.appendingPathComponent("\(imageID).jpg")
        
        do {
            try imageData.write(to: imageURL)
            
            // 验证文件完整性：确保文件存在且大小正确
            guard FileManager.default.fileExists(atPath: imageURL.path),
                  let fileAttributes = try? FileManager.default.attributesOfItem(atPath: imageURL.path),
                  let fileSize = fileAttributes[.size] as? Int64,
                  fileSize == imageData.count else {
                print("图片文件写入验证失败")
                return nil
            }
            
        } catch {
            print("保存图片失败: \(error)")
            return nil
        }
        
        // 更新元数据
        var metadataList = getImageMetadataList(for: sizeType)
        let newMetadata = ImageMetadata(
            id: imageID,
            addedDate: Date(),
            order: metadataList.count,
            sizeType: sizeType
        )
        metadataList.append(newMetadata)
        
        // 保存更新后的元数据
        guard saveImageMetadataList(metadataList, for: sizeType) else {
            print("保存元数据失败")
            return nil
        }
        
        return imageID
    }
    
    // 批量保存图片
    func saveImages(_ images: [UIImage]) -> [String] {
        var savedIDs: [String] = []
        
        for image in images {
            // 为 medium 尺寸保存图片
            if let id = saveImageWithoutReload(image, for: .medium) {
                savedIDs.append(id)
                
                // 同时为 large 尺寸保存图片
                _ = saveImageWithoutReload(image, for: .large)
            }
            
            // 如果达到最大数量限制，停止保存
            if getImageMetadataList(for: .medium).count >= maxImageCount {
                break
            }
        }
        
        // 批量保存完成后，统一刷新Widget
        if !savedIDs.isEmpty {
            // 使用更长的延迟时间
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                WidgetCenter.shared.reloadAllTimelines()
                
                // 添加二次刷新机制，确保 Widget 能够正确更新
                // 特别是对于 large 尺寸的 Widget
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
        }
        
        return savedIDs
    }
    
    // 已删除兼容旧版本的saveImageWithoutReload方法
    

    

    

    

    

    
    // 清空所有图片（清空所有尺寸的图片）- 原子性操作版本
    func clearAllImages() -> Bool {
        // 使用操作锁确保原子性
        let operationLock = NSLock()
        operationLock.lock()
        defer { operationLock.unlock() }
        
        // 1. 获取所有图片ID
        let mediumList = getImageMetadataList(for: .medium)
        let largeList = getImageMetadataList(for: .large)
        
        if mediumList.isEmpty && largeList.isEmpty {
            print("清空操作: 没有图片需要删除")
            return true
        }
        
        // 2. 原子性清空元数据
        var success = true
        success = success && saveImageMetadataList([], for: .medium)
        success = success && saveImageMetadataList([], for: .large)
        
        if !success {
            print("清空失败: 元数据清空失败")
            return false
        }
        
        // 3. 删除所有图片文件
        success = success && clearAllImageFiles(for: .medium)
        success = success && clearAllImageFiles(for: .large)
        
        if !success {
            print("清空失败: 图片文件删除失败")
            return false
        }
        
        // 4. 延迟刷新Widget，确保文件系统操作完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        
        return true
    }
    
    // 清空指定尺寸的所有图片文件
    private func clearAllImageFiles(for sizeType: WidgetSizeType) -> Bool {
        guard let imagesDirectory = getImagesDirectoryURL(for: sizeType) else { return false }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: imagesDirectory, includingPropertiesForKeys: nil)
            for fileURL in fileURLs {
                if fileURL.pathExtension.lowercased() == "jpg" {
                    try FileManager.default.removeItem(at: fileURL)
                }
            }
            print("成功清空所有图片文件: 尺寸 \(sizeType.rawValue)")
            return true
        } catch {
            print("清空图片文件失败: \(error)")
            return false
        }
    }
    
    // 此处移除了未使用的clearAllImagesWithoutReload方法
    
    // 根据ID获取图片（默认获取 medium 尺寸）
    func getImage(withID id: String) -> UIImage? {
        return getImage(withID: id, for: .medium)
    }
    
    // 根据ID和尺寸类型获取图片
    func getImage(withID id: String, for sizeType: WidgetSizeType) -> UIImage? {
        guard let imagesDirectory = getImagesDirectoryURL(for: sizeType) else { return nil }
        let imageURL = imagesDirectory.appendingPathComponent("\(id).jpg")
        
        guard FileManager.default.fileExists(atPath: imageURL.path),
              let imageData = try? Data(contentsOf: imageURL),
              let image = UIImage(data: imageData) else { return nil }
        
        return image
    }
    
    // 获取元数据列表（默认获取 medium 尺寸）
    func getImageMetadataList() -> [ImageMetadata] {
        return getImageMetadataList(for: .medium)
    }
    
    // 获取指定尺寸的元数据列表
    func getImageMetadataList(for sizeType: WidgetSizeType) -> [ImageMetadata] {
        guard let metadataFileURL = getMetadataFileURL(for: sizeType) else { return [] }
        
        // 如果元数据文件不存在，返回空数组
        if !FileManager.default.fileExists(atPath: metadataFileURL.path) {
            return []
        }
        
        do {
            // 读取元数据文件
            let data = try Data(contentsOf: metadataFileURL)
            
            // 解码JSON数据
            let decoder = JSONDecoder()
            let metadataList = try decoder.decode([ImageMetadata].self, from: data)
            
            // 按顺序排序
            return metadataList.sorted { $0.order < $1.order }
        } catch {
            print("读取元数据失败: \(error)")
            return []
        }
    }
    
    // 保存元数据列表（默认保存 medium 尺寸）
    func saveImageMetadataList(_ metadataList: [ImageMetadata]) -> Bool {
        return saveImageMetadataList(metadataList, for: .medium)
    }
    
    // 保存指定尺寸的元数据列表
    func saveImageMetadataList(_ metadataList: [ImageMetadata], for sizeType: WidgetSizeType) -> Bool {
        guard let metadataFileURL = getMetadataFileURL(for: sizeType) else { return false }
        
        do {
            // 编码为JSON数据
            let encoder = JSONEncoder()
            let data = try encoder.encode(metadataList)
            
            // 写入元数据文件
            try data.write(to: metadataFileURL)
            return true
        } catch {
            print("保存元数据失败: \(error)")
            return false
        }
    }
    
    // 获取所有图片（按顺序，默认获取 medium 尺寸）
    func getAllImages() -> [(metadata: ImageMetadata, image: UIImage)] {
        return getAllImages(for: .medium)
    }
    
    // 获取指定尺寸的所有图片（按顺序）
    func getAllImages(for sizeType: WidgetSizeType) -> [(metadata: ImageMetadata, image: UIImage)] {
        let metadataList = getImageMetadataList(for: sizeType).sorted { $0.order < $1.order }
        var result: [(metadata: ImageMetadata, image: UIImage)] = []
        
        for metadata in metadataList {
            if let image = getImage(withID: metadata.id, for: sizeType) {
                result.append((metadata: metadata, image: image))
            }
        }
        
        return result
    }
    
    // 获取图片数量（默认获取 medium 尺寸）
    func getImageCount() -> Int {
        return getImageMetadataList().count
    }
    
    // 获取指定尺寸的图片数量
    func getImageCount(for sizeType: WidgetSizeType) -> Int {
        return getImageMetadataList(for: sizeType).count
    }
    
    // 检查是否达到最大数量限制（默认检查 medium 尺寸）
    func isMaxImageCountReached() -> Bool {
        return getImageCount() >= maxImageCount
    }
    
    // 检查指定尺寸是否达到最大数量限制
    func isMaxImageCountReached(for sizeType: WidgetSizeType) -> Bool {
        return getImageCount(for: sizeType) >= maxImageCount
    }
}
