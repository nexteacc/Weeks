//
//  WeeksWidget.swift
//  WeeksWidget
//
//  Created by Sheng on 6/17/25.
//

import WidgetKit
import SwiftUI

// Widget 尺寸类型枚举（与App中保持一致）
enum WidgetSizeType: String, Codable {
    case large

    // 兼容旧版本：如遇到未知值（如 medium）时回退到 large
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? WidgetSizeType.large.rawValue
        self = WidgetSizeType(rawValue: raw) ?? .large
    }
}

// 图片元数据结构（与App中保持一致）
struct ImageMetadata: Codable {
    let id: String // UUID 字符串
    let addedDate: Date // 添加时间
    let order: Int // 顺序号
    let sizeType: WidgetSizeType? // Widget 尺寸类型，兼容旧版本，可为 nil
    
    // 兼容旧版本的初始化方法
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        addedDate = try container.decode(Date.self, forKey: .addedDate)
        order = try container.decode(Int.self, forKey: .order)
        sizeType = try container.decodeIfPresent(WidgetSizeType.self, forKey: .sizeType)
    }
}

// Widget 时间条目
struct WeeksEntry: TimelineEntry {
    let date: Date
    let imageID: String?
    let widgetFamily: WidgetFamily // Widget 尺寸
}

// Widget 提供者
struct Provider: TimelineProvider {
    // App Group 标识符
    private let appGroupIdentifier = "group.com.nextbigtoy.weeks"
    
    // 获取共享容器 URL
    private func getSharedContainerURL() -> URL? {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }
    
    // 获取图片存储目录（根据尺寸类型）
    private func getImagesDirectoryURL(for sizeType: WidgetSizeType) -> URL? {
        guard let containerURL = getSharedContainerURL() else { return nil }
        return containerURL.appendingPathComponent("Images/\(sizeType.rawValue)", isDirectory: true)
    }
    
    // 获取元数据文件 URL（根据尺寸类型）
    private func getMetadataFileURL(for sizeType: WidgetSizeType) -> URL? {
        guard let containerURL = getSharedContainerURL() else { return nil }
        return containerURL.appendingPathComponent("metadata_\(sizeType.rawValue).json")
    }
    

    
    // 获取指定尺寸的所有图片元数据
    private func getImageMetadataList(for sizeType: WidgetSizeType) -> [ImageMetadata] {
        guard let metadataURL = getMetadataFileURL(for: sizeType) else { 
            print("Widget Log: 获取元数据文件URL失败")
            return [] 
        }
        print("Widget Log: 元数据文件路径: \(metadataURL.path)")
        
        guard FileManager.default.fileExists(atPath: metadataURL.path) else { 
            print("Widget Log: 元数据文件不存在")
            return [] 
        }
        
        do {
            let data = try Data(contentsOf: metadataURL)
            let metadataList = try JSONDecoder().decode([ImageMetadata].self, from: data)
            print("Widget Log: 成功读取 \(metadataList.count) 条元数据")
            return metadataList.sorted { $0.order < $1.order }
        } catch {
            print("Widget Log: 读取或解码元数据失败: \(error)")
            return []
        }
    }
    

    
    // 获取指定尺寸的图片 URL
    private func getImageURL(withID id: String, for sizeType: WidgetSizeType) -> URL? {
        guard let imagesDirectory = getImagesDirectoryURL(for: sizeType) else { return nil }
        return imagesDirectory.appendingPathComponent("\(id).jpg")
    }
    

    
    // 提供占位符条目
    func placeholder(in context: Context) -> WeeksEntry {
        return WeeksEntry(date: Date(), imageID: nil, widgetFamily: context.family)
    }

