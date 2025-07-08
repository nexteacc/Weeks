//
//  WeeksApp.swift
//  Weeks
//
//  Created by Sheng on 6/17/25.
//

import SwiftUI
import UIKit
import WidgetKit

@main
struct WeeksApp: App {
    // 应用状态管理
    @AppStorage("hasAddedImages") private var hasAddedImages = false
    
    var body: some Scene {
        WindowGroup {
            ContentView(hasAddedImages: hasAddedImages)
                .preferredColorScheme(.light)
                .onAppear {
                    // 当应用启动时，确保hasAddedImages状态与实际图片状态一致
                    let hasImages = !ImageManager.shared.getAllImages().isEmpty
                    if hasAddedImages != hasImages {
                        hasAddedImages = hasImages
                    }
                }
        }
    }
}

