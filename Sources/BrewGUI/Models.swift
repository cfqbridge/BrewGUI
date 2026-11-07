import Foundation

public enum AppConstants {
    /// 版本格式: 版本号.修订号(用法兼容的修订).日期号(YYMMDD)
    public static let versionString: String = {
        if let shortVer = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, !shortVer.isEmpty {
            return shortVer
        }
        return "2.0.261107"
    }()
    public static let githubVersionJSONURL = "https://github.com/cfqbridge/BrewGUI/releases/latest/download/version.json"
    public static let githubMirrorPrefix = "https://ghfast.top/"

    public static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

public struct RemoteVersionInfo: Codable, Equatable, Sendable {
    public let version: String
    public let release_date: String
    public let download_url: String
    public let sha256: String
    public let release_page: String?

    public init(version: String, release_date: String, download_url: String, sha256: String, release_page: String? = nil) {
        self.version = version
        self.release_date = release_date
        self.download_url = download_url
        self.sha256 = sha256
        self.release_page = release_page
    }
}

public enum AppSelfUpdateState: Equatable, Sendable {
    case idle
    case checking
    case upToDate(String)
    case updateAvailable(RemoteVersionInfo)
    case downloading(RemoteVersionInfo, Double)
    case verifyingAndInstalling(RemoteVersionInfo)
    case failed(String)
}

public enum AutoUpdateInterval: Int, CaseIterable, Identifiable, Sendable {
    case off = 0
    case hours12 = 12
    case hours72 = 72

    public var id: Int { rawValue }

    public var label: String {
        switch self {
        case .off: return tr("关闭", "關閉", "Off")
        case .hours12: return tr("12小时", "12小時", "12h")
        case .hours72: return tr("72小时", "72小時", "72h")
        }
    }
}

public enum BrewMirrorSource: String, CaseIterable, Identifiable, Sendable {
    case auto = "auto"
    case ustc = "ustc"
    case tuna = "tuna"
    case official = "official"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .auto: return tr("自动 (智能测速)", "自動 (智慧測速)", "Auto (Smart Probe)")
        case .ustc: return tr("中科大镜像 (USTC)", "中科大鏡像 (USTC)", "USTC Mirror (China)")
        case .tuna: return tr("清华镜像 (TUNA)", "清華鏡像 (TUNA)", "TUNA Mirror (China)")
        case .official: return tr("官方直连 (GitHub)", "官方直連 (GitHub)", "Official (GitHub)")
        }
    }

    public var shortLabel: String {
        switch self {
        case .auto: return tr("自动", "自動", "Auto")
        case .ustc: return "USTC"
        case .tuna: return "TUNA"
        case .official: return tr("官方", "官方", "Official")
        }
    }

    public var probeURLString: String {
        switch self {
        case .auto, .official:
            return "https://formulae.brew.sh/api/formula_tap_migrations.jws.json"
        case .ustc:
            return "https://mirrors.ustc.edu.cn/homebrew-bottles/api/formula_tap_migrations.jws.json"
        case .tuna:
            return "https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api/formula_tap_migrations.jws.json"
        }
    }

    public var installScriptURLString: String {
        switch self {
        case .ustc, .tuna:
            return "https://mirrors.ustc.edu.cn/misc/brew-install.sh"
        case .auto, .official:
            return "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
        }
    }

    public var environmentVariables: [String: String] {
        switch self {
        case .ustc:
            return [
                "HOMEBREW_API_DOMAIN": "https://mirrors.ustc.edu.cn/homebrew-bottles/api",
                "HOMEBREW_BOTTLE_DOMAIN": "https://mirrors.ustc.edu.cn/homebrew-bottles",
                "HOMEBREW_BREW_GIT_REMOTE": "https://mirrors.ustc.edu.cn/brew.git",
                "HOMEBREW_CORE_GIT_REMOTE": "https://mirrors.ustc.edu.cn/homebrew-core.git"
            ]
        case .tuna:
            return [
                "HOMEBREW_API_DOMAIN": "https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api",
                "HOMEBREW_BOTTLE_DOMAIN": "https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles",
                "HOMEBREW_BREW_GIT_REMOTE": "https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git",
                "HOMEBREW_CORE_GIT_REMOTE": "https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
            ]
        case .auto, .official:
            return [:]
        }
    }
}

public enum HomebrewInstallState: Equatable, Sendable {
    case idle
    case probingMirrors
    case authorizing
    case installing(String)
    case configuringPath
    case succeeded
    case failed(String)

    public var isRunning: Bool {
        switch self {
        case .probingMirrors, .authorizing, .installing, .configuringPath:
            return true
        case .idle, .succeeded, .failed:
            return false
        }
    }
}

