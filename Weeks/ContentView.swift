import SwiftUI
import PhotosUI
import Combine

struct ContentView: View {
    @State private var currentLogoIndex = 0
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var navigateToGallery = false
    @State private var uiImages: [UIImage] = []
    
    // 自动播放相关状态
    @State private var autoPlayTimer: AnyCancellable?
   
    private let logoNames = [
        "dog",
        "cat",
        "giraffe",
        "koala",
        "monkey",
        "panda",
        "zebra"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()
                
                // 这里已删除播放器控制界面
                
                Image(logoNames[currentLogoIndex])
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .gesture(
                        DragGesture()
                            .onChanged { _ in
                                // 拖动时暂停自动播放
                                stopAutoPlay()
                            }
                            .onEnded { value in
                                if value.translation.width < -50 {
                                    currentLogoIndex = (currentLogoIndex + 1) % logoNames.count
                                } else if value.translation.width > 50 {
                                    currentLogoIndex = (currentLogoIndex - 1 + logoNames.count) % logoNames.count
                                }
                                
                                // 拖动结束后恢复自动播放
                                startAutoPlay()
                            }
                    )
                    .animation(.easeInOut, value: currentLogoIndex)

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
                
                // 启动自动播放
                startAutoPlay()
            }
            .onDisappear {
                // 页面消失时停止自动播放
                stopAutoPlay()
            }
            .onChange(of: selectedItems) { _, _ in
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
    
    // 启动自动播放
    private func startAutoPlay() {
        stopAutoPlay() // 先停止现有定时器
        
        autoPlayTimer = Timer.publish(every: 3.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                withAnimation(.easeInOut) {
                    currentLogoIndex = (currentLogoIndex + 1) % logoNames.count
                }
            }
    }
    
    // 停止自动播放
    private func stopAutoPlay() {
        autoPlayTimer?.cancel()
        autoPlayTimer = nil
    }
}

