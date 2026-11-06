import Foundation
import SwiftUI
import AppKit

@MainActor
public final class BrewStore: ObservableObject {
    public static let shared = BrewStore()

    @Published public var installedPackages: [BrewPackage] = []
    @Published public var catalogEntries: [CatalogEntry] = []
    @Published public var adoptCandidates: [AdoptCandidate] = []
    @Published public var ignoredAdoptTokens: Set<String> = []
    @Published public var showIgnoredAdoptCandidates: Bool = false
    @Published public var localApplicationsSet: Set<String> = []

    @Published public var isBrewInstalled: Bool = (BrewCommandRunner.detectBrewExecutablePath() != nil)
    @Published public var copiedInstallCommand: Bool = false

    // App Management Permission state
    @Published public var hasAppManagementPermission: Bool = true

    @Published public var isLoadingInstalled: Bool = false
    @Published public var isLoadingCatalog: Bool = false
    @Published public var lastRefreshedAt: Date?
    @Published public var errorMessage: String?

    // UI Navigation & Filter State (stored on ObservableObject to avoid CommandLineTools missing SwiftUIMacros plugin for @State)
    @Published public var selectedTab: NavigationTab = .search
    @Published public var isSidebarCollapsed: Bool = false

    @Published public var installedSearchText: String = ""
    @Published public var installedCategory: InstalledFilterCategory = .all
    @Published public var showAllDependencies: Bool = false
    @Published public var packagePendingUninstall: BrewPackage?

    @Published public var catalogSearchQuery: String = ""
    @Published public var catalogTypeFilter: SearchTypeFilter = .all

    // Batch Install state
    @Published public var batchInputText: String = ""
    @Published public var batchItems: [BatchInstallItem] = []
    @Published public var batchExportCopiedMessage: String?

    // MenuBar Preferences (Silent Launch at Login & Auto Check Updates)
    @Published public var launchAtLoginSilent: Bool = false {
        didSet {
            guard !isInitializingPreferences else { return }
            updateLaunchAgentPlist(enabled: launchAtLoginSilent)
        }
    }
    @Published public var autoUpdateInterval: AutoUpdateInterval = .off {
        didSet {
            guard !isInitializingPreferences else { return }
            UserDefaults.standard.set(autoUpdateInterval.rawValue, forKey: "BrewGUI.autoUpdateIntervalHours")
            rescheduleAutoUpdateTimer()
        }
    }

    // Task Queue & Terminal Drawer state
    @Published public var taskQueue: [BrewTaskItem] = []
    @Published public var currentTask: BrewTaskItem?
    @Published public var lastFailedOrSkippedTasks: [BrewTaskItem] = []
    @Published public var activeDownloadInfo: ActiveDownloadInfo?
    @Published public var terminalLog: String = ""
    @Published public var isTerminalDrawerExpanded: Bool = false

    // Package Download Size Probing & Maintenance Cache State
    @Published public var packageSizesByToken: [String: Int64] = [:]
    @Published public var isProbingSizes: Bool = false
    @Published public var cachedDownloadFiles: [CachedDownloadFile] = []
    @Published public var orphanFormulae: [String] = []
    @Published public var isScanningOrphans: Bool = false
    @Published public var isProcessingQueue: Bool = false

    private var packageSizesByFileName: [String: Int64] = [:]
    private var stopAllRequested: Bool = false
    private var skipCurrentRequested: Bool = false
    private var isInitializingPreferences: Bool = true
    private var autoUpdateTimer: Timer?
    private var downloadMonitorTimer: Timer?
    private var lastIncompleteSnapshot: (path: String, bytes: Int64, time: Date)?
    private var lastValidDownloadTime: Date?
    private var smoothedSpeedBytesPerSec: Double = 0

