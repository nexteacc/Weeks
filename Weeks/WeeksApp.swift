import SwiftUI
import Photos
import UserNotifications

@main
struct WeeksApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light) // Set SwiftUI view to prefer light mode
                .onAppear {
                    // Request photo library permission
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
                    
                    // Request notification permission
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

// App delegate for handling push notification registration etc.
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Register for remote notifications
        application.registerForRemoteNotifications()
        return true
    }
    
    // Handle device token
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        Logger.info("Device token received: \(token)", category: .general)
        // Here you can send the token to your server
    }
    
    // Handle registration failure
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Logger.error("Failed to register for remote notifications: \(error.localizedDescription)", category: .general)
    }
}