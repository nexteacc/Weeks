//
//  ImageMetadata.swift
//  Weeks
//
//  Created by Sheng on 7/5/25.
//


import UIKit
import WidgetKit

// 图片元数据结构
struct ImageMetadata: Codable {
    let id: String // UUID 字符串
    let addedDate: Date // 添加时间
    let order: Int // 顺序号
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
    private func getImagesDirectoryURL() -> URL? {
        guard let containerURL = getSharedContainerURL() else { return nil }
        let imagesURL = containerURL.appendingPathComponent("Images", isDirectory: true)
        
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
    
    // 获取元数据文件 URL
    private func getMetadataFileURL() -> URL? {
        guard let containerURL = getSharedContainerURL() else { return nil }
        return containerURL.appendingPathComponent("metadata.json")
    }
    
    // 保存图片
    func saveImage(_ image: UIImage) -> String? {
        // 检查是否达到最大数量限制
        if getImageMetadataList().count >= maxImageCount {
            return nil
        }
        
        // 生成 UUID
        let imageID = UUID().uuidString
        
        // 保存图片文件
        guard let imagesDirectory = getImagesDirectoryURL(),
              let imageData = image.jpegData(compressionQuality: 0.8) else { return nil }
        
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
        var metadataList = getImageMetadataList()
        let newMetadata = ImageMetadata(
            id: imageID,
            addedDate: Date(),
            order: metadataList.count
        )
        metadataList.append(newMetadata)
        
        // 保存更新后的元数据
        guard saveImageMetadataList(metadataList) else {
            print("保存元数据失败")
            return nil
        }
        
        // 延迟刷新Widget，确保文件系统操作完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        
        return imageID
    }
    
    // 批量保存图片
    func saveImages(_ images: [UIImage]) -> [String] {
        var savedIDs: [String] = []
        
        for image in images {
            // 使用内部保存方法，不刷新Widget
            if let id = saveImageWithoutReload(image) {
                savedIDs.append(id)
            }
            
            // 如果达到最大数量限制，停止保存
            if getImageMetadataList().count >= maxImageCount {
                break
            }
        }
        
        // 批量保存完成后，统一刷新Widget
        if !savedIDs.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        
        return savedIDs
    }
    
    // 内部保存方法：不刷新Widget
    private func saveImageWithoutReload(_ image: UIImage) -> String? {
        // 检查是否达到最大数量限制
        if getImageMetadataList().count >= maxImageCount {
            return nil
        }
        
        // 生成 UUID
        let imageID = UUID().uuidString
        
        // 保存图片文件
        guard let imagesDirectory = getImagesDirectoryURL(),
              let imageData = image.jpegData(compressionQuality: 0.8) else { return nil }
        
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
        var metadataList = getImageMetadataList()
        let newMetadata = ImageMetadata(
            id: imageID,
            addedDate: Date(),
            order: metadataList.count
        )
        metadataList.append(newMetadata)
        
        // 保存更新后的元数据
        guard saveImageMetadataList(metadataList) else {
            print("保存元数据失败")
            return nil
        }
        
        return imageID
    }
    
    // 删除图片
    func deleteImage(withID id: String) -> Bool {
        // 删除图片文件
        guard let imagesDirectory = getImagesDirectoryURL() else { return false }
        let imageURL = imagesDirectory.appendingPathComponent("\(id).jpg")
        
        do {
            if FileManager.default.fileExists(atPath: imageURL.path) {
                try FileManager.default.removeItem(at: imageURL)
            }
        } catch {
            print("删除图片失败: \(error)")
            return false
        }
        
        // 更新元数据
        var metadataList = getImageMetadataList()
        metadataList.removeAll { $0.id == id }
        
        // 更新顺序
        for (index, _) in metadataList.enumerated() {
            metadataList[index] = ImageMetadata(
                id: metadataList[index].id,
                addedDate: metadataList[index].addedDate,
                order: index
            )
        }
        
        // 保存更新后的元数据
        _ = saveImageMetadataList(metadataList)
        
        // 延迟刷新Widget，确保文件系统操作完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        
        return true
    }
    
    // 清空所有图片
    func clearAllImages() -> Bool {
        // 删除所有图片文件
        guard let imagesDirectory = getImagesDirectoryURL() else { return false }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: imagesDirectory,
                includingPropertiesForKeys: nil
            )
            
            for fileURL in fileURLs {
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            print("清空图片目录失败: \(error)")
            return false
        }
        
        // 清空元数据
        _ = saveImageMetadataList([])
        
        // 延迟刷新Widget，确保文件系统操作完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        
        return true
    }
    
    // 获取图片
    func getImage(withID id: String) -> UIImage? {
        guard let imagesDirectory = getImagesDirectoryURL() else { return nil }
        let imageURL = imagesDirectory.appendingPathComponent("\(id).jpg")
        
        guard FileManager.default.fileExists(atPath: imageURL.path),
              let imageData = try? Data(contentsOf: imageURL),
              let image = UIImage(data: imageData) else { return nil }
        
        return image
    }
    
    // 获取所有图片元数据
    func getImageMetadataList() -> [ImageMetadata] {
        guard let metadataURL = getMetadataFileURL() else { return [] }
        
        // 如果元数据文件不存在，返回空数组
        if !FileManager.default.fileExists(atPath: metadataURL.path) {
            return []
        }
        
        do {
            let data = try Data(contentsOf: metadataURL)
            let metadataList = try JSONDecoder().decode([ImageMetadata].self, from: data)
            return metadataList
        } catch {
            print("读取元数据失败: \(error)")
            return []
        }
    }
    
    // 保存图片元数据列表
    private func saveImageMetadataList(_ metadataList: [ImageMetadata]) -> Bool {
        guard let metadataURL = getMetadataFileURL() else { return false }
        
        do {
            let data = try JSONEncoder().encode(metadataList)
            try data.write(to: metadataURL)
            return true
        } catch {
            print("保存元数据失败: \(error)")
            return false
        }
    }
    
    // 获取所有图片（按顺序）
    func getAllImages() -> [(metadata: ImageMetadata, image: UIImage)] {
        let metadataList = getImageMetadataList().sorted { $0.order < $1.order }
        var result: [(metadata: ImageMetadata, image: UIImage)] = []
        
        for metadata in metadataList {
            if let image = getImage(withID: metadata.id) {
                result.append((metadata: metadata, image: image))
            }
        }
        
        return result
    }
    
    // 获取图片数量
    func getImageCount() -> Int {
        return getImageMetadataList().count
    }
    
    // 检查是否达到最大数量限制
    func isMaxImageCountReached() -> Bool {
        return getImageCount() >= maxImageCount
    }
}
