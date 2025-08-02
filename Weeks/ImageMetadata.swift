//
//  ImageMetadata.swift
//  Weeks
//
//  Created by Sheng on 7/5/25.
//


import Foundation
import UIKit
import WidgetKit

// Widget size type enumeration
enum WidgetSizeType: String, Codable {
    case large

    // 兼容旧版本：如遇到未知值（如 medium）时回退到 large
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? WidgetSizeType.large.rawValue
        self = WidgetSizeType(rawValue: raw) ?? .large
    }
}

// Image metadata structure
struct ImageMetadata: Codable {
    let id: String // UUID string
    let addedDate: Date // Date added
    let order: Int // Order number
    let sizeType: WidgetSizeType // Widget size type
}

// Image manager
class ImageManager {
    // Singleton pattern
    static let shared = ImageManager()
    
    // App Group identifier
    private let appGroupIdentifier = "group.com.nextbigtoy.weeks"
    
    // Maximum image count limit
    private let maxImageCount = 30
    
    // Private initialization method
    private init() {}
    
    // Get shared container URL
    private func getSharedContainerURL() -> URL? {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }
    
    // Get original images directory URL (in app's Documents directory)
    private func getOriginalImagesDirectoryURL() -> URL? {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let imagesURL = documentsDirectory.appendingPathComponent("OriginalImages", isDirectory: true)
        
        // Ensure directory exists
        if !fileManager.fileExists(atPath: imagesURL.path) {
            do {
                try fileManager.createDirectory(at: imagesURL, withIntermediateDirectories: true)
            } catch {
                print("Failed to create original image directory: \(error)")
                return nil
            }
        }
        
        return imagesURL
    }
    
