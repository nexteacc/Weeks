import SwiftUI
import Photos
import UserNotifications

@main
struct WeeksApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light) // 设置 SwiftUI 视图首选明亮模式
                .onAppear {
                    // 请求相册权限
                    PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                        switch status {
                        case .authorized, .limited:
                            Logger.info("Photo library access authorized", category: .general)
                        case .denied, .restricted:
                            Logger.warning("Photo library access denied", category: .general)
                        case .notDetermined:
                            Logger.info("Photo library access not determined", category: .general)
                        @unknown default:
                            break
                        }
                    }
                    
                    // 请求通知权限
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                        if granted {
                            Logger.info("Notification permission granted", category: .general)
                        } else if let error = error {
                            Logger.error("Notification permission error: \(error.localizedDescription)", category: .general)
                        }
                    }
                }
        }
    }
}

// 应用代理，处理推送通知注册等
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 注册远程通知
        application.registerForRemoteNotifications()
        return true
    }
    
    // 处理设备令牌
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        Logger.info("Device token received: \(token)", category: .general)
        // 这里可以将令牌发送到您的服务器
    }
    
    // 处理注册失败
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Logger.error("Failed to register for remote notifications: \(error.localizedDescription)", category: .general)
    }
}