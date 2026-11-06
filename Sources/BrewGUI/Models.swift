import Foundation

public enum AppConstants {
    /// 版本格式: 版本号.修订号(用法兼容的修订).日期号(YYMMDD)
    public static let versionString = "1.5.261105"

    public static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

public enum AutoUpdateInterval: Int, CaseIterable, Identifiable, Sendable {
    case off = 0
    case hours12 = 12
    case hours72 = 72

    public var id: Int { rawValue }

    public var label: String {
        switch self {
        case .off: return "关闭"
        case .hours12: return "12小时"
        case .hours72: return "72小时"
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

    /// True if the local .app version is older than the Homebrew Cask version (meaning `--adopt` would leave the old binary on disk while marking the new version as installed)
    public var isLocalOlderThanCask: Bool {
        guard let local = localVersion, !local.isEmpty, !caskVersion.isEmpty else { return false }
        let caskPrimary = caskVersion.split(separator: ",").first.map(String.init) ?? caskVersion
        if local == caskPrimary || caskPrimary.hasPrefix(local + ".") {
            return false
        }
        return local.compare(caskPrimary, options: .numeric) == .orderedAscending
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
        let speedStr = speedBytesPerSec > 0 ? "\(AppConstants.formatBytes(Int64(speedBytesPerSec)))/s" : "计算速度中…"
        if let total = totalBytes, total > 0 {
            let totalStr = AppConstants.formatBytes(total)
            let pct = Int(min(100, max(0, (Double(downloadedBytes) / Double(total)) * 100)))
            return "\(fileName): \(dlStr) / \(totalStr) (\(pct)%) · \(speedStr)"
        } else {
            return "\(fileName): 已下载 \(dlStr) · \(speedStr)"
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

    public init(
        name: String,
        displayName: String,
        type: PackageType,
        desc: String,
        homepage: String,
        version: String,
        appBundles: [String],
        downloadURL: String? = nil
    ) {
        self.name = name
        self.displayName = displayName
        self.type = type
        self.desc = desc
        self.homepage = homepage
        self.version = version
        self.appBundles = appBundles
        self.downloadURL = downloadURL
    }
}

public struct CatalogIndex: Codable, Sendable {
    public let generatedAt: Date
    public let entries: [CatalogEntry]
}
