import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = SettingsStore.shared

    var body: some View {
        TabView {
            GeneralTab()
                .tabItem {
                    Label("通用", systemImage: "gearshape")
                }

            ProvidersTab()
                .tabItem {
                    Label("API 密钥", systemImage: "key")
                }

            AboutTab()
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
        }
        .frame(width: 520, height: 420)
    }
}

// MARK: - General Tab

struct GeneralTab: View {
    @StateObject private var settings = SettingsStore.shared

    var body: some View {
        Form {
            Section {
                Picker("翻译引擎", selection: $settings.provider) {
                    ForEach(TranslationProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.radioGroup)

                Picker("模型", selection: Binding(
                    get: { settings.selectedModel },
                    set: { newModel in
                        switch settings.provider {
                        case .claude: settings.claudeModel = newModel
                        case .deepseek: settings.deepSeekModel = newModel
                        }
                    }
                )) {
                    ForEach(settings.provider.availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
            } header: {
                Text("引擎")
            }

            Section {
                Picker("目标语言", selection: $settings.targetLanguage) {
                    ForEach(SettingsStore.supportedLanguages, id: \.code) { lang in
                        Text("\(lang.name)").tag(lang.code)
                    }
                }

                Toggle("自动检测源语言", isOn: $settings.autoDetectSource)
                Text("开启后，App 将自动判断原文语言；关闭后由翻译引擎自行处理。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("语言")
            }

            Section {
                Toggle("开机自动启动", isOn: $settings.launchAtLogin)
                Text("开启后，ClipTranslator 将在你登录 Mac 时自动启动。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("启动")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Providers Tab

struct ProvidersTab: View {
    @StateObject private var settings = SettingsStore.shared
    @State private var claudeKey: String = ""
    @State private var deepseekKey: String = ""
    @State private var showClaudeKey = false
    @State private var showDeepseekKey = false
    @State private var statusMessage: String = ""
    @State private var isTesting = false
    @State private var statusIsError = false

    var body: some View {
        Form {
            Section {
                HStack {
                    if showClaudeKey {
                        TextField("sk-ant-api03-...", text: $claudeKey)
                            .font(.system(size: 12, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("sk-ant-api03-...", text: $claudeKey)
                            .font(.system(size: 12, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                    }

                    Button(action: { showClaudeKey.toggle() }) {
                        Image(systemName: showClaudeKey ? "eye.slash" : "eye")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .help(showClaudeKey ? "隐藏" : "显示")

                    Button("保存") {
                        saveKey(claudeKey, for: .claude)
                    }
                    .disabled(claudeKey.isEmpty)
                }
                Text("在 console.anthropic.com 获取 API Key")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Label("Claude API Key", systemImage: "brain.head.profile")
            }

            Section {
                HStack {
                    if showDeepseekKey {
                        TextField("sk-...", text: $deepseekKey)
                            .font(.system(size: 12, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("sk-...", text: $deepseekKey)
                            .font(.system(size: 12, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                    }

                    Button(action: { showDeepseekKey.toggle() }) {
                        Image(systemName: showDeepseekKey ? "eye.slash" : "eye")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .help(showDeepseekKey ? "隐藏" : "显示")

                    Button("保存") {
                        saveKey(deepseekKey, for: .deepseek)
                    }
                    .disabled(deepseekKey.isEmpty)
                }
                Text("在 platform.deepseek.com 获取 API Key")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Label("DeepSeek API Key", systemImage: "cpu")
            }

            Section {
                HStack {
                    Button("测试连接") {
                        testCurrentProvider()
                    }
                    .disabled(isTesting)

                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    }
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(statusIsError ? .red : .green)
                }
            } header: {
                Text("验证")
            }

            Section {
                HStack {
                    Image(systemName: AXIsProcessTrusted()
                        ? "checkmark.circle.fill"
                        : "exclamationmark.triangle.fill")
                        .foregroundColor(AXIsProcessTrusted() ? .green : .orange)

                    Text(AXIsProcessTrusted()
                        ? "辅助功能权限已授予"
                        : "需要辅助功能权限")

                    if !AXIsProcessTrusted() {
                        Button("打开系统设置") {
                            openAccessibilitySettings()
                        }
                    }
                }
                if !AXIsProcessTrusted() {
                    Text("ClipTranslator 需要辅助功能权限才能检测文字选中。请在「系统设置 > 隐私与安全性 > 辅助功能」中开启。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("权限")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            loadSavedKeys()
        }
    }

    private func loadSavedKeys() {
        if let _ = try? KeychainManager.shared.getAPIKey(for: .claude) {
            claudeKey = "••••••••已保存••••••••"
        }
        if let _ = try? KeychainManager.shared.getAPIKey(for: .deepseek) {
            deepseekKey = "••••••••已保存••••••••"
        }
    }

    private func saveKey(_ key: String, for provider: TranslationProvider) {
        guard !key.contains("••••••••") else { return }

        do {
            try KeychainManager.shared.setAPIKey(key, for: provider)
            KeychainManager.shared.invalidateCache(for: provider)
            statusMessage = "\(provider.displayName) API Key 已保存。"
            statusIsError = false
            showStatusTemporarily()
        } catch {
            statusMessage = "保存失败：\(error.localizedDescription)"
            statusIsError = true
            showStatusTemporarily()
        }
    }

    private func testCurrentProvider() {
        isTesting = true
        statusMessage = ""

        Task {
            let result = await TranslationService.shared.translate(
                text: "Hello, this is a test message.",
                targetLanguage: SettingsStore.shared.targetLanguage,
                provider: SettingsStore.shared.provider
            )

            await MainActor.run {
                isTesting = false
                if result.isError {
                    statusMessage = "连接失败：\(result.translatedText)"
                    statusIsError = true
                } else {
                    statusMessage = "测试成功！\"Hello, this is a test message.\" → \"\(result.translatedText)\""
                    statusIsError = false
                }
                showStatusTemporarily()
            }
        }
    }

    private func showStatusTemporarily() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            statusMessage = ""
        }
    }

    private func openAccessibilitySettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )!
        NSWorkspace.shared.open(url)
    }
}

// MARK: - About Tab

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "character.bubble.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("ClipTranslator")
                .font(.title)
                .fontWeight(.bold)

            Text("版本 1.3.0")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("选中文字 → 弹按钮 → 点翻译，任意软件都能用。")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            VStack(spacing: 4) {
                Text("由 Claude & DeepSeek 驱动")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("SwiftUI + AppKit 构建")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