public enum PackageType: String, Codable, CaseIterable, Sendable {
    case formula = "Formula"
    case cask = "Cask"
}

public struct BrewPackage: Identifiable, Hashable, Sendable {
    public var id: String { "\(type.rawValue):\(name)" }
    public let name: String          // token for cask, name for formula
    public let displayName: String   // readable name for cask, or name for formula
    public let type: PackageType
    public let desc: String
    public let homepage: String
    public let installedVersion: String?
    public let actualBundleVersion: String? // Actual CFBundleShortVersionString in /Applications/<App>.app if different from installedVersion
    public let latestVersion: String
    public let isOutdated: Bool
    public let isPinned: Bool
    public let isTopLevel: Bool      // leaf or installed on request / cask
    public let appBundles: [String]  // e.g. ["AppCleaner.app"] for Casks
    public let downloadURL: String?  // URL for HEAD Content-Length probing

    public init(
        name: String,
        displayName: String,
        type: PackageType,
        desc: String,
        homepage: String,
        installedVersion: String?,
        actualBundleVersion: String? = nil,
        latestVersion: String,
        isOutdated: Bool,
        isPinned: Bool,
        isTopLevel: Bool,
        appBundles: [String],
        downloadURL: String? = nil
    ) {
        self.name = name
        self.displayName = displayName
        self.type = type
        self.desc = desc
        self.homepage = homepage
        self.installedVersion = installedVersion
        self.actualBundleVersion = actualBundleVersion
        self.latestVersion = latestVersion
        self.isOutdated = isOutdated
        self.isPinned = isPinned
        self.isTopLevel = isTopLevel
        self.appBundles = appBundles
        self.downloadURL = downloadURL
    }

    public var isInstalled: Bool {
        installedVersion != nil
    }

    /// True when --adopt recorded a newer version in Caskroom metadata than the actual .app bundle on disk
    public var hasBundleVersionMismatch: Bool {
        guard type == .cask,
              let actual = actualBundleVersion,
              let recorded = installedVersion,
              !actual.isEmpty,
              !recorded.isEmpty else {
            return false
        }
        // Normalize version strings (e.g. Cask version "4.2.0.12,270348" vs Info.plist "4.2.0", or Cask packaging suffix "156.0.8078.47-1.1" vs "156.0.8078.47")
        let recordedPrimary = recorded.split(separator: ",").first.map(String.init) ?? recorded
        if recordedPrimary == actual
            || recordedPrimary.hasPrefix(actual + ".")
            || recordedPrimary.hasPrefix(actual + "-")
            || recordedPrimary.hasPrefix(actual + "_")
            || actual.hasPrefix(recordedPrimary + ".") {
            return false
        }
        return actual.compare(recordedPrimary, options: .numeric) == .orderedAscending
    }
}

public enum AdoptAdvisoryKind: Sendable, Hashable {
    case safeToAdopt
    case safeToAdoptAndUpgrade
    case cautionProductionVersion
    case suggestIgnoreAppStore
    case suggestIgnoreIOSWrapper
    case suggestIgnoreCaskLagging
    case suggestIgnoreDomesticUpdater
    case suggestIgnoreVersionCollision

    public var recommendsIgnore: Bool {
        switch self {
        case .suggestIgnoreAppStore, .suggestIgnoreIOSWrapper, .suggestIgnoreCaskLagging, .suggestIgnoreDomesticUpdater, .suggestIgnoreVersionCollision:
            return true
        case .safeToAdopt, .safeToAdoptAndUpgrade, .cautionProductionVersion:
            return false
        }
    }

    public var badgeText: String {
        switch self {
        case .safeToAdopt:
            return tr("推荐接管", "推薦接管", "Safe to Adopt")
        case .safeToAdoptAndUpgrade:
            return tr("推荐接管并升级", "推薦接管並升級", "Adopt & Upgrade")
        case .cautionProductionVersion:
            return tr("生产力/插件敏感 · 需保旧版请点忽略或仅认领", "生產力/外掛敏感 · 需保舊版請點忽略或僅認領", "Pro/Plugin App · Ignore or Adopt-Only to keep version")
        case .suggestIgnoreAppStore:
            return tr("建议忽略 · 商店版更新更积极", "建議忽略 · 商店版更新更積極", "Suggest Ignore · App Store channel")
        case .suggestIgnoreIOSWrapper:
            return tr("建议忽略 · iOS/iPad 包装应用", "建議忽略 · iOS/iPad 包裝應用", "Suggest Ignore · iOS Wrapped App")
        case .suggestIgnoreCaskLagging:
            return tr("建议忽略 · 本地版本已新于 Cask", "建議忽略 · 本機版本已新於 Cask", "Suggest Ignore · Local newer than Cask")
        case .suggestIgnoreDomesticUpdater:
            return tr("建议忽略 · 厂商内建热更新更快", "建議忽略 · 廠商內建熱更新更快", "Suggest Ignore · Built-in updater is faster")
        case .suggestIgnoreVersionCollision:
            return tr("⚠️ 建议忽略 · 版本跨度异常/疑似撞库", "⚠️ 建議忽略 · 版本跨度異常/疑似撞庫", "⚠️ Suggest Ignore · Possible Name Collision")
        }
    }
}

