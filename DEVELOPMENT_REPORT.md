# KeyPilot V1.2 开发与验收报告

日期：2026-07-23

## 1. 项目状态

**主要功能已完成；完整 XCTest 仍受环境限制。**

源码、XcodeGen 工程、菜单栏与设置界面、Event Tap 引擎、规则系统、配置服务、系统集成、38 项 XCTest、20 项独立核心烟雾检查、脚本和 README 均已完成。生产源码已在 macOS 12 目标下通过 `warnings-as-errors` 类型检查，并成功构建、签名和启动 Universal 2 App Bundle。

当前机器是 macOS 12.7.6，仅安装 Command Line Tools，没有完整 Xcode。新的兼容构建器已经在本机生成并启动 KeyPilot，但仍无法执行依赖完整 Xcode Test Host 的 XCTest。

运行版本已安装到固定路径 `~/Applications/KeyPilot.app`。旧的临时构建权限记录已通过 `tccutil reset Accessibility com.keypilot.mac` 清除，避免系统继续把权限绑定到 `.build` 中签名哈希已经变化的旧版本。

## 2. 工程产出

### 工程与元数据

- `project.yml`
- `KeyPilot.xcodeproj/project.pbxproj`
- `KeyPilot.xcodeproj/xcshareddata/xcschemes/KeyPilot.xcscheme`
- `KeyPilot/Info.plist`
- `KeyPilot/KeyPilot.entitlements`
- `Package.swift`
- `.gitignore`

### App

- `KeyPilot/App/KeyPilotApp.swift`
- `KeyPilot/App/AppDelegate.swift`
- `KeyPilot/App/AppState.swift`
- `KeyPilot/App/AppEnvironment.swift`

### Core

- `KeyPilot/Core/EventTapManager.swift`
- `KeyPilot/Core/KeyboardEventEngine.swift`
- `KeyPilot/Core/RuleCompiler.swift`
- `KeyPilot/Core/ConflictValidator.swift`
- `KeyPilot/Core/RuntimeRuleSnapshot.swift`
- `KeyPilot/Core/KeyEventDescriptor.swift`
- `KeyPilot/Core/HotkeyMatcher.swift`
- `KeyPilot/Core/RemapMatcher.swift`

### Models 与 Utilities

- `KeyPilot/Models/*.swift`：配置、规则、按键、快捷动作、应用目标、诊断和错误模型
- `KeyPilot/Utilities/*.swift`：线程安全容器、文件位置和键码名称

### Services

- `ConfigurationStore.swift` / `ImportExportService.swift`
- `PermissionManager.swift` / `LoginItemManager.swift`
- `ApplicationResolver.swift` / `ApplicationLauncher.swift`
- `DiagnosticsService.swift` / `TriggerNotificationService.swift`
- `KeyboardLayoutService.swift`

### Views

- 菜单栏：`Views/MenuBar/MenuBarContentView.swift`
- 设置：可视化概览、统一规则中心、键位映射、软件快捷键、连按动作、通用、权限与状态、日志与诊断八页
- 组件：按键录入、快捷键录入、事件监视、状态标签、错误和空状态
- 首次权限说明：`Views/Onboarding/PermissionOnboardingView.swift`

### 测试、脚本和文档

- `启动KeyPilot.command`：Finder 双击后检查环境、增量构建并启动应用
- `scripts/build-local.sh`：在 Command Line Tools 环境构建 Universal 2 App Bundle
- `KeyPilotLoginHelper/`：macOS 12 兼容登录启动助手
- `KeyPilotTests/`：38 项 XCTest
- `scripts/build.sh` / `test.sh` / `package.sh`
- `scripts/core-smoke.sh` / `CoreSmoke.swift`
- `README.md`
- `CHANGELOG.md`
- `DEVELOPMENT_REPORT.md`

## 3. 已实现功能