    // 提供快照条目
    func getSnapshot(in context: Context, completion: @escaping (WeeksEntry) -> ()) {
        // 根据 Widget 尺寸获取对应的元数据列表
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

    // 提供时间线条目
    func getTimeline(in context: Context, completion: @escaping (Timeline<WeeksEntry>) -> ()) {
        // 根据 Widget 尺寸获取对应的元数据列表
        let sizeType = getWidgetSizeType(for: context.family)
        let metadataList = getImageMetadataList(for: sizeType)
        
        // 验证元数据和文件的一致性
        let validatedMetadataList = validateImageMetadata(metadataList, for: sizeType)
        
        // 如果没有图片，返回空条目
        if validatedMetadataList.isEmpty {
            let entry = WeeksEntry(date: Date(), imageID: nil, widgetFamily: context.family)
            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
            return
        }
        
        // 创建时间线条目
        var entries: [WeeksEntry] = []
        let currentDate = Date()
        
        // 为每张图片创建一个条目，每隔15分钟切换一次
        for (index, metadata) in validatedMetadataList.enumerated() {
            let entryDate = Calendar.current.date(byAdding: .minute, value: index * 15, to: currentDate)!
            let entry = WeeksEntry(date: entryDate, imageID: metadata.id, widgetFamily: context.family)
            entries.append(entry)
        }
        
        // 创建时间线，最后一张图片显示完后重新开始
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
    
    // 验证图片元数据和文件的一致性
    private func validateImageMetadata(_ metadataList: [ImageMetadata], for sizeType: WidgetSizeType) -> [ImageMetadata] {
        guard let imagesDirectory = getImagesDirectoryURL(for: sizeType) else {
            print("Widget验证: 无法获取图片目录")
            return []
        }
        
        let validatedList = metadataList.filter { metadata in
            let imageURL = imagesDirectory.appendingPathComponent("\(metadata.id).jpg")
            let fileExists = FileManager.default.fileExists(atPath: imageURL.path)
            
            if !fileExists {
                print("Widget验证: 图片文件不存在 - ID: \(metadata.id), 尺寸: \(sizeType.rawValue)")
            }
            
            return fileExists
        }
        
        // 如果验证后的列表与原列表不同，说明存在不一致，记录日志
        if validatedList.count != metadataList.count {
            print("Widget验证: 发现数据不一致，原始数量: \(metadataList.count), 验证后数量: \(validatedList.count)")
        }
        
        return validatedList
    }
    
    // 根据 WidgetFamily 获取对应的 WidgetSizeType
    private func getWidgetSizeType(for family: WidgetFamily) -> WidgetSizeType {
        switch family {
        case .systemLarge:
            return .large
        default: // 统一使用 large 尺寸
            return .large
        }
    }
}

// Widget 定义
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

// Widget 视图
struct WeeksWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.redactionReasons) private var redactionReasons
    
    // App Group 标识符
    private let appGroupIdentifier = "group.com.nextbigtoy.weeks"
    
    // 获取图片（根据 Widget 尺寸加载对应的图片）
    private func loadImage(withID id: String) -> UIImage? {
        // 根据 Widget 尺寸获取对应的尺寸类型
        let sizeType = getWidgetSizeType(for: entry.widgetFamily)
        return loadImage(withID: id, for: sizeType)
    }
    
    // 根据 WidgetFamily 获取对应的 WidgetSizeType
    private func getWidgetSizeType(for family: WidgetFamily) -> WidgetSizeType {
        switch family {
        case .systemLarge:
            return .large
        default: // 统一使用 large 尺寸
            return .large
        }
    }
    
    // 获取指定尺寸的图片
    private func loadImage(withID id: String, for sizeType: WidgetSizeType) -> UIImage? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            print("Widget Log: 获取共享容器URL失败")
            return nil
        }
        
        let imagesDirectory = containerURL.appendingPathComponent("Images/\(sizeType.rawValue)")
        let imageURL = imagesDirectory.appendingPathComponent("\(id).jpg")
        print("Widget Log: 尝试加载图片路径: \(imageURL.path)")
        
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            print("Widget Log: 图片文件不存在")
            return nil
        }
        
        // 验证文件完整性：检查文件大小和可读性
        guard let fileAttributes = try? FileManager.default.attributesOfItem(atPath: imageURL.path),
              let fileSize = fileAttributes[.size] as? Int64,
              fileSize > 0 else {
            print("Widget Log: 图片文件大小无效")
            return nil
        }
        
        // 尝试读取文件数据
        guard let imageData = try? Data(contentsOf: imageURL),
              imageData.count > 0 else {
            print("Widget Log: 加载图片数据失败")
            return nil
        }
        
        // 验证数据完整性：确保可以创建UIImage
        guard let image = UIImage(data: imageData) else {
            print("Widget Log: 图片数据损坏，无法创建UIImage")
            return nil
        }
        
        print("Widget Log: 成功加载图片ID: \(id), 文件大小: \(imageData.count) bytes, 尺寸类型: \(sizeType.rawValue)")
        return image
    }
    
    var body: some View {
        ZStack {
            // 无图片时显示提示
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
                // 大尺寸 Widget 布局 - 移除时间信息展示
                // 保持空布局，只显示图片
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
