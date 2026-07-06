import SwiftUI
import AppKit

struct OnboardingView: View {
    @State private var isTrusted = AXIsProcessTrusted()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "character.bubble.fill")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)

            Text("欢迎使用 ClipTranslator")
                .font(.title)
                .fontWeight(.bold)

            Text("选中文字 → 弹出翻译按钮 → 一键翻译，无需快捷键。")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Spacer()

            // Permission status
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: isTrusted
                        ? "checkmark.circle.fill"
                        : "exclamationmark.triangle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(isTrusted ? .green : .orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isTrusted
                            ? "辅助功能权限已授予"
                            : "需要辅助功能权限")
                            .font(.headline)
                        if !isTrusted {
                            Text("ClipTranslator 需要辅助功能权限来检测你在任何 App 中的文字选中操作。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.05))
                )

                if !isTrusted {
                    VStack(spacing: 8) {
                        Button("打开系统设置") {
                            openAccessibilitySettings()
                        }
                        .buttonStyle(.borderedProminent)

                        Text("1. 点击上方按钮\n2. 在列表中找到 ClipTranslator\n3. 打开旁边的开关")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button("重新检查") {
                        isTrusted = AXIsProcessTrusted()
                    }
                    .buttonStyle(.link)
                }
            }
            .padding(.horizontal, 30)

            Spacer()

            if isTrusted {
                Button("开始使用") {
                    dismissWindow()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Text("你可以随时通过菜单栏图标修改设置。")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
        }
        .frame(width: 480, height: 420)
    }

    private func openAccessibilitySettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )!
        NSWorkspace.shared.open(url)
    }

    private func dismissWindow() {
        for window in NSApp.windows {
            if window.title == "欢迎使用 ClipTranslator" {
                window.close()
            }
        }
    }
}
