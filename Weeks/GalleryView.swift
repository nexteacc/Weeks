//
//  GalleryView.swift
//  Weeks
//
//  Created by Sheng on 7/4/25.
//

import SwiftUI
import PhotosUI

struct GalleryView: View {
    
    @Binding var uiImages: [UIImage]
    
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isPawAnimating = false
    @State private var animationProgress: CGFloat = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if uiImages.isEmpty {
            VStack {
                Text("No Images")
                    .foregroundColor(.gray)
                    .onAppear {
                        // 使用DispatchQueue.main.async确保在UI更新完成后执行dismiss
                        DispatchQueue.main.async {
                            dismiss()
                        }
                    }
            }
        } else {
            GeometryReader { proxy in
                let screenHeight = proxy.size.height
                let screenWidth = proxy.size.width

                HStack(spacing: 0) {
                    VStack(alignment: .center, spacing: 4) {
                        Spacer()
                        Text("2025")
                            .font(.system(size: 28, weight: .bold))
                        Text("Week 27")
                            .font(.system(size: 18))
                            .foregroundColor(.gray)
                        Spacer(minLength: screenHeight * 2/3)
                    }
                    .frame(width: screenWidth * 0.25)
                    .padding(.top, screenHeight / 3)

                    // 右侧区域使用VStack布局
                    VStack(spacing: 0) {
                        // 顶部区域：清空按钮
                        HStack {
                            Spacer()
                            Button {
                                // 显示确认对话框
                                let alert = UIAlertController(title: "Confirm Clear", message: "Are you sure you want to clear all images?", preferredStyle: .alert)
                                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                                alert.addAction(UIAlertAction(title: "Confirm", style: .destructive) { _ in
                                    // 清空所有图片
                                    _ = ImageManager.shared.clearAllImages()
                                    // 刷新所有图片
                                    let all = ImageManager.shared.getAllImages().map { $0.image }
                                    uiImages = all
                                    // 使用DispatchQueue.main.async确保在UI更新完成后执行dismiss
                                    DispatchQueue.main.async {
                                        dismiss()
                                    }
                                })
                                // 显示对话框
                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let rootViewController = windowScene.windows.first?.rootViewController {
                                    rootViewController.present(alert, animated: true)
                                }
                            } label: {
                                Image("clean")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                            }
                            Spacer()
                        }
                        .padding(.top, 10)
                        .padding(.bottom, 15) // 添加与图片区域的间距
                        
                        // 中间区域：图片滚动区域
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(Array(uiImages.enumerated()), id: \.offset) { (index, img) in
                                     GalleryImageCard(image: img, index: index)
                                }
                            }
                            .padding(.vertical, 20)
                        }
                        
                        // 底部区域：添加按钮和图片计数
                        VStack(spacing: 10) {
                            // 添加按钮
                            if !ImageManager.shared.isMaxImageCountReached() {
                                HStack {
                                    Spacer()
                                    ZStack {
                                        // 动画效果层
                                        if isPawAnimating {
                                            Image("paw")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 40, height: 40)
                                                .offset(y: animationProgress)
                                                .opacity(1.0 - (abs(animationProgress) / 20.0))
                                                .allowsHitTesting(false)
                                        }
                                        
                                        // 实际交互层
                                        PhotosPicker(selection: $selectedItems, maxSelectionCount: 30 - uiImages.count, matching: .images) {
                                            Image("paw")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 40, height: 40)
                                        }
                                        .onTapGesture {
                                            // 触发动画
                                            isPawAnimating = true
                                            animationProgress = 0
                                            
                                            withAnimation(.easeOut(duration: 0.4)) {
                                                animationProgress = -20
                                            }
                                            
                                            // 动画结束后重置
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                                isPawAnimating = false
                                                animationProgress = 0
                                            }
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.top, 15) // 添加与图片区域的间距
                            }
                            
                            // 图片计数
                            Text("\(uiImages.count) / 30")
                                .foregroundColor(.gray)
                                .font(.caption)
                                .padding(.bottom, 30)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        // 使用DispatchQueue.main.async确保在UI更新完成后执行dismiss
                        DispatchQueue.main.async {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
            }
            .onAppear {
                // 页面加载时同步所有图片
                DispatchQueue.main.async {
                    let all = ImageManager.shared.getAllImages().map { $0.image }
                    uiImages = all
                }
            }
            .onChange(of: selectedItems) {
                Task {
                    var results: [UIImage] = []
                    for item in selectedItems {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data),
                           let cropped = ImageCropper.cropCenter(of: image, toAspectRatio: 2.13) {
                            results.append(cropped)
                        }
                    }
                    if !results.isEmpty {
                        _ = ImageManager.shared.saveImages(results)
                        // 刷新所有图片
                        DispatchQueue.main.async {
                            let all = ImageManager.shared.getAllImages().map { $0.image }
                            uiImages = all
                        }
                    }
                    selectedItems = []
                }
            }
        }
    }
}

// 新增图片卡片子组件，简化主视图表达式
struct GalleryImageCard: View {
    let image: UIImage
    let index: Int
    var body: some View {
        GeometryReader { geo in
            let cardMidY = geo.frame(in: .global).midY
            let scrollMidY = geo.size.height / 2
            let normalized = (cardMidY - scrollMidY) / geo.size.height
            let rotationAngle = Double(normalized * 20)
            let scale = max(1 - abs(normalized) * 0.2, 0.8)
            // 完全不透明显示图片，保留3D效果但不影响图片清晰度
            let opacity = 1.0
            let zIndex = Double(1 - abs(normalized))
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 180)
                .clipped()
                .cornerRadius(20)
                .rotation3DEffect(
                    .degrees(rotationAngle),
                    axis: (x: 1.0, y: 0.0, z: 0.0),
                    perspective: 0.7
                )
                .scaleEffect(scale)
                .opacity(opacity)
                .shadow(radius: 6)
                .zIndex(zIndex)
        }
        .frame(height: 180)
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}
