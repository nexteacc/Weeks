import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var navigateToGallery = false
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var uiImages: [UIImage] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()

                Image("dogLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)

                PhotosPicker(selection: $selectedItems, maxSelectionCount: 30, matching: .images) {
                    Text("Choose Photos")
                        .foregroundColor(.black)
                        .padding()
                        .frame(width: 200, height: 280)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                .foregroundColor(.black)
                        )
                }

                Spacer()
            }
            // 使用新版 navigationDestination 替代过时的 NavigationLink
            .navigationDestination(isPresented: $navigateToGallery) {
                GalleryView(uiImages: $uiImages)
            }
            .onAppear {
                // 页面加载时同步所有图片
                let all = ImageManager.shared.getAllImages().map { $0.image }
                uiImages = all
            }
            .onChange(of: selectedItems) { _, _ in
                Task {
                    var results: [UIImage] = []
                    for item in selectedItems {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data),
                           let cropped = ImageCropper.cropCenter(of: image, toAspectRatio: 2.0) {
                            results.append(cropped)
                        }
                    }
                    if !results.isEmpty {
                        // 通过ImageManager批量保存
                        _ = ImageManager.shared.saveImages(results)
                        // 刷新所有图片
                        let all = ImageManager.shared.getAllImages().map { $0.image }
                        uiImages = all
                        navigateToGallery = true
                    }
                    selectedItems = []
                }
            }
        }
    }
}
// ContentView.swift 已升级为 iOS 18 推荐写法，移除所有过时API。
