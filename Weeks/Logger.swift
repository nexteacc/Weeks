import Foundation
import os.log

/// Unified logging system for the Weeks app
struct Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.weeks.app"
    
    // Different log categories
    private static let imageProcessing = OSLog(subsystem: subsystem, category: "ImageProcessing")
    private static let widget = OSLog(subsystem: subsystem, category: "Widget")
    private static let storage = OSLog(subsystem: subsystem, category: "Storage")
    private static let general = OSLog(subsystem: subsystem, category: "General")
    
    enum Category {
        case imageProcessing
        case widget
        case storage
        case general
        
        var osLog: OSLog {
            switch self {
            case .imageProcessing: return Logger.imageProcessing
            case .widget: return Logger.widget
            case .storage: return Logger.storage
            case .general: return Logger.general
            }
        }
    }
    
    /// Log debug information (only in debug builds)
    static func debug(_ message: String, category: Category = .general) {
        #if DEBUG
        os_log(.debug, log: category.osLog, "%{public}@", message)
        #endif
    }
    
    /// Log informational messages
    static func info(_ message: String, category: Category = .general) {
        os_log(.info, log: category.osLog, "%{public}@", message)
    }
    
    /// Log error messages
    static func error(_ message: String, category: Category = .general) {
        os_log(.error, log: category.osLog, "%{public}@", message)
    }
    
    /// Log warning messages
    static func warning(_ message: String, category: Category = .general) {
        os_log(.default, log: category.osLog, "%{public}@", message)
    }
}