- 单向键位映射和双向交换；交换编译为两条独立虚拟键码映射。
- 同时转换 `keyDown` 和 `keyUp`；按住期间暂停或改规则时，松开仍沿用按下时目标，避免粘键。
- 退出或重启引擎时为仍按下的映射目标发送安全释放事件。
- 快捷键基于映射前原始键码，优先于普通映射。
- Command、Option、Control、Shift 规范化和至少一个修饰键约束。
- `autorepeat` 与按下集合双重防重复；即使先松开修饰键，主键 `keyUp` 仍正确清理和吞掉。
- 连按同一物理键 2～4 次可启动应用或输出另一个按键；未完成序列会按顺序回放原按键。
- 连按判定支持 150～1000 毫秒间隔、长按旁路、修饰键旁路和合成事件防递归标记。
- Event Tap 运行期间保持后台低延迟活动；目标应用驻留后台时执行取消隐藏、激活和重新打开三重恢复。
- Bundle Identifier 优先的应用激活，保存 URL 启动和 Bundle Identifier 路径重定位。
- Event Tap 创建失败状态、系统禁用自动恢复、有限次指数退避和手动重启。
- 辅助功能权限检查、引导、定时撤销检测和真实运行状态。
- `SMAppService.mainApp` 登录项读取、注册、注销和待批准错误。
- 菜单栏暂停/恢复、计数、设置、权限、登录项和退出。
- 原生 SwiftUI 可视化控制台、常驻分类侧边栏、规则与运行状态统计及快速创建入口。
- 统一规则中心支持跨类型搜索、筛选、行内启停、创建停用副本、确认删除和单击直达编辑器。
- 三类规则编辑页、实际键码录入、规则增删改启停和应用选择。
- 重复源、交换占用、自映射、复杂链、重复快捷键、无修饰键和非 `.app` 目标校验。
- schemaVersion JSON、原子写入、写后回读、备份恢复、损坏文件保留、严格导入和导出。
- 最多 100 条不含用户输入的内存诊断日志。
- 可选本地触发通知；没有网络、遥测、root、私有 API、脚本或第三方运行时依赖。

## 4. 构建结果

### 已成功执行

```bash
xcodegen generate
```

结果：成功生成 `KeyPilot.xcodeproj` 和共享 `KeyPilot` Scheme。

```bash
xcrun swiftc -typecheck -warnings-as-errors ... -target x86_64-apple-macosx12.0
```

结果：通过，0 个错误、0 个警告。

```bash
./scripts/build-local.sh
```

结果：通过；生成已签名的 Universal 2 `KeyPilot.app`，包含 `x86_64` 与 `arm64`，`minos 12.0`，SDK 13.1。应用已在当前 macOS 12.7.6 Intel Mac 上实际启动并保持运行。

### 因环境失败

Debug、Test、Release 三条文档指定的 `xcodebuild` 命令均已真实执行，退出码均为 1，原因相同：

```text
xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer
directory '/Library/Developer/CommandLineTools' is a command line tools instance
```

结论：**未能在当前环境执行完整 Xcode Debug/Release 构建。**

## 5. 测试结果

### XCTest

- 总数：38
- 通过：0（未执行，不代表失败）
- 失败：0
- 未执行：38
- 原因：当前 Command Line Tools 不含可用 XCTest 模块和 Xcode Test Host；`swift test` 返回 `XCTest not available`，`xcodebuild test` 因完整 Xcode 缺失退出。

### 独立核心烟雾检查

命令：

```bash
./scripts/core-smoke.sh
```

结果：`CORE_SMOKE_CHECKS=20 PASS=20 FAIL=0`。

覆盖单向/双向编译、自映射、链式映射、快捷键冲突、连按编译与冲突、修饰键规范化、防长按、按下/松开一致性、默认配置、旧配置兼容、配置往返、备份恢复和应用启动解析。

## 6. 权限说明

首次运行必须由用户在“系统设置 → 隐私与安全性 → 辅助功能”手动授权 KeyPilot。代码只可检查和打开设置页，不能替代用户授权。授权前事件引擎不会显示为正常运行。

## 7. 真实限制

- 当前开发机无法完成 Xcode XCTest 验证。
- Intel App 已在当前机器运行；Apple Silicon 架构已构建并通过签名/架构检查，但未在 Apple Silicon 实机启动。
- 尚未完成 ANSI/JIS/ISO、USB/蓝牙键盘和多输入法组合的硬件手工验收。
- 登录、锁屏、FileVault、安全输入、纯修饰键、Fn/媒体键完整映射不在 V1 范围。
- 系统或其他应用可能抢占组合键；V1 只检查 KeyPilot 自身冲突。
- 正式发布仍需 Developer ID 签名、公证和真实应用图标素材。

## 8. macOS 12+ 机器上的最短验收

```bash
cd /path/to/KeyPilot
xcodegen generate
./scripts/test.sh
./scripts/build.sh
```

然后从 Xcode 运行 KeyPilot、授予辅助功能权限，并依次验证：

1. 添加 `B ↔ ,`，在 TextEdit 验证双向、长按、快速交替和暂停/退出恢复。
2. 添加一组安全单向映射，验证禁用后恢复。
3. 添加 `⌘⌥C` 选择 Chrome，验证启动、激活、防长按和吞掉原事件。
4. 撤销再恢复辅助功能权限，验证状态和引擎恢复。
5. 验证重启持久化、导出/导入，以及非法 JSON 不覆盖当前配置。
