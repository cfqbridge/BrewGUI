import Foundation

public enum ResolvedLanguage: String, Sendable {
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
    case en = "en"
}

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system = "system"
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
    case en = "en"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system:
            return tr("跟随系统", "跟隨系統", "System")
        case .zhHans:
            return "简体中文"
        case .zhHant:
            return "繁體中文"
        case .en:
            return "English"
        }
    }

    public var shortBadgeLabel: String {
        switch resolved {
        case .zhHans: return "简"
        case .zhHant: return "繁"
        case .en: return "EN"
        }
    }

    public var resolved: ResolvedLanguage {
        switch self {
        case .zhHans:
            return .zhHans
        case .zhHant:
            return .zhHant
        case .en:
            return .en
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            let lower = preferred.lowercased()
            if lower.contains("hant") || lower.contains("tw") || lower.contains("hk") || lower.contains("mo") {
                return .zhHant
            } else if lower.hasPrefix("zh") {
                return .zhHans
            } else {
                return .en
            }
        }
    }

    private static let userDefaultsKey = "BrewGUI.appLanguage"

    public static var current: AppLanguage {
        get {
            guard let raw = UserDefaults.standard.string(forKey: userDefaultsKey),
                  let lang = AppLanguage(rawValue: raw) else {
                return .system
            }
            return lang
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: userDefaultsKey)
        }
    }

    public static var currentResolved: ResolvedLanguage {
        current.resolved
    }
}

/// Global localization helper returning the string matching the active language (`简体中文`, `繁體中文`, or `English`).
@inline(__always)
public func tr(_ zhHans: String, _ zhHant: String, _ en: String) -> String {
    switch AppLanguage.currentResolved {
    case .zhHans:
        return zhHans
    case .zhHant:
        return zhHant
    case .en:
        return en
    }
}
