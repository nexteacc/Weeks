import SwiftUI
import Photos
import UserNotifications

@main
struct WeeksApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // 请求相册权限
                    PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                        switch status {
                        case .authorized, .limited:
                            print("相册访问权限已授权")
                        case .denied, .restricted:
                            print("相册访问权限被拒绝")
                        case .notDetermined:
                            print("相册访问权限未确定")
                        @unknown default:
                            break
                        }
                    }
                    
                    // 请求通知权限
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                        if granted {
                            print("通知权限已授权")
                        } else if let error = error {
                            print("通知权限错误: \(error.localizedDescription)")
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
        print("设备令牌: \(token)")
        // 这里可以将令牌发送到您的服务器
    }
    
    // 处理注册失败
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("注册远程通知失败: \(error.localizedDescription)")
    }
}