import SwiftUI
import PhotosUI
import Combine

struct ContentView: View {
    @State private var currentLogoIndex = 0
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var navigateToGallery = false
    @State private var uiImages: [UIImage] = []
    
    // Auto-play related state
    @State private var autoPlayTimer: AnyCancellable?
    
    // Flag indicating whether images have been added
    @AppStorage("hasAddedImages") private var hasAddedImages = false
    
    // Flag to mark initial app launch, used to determine if automatic navigation is needed
    @State private var isInitialLaunch: Bool
    
    // Initialization method, accepts hasAddedImages parameter
    init(hasAddedImages: Bool = false) {
        // If hasAddedImages parameter is true, update the @AppStorage value
        if hasAddedImages {
            UserDefaults.standard.set(true, forKey: "hasAddedImages")
        }
        // Mark as app launch during initialization
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
                        // When GalleryView disappears, ensure the state is correctly updated
                        if uiImages.isEmpty {
                            hasAddedImages = false
                        }
                    }
            }
            .onAppear {
                // Load all images
                let all = ImageManager.shared.getAllImages().map { $0.image }
                uiImages = all
                
                // Update hasAddedImages state
                if !all.isEmpty {
                    hasAddedImages = true
                } else {
                    hasAddedImages = false
                }
                
                // Only auto-navigate to Gallery page during app launch if images exist
                if isInitialLaunch && hasAddedImages && !all.isEmpty {
                    // Use DispatchQueue.main.async to ensure navigation state is set after UI updates
                    DispatchQueue.main.async {
                        navigateToGallery = true
                        // Mark as no longer initial launch after navigation
                        isInitialLaunch = false
                    }
                } else {
                    // If not initial launch or no images, ensure navigation state is false
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
                           let image = UIImage(data: data) {
                            results.append(image)
                        }
                    }
                    if !results.isEmpty {
                        // Save images using smart cropping
                        ImageManager.shared.saveImages(results) { savedIDs in
                            DispatchQueue.main.async {
                                // Update image list
                                let all = ImageManager.shared.getAllImages().map { $0.image }
                                uiImages = all
                                
                                // Set flag indicating images have been added
                                hasAddedImages = true
                                
                                // Navigate to Gallery page
                                navigateToGallery = true
                            }
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

