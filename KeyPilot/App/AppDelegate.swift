import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appState = AppState(environment: AppEnvironment())
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var stateObserver: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        appState.settingsPresenter = { [weak self] in self?.showSettingsWindow() }
        installStatusItem()
        stateObserver = appState.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.refreshStatusMenu() }
        }
        appState.start()
        refreshStatusMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.environment.keyboardEngine.stop()
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "KeyPilot")
        item.button?.image?.isTemplate = true
        item.menu = NSMenu(title: "KeyPilot")
        statusItem = item
    }

    private func refreshStatusMenu() {
        guard let statusItem, let menu = statusItem.menu else { return }
        let requestedImage = NSImage(
            systemSymbolName: appState.menuBarIconName,
            accessibilityDescription: "KeyPilot"
        )
        statusItem.button?.image = requestedImage
            ?? NSImage(systemSymbolName: "keyboard", accessibilityDescription: "KeyPilot")
        statusItem.button?.image?.isTemplate = true
        menu.removeAllItems()

        let status = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        let globalTitle = appState.configuration.globalEnabled ? "暂停所有规则" : "恢复所有规则"
        menu.addItem(menuItem(globalTitle, action: #selector(toggleGlobalState)))
        menu.addItem(.separator())

        let remapCount = NSMenuItem(
            title: "键位映射：\(appState.enabledRemapCount) 条启用",
            action: nil,
            keyEquivalent: ""
        )
        remapCount.isEnabled = false
        menu.addItem(remapCount)
        let shortcutCount = NSMenuItem(
            title: "软件快捷键：\(appState.enabledShortcutCount) 条启用",
            action: nil,
            keyEquivalent: ""
        )
        shortcutCount.isEnabled = false
        menu.addItem(shortcutCount)
        let multiPressCount = NSMenuItem(
            title: "连按动作：\(appState.enabledMultiPressCount) 条启用",
            action: nil,
            keyEquivalent: ""
        )
        multiPressCount.isEnabled = false
        menu.addItem(multiPressCount)
        menu.addItem(.separator())

        menu.addItem(menuItem("打开设置…", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(menuItem("权限与诊断…", action: #selector(showSettings)))
        let loginItem = menuItem("登录时启动", action: #selector(toggleLaunchAtLogin))
        loginItem.state = appState.configuration.launchAtLogin ? .on : .off
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(menuItem("退出 KeyPilot", action: #selector(quit), keyEquivalent: "q"))
    }

    private var statusText: String {
        if appState.permissionState != .granted { return "⚠ 缺少辅助功能权限" }
        if !appState.configuration.globalEnabled { return "所有规则已暂停" }
        return appState.eventTapStatus == .running
            ? "✓ 键盘规则已启用"
            : appState.eventTapStatus.displayName
    }

    private func menuItem(_ title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    @objc private func toggleGlobalState() {
        appState.setGlobalEnabled(!appState.configuration.globalEnabled)
    }

    @objc private func toggleLaunchAtLogin() {
        appState.setLaunchAtLogin(!appState.configuration.launchAtLogin)
    }

    @objc private func showSettings() {
        showSettingsWindow()
    }

    private func showSettingsWindow() {
        if settingsWindow == nil {
            let rootView = SettingsRootView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
            let controller = NSHostingController(rootView: rootView)
            let window = NSWindow(contentViewController: controller)
            window.title = "KeyPilot 设置"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 1040, height: 700))
            window.minSize = NSSize(width: 900, height: 600)
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
