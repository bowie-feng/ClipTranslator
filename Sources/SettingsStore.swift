import Foundation
import Combine
import ServiceManagement

enum TranslationProvider: String, CaseIterable {
    case claude = "Claude"
    case deepseek = "DeepSeek"

    var displayName: String { rawValue }

    var defaultModel: String {
        switch self {
        case .claude: return "claude-sonnet-4-20250514"
        case .deepseek: return "deepseek-chat"
        }
    }

    var availableModels: [String] {
        switch self {
        case .claude:
            return [
                "claude-sonnet-4-20250514",
                "claude-opus-4-20250514",
                "claude-haiku-4-20250514",
            ]
        case .deepseek:
            return [
                "deepseek-chat",
                "deepseek-reasoner",
            ]
        }
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var provider: TranslationProvider {
        didSet { UserDefaults.standard.set(provider.rawValue, forKey: "provider") }
    }

    @Published var targetLanguage: String {
        didSet { UserDefaults.standard.set(targetLanguage, forKey: "targetLanguage") }
    }

    @Published var claudeModel: String {
        didSet { UserDefaults.standard.set(claudeModel, forKey: "claudeModel") }
    }

    @Published var deepSeekModel: String {
        didSet { UserDefaults.standard.set(deepSeekModel, forKey: "deepSeekModel") }
    }

    @Published var autoDetectSource: Bool {
        didSet { UserDefaults.standard.set(autoDetectSource, forKey: "autoDetectSource") }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            syncLaunchAtLogin()
        }
    }

    private var isSyncingLaunchAtLogin = false

    var selectedModel: String {
        switch provider {
        case .claude: return claudeModel
        case .deepseek: return deepSeekModel
        }
    }

    static let supportedLanguages: [(code: String, name: String)] = [
        ("Simplified Chinese", "简体中文"),
        ("Traditional Chinese", "繁體中文"),
        ("English", "English"),
        ("Japanese", "日本語"),
        ("Korean", "한국어"),
        ("French", "Français"),
        ("German", "Deutsch"),
        ("Spanish", "Español"),
        ("Portuguese", "Português"),
        ("Russian", "Русский"),
        ("Arabic", "العربية"),
        ("Italian", "Italiano"),
    ]

    private init() {
        let defaults = UserDefaults.standard

        let savedProvider = defaults.string(forKey: "provider") ?? ""
        self.provider = TranslationProvider(rawValue: savedProvider) ?? .claude

        self.targetLanguage = defaults.string(forKey: "targetLanguage") ?? "Simplified Chinese"
        self.claudeModel = defaults.string(forKey: "claudeModel") ?? TranslationProvider.claude.defaultModel
        self.deepSeekModel = defaults.string(forKey: "deepSeekModel") ?? TranslationProvider.deepseek.defaultModel

        // autoDetectSource: if key doesn't exist, default to true
        if defaults.object(forKey: "autoDetectSource") == nil {
            self.autoDetectSource = true
        } else {
            self.autoDetectSource = defaults.bool(forKey: "autoDetectSource")
        }

        // launchAtLogin: if key doesn't exist, default to false
        if defaults.object(forKey: "launchAtLogin") == nil {
            self.launchAtLogin = false
        } else {
            self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        }
    }

    private func syncLaunchAtLogin() {
        // Prevent re-entrant didSet recursion when catch block assigns back
        guard !isSyncingLaunchAtLogin else { return }
        isSyncingLaunchAtLogin = true
        defer { isSyncingLaunchAtLogin = false }

        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Registration may fail if app is not in /Applications
            launchAtLogin = SMAppService.mainApp.status == .enabled
            print("Launch at login error: \(error.localizedDescription)")
        }
    }
}
