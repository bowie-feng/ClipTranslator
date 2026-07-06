# ClipTranslator

macOS 跨软件划词翻译工具 —— 在任何 App 中选中文字，自动弹出 AI 翻译结果。

## 功能

- **全自动触发**：选中文字即翻译，无需按任何快捷键
- **跨软件支持**：浏览器、PDF、Word、代码编辑器……任何能用 Cmd+C 的地方
- **浮动弹窗**：翻译结果在鼠标旁弹出，点击外部自动消失
- **多引擎支持**：Claude API / DeepSeek API，可随时切换
- **自动语言检测**：自动识别源语言，默认翻译为简体中文

## 系统要求

- macOS 15 (Sequoia) 或更高版本
- Apple Silicon (arm64) 或 Intel (x86_64)
- 辅助功能权限（Accessibility）

## 快速开始

### 编译

```bash
cd ClipTranslator
swift build -c release
```

### 运行

```bash
swift run
```

### 打包为 .app

```bash
# 编译
swift build -c release --arch arm64

# 创建 app bundle
mkdir -p ClipTranslator.app/Contents/MacOS
cp .build/arm64-apple-macosx/release/ClipTranslator ClipTranslator.app/Contents/MacOS/

# 创建 Info.plist
cat > ClipTranslator.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ClipTranslator</string>
    <key>CFBundleIdentifier</key>
    <string>com.cliptranslator.app</string>
    <key>CFBundleName</key>
    <string>ClipTranslator</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF
```

## 使用说明

1. **首次启动**：按引导开启「辅助功能权限」（系统设置 > 隐私与安全性 > 辅助功能）
2. **配置 API Key**：点击菜单栏图标 → Settings → API Keys 标签页，填入 Claude 或 DeepSeek 的 API Key
3. **开始使用**：在任何软件中选中文字，等待约 0.5 秒，翻译弹窗自动出现
4. **复制翻译**：点击弹窗中的 Copy 按钮
5. **关闭弹窗**：点击弹窗外任意位置，或按 Esc 键
6. **暂停翻译**：点击菜单栏图标 → Pause Translation

## 配置项

- **翻译引擎**：Claude / DeepSeek
- **模型选择**：每个引擎支持多个模型
- **目标语言**：简体中文、繁體中文、English、日本語、한국어 等 12 种语言
- **自动检测源语言**：可开关

## 技术架构

- Swift 6 + SwiftUI + AppKit
- Swift Package Manager 构建
- 无第三方依赖
- API Key 存储在 macOS Keychain 中
- 全局鼠标事件监听 + CGEvent 模拟 Cmd+C

## 工作原理

```
选中文字（拖拽/双击） → leftMouseUp 事件
  → 500ms 去抖
  → 保存剪贴板 → 模拟 ⌘C → 读取剪贴板 → 恢复剪贴板
  → 调用翻译 API
  → 鼠标旁弹出翻译结果
```
