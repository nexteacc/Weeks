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
    
    // 是否已添加过图片的标志
    @AppStorage("hasAddedImages") private var hasAddedImages = false
    
    // 标记是否是应用启动时的初始化，用于区分是否需要自动导航
    @State private var isInitialLaunch: Bool
    
    // 初始化方法，接收hasAddedImages参数
    init(hasAddedImages: Bool = false) {
        // 如果传入了hasAddedImages参数为true，则更新@AppStorage的值
        if hasAddedImages {
            UserDefaults.standard.set(true, forKey: "hasAddedImages")
        }
        // 初始化时标记为应用启动
        self._isInitialLaunch = State(initialValue: true)
    }
   
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
                
           
                
                Image(logoNames[currentLogoIndex])
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .gesture(
                        DragGesture()
                            .onChanged { _ in
                
                                stopAutoPlay()
                            }
                            .onEnded { value in
                                if value.translation.width < -50 {
                                    currentLogoIndex = (currentLogoIndex + 1) % logoNames.count
                                } else if value.translation.width > 50 {
                                    currentLogoIndex = (currentLogoIndex - 1 + logoNames.count) % logoNames.count
                                }
                                
               
                                startAutoPlay()
                            }
                    )
                    .animation(.easeInOut, value: currentLogoIndex)

                PhotosPicker(selection: $selectedItems, maxSelectionCount: 30, matching: .images) {
                    Image(systemName: "plus")
                        .font(.system(size: 40))
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

            .navigationDestination(isPresented: $navigateToGallery) {
                GalleryView(uiImages: $uiImages)
                    .onDisappear {
                        // 当GalleryView消失时，确保状态正确更新
                        if uiImages.isEmpty {
                            hasAddedImages = false
                        }
                        // 确保从Gallery返回后不会再次自动导航
                        isInitialLaunch = false
                    }
            }
            .onAppear {
                // 加载所有图片
                let all = ImageManager.shared.getAllImages().map { $0.image }
                uiImages = all
                
                // 更新hasAddedImages状态
                if !all.isEmpty {
                    hasAddedImages = true
                } else {
                    hasAddedImages = false
                }
                
                // 只在应用启动时且有图片时自动导航到Gallery页面
                if isInitialLaunch && hasAddedImages && !all.isEmpty {
                    // 使用DispatchQueue.main.async确保在UI更新完成后设置导航状态
                    DispatchQueue.main.async {
                        navigateToGallery = true
                        // 导航后标记不再是初始启动
                        isInitialLaunch = false
                    }
                } else {
                    // 如果不是初始启动或没有图片，确保导航状态为false
                    navigateToGallery = false
                    isInitialLaunch = false
                }
                
                startAutoPlay()
            }
            .onDisappear {

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
                        // 保存图片
                        _ = ImageManager.shared.saveImages(results)

                        // 更新图片列表
                        let all = ImageManager.shared.getAllImages().map { $0.image }
                        uiImages = all
                        
                        // 设置已添加图片标志
                        hasAddedImages = true
                        
                        // 使用DispatchQueue.main.async确保在UI更新完成后设置导航状态
                        DispatchQueue.main.async {
                            // 导航到Gallery页面
                            navigateToGallery = true
                        }
                    }
                    selectedItems = []
                }
            }
        }
    }
    

    private func startAutoPlay() {
        stopAutoPlay() 
        
        autoPlayTimer = Timer.publish(every: 2.5, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                withAnimation(.easeInOut) {
                    currentLogoIndex = (currentLogoIndex + 1) % logoNames.count
                }
            }
    }
    

    private func stopAutoPlay() {
        autoPlayTimer?.cancel()
        autoPlayTimer = nil
    }
}

