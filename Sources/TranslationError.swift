import Foundation

enum TranslationError: LocalizedError {
    case invalidAPIKey
    case rateLimited
    case networkError(String)
    case apiError(statusCode: Int, body: String)
    case keychainError(String)
    case noAPIKey

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
        }
    }
}