    private init() {
        BrewCommandRunner.rotateLogIfNeeded()
        let startStamp = Self.dateTimeFormatter.string(from: Date())
        let brewPath = BrewCommandRunner.detectBrewExecutablePath() ?? "NOT_FOUND"
        let isSilent = CommandLine.arguments.contains("--silent")
        BrewCommandRunner.appendToDiskLog("\n=== [\(startStamp)] BrewGUI v\(AppConstants.versionString) Started (brew: \(brewPath), silent: \(isSilent)) ===\n")
        loadIgnoredAdoptTokens()
        loadMenuBarPreferences()
        if !CommandLine.arguments.contains("--export-screenshots") && !CommandLine.arguments.contains("--self-test") {
            NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self, !self.hasAppManagementPermission else { return }
                    self.recheckAppManagementPermissionSilently()
                }
            }
            Task {
                await initialLoad()
                requestAndCheckAppManagementPermission()
            }
        }
    }

    public var outdatedPackages: [BrewPackage] {
        installedPackages.filter { $0.isOutdated || $0.hasBundleVersionMismatch }
    }

    public var outdatedCount: Int {
        outdatedPackages.count
    }

    public var activeAdoptCandidates: [AdoptCandidate] {
        adoptCandidates.filter { !$0.isIgnored }
    }

    public var ignoredAdoptCandidatesList: [AdoptCandidate] {
        adoptCandidates.filter { $0.isIgnored }
    }

    public var totalCachedDownloadsBytes: Int64 {
        cachedDownloadFiles.reduce(0) { $0 + $1.sizeBytes }
    }

    public func formattedSize(for token: String) -> String? {
        guard let bytes = packageSizesByToken[token.lowercased()], bytes > 0 else { return nil }
        return AppConstants.formatBytes(bytes)
    }

    public func sizeBytes(for token: String) -> Int64? {
        packageSizesByToken[token.lowercased()]
    }

    // MARK: - App Management Permission (macOS Privacy & Security -> App Management)

    /// Proactively probe /Applications bundle write access so macOS triggers the native "BrewGUI would like to update or delete other applications" prompt on first launch rather than failing mid-brew-operation.
    public func requestAndCheckAppManagementPermission() {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: "/Applications") else { return }
        // Pick a non-system third-party .app in /Applications whose Contents directory is owned by the user
        let uid = getuid()
        for item in items where item.hasSuffix(".app") && item != "Safari.app" && item != "BrewGUI.app" {
            let contentsPath = "/Applications/\(item)/Contents"
            guard let attrs = try? fm.attributesOfItem(atPath: contentsPath),
                  let ownerID = attrs[.ownerAccountID] as? NSNumber,
                  ownerID.uint32Value == uid else {
                continue
            }
            // Touching modificationDate or probing a harmless temp file inside a third-party .app bundle triggers the macOS TCC App Management prompt
            let probePath = "\(contentsPath)/.brewgui_permission_probe"
            if fm.createFile(atPath: probePath, contents: Data(), attributes: nil) {
                try? fm.removeItem(atPath: probePath)
                hasAppManagementPermission = true
                BrewCommandRunner.appendToDiskLog("[Permission] App Management permission verified via \(item)\n")
            } else {
                hasAppManagementPermission = false
                BrewCommandRunner.appendToDiskLog("[Permission] App Management permission denied or pending for \(item)\n")
                // Schedule a delayed silent recheck in case macOS TCC was asynchronously validating a newly updated binary signature
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    guard let self, !self.hasAppManagementPermission else { return }
                    self.recheckAppManagementPermissionSilently()
                }
            }
            return
        }
    }

    private func recheckAppManagementPermissionSilently() {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: "/Applications") else { return }
        let uid = getuid()
        for item in items where item.hasSuffix(".app") && item != "Safari.app" && item != "BrewGUI.app" {
            let contentsPath = "/Applications/\(item)/Contents"
            guard let attrs = try? fm.attributesOfItem(atPath: contentsPath),
                  let ownerID = attrs[.ownerAccountID] as? NSNumber,
                  ownerID.uint32Value == uid else {
                continue
            }
            let probePath = "\(contentsPath)/.brewgui_permission_probe"
            if fm.createFile(atPath: probePath, contents: Data(), attributes: nil) {
                try? fm.removeItem(atPath: probePath)
                hasAppManagementPermission = true
                BrewCommandRunner.appendToDiskLog("[Permission] App Management permission verified on recheck via \(item)\n")
            }
            return
        }
    }

    public func openSystemAppManagementSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AppBundles") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Launch at Login (Silent) & Auto Update Timer

    private var launchAgentPlistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/local.orca.BrewGUI.plist")
    }

    private func loadMenuBarPreferences() {
        isInitializingPreferences = true
        defer { isInitializingPreferences = false }

        launchAtLoginSilent = FileManager.default.fileExists(atPath: launchAgentPlistURL.path)
        let savedHours = UserDefaults.standard.integer(forKey: "BrewGUI.autoUpdateIntervalHours")
        autoUpdateInterval = AutoUpdateInterval(rawValue: savedHours) ?? .off
        rescheduleAutoUpdateTimer()
    }

    private func updateLaunchAgentPlist(enabled: Bool) {
        let fm = FileManager.default
        let plistURL = launchAgentPlistURL
        if !enabled {
            try? fm.removeItem(at: plistURL)
            BrewCommandRunner.appendToDiskLog("[Preferences] Disabled LaunchAtLogin (removed \(plistURL.path))\n")
            return
        }

        // Resolve executable path (prefer /Applications/BrewGUI.app if installed there, otherwise current bundle executable)
        let appInApplications = "/Applications/BrewGUI.app/Contents/MacOS/BrewGUI"
        let currentExec = Bundle.main.executablePath ?? ProcessInfo.processInfo.arguments.first ?? appInApplications
        let targetExec = fm.isExecutableFile(atPath: appInApplications) ? appInApplications : currentExec

        let launchAgentsDir = plistURL.deletingLastPathComponent()
        if !fm.fileExists(atPath: launchAgentsDir.path) {
            try? fm.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
        }

        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>local.orca.BrewGUI</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(targetExec)</string>
                <string>--silent</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>ProcessType</key>
            <string>Interactive</string>
        </dict>
        </plist>
        """
        do {
            try plistContent.write(to: plistURL, atomically: true, encoding: .utf8)
            BrewCommandRunner.appendToDiskLog("[Preferences] Enabled silent LaunchAtLogin -> \(targetExec) --silent\n")
        } catch {
            BrewCommandRunner.appendToDiskLog("[Preferences] Failed to write LaunchAgent plist: \(error.localizedDescription)\n")
        }
    }

    private func rescheduleAutoUpdateTimer() {
        autoUpdateTimer?.invalidate()
        autoUpdateTimer = nil

        guard autoUpdateInterval != .off else { return }
        let intervalSeconds = TimeInterval(autoUpdateInterval.rawValue * 3600)

        // Check every 15 minutes whether elapsed time since last auto-check >= intervalSeconds
        autoUpdateTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAndRunScheduledAutoUpdate(intervalSeconds: intervalSeconds)
            }
        }
        // Also check once shortly after startup
        checkAndRunScheduledAutoUpdate(intervalSeconds: intervalSeconds)
    }

    private func checkAndRunScheduledAutoUpdate(intervalSeconds: TimeInterval) {
        guard isBrewInstalled, !isProcessingQueue, taskQueue.isEmpty else { return }
        let lastTs = UserDefaults.standard.double(forKey: "BrewGUI.lastAutoUpdateTimestamp")
        let now = Date().timeIntervalSince1970
        if lastTs == 0 {
            UserDefaults.standard.set(now, forKey: "BrewGUI.lastAutoUpdateTimestamp")
            return
        }
        if now - lastTs >= intervalSeconds {
            UserDefaults.standard.set(now, forKey: "BrewGUI.lastAutoUpdateTimestamp")
            let stamp = Self.dateTimeFormatter.string(from: Date())
            BrewCommandRunner.appendToDiskLog("\n[\(stamp)] [AutoUpdate] Triggered scheduled brew update (interval: \(autoUpdateInterval.label))\n")
            checkUpdates(expandDrawer: false)
        }
    }

    // MARK: - Export Installed Packages as Commands

    /// Generates install commands for top-level installed packages (leaves + casks)
    public func exportInstalledCommands(twoLines: Bool) -> String {
        let formulae = installedPackages
            .filter { $0.type == .formula && $0.isTopLevel }
            .map(\.name)
            .sorted()
        let casks = installedPackages
            .filter { $0.type == .cask }
            .map(\.name)
            .sorted()

        if twoLines {
            var lines: [String] = []
            if !formulae.isEmpty {
                lines.append("brew install " + formulae.joined(separator: " "))
            }
            if !casks.isEmpty {
                lines.append("brew install --cask " + casks.joined(separator: " "))
            }
            return lines.joined(separator: "\n")
        } else {
            let all = formulae + casks
            guard !all.isEmpty else { return "" }
            return "brew install " + all.joined(separator: " ")
        }
    }

    // MARK: - Ignored Adopt Persistence

    private var ignoredAdoptFileURL: URL? {
        try? BrewCommandRunner.appSupportDirectory().appendingPathComponent("ignored_adopt.json")
    }

    private func loadIgnoredAdoptTokens() {
        guard let url = ignoredAdoptFileURL,
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([String].self, from: data) else {
            return
        }
        ignoredAdoptTokens = Set(list)
    }

    private func saveIgnoredAdoptTokens() {
        guard let url = ignoredAdoptFileURL,
              let data = try? JSONEncoder().encode(Array(ignoredAdoptTokens).sorted()) else {
            return
        }
        try? data.write(to: url, options: .atomic)
    }

    public func toggleIgnoreAdoptCandidate(caskToken: String) {
        if ignoredAdoptTokens.contains(caskToken) {
            ignoredAdoptTokens.remove(caskToken)
        } else {
            ignoredAdoptTokens.insert(caskToken)
        }
        saveIgnoredAdoptTokens()
        recomputeAdoptCandidates()
    }

    // MARK: - Brew Detection & Initial Load

    public func recheckBrewInstallation() {
        let detected = BrewCommandRunner.detectBrewExecutablePath()
        isBrewInstalled = (detected != nil)
        let stamp = Self.dateTimeFormatter.string(from: Date())
        BrewCommandRunner.appendToDiskLog("[\(stamp)] [CheckBrew] isBrewInstalled=\(isBrewInstalled), path=\(detected ?? "nil")\n")
        if isBrewInstalled {
            Task {
                await initialLoad()
            }
        }
    }

    public func initialLoad() async {
        let detected = BrewCommandRunner.detectBrewExecutablePath()
        isBrewInstalled = (detected != nil)
        guard isBrewInstalled else {
            return
        }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.refreshInstalled() }
            group.addTask { await self.refreshCatalog(forceRebuild: false) }
            group.addTask { await self.scanOrphanFormulae() }
        }
        scanCachedDownloads()
        recomputeAdoptCandidates()
        probeOutdatedPackageSizes()
        if !batchInputText.isEmpty {
            parseBatchInput()
        }
    }

    // MARK: - Refresh Installed & Leaves

    public func refreshInstalled() async {
        isLoadingInstalled = true
        errorMessage = nil
        defer { isLoadingInstalled = false }

        do {
            async let infoResult = BrewCommandRunner.shared.runCapture(arguments: ["info", "--json=v2", "--installed"])
            async let leavesResult = BrewCommandRunner.shared.runCapture(arguments: ["leaves"])

            let (infoOut, infoErr, infoExit) = try await infoResult
            let (leavesOut, _, _) = try await leavesResult

            guard infoExit == 0 else {
                errorMessage = "获取已安装列表失败: \(infoErr)"
                return
            }

            let leavesText = String(data: leavesOut, encoding: .utf8) ?? ""
            let leavesSet = Set(
                leavesText
                    .split(whereSeparator: \.isNewline)
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )

            let decoded = try JSONDecoder().decode(BrewInstalledResponse.self, from: infoOut)
            var packages: [BrewPackage] = []
            packages.reserveCapacity(decoded.formulae.count + decoded.casks.count)

            for f in decoded.formulae {
                let installedEntry = f.installed.last
                let installedVer = installedEntry?.version ?? ""
                var latestVer = f.versions.stable ?? installedVer
                if let rev = f.revision, rev > 0, !latestVer.hasSuffix("_\(rev)") {
                    latestVer = "\(latestVer)_\(rev)"
                }
                let isLeaf = leavesSet.contains(f.name) || (f.full_name != nil && leavesSet.contains(f.full_name!)) || (installedEntry?.installed_on_request == true && leavesSet.isEmpty)

                packages.append(
                    BrewPackage(
                        name: f.name,
                        displayName: f.name,
                        type: .formula,
                        desc: f.desc ?? "",
                        homepage: f.homepage ?? "",
                        installedVersion: installedVer,
                        actualBundleVersion: nil,
                        latestVersion: latestVer,
                        isOutdated: f.outdated ?? false,
                        isPinned: f.pinned ?? false,
                        isTopLevel: isLeaf,
                        appBundles: []
                    )
                )
            }

            for c in decoded.casks {
                let displayName = c.name?.first ?? c.token
                let installedVer = c.installed ?? ""
                let latestVer = c.version ?? installedVer
                var appBundles: [String] = []

                if let artifacts = c.artifacts {
                    for dict in artifacts {
                        if let appAny = dict["app"]?.value as? [Any] {
                            for item in appAny {
                                if let s = item as? String {
                                    let bundle = (s as NSString).lastPathComponent
                                    if bundle.hasSuffix(".app") {
                                        appBundles.append(bundle)
                                    }
                                }
                            }
                        }
                    }
                }

                // Read actual on-disk Info.plist version from /Applications/<App>.app to detect `--adopt` version mismatch
                var actualBundleVer: String? = nil
                if let firstBundle = appBundles.first {
                    let appPath = FileManager.default.fileExists(atPath: "/Applications/\(firstBundle)")
                        ? "/Applications/\(firstBundle)"
                        : FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/\(firstBundle)").path
                    let plistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")
                    if let dict = NSDictionary(contentsOfFile: plistPath) {
                        actualBundleVer = (dict["CFBundleShortVersionString"] as? String) ?? (dict["CFBundleVersion"] as? String)
                    }
                }

                packages.append(
                    BrewPackage(
                        name: c.token,
                        displayName: displayName,
                        type: .cask,
                        desc: c.desc ?? "",
                        homepage: c.homepage ?? "",
                        installedVersion: installedVer,
                        actualBundleVersion: actualBundleVer,
                        latestVersion: latestVer,
                        isOutdated: c.outdated ?? false,
                        isPinned: false,
                        isTopLevel: true,
                        appBundles: appBundles,
                        downloadURL: c.url
                    )
                )
            }

            packages.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            self.installedPackages = packages
            self.lastRefreshedAt = Date()
            self.scanLocalApplications()
            self.scanCachedDownloads()
            self.recomputeAdoptCandidates()
            self.probeOutdatedPackageSizes()
            if !batchInputText.isEmpty {
                parseBatchInput()
            }
        } catch {
            errorMessage = "解析 Homebrew 状态失败: \(error.localizedDescription)"
        }
    }

    // MARK: - Refresh Catalog & Scan /Applications

    public func refreshCatalog(forceRebuild: Bool) async {
        isLoadingCatalog = true
        defer { isLoadingCatalog = false }

        do {
            let entries = try await BrewCatalogService.shared.loadCatalog(forceRebuild: forceRebuild)
            self.catalogEntries = entries
            self.scanLocalApplications()
            self.recomputeAdoptCandidates()
            self.probeOutdatedPackageSizes()
            if !batchInputText.isEmpty {
                parseBatchInput()
            }
        } catch {
            appendLog("[警告] 加载本地全量索引失败: \(error.localizedDescription)\n")
        }
    }

    public func scanLocalApplications() {
        let fm = FileManager.default
        let appDirs = ["/Applications", fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path]
        var found: Set<String> = []

        for dir in appDirs {
            guard let items = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in items where item.hasSuffix(".app") {
                found.insert(item)
            }
        }
        self.localApplicationsSet = found
    }

    public func recomputeAdoptCandidates() {
        let fm = FileManager.default
        let installedCaskTokens = Set(installedPackages.filter { $0.type == .cask }.map { $0.name })
        let managedAppBundles = Set(installedPackages.filter { $0.type == .cask }.flatMap { $0.appBundles })

        var candidatesByApp: [String: CatalogEntry] = [:]

        for entry in catalogEntries where entry.type == .cask {
            guard !installedCaskTokens.contains(entry.name) else { continue }
            for appBundle in entry.appBundles {
                guard localApplicationsSet.contains(appBundle),
                      !managedAppBundles.contains(appBundle) else { continue }

                if let existing = candidatesByApp[appBundle] {
                    let existingIsVariant = existing.name.contains("@")
                    let currentIsVariant = entry.name.contains("@")
                    if existingIsVariant && !currentIsVariant {
                        candidatesByApp[appBundle] = entry
                    }
                } else {
                    candidatesByApp[appBundle] = entry
                }
            }
        }

        var list: [AdoptCandidate] = []
        for (appBundle, entry) in candidatesByApp {
            let appPath = fm.fileExists(atPath: "/Applications/\(appBundle)")
                ? "/Applications/\(appBundle)"
                : (fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications/\(appBundle)").path)

            // Detect iOS-on-Mac wrapped bundle or standard macOS bundle
            let wrappedPlistPath = (appPath as NSString).appendingPathComponent("WrappedBundle/Info.plist")
            let standardPlistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")
            let isIOSWrapped = fm.fileExists(atPath: (appPath as NSString).appendingPathComponent("WrappedBundle"))
            let plistPath = fm.fileExists(atPath: standardPlistPath) ? standardPlistPath : wrappedPlistPath

            var localVer: String? = nil
            if let dict = NSDictionary(contentsOfFile: plistPath) {
                localVer = (dict["CFBundleShortVersionString"] as? String) ?? (dict["CFBundleVersion"] as? String)
            }

            let masReceiptPath = (appPath as NSString).appendingPathComponent("Contents/_MASReceipt/receipt")
            let iOSReceiptPath = (appPath as NSString).appendingPathComponent("WrappedBundle/_MASReceipt/receipt")
            let hasMASReceipt = fm.fileExists(atPath: masReceiptPath) || fm.fileExists(atPath: iOSReceiptPath)

            list.append(
                AdoptCandidate(
                    appName: appBundle,
                    appPath: appPath,
                    localVersion: localVer,
                    isAppStoreReceiptPresent: hasMASReceipt,
                    isIOSWrappedApp: isIOSWrapped,
                    caskToken: entry.name,
                    caskDisplayName: entry.displayName,
                    caskVersion: entry.version,
                    desc: entry.desc,
                    homepage: entry.homepage,
                    isIgnored: ignoredAdoptTokens.contains(entry.name)
                )
            )
        }

        list.sort { $0.appName.localizedStandardCompare($1.appName) == .orderedAscending }
        self.adoptCandidates = list
    }

    public func installedPackage(for entry: CatalogEntry) -> BrewPackage? {
        installedPackages.first { $0.type == entry.type && $0.name == entry.name }
    }

    public func adoptableAppName(for entry: CatalogEntry) -> String? {
        guard entry.type == .cask,
              installedPackage(for: entry) == nil,
              !ignoredAdoptTokens.contains(entry.name) else { return nil }
        let managedAppBundles = Set(installedPackages.filter { $0.type == .cask }.flatMap { $0.appBundles })
        for bundle in entry.appBundles {
            if localApplicationsSet.contains(bundle) && !managedAppBundles.contains(bundle) {
                return bundle
            }
        }
        return nil
    }

    // MARK: - Batch Install Parsing & Execution

    public func parseBatchInput() {
        // Strip common prefixes like `brew install`, `--cask`, `--formula` and split by whitespace, commas, semicolons, newlines
        let stopWords: Set<String> = ["brew", "install", "reinstall", "--cask", "--casks", "--formula", "--formulae", "--adopt", "-f", "$"]
        let rawTokens = batchInputText
            .components(separatedBy: CharacterSet(charactersIn: " \t\r\n,;，；\"'`"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !stopWords.contains($0.lowercased()) }

        // Deduplicate while preserving order
        var seen = Set<String>()
        var uniqueTokens: [String] = []
        for t in rawTokens {
            let key = t.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                uniqueTokens.append(t)
            }
        }

        // Build fast lookup maps
        var formulaByName: [String: CatalogEntry] = [:]
        var caskByName: [String: CatalogEntry] = [:]
        var entryByDisplayName: [String: CatalogEntry] = [:]

        for entry in catalogEntries {
            let lowerName = entry.name.lowercased()
            let lowerDisplay = entry.displayName.lowercased()
            if entry.type == .formula {
                formulaByName[lowerName] = entry
            } else {
                caskByName[lowerName] = entry
            }
            if entryByDisplayName[lowerDisplay] == nil {
                entryByDisplayName[lowerDisplay] = entry
            }
        }

        var parsed: [BatchInstallItem] = []
        for token in uniqueTokens {
            let lower = token.lowercased()
            // Support explicit prefix like cask:wechat or homebrew/cask/wechat
            let cleanToken = (lower as NSString).lastPathComponent

            if let inst = installedPackages.first(where: { $0.name.lowercased() == cleanToken || $0.displayName.lowercased() == lower }) {
                parsed.append(
                    BatchInstallItem(
                        id: token,
                        rawToken: token,
                        status: .alreadyInstalled(inst),
                        isSelected: false,
                        useAdoptIfAvailable: false
                    )
                )
                continue
            }

            let matchedEntry: CatalogEntry? = {
                if lower.hasPrefix("cask:") || lower.contains("homebrew/cask/") {
                    return caskByName[cleanToken]
                }
                if lower.hasPrefix("formula:") || lower.contains("homebrew/core/") {
                    return formulaByName[cleanToken]
                }
                return formulaByName[cleanToken] ?? caskByName[cleanToken] ?? entryByDisplayName[lower]
            }()

            if let entry = matchedEntry {
                if let adoptApp = adoptableAppName(for: entry) {
                    parsed.append(
                        BatchInstallItem(
                            id: token,
                            rawToken: token,
                            status: .readyToAdopt(entry, adoptApp),
                            isSelected: true,
                            useAdoptIfAvailable: true
                        )
                    )
                } else {
                    parsed.append(
                        BatchInstallItem(
                            id: token,
                            rawToken: token,
                            status: .readyToInstall(entry),
                            isSelected: true,
                            useAdoptIfAvailable: false
                        )
                    )
                }
            } else {
                parsed.append(
                    BatchInstallItem(
                        id: token,
                        rawToken: token,
                        status: .notFound,
                        isSelected: false,
                        useAdoptIfAvailable: false
                    )
                )
            }
        }

        self.batchItems = parsed
        probeBatchPackageSizes()
    }

    public func toggleBatchItemSelection(id: String) {
        guard let idx = batchItems.firstIndex(where: { $0.id == id }) else { return }
        batchItems[idx].isSelected.toggle()
    }

    /// Selects only Formulae and Casks whose probed size is <= maxBytes (default 100 MB), unchecking large Cask installers.
    public func selectOnlyLightweightBatchItems(maxBytes: Int64 = 100 * 1024 * 1024) {
        for idx in batchItems.indices {
            switch batchItems[idx].status {
            case .readyToInstall(let entry), .readyToAdopt(let entry, _):
                if entry.type == .formula {
                    batchItems[idx].isSelected = true
                } else if let knownBytes = sizeBytes(for: entry.name) {
                    batchItems[idx].isSelected = (knownBytes <= maxBytes)
                } else {
                    batchItems[idx].isSelected = true
                }
            case .alreadyInstalled, .notFound:
                batchItems[idx].isSelected = false
            }
        }
    }

    public func executeSelectedBatchInstall() {
        let selected = batchItems.filter { $0.isSelected }
        guard !selected.isEmpty else { return }

        // 1. Merge all selected Formulae into a single `brew install --formula f1 f2 ...` command for unified dependency resolution
        var formulaEntries: [CatalogEntry] = []
        for item in selected {
            if case .readyToInstall(let entry) = item.status, entry.type == .formula {
                formulaEntries.append(entry)
            }
        }
        if formulaEntries.count == 1 {
            installCatalogEntry(formulaEntries[0])
        } else if formulaEntries.count > 1 {
            let names = formulaEntries.map(\.name)
            let preview = names.prefix(3).joined(separator: ", ") + (names.count > 3 ? " 等" : "")
            enqueueTask(
                title: "批量安装 \(names.count) 个 Formula (\(preview))",
                arguments: ["install", "--formula"] + names
            )
        }

        // 2. Enqueue each selected Cask as an independent task so completed Casks take effect immediately and any slow Cask can be skipped individually
        for item in selected {
            switch item.status {
            case .readyToInstall(let entry) where entry.type == .cask:
                installCatalogEntry(entry)
            case .readyToAdopt(let entry, let localApp):
                if item.useAdoptIfAvailable {
                    let candidate = adoptCandidates.first { $0.caskToken == entry.name }
                    let forceUpgrade = candidate?.isLocalOlderThanCask ?? false
                    adoptCask(
                        token: entry.name,
                        displayName: entry.displayName,
                        appBundles: [localApp],
                        forceOverwriteToUpgrade: forceUpgrade
                    )
                } else {
                    installCatalogEntry(entry, forceOverwrite: true)
                }
            default:
                break
            }
        }
    }

    // MARK: - Package Size Probing (HTTP HEAD Content-Length)

    public func probeOutdatedPackageSizes() {
        let catalogMap = Dictionary(uniqueKeysWithValues: catalogEntries.map { ($0.name.lowercased(), $0.downloadURL) })
        var targets: [(token: String, urlString: String?)] = []
        for pkg in outdatedPackages {
            let url = pkg.downloadURL ?? catalogMap[pkg.name.lowercased()] ?? nil
            targets.append((pkg.name.lowercased(), url))
        }
        probePackageSizes(items: targets)
    }

    public func probeBatchPackageSizes() {
        var targets: [(token: String, urlString: String?)] = []
        for item in batchItems {
            switch item.status {
            case .readyToInstall(let entry), .readyToAdopt(let entry, _):
                targets.append((entry.name.lowercased(), entry.downloadURL))
            default:
                break
            }
        }
        probePackageSizes(items: targets)
    }

    public func probePackageSizes(items: [(token: String, urlString: String?)]) {
        let pending = items.filter { item in
            packageSizesByToken[item.token] == nil && (item.urlString != nil && !(item.urlString?.isEmpty ?? true))
        }
        guard !pending.isEmpty else { return }

        isProbingSizes = true
        Task {
            await withTaskGroup(of: (String, String?, Int64?).self) { group in
                var inFlight = 0
                for item in pending {
                    if inFlight >= 6 {
                        if let (tok, fileName, bytes) = await group.next(), let bytes, bytes > 0 {
                            self.packageSizesByToken[tok] = bytes
                            if let fileName, !fileName.isEmpty {
                                self.packageSizesByFileName[fileName] = bytes
                            }
                        }
                        inFlight -= 1
                    }
                    inFlight += 1
                    let token = item.token
                    let urlStr = item.urlString ?? ""
                    let fileName = URL(string: urlStr)?.lastPathComponent.lowercased()
                    group.addTask {
                        let size = await Self.fetchContentLength(urlString: urlStr)
                        return (token, fileName, size)
                    }
                }
                for await (tok, fileName, bytes) in group {
                    if let bytes, bytes > 0 {
                        self.packageSizesByToken[tok] = bytes
                        if let fileName, !fileName.isEmpty {
                            self.packageSizesByFileName[fileName] = bytes
                        }
                    }
                }
            }
            self.isProbingSizes = false
        }
    }

    private static func fetchContentLength(urlString: String) async -> Int64? {
        guard let url = URL(string: urlString) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "HEAD"
        req.timeoutInterval = 5.0
        req.setValue("Homebrew/7.0 (Macintosh; arm64 Mac OS X) curl/8.7.1", forHTTPHeaderField: "User-Agent")
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse,
               (200...399).contains(http.statusCode),
               http.expectedContentLength > 1024 {
                return http.expectedContentLength
            }
        } catch {
            return nil
        }
        return nil
    }

    // MARK: - Maintenance & Cache Cleanup (3rd Tab)

    public func scanCachedDownloads() {
        let fm = FileManager.default
        let downloadsDir = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches/Homebrew/downloads", isDirectory: true)
        guard let urls = try? fm.contentsOfDirectory(
            at: downloadsDir,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else {
            cachedDownloadFiles = []
            return
        }

        var files: [CachedDownloadFile] = []
        for url in urls {
            let name = url.lastPathComponent
            if name.hasSuffix(".incomplete") { continue }
            guard let vals = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey, .isSymbolicLinkKey]),
                  vals.isRegularFile == true,
                  vals.isSymbolicLink != true else {
                continue
            }
            let size = Int64(vals.fileSize ?? 0)
            guard size > 0 else { continue }
            let mtime = vals.contentModificationDate ?? .distantPast
            let readableName: String = {
                if let range = name.range(of: "--") {
                    return String(name[range.upperBound...])
                }
                return name
            }()
            files.append(
                CachedDownloadFile(
                    fileName: readableName,
                    fullPath: url.path,
                    sizeBytes: size,
                    modifiedAt: mtime
                )
            )
        }
        files.sort { $0.sizeBytes > $1.sizeBytes }
        self.cachedDownloadFiles = files
    }

    public func deleteSingleCachedFile(_ file: CachedDownloadFile) {
        guard !isProcessingQueue else { return }
        try? FileManager.default.removeItem(atPath: file.fullPath)
        scanCachedDownloads()
    }

    public func revealCachedFileInFinder(_ file: CachedDownloadFile) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file.fullPath)])
    }

    public func runCleanupAllCaches() {
        enqueueTask(
            title: "清理全部下载缓存与旧版本 (brew cleanup --prune=all)",
            arguments: ["cleanup", "--prune=all"]
        )
    }

    public func scanOrphanFormulae() async {
        isScanningOrphans = true
        defer { isScanningOrphans = false }

        do {
            let (out, _, exitCode) = try await BrewCommandRunner.shared.runCapture(arguments: ["autoremove", "-n"])
            guard exitCode == 0 else { return }
            let text = String(data: out, encoding: .utf8) ?? ""
            var orphans: [String] = []
            for rawLine in text.split(whereSeparator: \.isNewline) {
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                if line.isEmpty || line.hasPrefix("==>") { continue }
                // Sometimes `brew autoremove -n` lists one package per line or multiple tokens
                for token in line.split(whereSeparator: \.isWhitespace) {
                    let clean = String(token)
                    if !clean.isEmpty {
                        orphans.append(clean)
                    }
                }
            }
            self.orphanFormulae = orphans.sorted()
        } catch {
            self.orphanFormulae = []
        }
    }

    public func runAutoremoveOrphans() {
        enqueueTask(
            title: "清理无用孤儿依赖 (brew autoremove)",
            arguments: ["autoremove"]
        )
    }

    // MARK: - Mutating Commands & Serial Queue

    public func checkUpdates(expandDrawer: Bool = true) {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "BrewGUI.lastAutoUpdateTimestamp")
        enqueueTask(
            title: "检查更新 (brew update)",
            arguments: ["update"],
            allowAutoUpdate: true,
            rebuildCatalogAfter: true,
            expandDrawer: expandDrawer
        )
    }

    public func upgradeAll() {
        // 1. Reinstall any Cask that has a bundle version mismatch due to previous --adopt
        let mismatchedCasks = installedPackages.filter { $0.hasBundleVersionMismatch && !$0.isOutdated }
        for pkg in mismatchedCasks {
            reinstallAndOverwritePackage(pkg)
        }

        // 2. Hybrid scheduling for outdated packages:
        //    - Merge all outdated Formulae into a single fast `brew upgrade --formula f1 f2 ...` command
        //    - Enqueue each outdated Cask as an individual task so slow Cask downloads never block Formulae and can be skipped individually
        let outdatedFormulae = installedPackages.filter { $0.type == .formula && $0.isOutdated && !$0.isPinned }
        let outdatedCasks = installedPackages.filter { $0.type == .cask && $0.isOutdated }

        if outdatedFormulae.count == 1 {
            upgradePackage(outdatedFormulae[0])
        } else if outdatedFormulae.count > 1 {
            let names = outdatedFormulae.map(\.name)
            let preview = names.prefix(3).joined(separator: ", ") + (names.count > 3 ? " 等" : "")
            enqueueTask(
                title: "升级 \(names.count) 个 Formula (\(preview))",
                arguments: ["upgrade", "--formula"] + names
            )
        }

        for caskPkg in outdatedCasks {
            upgradePackage(caskPkg)
        }

        // Fallback if no local outdated flags were set when user explicitly triggered upgradeAll
        if mismatchedCasks.isEmpty && outdatedFormulae.isEmpty && outdatedCasks.isEmpty {
            enqueueTask(
                title: "升级全部可更新包 (brew upgrade)",
                arguments: ["upgrade"]
            )
        }
    }

    public func upgradePackage(_ pkg: BrewPackage) {
        if pkg.type == .cask && pkg.hasBundleVersionMismatch && !pkg.isOutdated {
            reinstallAndOverwritePackage(pkg)
            return
        }
        let args = pkg.type == .cask
            ? ["upgrade", "--cask", pkg.name]
            : ["upgrade", pkg.name]
        enqueueTask(
            title: "升级 \(pkg.displayName)",
            arguments: args,
            appBundlesToQuit: pkg.type == .cask ? pkg.appBundles : [],
            quitReason: "完成升级与文件覆盖"
        )
    }

    public func reinstallAndOverwritePackage(_ pkg: BrewPackage) {
        let args = pkg.type == .cask
            ? ["reinstall", "--cask", "--force", pkg.name]
            : ["reinstall", pkg.name]
        enqueueTask(
            title: "覆盖同步 \(pkg.displayName) 至 \(pkg.latestVersion)",
            arguments: args,
            appBundlesToQuit: pkg.type == .cask ? pkg.appBundles : [],
            quitReason: "完成文件覆盖更新"
        )
    }

    public func uninstallPackage(_ pkg: BrewPackage, zap: Bool = false) {
        var args = pkg.type == .cask
            ? ["uninstall", "--cask"]
            : ["uninstall"]
        if zap && pkg.type == .cask {
            args.append("--zap")
        }
        args.append(pkg.name)
        enqueueTask(
            title: zap ? "彻底卸载 \(pkg.displayName) (--zap)" : "卸载 \(pkg.displayName)",
            arguments: args,
            appBundlesToQuit: pkg.type == .cask ? pkg.appBundles : [],
            quitReason: "完成卸载"
        )
    }

    public func togglePin(_ pkg: BrewPackage) {
        guard pkg.type == .formula else { return }
        let cmd = pkg.isPinned ? "unpin" : "pin"
        let actionLabel = pkg.isPinned ? "解锁版本" : "锁定版本"
        enqueueTask(
            title: "\(actionLabel) \(pkg.name)",
            arguments: [cmd, pkg.name]
        )
    }

    public func installCatalogEntry(_ entry: CatalogEntry, forceOverwrite: Bool = false) {
        var args = entry.type == .cask
            ? ["install", "--cask"]
            : ["install", "--formula"]
        if forceOverwrite && entry.type == .cask {
            args.append("--force")
        }
        args.append(entry.name)
        enqueueTask(
            title: forceOverwrite ? "接管并升级 \(entry.displayName) (--force)" : "安装 \(entry.displayName)",
            arguments: args,
            appBundlesToQuit: (entry.type == .cask && forceOverwrite) ? entry.appBundles : [],
            quitReason: "完成接管与文件覆盖更新"
        )
    }

    public func adoptCask(token: String, displayName: String, appBundles: [String] = [], forceOverwriteToUpgrade: Bool = false) {
        if forceOverwriteToUpgrade {
            enqueueTask(
                title: "接管并升级 \(displayName) (--force 覆盖旧版)",
                arguments: ["install", "--cask", "--force", token],
                appBundlesToQuit: appBundles,
                quitReason: "完成接管与文件覆盖更新"
            )
        } else {
            enqueueTask(
                title: "接管应用 \(displayName) (--adopt 仅认领)",
                arguments: ["install", "--cask", "--adopt", token]
            )
        }
    }

    // MARK: - Task Control: Stop All, Skip Current, Remove Queued, Retry

    public func stopAllTasks() {
        stopAllRequested = true
        var aborted: [BrewTaskItem] = []
        if var running = currentTask, running.status == .running {
            running.status = .cancelled
            aborted.append(running)
        }
        aborted.append(contentsOf: taskQueue)
        taskQueue.removeAll()
        if !aborted.isEmpty {
            lastFailedOrSkippedTasks = aborted
        }
        appendLog("\n[用户操作] ⏹ 已请求停止当前任务并清空等待队列…\n")
        Task {
            await BrewCommandRunner.shared.terminateActiveProcess()
        }
    }

    public func skipCurrentTask() {
        guard let running = currentTask, running.status == .running else { return }
        skipCurrentRequested = true
        appendLog("\n[用户操作] ⏭ 已请求跳过当前任务 (\(running.title))，正在切换至下一队列任务…\n")
        Task {
            await BrewCommandRunner.shared.terminateActiveProcess()
        }
    }

    public func removeQueuedTask(id: UUID) {
        taskQueue.removeAll { $0.id == id }
    }

    public func retryFailedOrSkippedTasks() {
        let toRetry = lastFailedOrSkippedTasks
        guard !toRetry.isEmpty else {
            if let current = currentTask, (current.status == .failed || current.status == .cancelled || current.status == .skipped) {
                enqueueTask(
                    title: current.title,
                    arguments: current.arguments,
                    appBundlesToQuit: current.appBundlesToQuit,
                    quitReason: current.quitReason
                )
            }
            return
        }
        lastFailedOrSkippedTasks.removeAll()
        for item in toRetry {
            enqueueTask(
                title: item.title,
                arguments: item.arguments,
                appBundlesToQuit: item.appBundlesToQuit,
                quitReason: item.quitReason
            )
        }
    }

    // MARK: - Live `.incomplete` Download Progress Monitor

    private func startDownloadMonitor() {
        downloadMonitorTimer?.invalidate()
        lastIncompleteSnapshot = nil
        lastValidDownloadTime = nil
        smoothedSpeedBytesPerSec = 0
        downloadMonitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollIncompleteDownload()
            }
        }
    }

    private func stopDownloadMonitor() {
        downloadMonitorTimer?.invalidate()
        downloadMonitorTimer = nil
        lastIncompleteSnapshot = nil
        lastValidDownloadTime = nil
        smoothedSpeedBytesPerSec = 0
        activeDownloadInfo = nil
    }

    private func pollIncompleteDownload() {
        let fm = FileManager.default
        let downloadsDir = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches/Homebrew/downloads", isDirectory: true)
        guard let urls = try? fm.contentsOfDirectory(
            at: downloadsDir,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            activeDownloadInfo = nil
            return
        }

        let now = Date()
        let incompleteCandidates = urls.compactMap { url -> (url: URL, size: Int64, mtime: Date)? in
            guard url.pathExtension == "incomplete" else { return nil }
            let baseName = url.deletingPathExtension().lastPathComponent
            // Filter out transient small bottle_manifest metadata downloads so UI doesn't flicker
            if baseName.contains("bottle_manifest") { return nil }
            guard let vals = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
                  let mtime = vals.contentModificationDate,
                  now.timeIntervalSince(mtime) < 120 else {
                return nil
            }
            let size = Int64(vals.fileSize ?? 0)
            guard size > 0 else { return nil }
            return (url, size, mtime)
        }

        guard let active = incompleteCandidates.max(by: { $0.mtime < $1.mtime }) else {
            // Check if the previous .incomplete file was already finalized into its target file (meaning download finished and extraction started)
            if let prev = lastIncompleteSnapshot {
                let finalizedPath = (prev.path as NSString).deletingPathExtension
                if fm.fileExists(atPath: finalizedPath) {
                    activeDownloadInfo = nil
                    lastValidDownloadTime = nil
                    return
                }
            }
            // Otherwise debounce brief <2s inter-package gaps
            if let lastTime = lastValidDownloadTime, now.timeIntervalSince(lastTime) < 2.0 {
                return
            }
            activeDownloadInfo = nil
            return
        }

        let rawName = active.url.deletingPathExtension().lastPathComponent
        let cleanFileName: String = {
            if let range = rawName.range(of: "--") {
                return String(rawName[range.upperBound...])
            }
            return rawName
        }()

        // Calculate speed
        var speed: Double = smoothedSpeedBytesPerSec
        if let prev = lastIncompleteSnapshot, prev.path == active.url.path {
            let dt = now.timeIntervalSince(prev.time)
            if dt >= 0.4 {
                let deltaBytes = max(0, active.size - prev.bytes)
                let instantSpeed = Double(deltaBytes) / dt
                if smoothedSpeedBytesPerSec <= 0 {
                    smoothedSpeedBytesPerSec = instantSpeed
                } else {
                    smoothedSpeedBytesPerSec = smoothedSpeedBytesPerSec * 0.6 + instantSpeed * 0.4
                }
                speed = smoothedSpeedBytesPerSec
                lastIncompleteSnapshot = (active.url.path, active.size, now)
            }
        } else {
            smoothedSpeedBytesPerSec = 0
            speed = 0
            lastIncompleteSnapshot = (active.url.path, active.size, now)
        }

        // Deterministic matching of expected totalBytes:
        // 1. Exact URL filename match from packageSizesByFileName
        // 2. Explicit package token from currentTask.arguments
        let lowerFile = cleanFileName.lowercased()
        var matchedTotal: Int64? = nil
        if let byFile = packageSizesByFileName[lowerFile], byFile >= active.size {
            matchedTotal = byFile
        }
        if matchedTotal == nil, let current = currentTask {
            for arg in current.arguments.reversed() where !arg.hasPrefix("-") {
                if let known = packageSizesByToken[arg.lowercased()], known >= active.size {
                    matchedTotal = known
                    break
                }
            }
        }

        lastValidDownloadTime = now
        activeDownloadInfo = ActiveDownloadInfo(
            fileName: cleanFileName,
            downloadedBytes: active.size,
            totalBytes: matchedTotal,
            speedBytesPerSec: speed
        )
    }

    /// Gracefully ask running macOS applications matching `appBundles` to terminate right before Cask execution starts so the new binary takes effect and in-memory state doesn't conflict.
    private func quitRunningAppsIfNeeded(appBundles: [String], reason: String) {
        guard !appBundles.isEmpty else { return }
        let targetNames = Set(appBundles.map { ($0 as NSString).deletingPathExtension.lowercased() })
        for runningApp in NSWorkspace.shared.runningApplications {
            guard let bundleURL = runningApp.bundleURL else { continue }
            let bundleFile = bundleURL.lastPathComponent
            let execName = (bundleFile as NSString).deletingPathExtension.lowercased()
            if appBundles.contains(bundleFile) || targetNames.contains(execName) {
                appendLog("[提示] 检测到 \(bundleFile) 正在运行，正在请求安全退出以\(reason)…\n")
                runningApp.terminate()
            }
        }
    }

    public func clearTerminalLog() {
        terminalLog = ""
    }

    private func enqueueTask(
        title: String,
        arguments: [String],
        appBundlesToQuit: [String] = [],
        quitReason: String = "完成升级与文件覆盖",
        allowAutoUpdate: Bool = false,
        rebuildCatalogAfter: Bool = false,
        expandDrawer: Bool = true
    ) {
        let cmdString = "brew " + arguments.joined(separator: " ")
        let item = BrewTaskItem(
            title: title,
            commandDescription: cmdString,
            arguments: arguments,
            appBundlesToQuit: appBundlesToQuit,
            quitReason: quitReason
        )
        taskQueue.append(item)
        if expandDrawer {
            isTerminalDrawerExpanded = true
        }

        if !isProcessingQueue {
            Task {
                await processQueue(allowAutoUpdate: allowAutoUpdate, rebuildCatalogAfter: rebuildCatalogAfter)
            }
        }
    }

    private func processQueue(allowAutoUpdate: Bool, rebuildCatalogAfter: Bool) async {
        guard !isProcessingQueue else { return }
        isProcessingQueue = true
        stopAllRequested = false
        skipCurrentRequested = false
        startDownloadMonitor()
        defer {
            stopDownloadMonitor()
            isProcessingQueue = false
        }

        var needsCatalogRebuild = rebuildCatalogAfter

        while !taskQueue.isEmpty {
            if stopAllRequested {
                taskQueue.removeAll()
                break
            }

            var task = taskQueue.removeFirst()
            task.status = .running
            task.startedAt = Date()
            currentTask = task
            skipCurrentRequested = false

            let timestamp = Self.dateTimeFormatter.string(from: Date())
            appendLog("\n[\(timestamp)] $ \(task.commandDescription)\n")

            if !task.appBundlesToQuit.isEmpty {
                quitRunningAppsIfNeeded(appBundles: task.appBundlesToQuit, reason: task.quitReason)
            }

            let isUpdateCommand = task.arguments.first == "update"
            if isUpdateCommand {
                needsCatalogRebuild = true
            }

            do {
                let exitCode = try await BrewCommandRunner.shared.runStreaming(
                    arguments: task.arguments,
                    allowAutoUpdate: isUpdateCommand || allowAutoUpdate
                ) { [weak self] chunk in
                    Task { @MainActor in
                        self?.appendLog(chunk)
                    }
                }

                task.exitCode = exitCode
                task.finishedAt = Date()

                let endStamp = Self.dateTimeFormatter.string(from: Date())
                if stopAllRequested {
                    task.status = .cancelled
                    currentTask = task
                    appendLog("[\(endStamp)] ⏹ 已停止 (\(task.title))\n")
                    break
                } else if skipCurrentRequested {
                    task.status = .skipped
                    currentTask = task
                    if !lastFailedOrSkippedTasks.contains(where: { $0.commandDescription == task.commandDescription }) {
                        lastFailedOrSkippedTasks.append(task)
                    }
                    appendLog("[\(endStamp)] ⏭ 已跳过 (\(task.title))\n")
                } else if exitCode == 0 {
                    task.status = .succeeded
                    currentTask = task
                    lastFailedOrSkippedTasks.removeAll { $0.commandDescription == task.commandDescription }
                    appendLog("[\(endStamp)] ✓ 完成 (\(task.title))\n")
                } else {
                    task.status = .failed
                    currentTask = task
                    if !lastFailedOrSkippedTasks.contains(where: { $0.commandDescription == task.commandDescription }) {
                        lastFailedOrSkippedTasks.append(task)
                    }
                    appendLog("[\(endStamp)] ✗ 失败，退出码 \(exitCode) (\(task.title))\n")
                }
            } catch {
                task.status = .failed
                task.finishedAt = Date()
                currentTask = task
                if !lastFailedOrSkippedTasks.contains(where: { $0.commandDescription == task.commandDescription }) {
                    lastFailedOrSkippedTasks.append(task)
                }
                appendLog("\n[错误] 无法启动命令: \(error.localizedDescription)\n")
            }
        }

        // Unified state refresh once the entire taskQueue finishes or stops
        await refreshInstalled()
        await scanOrphanFormulae()
        scanCachedDownloads()
        if needsCatalogRebuild {
            await refreshCatalog(forceRebuild: true)
        }
    }

    private func appendLog(_ text: String) {
        terminalLog.append(text)
        BrewCommandRunner.appendToDiskLog(text)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()
}
