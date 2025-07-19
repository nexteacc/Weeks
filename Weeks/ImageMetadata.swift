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
    case medium
    case large
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
    
    // Removed compatibility method for old version of getImagesDirectoryURL()
    
    // Get metadata file URL
    private func getMetadataFileURL(for sizeType: WidgetSizeType) -> URL? {
        guard let containerURL = getSharedContainerURL() else { return nil }
        return containerURL.appendingPathComponent("metadata_\(sizeType.rawValue).json")
    }
    
    // Removed compatibility method for old version of getMetadataFileURL()
    
    // Save image (save independent images for all sizes)
    func saveImage(_ image: UIImage, completion: @escaping (String?) -> Void) {
        let group = DispatchGroup()
        var mediumID: String?
        
        // Save image for medium size
        group.enter()
        saveImageWithoutReload(image, for: .medium) { id in
            mediumID = id
            group.leave()
        }
        
        // Save image for large size
        group.enter()
        saveImageWithoutReload(image, for: .large) { _ in
            group.leave()
        }
        
        // Wait for all save operations to complete
        group.notify(queue: .main) {
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
    
    // Save image for specified size (smart cropping version)
    private func saveImageWithoutReload(
        _ image: UIImage, 
        for sizeType: WidgetSizeType, 
        completion: @escaping (String?) -> Void
    ) {
        // Check if maximum count limit is reached
        if getImageMetadataList(for: sizeType).count >= maxImageCount {
            completion(nil)
            return
        }
        
        // Generate UUID
        let imageID = UUID().uuidString
        
        // Use smart cropping
        SmartImageCropper.smartCrop(image: image, for: sizeType, strategy: .hybrid) { [weak self] croppedImage in
            guard let self = self,
                  let croppedImage = croppedImage,
                  let imageData = croppedImage.jpegData(compressionQuality: 0.8) else {
                completion(nil)
                return
            }
            
            // Get image directory for corresponding size
            guard let imagesDirectory = self.getImagesDirectoryURL(for: sizeType) else {
                completion(nil)
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
                    print("Image file write verification failed")
                    completion(nil)
                    return
                }
                
            } catch {
                print("Failed to save image: \(error)")
                completion(nil)
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
                print("Failed to save metadata")
                completion(nil)
                return
            }
            
            completion(imageID)
        }
    }
    
    // Batch save images
    func saveImages(_ images: [UIImage], completion: @escaping ([String]) -> Void) {
        let group = DispatchGroup()
        var savedIDs: [String] = []
        let lock = NSLock()
        
        for image in images {
            // Check if maximum count limit is reached
            if getImageMetadataList(for: .medium).count >= maxImageCount {
                break
            }
            
            // Save image for medium size
            group.enter()
            saveImageWithoutReload(image, for: .medium) { id in
                if let id = id {
                    lock.lock()
                    savedIDs.append(id)
                    lock.unlock()
                }
                group.leave()
            }
            
            // Simultaneously save image for large size
            group.enter()
            saveImageWithoutReload(image, for: .large) { _ in
                group.leave()
            }
        }
        
        // Wait for all save operations to complete
        group.notify(queue: .main) {
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
    
    // Compatibility method for old version (deprecated)
    @available(*, deprecated, message: "Use async version with completion handler")
    func saveImage(_ image: UIImage) -> String? {
        var result: String?
        let semaphore = DispatchSemaphore(value: 0)
        
        saveImage(image) { id in
            result = id
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    @available(*, deprecated, message: "Use async version with completion handler")
    func saveImages(_ images: [UIImage]) -> [String] {
        var result: [String] = []
        let semaphore = DispatchSemaphore(value: 0)
        
        saveImages(images) { ids in
            result = ids
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    

    

    

    

    

    
    // Clear all images (clear images of all sizes) - atomic operation version
    func clearAllImages() -> Bool {
        // Use operation lock to ensure atomicity
        let operationLock = NSLock()
        operationLock.lock()
        defer { operationLock.unlock() }
        
        // 1. Get all image IDs
        let mediumList = getImageMetadataList(for: .medium)
        let largeList = getImageMetadataList(for: .large)
        
        if mediumList.isEmpty && largeList.isEmpty {
            print("Clear operation: No images to delete")
            return true
        }
        
        // 2. Atomically clear metadata
        var success = true
        success = success && saveImageMetadataList([], for: .medium)
        success = success && saveImageMetadataList([], for: .large)
        
        if !success {
            print("Clear failed: Metadata clearing failed")
            return false
        }
        
        // 3. Delete all image files
        success = success && clearAllImageFiles(for: .medium)
        success = success && clearAllImageFiles(for: .large)
        
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
    
    // Get image by ID (default gets medium size)
    func getImage(withID id: String) -> UIImage? {
        return getImage(withID: id, for: .medium)
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
        return getImageMetadataList(for: .medium)
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
        return saveImageMetadataList(metadataList, for: .medium)
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
    
    // Get all images (in order, default gets medium size)
    func getAllImages() -> [(metadata: ImageMetadata, image: UIImage)] {
        return getAllImages(for: .medium)
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
