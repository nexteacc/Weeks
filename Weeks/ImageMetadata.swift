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

    // Compatibility: fallback to large for unknown values (e.g. deprecated medium)
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
    
    // App Group identifier - must match the ID in entitlements file
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
    
    // Save image (only saves large size for Widget)
    func saveImage(_ image: UIImage, completion: @escaping (String?) -> Void) {
        // Use main queue to ensure thread safety
        DispatchQueue.main.async {
            let group = DispatchGroup()
            var largeID: String?
            
            // Add timeout protection
            let timeoutSeconds = 15.0 // 15 seconds timeout
            var hasCompleted = false
            let timeoutWorkItem = DispatchWorkItem {
                if !hasCompleted {
                    print("Single image save timeout")
                    hasCompleted = true
                    completion(largeID) // Return saved image ID if any
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds, execute: timeoutWorkItem)
            
            // Save image (large size only)
            group.enter()
            self.saveImageWithoutReload(image, for: .large) { id in
                largeID = id // Return large size ID
                group.leave()
            }
            
            // Wait for all save operations to complete
            group.notify(queue: .main) {
                // Cancel timeout task
                timeoutWorkItem.cancel()
                
                // Mark as completed
                if !hasCompleted {
                    hasCompleted = true
                    
                    // Delay widget refresh to ensure file system operations are complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        WidgetCenter.shared.reloadAllTimelines()
                        
                        // Add secondary refresh mechanism to ensure Widget updates correctly
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            WidgetCenter.shared.reloadAllTimelines()
                        }
                    }
                    
                    // Return large size image ID
                    completion(largeID)
                }
            }
        }
    }
    
    // Save original image (before cropping)
    private func saveOriginalImage(_ image: UIImage, withID imageID: String) {
        guard let originalImagesDirectory = getOriginalImagesDirectoryURL(),
              let imageData = image.jpegData(compressionQuality: 0.9) else {
            print("Failed to save original image: unable to get directory or convert image data")
            return
        }
        
        let imageURL = originalImagesDirectory.appendingPathComponent("\(imageID).jpg")
        
        do {
            try imageData.write(to: imageURL)
            print("Original image saved successfully, ID: \(imageID)")
        } catch {
            print("Failed to save original image file: \(error), ID: \(imageID)")
        }
    }
    
    // Save image for specified size (smart cropping version)
    private func saveImageWithoutReload(
        _ image: UIImage, 
        for sizeType: WidgetSizeType, 
        completion: @escaping (String?) -> Void
    ) {
        // Add method-level timeout protection
        var hasCompleted = false
        let timeoutSeconds = 10.0 // 10 seconds timeout
        
        // Create safe completion function to ensure single call
        let safeCompletion: (String?) -> Void = { result in
            DispatchQueue.main.async {
                if !hasCompleted {
                    hasCompleted = true
                    completion(result)
                }
            }
        }
        
        // Set timeout
        DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds) {
            if !hasCompleted {
                print("Single image cropping save timeout, size: \(sizeType.rawValue)")
                safeCompletion(nil)
            }
        }
        
        // Check if maximum count limit is reached
        if getImageMetadataList(for: sizeType).count >= maxImageCount {
            // Important: Always call completion handler
            print("Maximum image count limit reached: \(maxImageCount), size: \(sizeType.rawValue)")
            safeCompletion(nil)
            return
        }
        
        // Generate UUID
        let imageID = UUID().uuidString
        print("Starting image processing, ID: \(imageID), size: \(sizeType.rawValue)")
        
        // Save original image (before cropping)
        saveOriginalImage(image, withID: imageID)
        
        // Use smart cropping
        SmartImageCropper.smartCrop(image: image, for: sizeType, strategy: .hybrid) { [weak self] croppedImage in
            // Check if already completed (possibly due to timeout)
            if hasCompleted {
                #if DEBUG
                print("Smart cropping callback returned but already timed out, ID: \(imageID), size: \(sizeType.rawValue)")
                #endif
                return
            }
            
            guard let self = self else {
                // Handle case where self is nil
                #if DEBUG
                print("Self is nil, ID: \(imageID), size: \(sizeType.rawValue)")
                #endif
                safeCompletion(nil)
                return
            }
            
            // Check if we have a valid cropped image
            guard let croppedImage = croppedImage,
                  let imageData = croppedImage.jpegData(compressionQuality: 0.8) else {
                print("Image cropping failed or compression failed, ID: \(imageID), size: \(sizeType.rawValue)")
                safeCompletion(nil)
                return
            }
            
            // Get image directory for corresponding size
            guard let imagesDirectory = self.getImagesDirectoryURL(for: sizeType) else {
                print("Failed to get image directory, ID: \(imageID), size: \(sizeType.rawValue)")
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
                    print("Image file integrity verification failed, ID: \(imageID), size: \(sizeType.rawValue)")
                    safeCompletion(nil)
                    return
                }
                
            } catch {
                print("Failed to save image file: \(error), ID: \(imageID), size: \(sizeType.rawValue)")
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
                print("Failed to save metadata, ID: \(imageID), size: \(sizeType.rawValue)")
                safeCompletion(nil)
                return
            }
            
            print("Image processing completed, ID: \(imageID), size: \(sizeType.rawValue)")
            safeCompletion(imageID)
        }
    }
    
    // Batch save images
    func saveImages(_ images: [UIImage], completion: @escaping ([String]) -> Void) {
        // Use main queue to ensure thread safety
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
            
            // Add global timeout protection
            let timeoutSeconds = 30.0 // 30 seconds timeout
            var hasCompleted = false
            let timeoutWorkItem = DispatchWorkItem {
                if !hasCompleted {
                    print("Batch image save timeout")
                    hasCompleted = true
                    completion(savedIDs) // Return saved image IDs
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
                // Cancel timeout task
                timeoutWorkItem.cancel()
                
                // Mark as completed
                if !hasCompleted {
                    hasCompleted = true
                    
                    // Refresh Widget after batch save is complete
                    if !savedIDs.isEmpty {
                        // Use longer delay time
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            WidgetCenter.shared.reloadAllTimelines()
                            
                            // Add secondary refresh mechanism to ensure Widget updates correctly
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
    
    // Delete single image by ID
    func deleteImage(withID imageID: String) -> Bool {
        // Use operation lock to ensure atomicity
        let operationLock = NSLock()
        operationLock.lock()
        defer { operationLock.unlock() }
        
        // 1. Get current metadata list
        var metadataList = getImageMetadataList(for: .large)
        
        // 2. Find and remove the target image metadata
        guard let index = metadataList.firstIndex(where: { $0.id == imageID }) else {
            print("Delete failed: Image with ID \(imageID) not found in metadata")
            return false
        }
        
        metadataList.remove(at: index)
        
        // 3. Update metadata file
        guard saveImageMetadataList(metadataList, for: .large) else {
            print("Delete failed: Could not update metadata")
            return false
        }
        
        // 4. Delete image files
        var success = true
        
        // Delete cropped image file
        if let imagesDirectory = getImagesDirectoryURL(for: .large) {
            let imageURL = imagesDirectory.appendingPathComponent("\(imageID).jpg")
            if FileManager.default.fileExists(atPath: imageURL.path) {
                do {
                    try FileManager.default.removeItem(at: imageURL)
                    print("Successfully deleted cropped image file: \(imageID)")
                } catch {
                    print("Failed to delete cropped image file: \(error)")
                    success = false
                }
            }
        }
        
        // Delete original image file
        if let originalImagesDirectory = getOriginalImagesDirectoryURL() {
            let originalImageURL = originalImagesDirectory.appendingPathComponent("\(imageID).jpg")
            if FileManager.default.fileExists(atPath: originalImageURL.path) {
                do {
                    try FileManager.default.removeItem(at: originalImageURL)
                    print("Successfully deleted original image file: \(imageID)")
                } catch {
                    print("Failed to delete original image file: \(error)")
                    success = false
                }
            }
        }
        
        // 5. Refresh Widget
        if success {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        
        return success
    }
    
    // Clear all images (clear images of all sizes) - atomic operation version
    func clearAllImages() -> Bool {
        // Use operation lock to ensure atomicity
        let operationLock = NSLock()
        operationLock.lock()
        defer { operationLock.unlock() }
        
        // 1. Get all image IDs
        // Only .large size is retained, other sizes have been removed
        let list = getImageMetadataList(for: .large)
        
        if list.isEmpty {
             print("Clear operation: No images to delete")
             return true
         }
         
         // 2. Atomically clear metadata
        var success = saveImageMetadataList([], for: .large)
        
        if !success {
            print("Clear failed: Metadata clearing failed")
            return false
        }
        
        // 3. Delete all image files
        success = success && clearAllImageFiles(for: .large)
        success = success && clearAllOriginalImageFiles() // Add clearing original images
        
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
            print("Unable to get original image directory, ID: \(id)")
            return nil // Return nil directly, no fallback
        }
        
        let imageURL = originalImagesDirectory.appendingPathComponent("\(id).jpg")
        
        guard FileManager.default.fileExists(atPath: imageURL.path),
              let imageData = try? Data(contentsOf: imageURL),
              let image = UIImage(data: imageData) else {
            print("Original image does not exist or is corrupted, ID: \(id)")
            return nil // Return nil directly, no fallback
        }
        
        return image
    }
    
    // Get image by ID (default gets large size)
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
    
    // Get metadata list (default gets large size)
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
    
    // Save metadata list (default saves large size)
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
            // No fallback to cropped version, skip if original image doesn't exist
        }
        
        return result
    }
    
    // Get all images (in order, default gets large size)
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
    
    // Get image count (default gets large size)
    func getImageCount() -> Int {
        return getImageMetadataList().count
    }
    
    // Get image count for specified size
    func getImageCount(for sizeType: WidgetSizeType) -> Int {
        return getImageMetadataList(for: sizeType).count
    }
    
    // Check if maximum count limit is reached (default checks large size)
    func isMaxImageCountReached() -> Bool {
        return getImageCount() >= maxImageCount
    }
    
    // Check if maximum count limit is reached for specified size
    func isMaxImageCountReached(for sizeType: WidgetSizeType) -> Bool {
        return getImageCount(for: sizeType) >= maxImageCount
    }
}
