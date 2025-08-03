import Foundation

/// Unified error handling for the Weeks app
enum WeeksError: LocalizedError {
    case imageProcessingFailed(reason: String)
    case storageError(reason: String)
    case widgetError(reason: String)
    case networkError(reason: String)
    case permissionDenied(type: String)
    case invalidData(reason: String)
    case timeout(operation: String)
    
    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed(let reason):
            return "Image processing failed: \(reason)"
        case .storageError(let reason):
            return "Storage error: \(reason)"
        case .widgetError(let reason):
            return "Widget error: \(reason)"
        case .networkError(let reason):
            return "Network error: \(reason)"
        case .permissionDenied(let type):
            return "Permission denied for \(type)"
        case .invalidData(let reason):
            return "Invalid data: \(reason)"
        case .timeout(let operation):
            return "Operation timed out: \(operation)"
        }
    }
    
    var failureReason: String? {
        return errorDescription
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .imageProcessingFailed:
            return "Try selecting a different image or restart the app"
        case .storageError:
            return "Check available storage space and try again"
        case .widgetError:
            return "Try removing and re-adding the widget"
        case .networkError:
            return "Check your internet connection and try again"
        case .permissionDenied:
            return "Grant the required permission in Settings"
        case .invalidData:
            return "The data appears to be corrupted, try again"
        case .timeout:
            return "The operation took too long, try again"
        }
    }
}