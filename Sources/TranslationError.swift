import Foundation

enum TranslationError: LocalizedError {
    case invalidAPIKey
    case rateLimited
    case networkError(String)
    case apiError(statusCode: Int, body: String)
    case keychainError(String)
    case noAPIKey
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "API Key 无效，请检查设置。"
        case .rateLimited:
            return "请求过于频繁，请稍后再试。"
        case .networkError(let msg):
            return "网络错误：\(msg)"
        case .apiError(let code, let body):
            return "API 错误（HTTP \(code)）：\(body)"
        case .keychainError(let msg):
            return "钥匙串错误：\(msg)"
        case .noAPIKey:
            return "未配置 API Key，请在设置中添加。"
        case .cancelled:
            return "翻译已取消。"
        }
    }

    /// Maps any Error to a user-friendly TranslationError with Chinese messages.
    static func map(_ error: Error) -> TranslationError {
        // Already a TranslationError — return as-is
        if let te = error as? TranslationError {
            return te
        }

        // CancellationError → cancelled
        if error is CancellationError {
            return .cancelled
        }

        // URLError — provide Chinese descriptions for common network issues
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut:
                return .networkError("请求超时，请检查网络连接后重试。")
            case NSURLErrorNotConnectedToInternet:
                return .networkError("网络未连接，请检查网络后重试。")
            case NSURLErrorNetworkConnectionLost:
                return .networkError("网络连接已断开，请检查网络后重试。")
            case NSURLErrorCannotFindHost:
                return .networkError("无法找到服务器，请检查网络后重试。")
            case NSURLErrorCannotConnectToHost:
                return .networkError("无法连接到服务器，请检查网络后重试。")
            case NSURLErrorSecureConnectionFailed:
                return .networkError("安全连接失败，请检查系统时间是否正确。")
            case NSURLErrorDNSLookupFailed:
                return .networkError("DNS 解析失败，请检查网络设置。")
            default:
                return .networkError(error.localizedDescription)
            }
        }

        return .networkError(error.localizedDescription)
    }
}
