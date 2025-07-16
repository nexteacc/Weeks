//
//  WeeksWidget.swift
//  WeeksWidget
//
//  Created by Sheng on 6/17/25.
//

import WidgetKit
import SwiftUI

// 图片元数据结构（与App中保持一致）
struct ImageMetadata: Codable {
    let id: String // UUID 字符串
    let addedDate: Date // 添加时间
    let order: Int // 顺序号
}

// Widget 时间条目
struct WeeksEntry: TimelineEntry {
    let date: Date
    let imageID: String?
    let weekNumber: Int
    let year: Int
}

// Widget 提供者
struct Provider: TimelineProvider {
    // App Group 标识符
    private let appGroupIdentifier = "group.com.nextbigtoy.weeks"
    
    // 获取共享容器 URL
    private func getSharedContainerURL() -> URL? {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }
    
    // 获取图片存储目录
    private func getImagesDirectoryURL() -> URL? {
        guard let containerURL = getSharedContainerURL() else { return nil }
        return containerURL.appendingPathComponent("Images", isDirectory: true)
    }
    
    // 获取元数据文件 URL
    private func getMetadataFileURL() -> URL? {
        guard let containerURL = getSharedContainerURL() else { return nil }
        return containerURL.appendingPathComponent("metadata.json")
    }
    
    // 获取所有图片元数据
    private func getImageMetadataList() -> [ImageMetadata] {
        guard let metadataURL = getMetadataFileURL() else { 
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
    
    // 获取图片 URL
    private func getImageURL(withID id: String) -> URL? {
        guard let imagesDirectory = getImagesDirectoryURL() else { return nil }
        return imagesDirectory.appendingPathComponent("\(id).jpg")
    }
    
    // 获取当前周数和年份
    private func getCurrentWeekAndYear() -> (week: Int, year: Int) {
        let calendar = Calendar.current
        let today = Date()
        let weekOfYear = calendar.component(.weekOfYear, from: today)
        let year = calendar.component(.year, from: today)
        return (week: weekOfYear, year: year)
    }
    
    // 提供占位符条目
    func placeholder(in context: Context) -> WeeksEntry {
        let (week, year) = getCurrentWeekAndYear()
        return WeeksEntry(date: Date(), imageID: nil, weekNumber: week, year: year)
    }

    // 提供快照条目
    func getSnapshot(in context: Context, completion: @escaping (WeeksEntry) -> ()) {
        let metadataList = getImageMetadataList()
        let (week, year) = getCurrentWeekAndYear()
        
        if let firstMetadata = metadataList.first {
            let entry = WeeksEntry(date: Date(), imageID: firstMetadata.id, weekNumber: week, year: year)
            completion(entry)
        } else {
            let entry = WeeksEntry(date: Date(), imageID: nil, weekNumber: week, year: year)
            completion(entry)
        }
    }

    // 提供时间线条目
    func getTimeline(in context: Context, completion: @escaping (Timeline<WeeksEntry>) -> ()) {
        let metadataList = getImageMetadataList()
        let (week, year) = getCurrentWeekAndYear()
        
        // 如果没有图片，返回空条目
        if metadataList.isEmpty {
            let entry = WeeksEntry(date: Date(), imageID: nil, weekNumber: week, year: year)
            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
            return
        }
        
        // 创建时间线条目
        var entries: [WeeksEntry] = []
        let currentDate = Date()
        
        // 为每张图片创建一个条目，每隔15分钟切换一次
        for (index, metadata) in metadataList.enumerated() {
            let entryDate = Calendar.current.date(byAdding: .minute, value: index * 15, to: currentDate)!
            let entry = WeeksEntry(date: entryDate, imageID: metadata.id, weekNumber: week, year: year)
            entries.append(entry)
        }
        
        // 创建时间线，最后一张图片显示完后重新开始
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
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
        .description("显示每周精选图片")
        .supportedFamilies([.systemMedium])
    }
}

// Widget 视图
struct WeeksWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.redactionReasons) private var redactionReasons
    
    // App Group 标识符
    private let appGroupIdentifier = "group.com.nextbigtoy.weeks"
    
    // 获取图片
    private func loadImage(withID id: String) -> UIImage? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            print("Widget Log: 获取共享容器URL失败")
            return nil
        }
        
        let imagesDirectory = containerURL.appendingPathComponent("Images")
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
        
        print("Widget Log: 成功加载图片ID: \(id), 文件大小: \(imageData.count) bytes")
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
