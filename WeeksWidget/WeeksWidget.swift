//
//  WeeksWidget.swift
//  WeeksWidget
//
//  Created by Sheng on 6/17/25.
//

import WidgetKit
import SwiftUI

// Widget size type enumeration (consistent with App)
enum WidgetSizeType: String, Codable {
    case large

    // Compatibility: fallback to large for unknown values (e.g. deprecated medium)
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? WidgetSizeType.large.rawValue
        self = WidgetSizeType(rawValue: raw) ?? .large
    }
}

// Image metadata structure (consistent with App)
struct ImageMetadata: Codable {
    let id: String // UUID string
    let addedDate: Date // Date added
    let order: Int // Order number
    let sizeType: WidgetSizeType? // Widget size type, compatible with old versions, can be nil
    
    // Compatibility initialization method
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        addedDate = try container.decode(Date.self, forKey: .addedDate)
        order = try container.decode(Int.self, forKey: .order)
        sizeType = try container.decodeIfPresent(WidgetSizeType.self, forKey: .sizeType)
    }
}

// Widget timeline entry
struct WeeksEntry: TimelineEntry {
    let date: Date
    let imageID: String?
    let widgetFamily: WidgetFamily // Widget size
}

// Widget provider
struct Provider: TimelineProvider {
    // App Group identifier - must match the ID in entitlements file
    private let appGroupIdentifier = "group.com.nextbigtoy.weeks"
    
    // Get shared container URL
    private func getSharedContainerURL() -> URL? {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }
    
    // Get image storage directory (by size type)
    private func getImagesDirectoryURL(for sizeType: WidgetSizeType) -> URL? {
        guard let containerURL = getSharedContainerURL() else { return nil }
        return containerURL.appendingPathComponent("Images/\(sizeType.rawValue)", isDirectory: true)
    }
    
    // Get metadata file URL (by size type)
    private func getMetadataFileURL(for sizeType: WidgetSizeType) -> URL? {
        guard let containerURL = getSharedContainerURL() else { return nil }
        return containerURL.appendingPathComponent("metadata_\(sizeType.rawValue).json")
    }
    

    
    // Get all image metadata for specified size
    private func getImageMetadataList(for sizeType: WidgetSizeType) -> [ImageMetadata] {
        guard let metadataURL = getMetadataFileURL(for: sizeType) else { 
            return [] 
        }
        
        guard FileManager.default.fileExists(atPath: metadataURL.path) else { 
            return [] 
        }
        
        do {
            let data = try Data(contentsOf: metadataURL)
            let metadataList = try JSONDecoder().decode([ImageMetadata].self, from: data)
            return metadataList.sorted { $0.order < $1.order }
        } catch {
            return []
        }
    }
    

    
    // Get image URL for specified size
    private func getImageURL(withID id: String, for sizeType: WidgetSizeType) -> URL? {
        guard let imagesDirectory = getImagesDirectoryURL(for: sizeType) else { return nil }
        return imagesDirectory.appendingPathComponent("\(id).jpg")
    }
    

    
    // Provide placeholder entry
    func placeholder(in context: Context) -> WeeksEntry {
        return WeeksEntry(date: Date(), imageID: nil, widgetFamily: context.family)
    }

    // Provide snapshot entry
    func getSnapshot(in context: Context, completion: @escaping (WeeksEntry) -> ()) {
        // Get corresponding metadata list based on Widget size
        let sizeType = getWidgetSizeType(for: context.family)
        let metadataList = getImageMetadataList(for: sizeType)
        
        if let firstMetadata = metadataList.first {
            let entry = WeeksEntry(date: Date(), imageID: firstMetadata.id, widgetFamily: context.family)
            completion(entry)
        } else {
            let entry = WeeksEntry(date: Date(), imageID: nil, widgetFamily: context.family)
            completion(entry)
        }
    }