public struct AdoptCandidate: Identifiable, Hashable, Sendable {
    public var id: String { caskToken }
    public let appName: String       // e.g. "Visual Studio Code.app"
    public let appPath: String       // e.g. "/Applications/Visual Studio Code.app"
    public let localVersion: String?
    public let isAppStoreReceiptPresent: Bool // true if Contents/_MASReceipt/receipt exists
    public let isIOSWrappedApp: Bool          // true if WrappedBundle or iOS-on-Mac structure detected
    public let caskToken: String     // e.g. "visual-studio-code"
    public let caskDisplayName: String
    public let caskVersion: String
    public let desc: String
    public let homepage: String
    public let isIgnored: Bool

    private static let productionSensitiveTokens: Set<String> = [
        "blender", "ogdesign-eagle", "eagle", "unity", "unity-hub", "unreal-engine",
        "godot", "davinci-resolve", "obs", "kicad", "freecad", "openscad",
        "ableton-live-suite", "ableton-live-standard", "ardour", "reaper",
        "krita", "gimp", "inkscape", "scribus", "darktable", "rawtherapee",
        "docker", "virtualbox", "utm", "vmware-fusion", "parallels"
    ]

    private static let domesticSelfUpdatingTokens: Set<String> = [
        "neteasemusic", "youdaodict", "youdaonote", "wechat", "qq", "qqmusic",
        "kugoumusic", "kuwomusic", "baidunetdisk", "aliyundrive", "dingtalk",
        "feishu", "lark", "tencent-meeting", "voov-meeting", "wpsoffice",
        "wpsoffice-cn", "bilibili", "douyin", "ximalaya", "sogouinput", "eudic",
        "xyplorer", "snipaste", "pixpin"
    ]

    public var caskPrimaryVersion: String {
        caskVersion.split(separator: ",").first.map(String.init) ?? caskVersion
    }

    /// True if the local .app version is older than the Homebrew Cask version (meaning `--adopt` would leave the old binary on disk while marking the new version as installed)
    public var isLocalOlderThanCask: Bool {
        guard let local = localVersion, !local.isEmpty, !caskVersion.isEmpty else { return false }
        let caskPrimary = caskPrimaryVersion
        if local == caskPrimary || caskPrimary.hasPrefix(local + ".") || local.hasPrefix(caskPrimary + ".") {
            return false
        }
        return local.compare(caskPrimary, options: .numeric) == .orderedAscending
    }

    /// True if the local .app version is already newer than the Homebrew Cask version (meaning the app's built-in updater or App Store channel updates faster than Brew Cask)
    public var isLocalNewerThanCask: Bool {
        guard let local = localVersion, !local.isEmpty, !caskVersion.isEmpty else { return false }
        let caskPrimary = caskPrimaryVersion
        if local == caskPrimary || caskPrimary.hasPrefix(local + ".") || local.hasPrefix(caskPrimary + ".") {
            return false
        }
        return local.compare(caskPrimary, options: .numeric) == .orderedDescending
    }

    /// True if local version and Cask version have an abnormally huge major-version discrepancy (e.g. local "1.0.0" vs Cask "741.1" due to name collision or wrapper bundle)
    public var isSuspiciousVersionCollision: Bool {
        guard let local = localVersion, !local.isEmpty, !caskVersion.isEmpty else { return false }
        let localFirst = local.split(whereSeparator: { !$0.isNumber }).first.flatMap { Int($0) }
        let caskFirst = caskPrimaryVersion.split(whereSeparator: { !$0.isNumber }).first.flatMap { Int($0) }
        guard let lMaj = localFirst, let cMaj = caskFirst else { return false }
        // Ignore calendar/year-style versions (e.g. 2024..2030 or 26.x) when both are calendar-like
        if (local == "1.0" || local == "1.0.0") && cMaj >= 5 {
            return true
        }
        if abs(cMaj - lMaj) >= 10 && min(lMaj, cMaj) <= 5 {
            return true
        }
        return false
    }

