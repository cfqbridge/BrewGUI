import SwiftUI
import AppKit
import Combine

public enum NavigationTab: String, CaseIterable, Identifiable {
    case search = "搜索与安装"
    case installed = "已安装与更新"
    case maintenance = "清理与维护"
    case batchInstall = "批量安装"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .search: return "magnifyingglass"
        case .installed: return "shippingbox.fill"
        case .maintenance: return "sparkles"
        case .batchInstall: return "list.bullet.clipboard.fill"
        }
    }
}

public struct MainWindowView: View {
    @ObservedObject var store: BrewStore

    public init(store: BrewStore) {
        self.store = store
    }

    public var body: some View {
        Group {
            if !store.isBrewInstalled {
                BrewMissingGuideView(store: store)
                    .frame(minWidth: 880, minHeight: 580)
            } else {
                HStack(spacing: 0) {
                    // Collapsible Sidebar (Expanded vs Icon-only Rail)
                    SidebarRailView(store: store)

                    Divider()

                    // Right Main Content + Permission Banner + Bottom Terminal Drawer
                    VStack(spacing: 0) {
                        if !store.hasAppManagementPermission {
                            HStack(spacing: 10) {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundStyle(.orange)
                                Text("BrewGUI 尚未获得「App 管理权限」，更新或卸载 `/Applications` 下的 Cask 应用时可能会被系统拦截。")
                                    .font(.caption)
                                Spacer()
                                Button("前往系统设置开启") {
                                    store.openSystemAppManagementSettings()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                                .controlSize(.mini)

                                Button("重新检测") {
                                    store.requestAndCheckAppManagementPermission()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.14))

                            Divider()
                        }

                        Group {
                            switch store.selectedTab {
                            case .search:
                                SearchView(store: store)
                            case .installed:
                                InstalledView(store: store)
                            case .maintenance:
                                MaintenanceView(store: store)
                            case .batchInstall:
                                BatchInstallView(store: store)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        TerminalDrawerView(store: store)
                    }
                }
                .frame(minWidth: 920, minHeight: 580)
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                store.isSidebarCollapsed.toggle()
                            }
                        } label: {
                            Image(systemName: "sidebar.left")
                        }
                        .help(store.isSidebarCollapsed ? "展开侧边栏文字" : "折叠侧边栏为纯图标模式")
                    }
                }
            }
        }
        .onAppear { WindowPolicyManager.shared.mainWindowDidAppear() }
        .onDisappear { WindowPolicyManager.shared.mainWindowDidDisappear() }
    }
}

private struct SidebarRailView: View {
    @ObservedObject var store: BrewStore

    var body: some View {
        VStack(spacing: 6) {
            ForEach(NavigationTab.allCases) { tab in
                let isSelected = (store.selectedTab == tab)
                Button {
                    store.selectedTab = tab
                } label: {
                    if store.isSidebarCollapsed {
                        // Compact Icon-Only Mode (No text, no badge numbers)
                        Image(systemName: tab.iconName)
                            .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
                            )
                    } else {
                        // Expanded Mode with Text & Badges
                        HStack(spacing: 8) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                                .frame(width: 18)

                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(Color.primary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)

                            Spacer(minLength: 4)

                            if tab == .installed && store.outdatedCount > 0 {
                                BadgeView(text: "\(store.outdatedCount)", color: .orange)
                                    .fixedSize()
                            } else if tab == .search && !store.activeAdoptCandidates.isEmpty {
                                BadgeView(text: "\(store.activeAdoptCandidates.count)", color: .teal)
                                    .fixedSize()
                            } else if tab == .maintenance && store.totalCachedDownloadsBytes >= 200 * 1024 * 1024 {
                                BadgeView(text: AppConstants.formatBytes(store.totalCachedDownloadsBytes), color: .purple)
                                    .fixedSize()
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                        )
                    }
                }
                .buttonStyle(.plain)
                .help(tab.rawValue)
            }

            Spacer()

            // Version Footer (Hidden when collapsed to icon-only mode)
            if !store.isSidebarCollapsed {
                Divider()
                HStack {
                    Text("v\(AppConstants.versionString)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
        }
        .padding(.horizontal, store.isSidebarCollapsed ? 8 : 10)
        .padding(.vertical, 10)
        .frame(width: store.isSidebarCollapsed ? 52 : 212)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }
}

/// Manages macOS Dock Icon visibility: shows Dock icon when main window is open, hides Dock icon (.accessory) when main window is closed so only MenuBarExtra remains.
@MainActor
public final class WindowPolicyManager {
    public static let shared = WindowPolicyManager()

    private var openMainWindowCount = 0

    private init() {
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkVisibleMainWindowsAfterClose()
            }
        }
    }