    // Provide timeline entries
    func getTimeline(in context: Context, completion: @escaping (Timeline<WeeksEntry>) -> ()) {
        // Get corresponding metadata list based on Widget size
        let sizeType = getWidgetSizeType(for: context.family)
        let metadataList = getImageMetadataList(for: sizeType)
        
        // Validate consistency between metadata and files
        let validatedMetadataList = validateImageMetadata(metadataList, for: sizeType)
        
        // If no images, return empty entry
        if validatedMetadataList.isEmpty {
            let entry = WeeksEntry(date: Date(), imageID: nil, widgetFamily: context.family)
            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
            return
        }
        
        // Create timeline entries
        var entries: [WeeksEntry] = []
        let currentDate = Date()
        
        // Create an entry for each image, switching every 15 minutes
        for (index, metadata) in validatedMetadataList.enumerated() {
            let entryDate = Calendar.current.date(byAdding: .minute, value: index * 15, to: currentDate)!
            let entry = WeeksEntry(date: entryDate, imageID: metadata.id, widgetFamily: context.family)
            entries.append(entry)
        }
        
        // Create timeline, restart after the last image is displayed
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
    
    // Validate consistency between image metadata and files
    private func validateImageMetadata(_ metadataList: [ImageMetadata], for sizeType: WidgetSizeType) -> [ImageMetadata] {
        guard let imagesDirectory = getImagesDirectoryURL(for: sizeType) else {
            return []
        }
        
        let validatedList = metadataList.filter { metadata in
            let imageURL = imagesDirectory.appendingPathComponent("\(metadata.id).jpg")
            let fileExists = FileManager.default.fileExists(atPath: imageURL.path)
            
            // File validation - no logging needed in production
            
            return fileExists
        }
        
        // Data consistency validation completed
        
        return validatedList
    }
    
    // Get corresponding WidgetSizeType based on WidgetFamily
    private func getWidgetSizeType(for family: WidgetFamily) -> WidgetSizeType {
        switch family {
        case .systemLarge:
            return .large
        default: // Unified use of large size
            return .large
        }
    }
}

// Widget definition
struct WeeksWidget: Widget {
    let kind: String = "WeeksWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WeeksWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Weeks")
        .description("Display weekly featured images")
        .supportedFamilies([.systemLarge])
    }
}

// Widget view
struct WeeksWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.redactionReasons) private var redactionReasons
    
    // App Group identifier - must match the ID in entitlements file
    private let appGroupIdentifier = "group.com.nextbigtoy.weeks"
    
    // Get image (load corresponding image based on Widget size)
    private func loadImage(withID id: String) -> UIImage? {
        // Get corresponding size type based on Widget size
        let sizeType = getWidgetSizeType(for: entry.widgetFamily)
        return loadImage(withID: id, for: sizeType)
    }
    
    // Get corresponding WidgetSizeType based on WidgetFamily
    private func getWidgetSizeType(for family: WidgetFamily) -> WidgetSizeType {
        switch family {
        case .systemLarge:
            return .large
        default: // Unified use of large size
            return .large
        }
    }
    
    // Get image for specified size
    private func loadImage(withID id: String, for sizeType: WidgetSizeType) -> UIImage? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return nil
        }
        
        let imagesDirectory = containerURL.appendingPathComponent("Images/\(sizeType.rawValue)")
        let imageURL = imagesDirectory.appendingPathComponent("\(id).jpg")
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            return nil
        }
        
        // Verify file integrity: check file size and readability
        guard let fileAttributes = try? FileManager.default.attributesOfItem(atPath: imageURL.path),
              let fileSize = fileAttributes[.size] as? Int64,
              fileSize > 0 else {
            return nil
        }
        
        // Try to read file data
        guard let imageData = try? Data(contentsOf: imageURL),
              imageData.count > 0 else {
            return nil
        }
        
        // Verify data integrity: ensure UIImage can be created
        guard let image = UIImage(data: imageData) else {
            return nil
        }
        
        return image
    }
    
    var body: some View {
        ZStack {
            // Show prompt when no images
            if entry.imageID == nil {
                VStack(spacing: 10) {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("add photos")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
            } else if entry.widgetFamily == .systemLarge {
                // Large Widget layout - removed time information display
                // Keep empty layout, only show image
                EmptyView()
            }
        }
        .containerBackground(for: .widget) {
            if let imageID = entry.imageID, let uiImage = loadImage(withID: imageID) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.black
            }
        }
        .widgetURL(URL(string: "weeksWidget://openApp"))
    }
}