    public var isProductionVersionSensitive: Bool {
        Self.productionSensitiveTokens.contains(caskToken.lowercased())
    }

    public var isDomesticSelfUpdating: Bool {
        Self.domesticSelfUpdatingTokens.contains(caskToken.lowercased())
    }

    public var advisory: AdoptAdvisoryKind {
        if isIOSWrappedApp {
            return .suggestIgnoreIOSWrapper
        }
        if isAppStoreReceiptPresent {
            return .suggestIgnoreAppStore
        }
        if isSuspiciousVersionCollision {
            return .suggestIgnoreVersionCollision
        }
        if isDomesticSelfUpdating {
            return .suggestIgnoreDomesticUpdater
        }
        if isLocalNewerThanCask {
            return .suggestIgnoreCaskLagging
        }
        if isProductionVersionSensitive {
            return .cautionProductionVersion
        }
        return isLocalOlderThanCask ? .safeToAdoptAndUpgrade : .safeToAdopt
    }

    public var isSuggestedToIgnore: Bool {
        advisory.recommendsIgnore
    }
}

public enum BatchMatchStatus: Sendable, Hashable {
    case readyToInstall(CatalogEntry)
    case readyToAdopt(CatalogEntry, String) // entry, local appName
    case alreadyInstalled(BrewPackage)
    case notFound
}

public struct BatchInstallItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let rawToken: String
    public let status: BatchMatchStatus
    public var isSelected: Bool
    public var useAdoptIfAvailable: Bool
}

public enum TaskStatus: String, Sendable {
    case queued = "排队中"
    case running = "执行中"
    case succeeded = "成功"
    case failed = "失败"
    case cancelled = "已停止"
    case skipped = "已跳过"
}

public struct ActiveDownloadInfo: Equatable, Sendable {
    public let fileName: String
    public let downloadedBytes: Int64
    public let totalBytes: Int64?
    public let speedBytesPerSec: Double

    public var progressFraction: Double? {
        guard let total = totalBytes, total > 0 else { return nil }
        return min(1.0, max(0.0, Double(downloadedBytes) / Double(total)))
    }

    public var formattedSummary: String {
        let dlStr = AppConstants.formatBytes(downloadedBytes)
        let speedStr = speedBytesPerSec > 0
            ? "\(AppConstants.formatBytes(Int64(speedBytesPerSec)))/s"
            : tr("计算速度中…", "計算速度中…", "Calculating…")
        if let total = totalBytes, total > 0 {
            let totalStr = AppConstants.formatBytes(total)
            let pct = Int(min(100, max(0, (Double(downloadedBytes) / Double(total)) * 100)))
            return "\(fileName): \(dlStr) / \(totalStr) (\(pct)%) · \(speedStr)"
        } else {
            return "\(fileName): \(tr("已下载", "已下載", "Downloaded")) \(dlStr) · \(speedStr)"
        }
    }
}

public struct CachedDownloadFile: Identifiable, Hashable, Sendable {
    public var id: String { fullPath }
    public let fileName: String
    public let fullPath: String
    public let sizeBytes: Int64
    public let modifiedAt: Date
}

public struct BrewTaskItem: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let commandDescription: String
    public let arguments: [String]
    public let appBundlesToQuit: [String]
    public let quitReason: String
    public var status: TaskStatus
    public var startedAt: Date?
    public var finishedAt: Date?
    public var exitCode: Int32?

    public init(
        id: UUID = UUID(),
        title: String,
        commandDescription: String,
        arguments: [String],
        appBundlesToQuit: [String] = [],
        quitReason: String = "完成升级与文件覆盖",
        status: TaskStatus = .queued
    ) {
        self.id = id
        self.title = title
        self.commandDescription = commandDescription
        self.arguments = arguments
        self.appBundlesToQuit = appBundlesToQuit
        self.quitReason = quitReason
        self.status = status
    }
}

// MARK: - JSON Decoding Models for `brew info --json=v2 --installed`

struct BrewInstalledResponse: Decodable {
    let formulae: [InstalledFormulaJSON]
    let casks: [InstalledCaskJSON]
}

struct InstalledFormulaJSON: Decodable {
    let name: String
    let full_name: String?
    let desc: String?
    let homepage: String?
    let versions: FormulaVersionsJSON
    let revision: Int?
    let installed: [FormulaInstalledEntryJSON]
    let pinned: Bool?
    let outdated: Bool?
}

struct FormulaVersionsJSON: Decodable {
    let stable: String?
}

struct FormulaInstalledEntryJSON: Decodable {
    let version: String
    let installed_on_request: Bool?
}