    public static var isCLIMode: Bool {
        CommandLine.arguments.contains("--export-screenshots")
            || CommandLine.arguments.contains("--self-test")
            || CommandLine.arguments.contains("--make-squircle")
    }

    public static var isSilentLaunch: Bool {
        CommandLine.arguments.contains("--silent")
    }

    private var didPerformInitialSilentHide = false

    public func mainWindowDidAppear() {
        guard !Self.isCLIMode else { return }
        if Self.isSilentLaunch && !didPerformInitialSilentHide {
            didPerformInitialSilentHide = true
            DispatchQueue.main.async {
                for win in NSApp.windows where win.styleMask.contains(.titled) {
                    win.close()
                }
                NSApp.setActivationPolicy(.accessory)
            }
            return
        }
        openMainWindowCount += 1
        NSApp.setActivationPolicy(.regular)
    }

    public func mainWindowDidDisappear() {
        guard !Self.isCLIMode else { return }
        openMainWindowCount = max(0, openMainWindowCount - 1)
        if openMainWindowCount == 0 {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    public func activateAndShowMainWindow(openWindowAction: OpenWindowAction? = nil) {
        NSApp.setActivationPolicy(.regular)
        if let existing = NSApp.windows.first(where: { $0.styleMask.contains(.titled) }) {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        if let openWindowAction {
            openWindowAction(id: "main-window")
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func checkVisibleMainWindowsAfterClose() {
        let remainingStandardWindows = NSApp.windows.filter { win in
            win.isVisible && win.styleMask.contains(.titled)
        }
        if remainingStandardWindows.isEmpty {
            openMainWindowCount = 0
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

public struct BrewMissingGuideView: View {
    @ObservedObject var store: BrewStore

    public static let officialInstallCommand = #"/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)""#

    public init(store: BrewStore) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "mug.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text("未在当前 Mac 上检测到 Homebrew")
                    .font(.title2.weight(.bold))

                Text("BrewGUI (v\(AppConstants.versionString)) 依赖 Homebrew (`/opt/homebrew/bin/brew`) 管理软件包。请使用下方官方命令完成安装：")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 580)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("方法一：官方标准安装脚本（推荐）", systemImage: "terminal.fill")
                        .font(.callout.weight(.semibold))
                    Spacer()
                    if store.copiedInstallCommand {
                        Label("已复制到剪贴板", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Text(Self.officialInstallCommand)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                HStack(spacing: 12) {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(Self.officialInstallCommand, forType: .string)
                        store.copiedInstallCommand = true
                    } label: {
                        Label("复制安装命令", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Self.launchInstallInTerminal()
                    } label: {
                        Label("在「终端 (Terminal)」中打开并安装", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)

                    if let url = URL(string: "https://brew.sh/zh-cn/") {
                        Link(destination: url) {
                            Label("访问 Homebrew 官网", systemImage: "safari")
                        }
                        .font(.callout)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: 640)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 12) {
                Button {
                    store.recheckBrewInstallation()
                } label: {
                    Label("我已完成安装，重新检测 Homebrew", systemImage: "arrow.clockwise.circle.fill")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    public static func launchInstallInTerminal() {
        // Use a temporary .command file opened via NSWorkspace so macOS launches Terminal.app directly without requiring AppleEvents Automation TCC permission
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("install_homebrew.command")
        let scriptContent = """
        #!/bin/zsh
        clear
        echo "==> 正在为您启动 Homebrew 官方安装向导..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        echo ""
        echo "==> 安装流程已结束，您现在可以返回 BrewGUI 点击「我已完成安装，重新检测 Homebrew」。"
        exec zsh
        """
        do {
            try scriptContent.write(to: tempURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempURL.path)
            NSWorkspace.shared.open(tempURL)
        } catch {
            BrewCommandRunner.appendToDiskLog("[Guide] Failed to launch .command script: \(error.localizedDescription)\n")
        }
    }
}

public struct MenuBarPanelView: View {
    @ObservedObject var store: BrewStore
    public var onRequestOpenMainWindow: (() -> Void)?

    public init(store: BrewStore, onRequestOpenMainWindow: (() -> Void)? = nil) {
        self.store = store
        self.onRequestOpenMainWindow = onRequestOpenMainWindow
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: "mug.fill")
                    .foregroundStyle(.orange)
                Text("BrewGUI")
                    .font(.headline)
                Text("v\(AppConstants.versionString)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                if !store.isBrewInstalled {
                    BadgeView(text: "未安装 Brew", color: .red)
                } else if store.outdatedCount > 0 {
                    BadgeView(text: "\(store.outdatedCount) 个可更新", color: .orange)
                } else {
                    BadgeView(text: "全部最新", color: .green)
                }
            }

            Divider()

            if !store.isBrewInstalled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("未检测到 Homebrew (`/opt/homebrew/bin/brew`)。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Button("在终端中安装") {
                            BrewMissingGuideView.launchInstallInTerminal()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.small)

                        Button("重新检测") {
                            store.recheckBrewInstallation()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 4)
            } else {
                // Active Task Banner
                if let current = store.currentTask, current.status == .running {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(current.title)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                                if let dl = store.activeDownloadInfo {
                                    Text("⬇︎ \(dl.formattedSummary)")
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.blue)
                                        .lineLimit(1)
                                } else {
                                    Text(current.commandDescription)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            if !store.taskQueue.isEmpty {
                                Button("跳过") {
                                    store.skipCurrentTask()
                                }
                                .buttonStyle(.bordered)
                                .tint(.orange)
                                .controlSize(.mini)
                            }
                            Button("停止", role: .destructive) {
                                store.stopAllTasks()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .controlSize(.mini)
                        }
                        if let frac = store.activeDownloadInfo?.progressFraction {
                            ProgressView(value: frac)
                                .controlSize(.mini)
                        }
                    }
                    .padding(8)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else if !store.lastFailedOrSkippedTasks.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text("有 \(store.lastFailedOrSkippedTasks.count) 个未完成任务")
                            .font(.caption)
                        Spacer()
                        Button("重试") {
                            store.retryFailedOrSkippedTasks()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.mini)
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                // Outdated Packages Quick List
                if store.outdatedPackages.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.green)
                        Text("当前没有待升级的软件包")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    Text("待升级软件包 (\(store.outdatedCount))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(store.outdatedPackages) { pkg in
                                HStack {
                                    VStack(alignment: .leading, spacing: 1) {
                                        HStack(spacing: 4) {
                                            Text(pkg.displayName)
                                                .font(.caption.weight(.medium))
                                                .lineLimit(1)
                                            if let sizeStr = store.formattedSize(for: pkg.name) {
                                                Text("(\(sizeStr))")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        if pkg.hasBundleVersionMismatch && !pkg.isOutdated {
                                            Text("实际 \(pkg.actualBundleVersion ?? "?") → 账面 \(pkg.latestVersion)")
                                                .font(.caption2.monospaced())
                                                .foregroundStyle(.orange)
                                        } else {
                                            Text("\(pkg.installedVersion ?? "") → \(pkg.latestVersion)")
                                                .font(.caption2.monospaced())
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                    Spacer()
                                    Button(pkg.hasBundleVersionMismatch && !pkg.isOutdated ? "覆盖升级" : "升级") {
                                        store.upgradePackage(pkg)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.orange)
                                    .controlSize(.mini)
                                    .disabled(pkg.isPinned)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(height: min(CGFloat(store.outdatedPackages.count) * 34 + 6, 160))
                }

                Divider()

                // Quick Action Buttons
                HStack(spacing: 8) {
                    Button {
                        store.checkUpdates()
                    } label: {
                        Label("检查更新", systemImage: "icloud.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        store.upgradeAll()
                    } label: {
                        Label("全部升级", systemImage: "arrow.up.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }

            Divider()

            // MenuBar Lightweight Settings (Silent Launch at Login & Auto Check Updates)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Toggle("开机静默启动 (仅驻留菜单栏)", isOn: $store.launchAtLoginSilent)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .font(.caption)
                    Spacer()
                }

                HStack(spacing: 6) {
                    Text("自动检查更新:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("自动检查更新", selection: $store.autoUpdateInterval) {
                        ForEach(AutoUpdateInterval.allCases) { interval in
                            Text(interval.label).tag(interval)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .controlSize(.mini)
                    .fixedSize()
                }
            }
            .padding(.vertical, 2)

            Divider()

            HStack(spacing: 8) {
                Button {
                    if let onRequestOpenMainWindow {
                        onRequestOpenMainWindow()
                    } else {
                        WindowPolicyManager.shared.activateAndShowMainWindow()
                    }
                } label: {
                    Label("打开主窗口", systemImage: "macwindow")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("退出", systemImage: "power")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .frame(width: 320)
        .fixedSize(horizontal: true, vertical: true)
    }
}

/// Native NSStatusItem + NSPopover controller:
/// - Left-click on MenuBar icon: opens/activates the Main Window immediately.
/// - Right-click on MenuBar icon: toggles the adaptive-height NSPopover panel (with zero shadow/frame artifacts when list height changes).
@MainActor
public final class StatusBarController: NSObject, NSApplicationDelegate {
    public static let shared = StatusBarController()

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()
    private var mainWindowController: NSWindowController?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        guard !WindowPolicyManager.isCLIMode else { return }
        setupStatusItem()
        if WindowPolicyManager.isSilentLaunch {
            NSApp.setActivationPolicy(.accessory)
            for win in NSApp.windows where win.styleMask.contains(.titled) {
                win.close()
            }
        }
    }

    public func setupStatusItem() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = item

        if let button = item.button {
            button.image = NSImage(systemSymbolName: "mug.fill", accessibilityDescription: "BrewGUI")
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(handleStatusBarClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "左键：打开主窗口 | 右键：打开快捷菜单栏面板"
        }

        let hostingController = NSHostingController(
            rootView: MenuBarPanelView(store: BrewStore.shared) { [weak self] in
                self?.popover.performClose(nil)
                self?.showOrCreateMainWindow()
            }
        )
        hostingController.sizingOptions = .preferredContentSize
        popover.contentViewController = hostingController
        popover.behavior = .transient
        popover.animates = true

        // Observe outdatedCount changes to update status bar badge text and resize popover smoothly
        BrewStore.shared.$installedPackages
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusItemBadge()
            }
            .store(in: &cancellables)

        BrewStore.shared.$currentTask
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusItemBadge()
            }
            .store(in: &cancellables)

        updateStatusItemBadge()
    }

    private func updateStatusItemBadge() {
        guard let button = statusItem?.button else { return }
        let count = BrewStore.shared.outdatedCount
        button.title = count > 0 ? " \(count)" : ""
        if popover.isShown, let hc = popover.contentViewController {
            hc.view.layoutSubtreeIfNeeded()
            popover.contentSize = hc.view.fittingSize
        }
    }

    @objc private func handleStatusBarClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            showOrCreateMainWindow()
            return
        }
        let isRightClick = (event.type == .rightMouseUp)
            || (event.type == .leftMouseUp && event.modifierFlags.contains(.control))

        if isRightClick {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                if let hc = popover.contentViewController {
                    hc.view.layoutSubtreeIfNeeded()
                    popover.contentSize = hc.view.fittingSize
                }
                popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        } else {
            if popover.isShown {
                popover.performClose(sender)
            }
            showOrCreateMainWindow()
        }
    }

    public func showOrCreateMainWindow() {
        NSApp.setActivationPolicy(.regular)
        if let existing = NSApp.windows.first(where: { $0.styleMask.contains(.titled) && $0.title.contains("BrewGUI") }) {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "BrewGUI v\(AppConstants.versionString) — Homebrew 管理器"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: MainWindowView(store: BrewStore.shared))
        let controller = NSWindowController(window: window)
        self.mainWindowController = controller
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
public struct BrewGUIApp: App {
    @NSApplicationDelegateAdaptor(StatusBarController.self) private var appDelegate
    @StateObject private var store = BrewStore.shared

    public init() {
        if let idx = CommandLine.arguments.firstIndex(of: "--make-squircle"),
           idx + 2 < CommandLine.arguments.count {
            let srcPath = CommandLine.arguments[idx + 1]
            let dstPath = CommandLine.arguments[idx + 2]
            Self.renderTransparentSquircleIcon(srcPath: srcPath, dstPath: dstPath)
            exit(0)
        }
        if let idx = CommandLine.arguments.firstIndex(of: "--export-screenshots"),
           idx + 1 < CommandLine.arguments.count {
            let outDir = CommandLine.arguments[idx + 1]
            Task { @MainActor in
                NSApp.setActivationPolicy(.accessory)
                for win in NSApp.windows {
                    win.orderOut(nil)
                }
                await Self.exportProductScreenshots(to: outDir)
                exit(0)
            }
            return
        }
        if CommandLine.arguments.contains("--self-test") {
            Task { @MainActor in
                NSApp.setActivationPolicy(.accessory)
                for win in NSApp.windows {
                    win.orderOut(nil)
                }
                await BrewStore.shared.initialLoad()
                let s = BrewStore.shared
                let topLevelCount = s.installedPackages.filter(\.isTopLevel).count
                print("=== BREWGUI v\(AppConstants.versionString) SELF TEST ===")
                print("Installed Total: \(s.installedPackages.count) (Top-Level/Leaves+Casks: \(topLevelCount), Outdated/Mismatched: \(s.outdatedCount))")
                for pkg in s.outdatedPackages {
                    print("  -> [Needs Update/Sync] \(pkg.displayName) (recorded: \(pkg.installedVersion ?? "?"), actualDisk: \(pkg.actualBundleVersion ?? "?"), latest: \(pkg.latestVersion), mismatch=\(pkg.hasBundleVersionMismatch))")
                }
                print("Catalog Index Total: \(s.catalogEntries.count)")
                print("Local /Applications Scanned: \(s.localApplicationsSet.count)")
                print("Adoptable Cask Candidates: \(s.adoptCandidates.count) (Active: \(s.activeAdoptCandidates.count), Ignored: \(s.ignoredAdoptCandidatesList.count))")
                for c in s.adoptCandidates {
                    print("  -> [Adopt Candidate] \(c.appName) (local \(c.localVersion ?? "?"), olderThanCask=\(c.isLocalOlderThanCask), iOSWrapped=\(c.isIOSWrappedApp), MAS=\(c.isAppStoreReceiptPresent)) => cask: \(c.caskToken) (\(c.caskVersion))")
                }
                print("Cached Downloads: \(s.cachedDownloadFiles.count) files, total \(AppConstants.formatBytes(s.totalCachedDownloadsBytes))")
                print("Orphan Formulae (autoremove): \(s.orphanFormulae.count) (\(s.orphanFormulae.joined(separator: ", ")))")
                exit(0)
            }
            return
        }

        // Single-instance cleanup: terminate any stale BrewGUI instances left running from prior builds
        let currentPID = ProcessInfo.processInfo.processIdentifier
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: "local.orca.BrewGUI")
            where app.processIdentifier != currentPID {
            app.forceTerminate()
        }
    }

    public var body: some Scene {
        WindowGroup("BrewGUI v\(AppConstants.versionString) — Homebrew 管理器", id: "main-window") {
            MainWindowView(store: store)
        }
        .defaultSize(width: 980, height: 640)
    }

    public static func renderTransparentSquircleIcon(srcPath: String, dstPath: String) {
        guard let srcImage = NSImage(contentsOfFile: srcPath) else {
            fputs("Failed to load source image: \(srcPath)\n", stderr)
            exit(1)
        }
        let targetSize = 1024
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: targetSize,
            pixelsHigh: targetSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            exit(1)
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

        let iconRect = NSRect(x: 100, y: 100, width: 824, height: 824)
        let clipPath = NSBezierPath(roundedRect: iconRect, xRadius: 185, yRadius: 185)
        clipPath.addClip()

        let srcSize = srcImage.size
        let cropInset = srcSize.width * 0.153
        let srcRect = NSRect(
            x: cropInset,
            y: cropInset,
            width: srcSize.width - cropInset * 2,
            height: srcSize.height - cropInset * 2
        )
        srcImage.draw(in: iconRect, from: srcRect, operation: .sourceOver, fraction: 1.0)

        NSGraphicsContext.restoreGraphicsState()

        if let pngData = rep.representation(using: .png, properties: [:]) {
            try? pngData.write(to: URL(fileURLWithPath: dstPath))
        }
    }

    @MainActor
    public static func exportProductScreenshots(to outDir: String) async {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)

        let s = BrewStore.shared
        s.isBrewInstalled = true
        s.hasAppManagementPermission = true
        s.isLoadingInstalled = false
        s.isLoadingCatalog = false

        // Curated mainstream Mac apps & CLI tools for clean, privacy-safe beginner screenshots
        let sampleCatalog: [CatalogEntry] = [
            CatalogEntry(name: "google-chrome", displayName: "Google Chrome", type: .cask, desc: "主流跨平台网页浏览器", homepage: "https://www.google.com/chrome/", version: "130.0.6723.92", appBundles: ["Google Chrome.app"]),
            CatalogEntry(name: "wechat", displayName: "WeChat (微信)", type: .cask, desc: "腾讯微信 Mac 桌面客户端", homepage: "https://mac.weixin.qq.com/", version: "4.2.0.12", appBundles: ["WeChat.app"]),
            CatalogEntry(name: "iina", displayName: "IINA", type: .cask, desc: "专为 macOS 设计的现代全能开源视频播放器", homepage: "https://iina.io/", version: "1.5.0", appBundles: ["IINA.app"]),
            CatalogEntry(name: "notion", displayName: "Notion", type: .cask, desc: "集笔记、知识库与任务管理于一体的协作工作区", homepage: "https://www.notion.so/", version: "4.2.1", appBundles: ["Notion.app"]),
            CatalogEntry(name: "raycast", displayName: "Raycast", type: .cask, desc: "极速高效的聚焦启动器与效率工具箱", homepage: "https://raycast.com/", version: "1.86.2", appBundles: ["Raycast.app"]),
            CatalogEntry(name: "visual-studio-code", displayName: "Visual Studio Code", type: .cask, desc: "微软开源代码与文本编辑器", homepage: "https://code.visualstudio.com/", version: "1.144.0", appBundles: ["Visual Studio Code.app"]),
            CatalogEntry(name: "keka", displayName: "Keka", type: .cask, desc: "macOS 必备的高颜值解压缩工具", homepage: "https://www.keka.io/", version: "1.4.6", appBundles: ["Keka.app"]),
            CatalogEntry(name: "appcleaner", displayName: "AppCleaner", type: .cask, desc: "彻底卸载 Mac 应用及残留文件的轻量工具", homepage: "https://freemacsoft.net/appcleaner/", version: "3.7.0", appBundles: ["AppCleaner.app"]),
            CatalogEntry(name: "typora", displayName: "Typora", type: .cask, desc: "所见即所得的极简 Markdown 写作软件", homepage: "https://typora.io/", version: "1.14.15", appBundles: ["Typora.app"]),
            CatalogEntry(name: "obs", displayName: "OBS Studio", type: .cask, desc: "开源高清录屏与直播推流软件", homepage: "https://obsproject.com/", version: "33.0.1", appBundles: ["OBS.app"]),
            CatalogEntry(name: "ffmpeg", displayName: "ffmpeg", type: .formula, desc: "强大的音视频转码与处理命令行工具集", homepage: "https://ffmpeg.org/", version: "7.1_2", appBundles: []),
            CatalogEntry(name: "yt-dlp", displayName: "yt-dlp", type: .formula, desc: "支持上千个网站的高清视频流下载工具", homepage: "https://github.com/yt-dlp/yt-dlp", version: "2026.10.22", appBundles: [])
        ]

        let sampleInstalled: [BrewPackage] = [
            BrewPackage(name: "wechat", displayName: "WeChat (微信)", type: .cask, desc: "腾讯微信 Mac 桌面客户端", homepage: "https://mac.weixin.qq.com/", installedVersion: "4.1.15", latestVersion: "4.2.0.12", isOutdated: true, isPinned: false, isTopLevel: true, appBundles: ["WeChat.app"]),
            BrewPackage(name: "raycast", displayName: "Raycast", type: .cask, desc: "极速高效的聚焦启动器与效率工具箱", homepage: "https://raycast.com/", installedVersion: "1.84.0", latestVersion: "1.86.2", isOutdated: true, isPinned: false, isTopLevel: true, appBundles: ["Raycast.app"]),
            BrewPackage(name: "yt-dlp", displayName: "yt-dlp", type: .formula, desc: "支持上千个网站的高清视频流下载工具", homepage: "https://github.com/yt-dlp/yt-dlp", installedVersion: "2026.09.10", latestVersion: "2026.10.22", isOutdated: true, isPinned: false, isTopLevel: true, appBundles: []),
            BrewPackage(name: "google-chrome", displayName: "Google Chrome", type: .cask, desc: "主流跨平台网页浏览器", homepage: "https://www.google.com/chrome/", installedVersion: "130.0.6723.92", latestVersion: "130.0.6723.92", isOutdated: false, isPinned: false, isTopLevel: true, appBundles: ["Google Chrome.app"]),
            BrewPackage(name: "keka", displayName: "Keka", type: .cask, desc: "macOS 必备的高颜值解压缩工具", homepage: "https://www.keka.io/", installedVersion: "1.4.6", latestVersion: "1.4.6", isOutdated: false, isPinned: false, isTopLevel: true, appBundles: ["Keka.app"]),
            BrewPackage(name: "ffmpeg", displayName: "ffmpeg", type: .formula, desc: "强大的音视频转码与处理命令行工具集", homepage: "https://ffmpeg.org/", installedVersion: "7.1_2", latestVersion: "7.1_2", isOutdated: false, isPinned: true, isTopLevel: true, appBundles: [])
        ]

        let sampleAdopt: [AdoptCandidate] = [
            AdoptCandidate(appName: "IINA.app", appPath: "/Applications/IINA.app", localVersion: "1.5.0", isAppStoreReceiptPresent: false, isIOSWrappedApp: false, caskToken: "iina", caskDisplayName: "IINA", caskVersion: "1.5.0", desc: "专为 macOS 设计的现代全能开源视频播放器", homepage: "https://iina.io/", isIgnored: false),
            AdoptCandidate(appName: "Visual Studio Code.app", appPath: "/Applications/Visual Studio Code.app", localVersion: "1.144.0", isAppStoreReceiptPresent: false, isIOSWrappedApp: false, caskToken: "visual-studio-code", caskDisplayName: "Visual Studio Code", caskVersion: "1.144.0", desc: "微软开源代码与文本编辑器", homepage: "https://code.visualstudio.com/", isIgnored: false),
            AdoptCandidate(appName: "AppCleaner.app", appPath: "/Applications/AppCleaner.app", localVersion: "3.7.0", isAppStoreReceiptPresent: false, isIOSWrappedApp: false, caskToken: "appcleaner", caskDisplayName: "AppCleaner", caskVersion: "3.7.0", desc: "彻底卸载 Mac 应用及残留文件的轻量工具", homepage: "https://freemacsoft.net/appcleaner/", isIgnored: false),
            AdoptCandidate(appName: "Typora.app", appPath: "/Applications/Typora.app", localVersion: "1.14.15", isAppStoreReceiptPresent: false, isIOSWrappedApp: false, caskToken: "typora", caskDisplayName: "Typora", caskVersion: "1.14.15", desc: "所见即所得的极简 Markdown 写作软件", homepage: "https://typora.io/", isIgnored: false),
            AdoptCandidate(appName: "LarkSuite.app", appPath: "/Applications/LarkSuite.app", localVersion: "8.3.21", isAppStoreReceiptPresent: true, isIOSWrappedApp: false, caskToken: "lark", caskDisplayName: "Feishu (飞书)", caskVersion: "8.3.14", desc: "字节跳动飞书办公协作套件（检测到 Mac App Store 商店版收据）", homepage: "https://www.feishu.cn/", isIgnored: false),
            AdoptCandidate(appName: "哔哩哔哩.app", appPath: "/Applications/哔哩哔哩.app", localVersion: "9.17.0", isAppStoreReceiptPresent: false, isIOSWrappedApp: true, caskToken: "bilibili", caskDisplayName: "Bilibili", caskVersion: "1.20.0", desc: "哔哩哔哩客户端（检测到本机为 iPad/iOS 包装应用）", homepage: "https://app.bilibili.com/", isIgnored: false)
        ]

        s.catalogEntries = sampleCatalog
        s.installedPackages = sampleInstalled
        s.adoptCandidates = sampleAdopt
        s.localApplicationsSet = ["Google Chrome.app", "WeChat.app", "Raycast.app", "Keka.app", "IINA.app", "Visual Studio Code.app", "AppCleaner.app", "Typora.app", "LarkSuite.app", "哔哩哔哩.app"]
        s.packageSizesByToken = [
            "wechat": 570_425_344,
            "raycast": 85_983_232,
            "notion": 176_160_768,
            "obs": 298_844_160,
            "iina": 67_108_864,
            "visual-studio-code": 339_738_624
        ]
        s.cachedDownloadFiles = [
            CachedDownloadFile(fileName: "WeChatMac-4.1.15.dmg", fullPath: "/Users/demo/Library/Caches/Homebrew/downloads/WeChatMac-4.1.15.dmg", sizeBytes: 562_036_736, modifiedAt: Date().addingTimeInterval(-86400 * 5)),
            CachedDownloadFile(fileName: "VSCode-darwin-arm64-1.143.0.zip", fullPath: "/Users/demo/Library/Caches/Homebrew/downloads/VSCode-darwin-arm64-1.143.0.zip", sizeBytes: 335_544_320, modifiedAt: Date().addingTimeInterval(-86400 * 8)),
            CachedDownloadFile(fileName: "OBS-Studio-32.1-macos-arm64.dmg", fullPath: "/Users/demo/Library/Caches/Homebrew/downloads/OBS-Studio-32.1-macos-arm64.dmg", sizeBytes: 294_649_856, modifiedAt: Date().addingTimeInterval(-86400 * 12)),
            CachedDownloadFile(fileName: "GoogleChrome-129.0.dmg", fullPath: "/Users/demo/Library/Caches/Homebrew/downloads/GoogleChrome-129.0.dmg", sizeBytes: 230_686_720, modifiedAt: Date().addingTimeInterval(-86400 * 15)),
            CachedDownloadFile(fileName: "Notion-4.1.0-arm64.dmg", fullPath: "/Users/demo/Library/Caches/Homebrew/downloads/Notion-4.1.0-arm64.dmg", sizeBytes: 171_966_464, modifiedAt: Date().addingTimeInterval(-86400 * 20)),
            CachedDownloadFile(fileName: "Raycast_v1.83.0.dmg", fullPath: "/Users/demo/Library/Caches/Homebrew/downloads/Raycast_v1.83.0.dmg", sizeBytes: 83_886_080, modifiedAt: Date().addingTimeInterval(-86400 * 24))
        ]
        s.orphanFormulae = ["libx11", "xorgproto", "bdftopcf"]

        // 1. Search View
        s.selectedTab = .search
        s.catalogTypeFilter = .all
        s.catalogSearchQuery = ""
        s.isTerminalDrawerExpanded = false
        s.currentTask = nil
        s.activeDownloadInfo = nil
        await snapshotView(
            WindowChromeSnapshotWrapper(title: "BrewGUI v\(AppConstants.versionString) — Homebrew 管理器") {
                MainWindowView(store: s)
            },
            size: NSSize(width: 1020, height: 660),
            to: "\(outDir)/search.png"
        )

        // 2. Adoptable View
        s.selectedTab = .search
        s.catalogTypeFilter = .adoptable
        s.catalogSearchQuery = ""
        await snapshotView(
            WindowChromeSnapshotWrapper(title: "BrewGUI v\(AppConstants.versionString) — Homebrew 管理器") {
                MainWindowView(store: s)
            },
            size: NSSize(width: 1020, height: 660),
            to: "\(outDir)/adopt.png"
        )

        // 3. Installed & Updates View (with Terminal Drawer open showing live download progress)
        s.selectedTab = .installed
        s.installedCategory = .all
        s.isTerminalDrawerExpanded = true
        s.currentTask = BrewTaskItem(title: "升级 WeChat (微信)", commandDescription: "brew upgrade --cask wechat", arguments: ["upgrade", "--cask", "wechat"], status: .running)
        s.activeDownloadInfo = ActiveDownloadInfo(
            fileName: "WeChatMac-4.2.0.12.dmg",
            downloadedBytes: 382_730_240,
            totalBytes: 570_425_344,
            speedBytesPerSec: 18_874_368
        )
        s.terminalLog = """
        $ /opt/homebrew/bin/brew upgrade --cask wechat
        ==> Upgrading 1 outdated package:
        wechat 4.1.15 -> 4.2.0.12
        ==> Downloading https://dldir1.qq.com/weixin/mac/WeChatMac.dmg
        """
        await snapshotView(
            WindowChromeSnapshotWrapper(title: "BrewGUI v\(AppConstants.versionString) — Homebrew 管理器") {
                MainWindowView(store: s)
            },
            size: NSSize(width: 1020, height: 660),
            to: "\(outDir)/installed.png"
        )

        // 4. Maintenance & Cleanup View
        s.isTerminalDrawerExpanded = false
        s.currentTask = nil
        s.activeDownloadInfo = nil
        s.selectedTab = .maintenance
        await snapshotView(
            WindowChromeSnapshotWrapper(title: "BrewGUI v\(AppConstants.versionString) — Homebrew 管理器") {
                MainWindowView(store: s)
            },
            size: NSSize(width: 1020, height: 660),
            to: "\(outDir)/maintenance.png"
        )

        // 5. Batch Install View
        s.selectedTab = .batchInstall
        s.batchInputText = """
        brew install --cask notion obs
        iina
        visual-studio-code
        google-chrome
        wechat
        """
        s.parseBatchInput()
        await snapshotView(
            WindowChromeSnapshotWrapper(title: "BrewGUI v\(AppConstants.versionString) — Homebrew 管理器") {
                MainWindowView(store: s)
            },
            size: NSSize(width: 1020, height: 660),
            to: "\(outDir)/batch.png"
        )

        // 6. MenuBar Panel View
        await snapshotView(
            MenuBarPanelView(store: s)
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.25), lineWidth: 1))
                .padding(12),
            size: NSSize(width: 344, height: 430),
            to: "\(outDir)/menubar.png"
        )

        // 7. Missing Homebrew Beginner Guide View
        s.isBrewInstalled = false
        s.copiedInstallCommand = true
        await snapshotView(
            WindowChromeSnapshotWrapper(title: "BrewGUI v\(AppConstants.versionString) — 首次启动环境向导") {
                BrewMissingGuideView(store: s)
            },
            size: NSSize(width: 920, height: 560),
            to: "\(outDir)/guide.png"
        )
        print("Exported 7 screenshots to \(outDir)")
    }

    @MainActor
    private static func snapshotView<V: View>(_ view: V, size: NSSize, to path: String) async {
        NSApp.setActivationPolicy(.accessory)
        let hosting = NSHostingView(rootView: view.environment(\.colorScheme, .light))
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.appearance = NSAppearance(named: .aqua)

        let window = SnapshotKeyWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: .aqua)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        try? await Task.sleep(nanoseconds: 150_000_000)
        hosting.layoutSubtreeIfNeeded()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path))
        }
        window.contentView = nil
        window.orderOut(nil)
    }
}

private final class SnapshotKeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var isKeyWindow: Bool { true }
    override var canBecomeMain: Bool { true }
    override var isMainWindow: Bool { true }
}

private struct WindowChromeSnapshotWrapper<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            // Native-style macOS Window Titlebar
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Circle().fill(Color(red: 1.0, green: 0.37, blue: 0.34)).frame(width: 12, height: 12)
                    Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18)).frame(width: 12, height: 12)
                    Circle().fill(Color(red: 0.15, green: 0.78, blue: 0.25)).frame(width: 12, height: 12)
                }
                Image(systemName: "sidebar.left")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 6)
                Spacer()
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.85))
                Spacer()
                Color.clear.frame(width: 72, height: 12)
            }
            .padding(.horizontal, 16)
            .frame(height: 38)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            content()
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.12), lineWidth: 1)
        )
    }
}