    // Get image storage directory
    private func getImagesDirectoryURL(for sizeType: WidgetSizeType) -> URL? {
        guard let containerURL = getSharedContainerURL() else { return nil }
        let imagesURL = containerURL.appendingPathComponent("Images/\(sizeType.rawValue)", isDirectory: true)
        
        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: imagesURL.path) {
            do {
                try FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)
            } catch {
                print("Failed to create image directory: \(error)")
                return nil
            }
        }
        
        return imagesURL
    }
    

    // Get metadata file URL
    private func getMetadataFileURL(for sizeType: WidgetSizeType) -> URL? {
        guard let containerURL = getSharedContainerURL() else { return nil }
        return containerURL.appendingPathComponent("metadata_\(sizeType.rawValue).json")
    }
    
    // Save image (save independent images for all sizes)
    func saveImage(_ image: UIImage, completion: @escaping (String?) -> Void) {
        // 使用主队列确保线程安全
        DispatchQueue.main.async {
            let group = DispatchGroup()
            var mediumID: String?
            
            // 添加超时保护
            let timeoutSeconds = 15.0 // 15秒超时
            var hasCompleted = false
            let timeoutWorkItem = DispatchWorkItem {
                if !hasCompleted {
                    print("单张图片保存超时")
                    hasCompleted = true
                    completion(mediumID) // 返回已保存的图片ID（如果有）
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds, execute: timeoutWorkItem)
            
            // Save image (large size only)
            group.enter()
            self.saveImageWithoutReload(image, for: .large) { id in
                mediumID = id // 返回 large 尺寸 ID
                group.leave()
            }
            
            // Wait for all save operations to complete
            group.notify(queue: .main) {
                // 取消超时任务
                timeoutWorkItem.cancel()
                
                // 标记完成
                if !hasCompleted {
                    hasCompleted = true
                    
                    // Delay widget refresh to ensure file system operations are complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        WidgetCenter.shared.reloadAllTimelines()
                        
                        // Add secondary refresh mechanism to ensure Widget updates correctly
                        // Especially for large size Widgets
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            WidgetCenter.shared.reloadAllTimelines()
                        }
                    }
                    
                    // Return medium size image ID (consistent with original logic)
                    completion(mediumID)
                }
            }
        }
    }
    
    // Save original image (before cropping)
    private func saveOriginalImage(_ image: UIImage, withID imageID: String) {
        guard let originalImagesDirectory = getOriginalImagesDirectoryURL(),
              let imageData = image.jpegData(compressionQuality: 0.9) else {
            print("保存原始图片失败：无法获取目录或转换图片数据")
            return
        }
        
        let imageURL = originalImagesDirectory.appendingPathComponent("\(imageID).jpg")
        
        do {
            try imageData.write(to: imageURL)
            print("原始图片保存成功，ID：\(imageID)")
        } catch {
            print("保存原始图片文件失败：\(error)，ID：\(imageID)")
        }
    }
    
    // Save image for specified size (smart cropping version)
    private func saveImageWithoutReload(
        _ image: UIImage, 
        for sizeType: WidgetSizeType, 
        completion: @escaping (String?) -> Void
    ) {
        // 添加方法级别的超时保护
        var hasCompleted = false
        let timeoutSeconds = 10.0 // 10秒超时
        
        // 创建安全回调函数，确保只调用一次
        let safeCompletion: (String?) -> Void = { result in
            DispatchQueue.main.async {
                if !hasCompleted {
                    hasCompleted = true
                    completion(result)
                }
            }
        }
        
        // 设置超时
        DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds) {
            if !hasCompleted {
                print("单张图片裁剪保存超时，尺寸：\(sizeType.rawValue)")
                safeCompletion(nil)
            }
        }
        
        // Check if maximum count limit is reached
        if getImageMetadataList(for: sizeType).count >= maxImageCount {
            // Important: Always call completion handler
            print("已达到最大图片数量限制：\(maxImageCount)，尺寸：\(sizeType.rawValue)")
            safeCompletion(nil)
            return
        }
        
        // Generate UUID
        let imageID = UUID().uuidString
        print("开始处理图片，ID：\(imageID)，尺寸：\(sizeType.rawValue)")
        
        // 保存原始图片（在裁剪前）
        saveOriginalImage(image, withID: imageID)
        
        // Use smart cropping
        SmartImageCropper.smartCrop(image: image, for: sizeType, strategy: .hybrid) { [weak self] croppedImage in
            // 检查是否已经完成（可能是由于超时）
            if hasCompleted {
                print("智能裁剪回调返回，但已超时完成，ID：\(imageID)，尺寸：\(sizeType.rawValue)")
                return
            }
            
            guard let self = self else {
                // Handle case where self is nil
                print("self 为 nil，ID：\(imageID)，尺寸：\(sizeType.rawValue)")
                safeCompletion(nil)
                return
            }
            
            // Check if we have a valid cropped image
            guard let croppedImage = croppedImage,
                  let imageData = croppedImage.jpegData(compressionQuality: 0.8) else {
                print("裁剪图片失败或压缩失败，ID：\(imageID)，尺寸：\(sizeType.rawValue)")
                safeCompletion(nil)
                return
            }
            
            // Get image directory for corresponding size
            guard let imagesDirectory = self.getImagesDirectoryURL(for: sizeType) else {
                print("获取图片目录失败，ID：\(imageID)，尺寸：\(sizeType.rawValue)")
                safeCompletion(nil)
                return
            }
            
            let imageURL = imagesDirectory.appendingPathComponent("\(imageID).jpg")
            
            do {
                try imageData.write(to: imageURL)
                
                // Verify file integrity: ensure file exists and size is correct
                guard FileManager.default.fileExists(atPath: imageURL.path),
                      let fileAttributes = try? FileManager.default.attributesOfItem(atPath: imageURL.path),
                      let fileSize = fileAttributes[.size] as? Int64,
                      fileSize == imageData.count else {
                    print("图片文件完整性验证失败，ID：\(imageID)，尺寸：\(sizeType.rawValue)")
                    safeCompletion(nil)
                    return
                }
                
            } catch {
                print("保存图片文件失败：\(error)，ID：\(imageID)，尺寸：\(sizeType.rawValue)")
                safeCompletion(nil)
                return
            }
            
            // Update metadata
            var metadataList = self.getImageMetadataList(for: sizeType)
            let newMetadata = ImageMetadata(
                id: imageID,
                addedDate: Date(),
                order: metadataList.count,
                sizeType: sizeType
            )
            metadataList.append(newMetadata)
            
            // Save updated metadata
            guard self.saveImageMetadataList(metadataList, for: sizeType) else {
                print("保存元数据失败，ID：\(imageID)，尺寸：\(sizeType.rawValue)")
                safeCompletion(nil)
                return
            }
            
            print("图片处理完成，ID：\(imageID)，尺寸：\(sizeType.rawValue)")
            safeCompletion(imageID)
        }
    }
    
    // Batch save images
    func saveImages(_ images: [UIImage], completion: @escaping ([String]) -> Void) {
        // 使用主队列确保线程安全
        DispatchQueue.main.async {
            let group = DispatchGroup()
            var savedIDs: [String] = []
            let lock = NSLock()
            
            // Check if there are any images to process
            if images.isEmpty {
                completion([])
                return
            }
            
            // Track how many images we can actually save
            let availableSlots = self.maxImageCount - self.getImageMetadataList(for: .large).count
            let imagesToProcess = availableSlots > 0 ? Array(images.prefix(availableSlots)) : []
            
            // If we can't save any images, return immediately
            if imagesToProcess.isEmpty {
                completion([])
                return
            }
            
            // 添加全局超时保护
            let timeoutSeconds = 30.0 // 30秒超时
            var hasCompleted = false
            let timeoutWorkItem = DispatchWorkItem {
                if !hasCompleted {
                    print("批量保存图片超时")
                    hasCompleted = true
                    completion(savedIDs) // 返回已保存的图片ID
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds, execute: timeoutWorkItem)
            
            for image in imagesToProcess {
                // Save image (large size only)
                group.enter()
                self.saveImageWithoutReload(image, for: .large) { id in
                    if let id = id {
                        lock.lock()
                        savedIDs.append(id)
                        lock.unlock()
                    }
                    group.leave()
                }
            }
            
            // Wait for all save operations to complete
            group.notify(queue: .main) {
                // 取消超时任务
                timeoutWorkItem.cancel()
                
                // 标记完成
                if !hasCompleted {
                    hasCompleted = true
                    
                    // Refresh Widget after batch save is complete
                    if !savedIDs.isEmpty {
                        // Use longer delay time
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            WidgetCenter.shared.reloadAllTimelines()
                            
                            // Add secondary refresh mechanism to ensure Widget updates correctly
                            // Especially for large size Widgets
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                WidgetCenter.shared.reloadAllTimelines()
                            }
                        }
                    }
                    
                    completion(savedIDs)
                }
            }
        }
    }
    
    // 已移除弃用的同步版本函数，请使用带有完成处理程序的异步版本
    

    

    

    

    

    
    // Clear all original image files
    private func clearAllOriginalImageFiles() -> Bool {
        guard let imagesDirectory = getOriginalImagesDirectoryURL() else { return false }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: imagesDirectory, includingPropertiesForKeys: nil)
            for fileURL in fileURLs {
                if fileURL.pathExtension.lowercased() == "jpg" {
                    try FileManager.default.removeItem(at: fileURL)
                }
            }
            print("Successfully cleared all original image files")
            return true
        } catch {
            print("Failed to clear original image files: \(error)")
            return false
        }
    }
    
    // Clear all images (clear images of all sizes) - atomic operation version
    func clearAllImages() -> Bool {
        // Use operation lock to ensure atomicity
        let operationLock = NSLock()
        operationLock.lock()
        defer { operationLock.unlock() }
        
        // 1. Get all image IDs
        let mediumList = getImageMetadataList(for: .large)
        let largeList = getImageMetadataList(for: .large)
        
        if mediumList.isEmpty && largeList.isEmpty {
            print("Clear operation: No images to delete")
            return true
        }
        
        // 2. Atomically clear metadata
        var success = true
        success = success && saveImageMetadataList([], for: .large)
        success = success && saveImageMetadataList([], for: .large)
        
        if !success {
            print("Clear failed: Metadata clearing failed")
            return false
        }
        
        // 3. Delete all image files
        success = success && clearAllImageFiles(for: .large)
        success = success && clearAllImageFiles(for: .large)
        success = success && clearAllOriginalImageFiles() // 添加清理原始图片
        
        if !success {
            print("Clear failed: Image file deletion failed")
            return false
        }
        
        // 4. Delay Widget refresh to ensure file system operations are complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        
        return true
    }
    
    // Clear all image files for specified size
    private func clearAllImageFiles(for sizeType: WidgetSizeType) -> Bool {
        guard let imagesDirectory = getImagesDirectoryURL(for: sizeType) else { return false }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: imagesDirectory, includingPropertiesForKeys: nil)
            for fileURL in fileURLs {
                if fileURL.pathExtension.lowercased() == "jpg" {
                    try FileManager.default.removeItem(at: fileURL)
                }
            }
            print("Successfully cleared all image files: size \(sizeType.rawValue)")
            return true
        } catch {
            print("Failed to clear image files: \(error)")
            return false
        }
    }
    
    // Removed unused clearAllImagesWithoutReload method
    
    // Get original image by ID
    func getOriginalImage(withID id: String) -> UIImage? {
        guard let originalImagesDirectory = getOriginalImagesDirectoryURL() else {
            print("无法获取原始图片目录，ID：\(id)")
            return nil // 直接返回nil，不回退
        }
        
        let imageURL = originalImagesDirectory.appendingPathComponent("\(id).jpg")
        
        guard FileManager.default.fileExists(atPath: imageURL.path),
              let imageData = try? Data(contentsOf: imageURL),
              let image = UIImage(data: imageData) else {
            print("原始图片不存在或已损坏，ID：\(id)")
            return nil // 直接返回nil，不回退
        }
        
        return image
    }
    
    // Get image by ID (default gets medium size)
    func getImage(withID id: String) -> UIImage? {
        return getImage(withID: id, for: .large)
    }
    
    // Get image by ID and size type
    func getImage(withID id: String, for sizeType: WidgetSizeType) -> UIImage? {
        guard let imagesDirectory = getImagesDirectoryURL(for: sizeType) else { return nil }
        let imageURL = imagesDirectory.appendingPathComponent("\(id).jpg")
        
        guard FileManager.default.fileExists(atPath: imageURL.path),
              let imageData = try? Data(contentsOf: imageURL),
              let image = UIImage(data: imageData) else { return nil }
        
        return image
    }
    
    // Get metadata list (default gets medium size)
    func getImageMetadataList() -> [ImageMetadata] {
        return getImageMetadataList(for: .large)
    }
    
    // Get metadata list for specified size
    func getImageMetadataList(for sizeType: WidgetSizeType) -> [ImageMetadata] {
        guard let metadataFileURL = getMetadataFileURL(for: sizeType) else { return [] }
        
        // If metadata file doesn't exist, return empty array
        if !FileManager.default.fileExists(atPath: metadataFileURL.path) {
            return []
        }
        
        do {
            // Read metadata file
            let data = try Data(contentsOf: metadataFileURL)
            
            // Decode JSON data
            let decoder = JSONDecoder()
            let metadataList = try decoder.decode([ImageMetadata].self, from: data)
            
            // Sort by order
            return metadataList.sorted { $0.order < $1.order }
        } catch {
            print("Failed to read metadata: \(error)")
            return []
        }
    }
    
    // Save metadata list (default saves medium size)
    func saveImageMetadataList(_ metadataList: [ImageMetadata]) -> Bool {
        return saveImageMetadataList(metadataList, for: .large)
    }
    
    // Save metadata list for specified size
    func saveImageMetadataList(_ metadataList: [ImageMetadata], for sizeType: WidgetSizeType) -> Bool {
        guard let metadataFileURL = getMetadataFileURL(for: sizeType) else { return false }
        
        do {
            // Encode to JSON data
            let encoder = JSONEncoder()
            let data = try encoder.encode(metadataList)
            
            // Write to metadata file
            try data.write(to: metadataFileURL)
            return true
        } catch {
            print("Failed to save metadata: \(error)")
            return false
        }
    }
    
    // Get all original images (in order)
    func getAllOriginalImages() -> [(metadata: ImageMetadata, image: UIImage)] {
        let metadataList = getImageMetadataList(for: .large).sorted { $0.order < $1.order }
        var result: [(metadata: ImageMetadata, image: UIImage)] = []
        
        for metadata in metadataList {
            if let image = getOriginalImage(withID: metadata.id) {
                result.append((metadata: metadata, image: image))
            }
            // 不回退到裁剪版本，如果原始图片不存在则跳过
        }
        
        return result
    }
    
    // Get all images (in order, default gets medium size)
    func getAllImages() -> [(metadata: ImageMetadata, image: UIImage)] {
        return getAllImages(for: .large)
    }
    
    // Get all images for specified size (in order)
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
    
    // Get image count (default gets medium size)
    func getImageCount() -> Int {
        return getImageMetadataList().count
    }
    
    // Get image count for specified size
    func getImageCount(for sizeType: WidgetSizeType) -> Int {
        return getImageMetadataList(for: sizeType).count
    }
    
    // Check if maximum count limit is reached (default checks medium size)
    func isMaxImageCountReached() -> Bool {
        return getImageCount() >= maxImageCount
    }
    
    // Check if maximum count limit is reached for specified size
    func isMaxImageCountReached(for sizeType: WidgetSizeType) -> Bool {
        return getImageCount(for: sizeType) >= maxImageCount
    }
}