struct InstalledCaskJSON: Decodable {
    let token: String
    let name: [String]?
    let desc: String?
    let homepage: String?
    let url: String?
    let version: String?
    let installed: String?
    let outdated: Bool?
    let artifacts: [[String: AnyCodable]]?
}

struct AnyCodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            value = str
        } else if let arr = try? container.decode([AnyCodable].self) {
            value = arr.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else {
            value = ""
        }
    }
}

// MARK: - Local Metadata Index Model

public struct CatalogEntry: Codable, Identifiable, Hashable, Sendable {
    public var id: String { "\(type.rawValue):\(name)" }
    public let name: String
    public let displayName: String
    public let type: PackageType
    public let desc: String
    public let homepage: String
    public let version: String
    public let appBundles: [String]
    public let downloadURL: String?
    public let zapTrashPaths: [String]?

    public init(
        name: String,
        displayName: String,
        type: PackageType,
        desc: String,
        homepage: String,
        version: String,
        appBundles: [String],
        downloadURL: String? = nil,
        zapTrashPaths: [String]? = nil
    ) {
        self.name = name
        self.displayName = displayName
        self.type = type
        self.desc = desc
        self.homepage = homepage
        self.version = version
        self.appBundles = appBundles
        self.downloadURL = downloadURL
        self.zapTrashPaths = zapTrashPaths
    }
}

public struct CatalogIndex: Codable, Sendable {
    public let generatedAt: Date
    public let entries: [CatalogEntry]
}

// MARK: - v2.0 Advanced Maintenance Models (Leftovers, Services, Doctor & Taps)

public enum MaintenanceSubTab: String, CaseIterable, Identifiable, Sendable {
    case cacheAndOrphans = "cache"
    case appLeftovers = "leftovers"
    case services = "services"
    case doctorAndTaps = "doctor"

    public var id: String { rawValue }

    public var localizedLabel: String {
        switch self {
        case .cacheAndOrphans:
            return tr("缓存与依赖", "快取與依賴", "Caches & Orphans")
        case .appLeftovers:
            return tr("卸载残留", "殘留清理", "Leftovers")
        case .services:
            return tr("后台服务", "背景服務", "Services")
        case .doctorAndTaps:
            return tr("体检与 Tap", "體檢與 Tap", "Doctor & Taps")
        }
    }
}

public struct AppLeftoverItem: Identifiable, Hashable, Sendable {
    public var id: String { fullPath }
    public let caskToken: String
    public let caskDisplayName: String
    public let displayPath: String
    public let fullPath: String
    public let sizeBytes: Int64
    public let modifiedAt: Date
    public var isSelected: Bool

    public init(
        caskToken: String,
        caskDisplayName: String,
        displayPath: String,
        fullPath: String,
        sizeBytes: Int64,
        modifiedAt: Date,
        isSelected: Bool = true
    ) {
        self.caskToken = caskToken
        self.caskDisplayName = caskDisplayName
        self.displayPath = displayPath
        self.fullPath = fullPath
        self.sizeBytes = sizeBytes
        self.modifiedAt = modifiedAt
        self.isSelected = isSelected
    }
}

public struct BrewServiceItem: Codable, Identifiable, Hashable, Sendable {
    public var id: String { name }
    public let name: String
    public let status: String
    public let user: String?
    public let file: String?
    public let exit_code: Int?

    public init(name: String, status: String, user: String? = nil, file: String? = nil, exit_code: Int? = nil) {
        self.name = name
        self.status = status
        self.user = user
        self.file = file
        self.exit_code = exit_code
    }

    public var isRunning: Bool {
        status.lowercased() == "started" || status.lowercased() == "scheduled"
    }

    public var isError: Bool {
        status.lowercased() == "error" || (exit_code != nil && exit_code != 0 && !isRunning)
    }

    public var statusBadgeText: String {
        switch status.lowercased() {
        case "started":
            return tr("运行中 (Started)", "執行中 (Started)", "Running (Started)")
        case "scheduled":
            return tr("定时调度 (Scheduled)", "排程中 (Scheduled)", "Scheduled")
        case "stopped", "none":
            return tr("未运行 (Stopped)", "未執行 (Stopped)", "Stopped")
        case "error":
            if let code = exit_code {
                return tr("异常退出 (Exit \(code))", "異常結束 (Exit \(code))", "Error (Exit \(code))")
            }
            return tr("异常 (Error)", "異常 (Error)", "Error")
        default:
            return status
        }
    }
}

public enum BrewDoctorState: Equatable, Sendable {
    case idle
    case running
    case healthy(String)
    case warnings([String], String)
    case failed(String)

    public var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
}
