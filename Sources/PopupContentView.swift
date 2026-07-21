import SwiftUI

struct PopupContentView: View {
    let originalText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let isLoading: Bool
    let isError: Bool
    let isDictionaryMode: Bool
    let onCopy: () -> Void
    let onDismiss: () -> Void
    let onLanguageChange: ((String) -> Void)?
    let onToggleMode: (() -> Void)?

    @State private var isCopied = false

    private static let quickTargetLanguages: [(code: String, name: String)] = [
        ("Simplified Chinese", "简体中文"),
        ("English", "English"),
        ("Japanese", "日本語"),
        ("Korean", "한국어"),
        ("French", "Français"),
        ("German", "Deutsch"),
        ("Spanish", "Español"),
        ("Portuguese", "Português"),
        ("Russian", "Русский"),
        ("Arabic", "العربية"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with drag handle
            HStack(spacing: 6) {
                // Drag handle indicator
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.primary.opacity(0.15))
                    .frame(width: 20, height: 3)

                if isDictionaryMode {
                    // Dictionary mode badge
                    Text("📖 查词")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.accentColor.opacity(0.1))
                        )
                } else {
                    // Language direction badge with target-language picker
                    HStack(spacing: 2) {
                        Text("\(languageDisplayName(sourceLanguage)) → ")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)

                        if let onLanguageChange = onLanguageChange {
                            Menu {
                                ForEach(Self.quickTargetLanguages, id: \.code) { lang in
                                    Button(lang.name) {
                                        onLanguageChange(lang.code)
                                    }
                                }
                            } label: {
                                HStack(spacing: 2) {
                                    Text(languageDisplayName(targetLanguage))
                                        .font(.system(size: 10, weight: .medium))
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 6, weight: .bold))
                                }
                                .foregroundColor(.accentColor)
                            }
                            .menuStyle(.borderlessButton)
                            .buttonStyle(.plain)
                            .fixedSize()
                        } else {
                            Text(languageDisplayName(targetLanguage))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.08))
                    )
                }

                Spacer()

                // Toggle mode button (only for single words)
                if let onToggleMode = onToggleMode, !isLoading {
                    Button(action: onToggleMode) {
                        Text(isDictionaryMode ? "翻译" : "查词")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.accentColor.opacity(0.4), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(isDictionaryMode ? "切换到翻译模式" : "切换到查词模式")
                }

                // Character count (when not loading, translation mode only)
                if !isLoading && !isDictionaryMode {
                    Text("\(translatedText.count) 字")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                // Dismiss button
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("关闭（Esc）")
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Divider()
                .opacity(0.3)

            // Original text (truncated) — only in translation mode
            if !isDictionaryMode {
                VStack(alignment: .leading, spacing: 2) {
                    Text("原文")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text(truncatedOriginal)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

                Divider()
                    .opacity(0.3)
            } else if !isLoading && !isError {
                // Dictionary mode: show the word prominently
                VStack(alignment: .leading, spacing: 2) {
                    Text(originalText)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 14)
                        .padding(.top, 10)
                        .padding(.bottom, 4)
                }

                Divider()
                    .opacity(0.3)
            }

            // Content area: loading spinner or translated text
            if isLoading {
                VStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.9)
                    Text("翻译中...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 80)
            } else {
                ScrollView {
                    Text(translatedText)
                        .font(.system(size: 13))
                        .foregroundColor(isError ? .red : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }
            }

            Divider()
                .opacity(0.3)

            // Footer with copy button + resize grip
            HStack {
                if !isLoading {
                    Button(action: {
                        onCopy()
                        isCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            isCopied = false
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                                .font(.system(size: 11))
                            Text(isCopied ? "已复制！" : "复制")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(isCopied ? .green : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.primary.opacity(isCopied ? 0.1 : 0.06))
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Resize grip
                Image(systemName: "arrow.up.backward.and.arrow.down.forward")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(minWidth: 280, idealWidth: 360, maxWidth: 600, minHeight: 180)
        .background(
            VisualEffectView(material: .popover, blendingMode: .behindWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
    }

    private var truncatedOriginal: String {
        let maxLen = 200
        if originalText.count > maxLen {
            return String(originalText.prefix(maxLen)) + "..."
        }
        return originalText
    }

    private func languageDisplayName(_ code: String) -> String {
        switch code {
        case "Simplified Chinese": return "简体中文"
        case "Traditional Chinese": return "繁體中文"
        case "English": return "英语"
        case "Japanese": return "日语"
        case "Korean": return "韩语"
        case "French": return "法语"
        case "German": return "德语"
        case "Spanish": return "西班牙语"
        case "Portuguese": return "葡萄牙语"
        case "Russian": return "俄语"
        case "Arabic": return "阿拉伯语"
        case "Italian": return "意大利语"
        case "Chinese": return "中文"
        case "auto": return "自动检测"
        default: return code
        }
    }
}

// MARK: - Visual Effect Background

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 12
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
