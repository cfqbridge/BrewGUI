import SwiftUI
import AppKit

public enum SearchTypeFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case formulae = "Formula (命令行)"
    case casks = "Cask (图形应用)"
    case adoptable = "本机可接管"

    public var id: String { rawValue }

    public var localizedLabel: String {
        switch self {
        case .all:
            return tr("全部", "全部", "All")
        case .formulae:
            return tr("Formula (命令行)", "Formula (命令列)", "Formula (CLI)")
        case .casks:
            return tr("Cask (图形应用)", "Cask (圖形應用)", "Cask (GUI Apps)")
        case .adoptable:
            return tr("本机可接管", "本機可接管", "Adoptable")
        }
    }
}

public struct SearchView: View {
    @ObservedObject var store: BrewStore

    public init(store: BrewStore) {
        self.store = store
    }

    private var searchResults: [CatalogEntry] {
        let trimmed = store.catalogSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let pool = store.catalogEntries.filter { entry in
            switch store.catalogTypeFilter {
            case .all: return true
            case .formulae: return entry.type == .formula
            case .casks: return entry.type == .cask
            case .adoptable: return false
            }
        }

        guard !trimmed.isEmpty else {
            return Array(pool.prefix(120))
        }

        var exactMatches: [CatalogEntry] = []
        var prefixMatches: [CatalogEntry] = []
        var nameContainsMatches: [CatalogEntry] = []
        var descMatches: [CatalogEntry] = []

        for entry in pool {
            let nameLower = entry.name.lowercased()
            let displayLower = entry.displayName.lowercased()

            if nameLower == trimmed || displayLower == trimmed {
                exactMatches.append(entry)
            } else if nameLower.hasPrefix(trimmed) || displayLower.hasPrefix(trimmed) {
                prefixMatches.append(entry)
            } else if nameLower.contains(trimmed) || displayLower.contains(trimmed) {
                nameContainsMatches.append(entry)
            } else if entry.desc.lowercased().contains(trimmed) {
                descMatches.append(entry)
            }
        }

        let merged = exactMatches + prefixMatches + nameContainsMatches + descMatches
        return Array(merged.prefix(200))
    }

    private var filteredAdoptCandidates: [AdoptCandidate] {
        let base = store.showIgnoredAdoptCandidates ? store.adoptCandidates : store.activeAdoptCandidates
        let trimmed = store.catalogSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return base }
        return base.filter { item in
            item.appName.lowercased().contains(trimmed)
                || item.caskToken.lowercased().contains(trimmed)
                || item.caskDisplayName.lowercased().contains(trimmed)
                || item.desc.lowercased().contains(trimmed)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Search Bar & Filter
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(
                        store.catalogTypeFilter == .adoptable
                            ? tr("筛选本机可接管应用名称或 Cask Token…", "篩選本機可接管應用程式名稱或 Cask Token…", "Filter adoptable apps or Cask tokens…")
                            : tr("搜索 Formula 或 Cask（支持包名、应用名、关键词实时过滤）…", "搜尋 Formula 或 Cask（支援套件名、應用名、關鍵字即時過濾）…", "Search Formulae or Casks (by name, app title, or description)…"),
                        text: $store.catalogSearchQuery
                    )
                    .textFieldStyle(.plain)

                    if !store.catalogSearchQuery.isEmpty {
                        Button {
                            store.catalogSearchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Picker(tr("类型", "類型", "Type"), selection: $store.catalogTypeFilter) {
                    ForEach(SearchTypeFilter.allCases) { item in
                        if item == .adoptable {
                            let count = store.activeAdoptCandidates.count
                            Text(count > 0 ? "\(item.localizedLabel) (\(count))" : item.localizedLabel).tag(item)
                        } else {
                            Text(item.localizedLabel).tag(item)
                        }
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()

                if store.catalogTypeFilter == .adoptable {
                    Button {
                        store.scanLocalApplications()
                        store.recomputeAdoptCandidates()
                    } label: {
                        Label(tr("重新扫描", "重新掃描", "Rescan"), systemImage: "arrow.clockwise")
                    }
                    .help(tr("重新扫描 /Applications 下的本地应用", "重新掃描 /Applications 下的本機應用程式", "Rescan local applications in /Applications"))
                } else {
                    Button {
                        Task { await store.refreshCatalog(forceRebuild: true) }
                    } label: {
                        Label(tr("重建索引", "重建索引", "Rebuild Index"), systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(store.isLoadingCatalog)
                    .help(tr("从本地 Homebrew API 缓存重新生成全量搜索索引", "從本機 Homebrew API 快取重新產生全量搜尋索引", "Rebuild full search index from local Homebrew API cache"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            if store.catalogTypeFilter == .adoptable {
                adoptModeContent
            } else {
                catalogSearchModeContent
            }
        }
    }

    // MARK: - Subview: Catalog Search Mode

    @ViewBuilder
    private var catalogSearchModeContent: some View {
        HStack {
            if store.isLoadingCatalog {
                ProgressView()
                    .controlSize(.small)
                Text(tr("正在构建本地全量元数据索引…", "正在建構本機全量中繼資料索引…", "Building local full catalog index…"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(
                    tr(
                        "本地索引库共 \(store.catalogEntries.count) 个软件包（显示前 \(searchResults.count) 条匹配结果）",
                        "本機索引庫共 \(store.catalogEntries.count) 個軟體套件（顯示前 \(searchResults.count) 筆符合結果）",
                        "\(store.catalogEntries.count) packages indexed locally (showing top \(searchResults.count) matches)"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if !store.activeAdoptCandidates.isEmpty {
                Button {
                    store.catalogTypeFilter = .adoptable
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.merge")
                        Text(
                            tr(
                                "发现 \(store.activeAdoptCandidates.count) 个本机应用可一键接管，点击查看",
                                "發現 \(store.activeAdoptCandidates.count) 個本機應用程式可一鍵接管，點擊查看",
                                "\(store.activeAdoptCandidates.count) unmanaged local apps found for Cask Adopt — click to view"
                            )
                        )
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.teal)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

        Divider()

        if searchResults.isEmpty && !store.isLoadingCatalog {
            VStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text(tr("未找到匹配的软件包", "找不到符合的軟體套件", "No matching packages found"))
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(searchResults) { entry in
                SearchCatalogRow(
                    entry: entry,
                    installedPkg: store.installedPackage(for: entry),
                    adoptableApp: store.adoptableAppName(for: entry),
                    isLocalOlderThanCask: store.adoptCandidates.first(where: { $0.caskToken == entry.name })?.isLocalOlderThanCask ?? false,
                    onInstall: { store.installCatalogEntry(entry, forceOverwrite: store.adoptableAppName(for: entry) != nil) },
                    onAdopt: { forceUpgrade in
                        store.adoptCask(
                            token: entry.name,
                            displayName: entry.displayName,
                            appBundles: entry.appBundles,
                            forceOverwriteToUpgrade: forceUpgrade
                        )
                    },
                    onIgnoreAdopt: { store.toggleIgnoreAdoptCandidate(caskToken: entry.name) }
                )
                .padding(.vertical, 4)
            }
            .listStyle(.inset)
        }
    }

    // MARK: - Subview: Adopt Scanner Mode

    @ViewBuilder
    private var adoptModeContent: some View {
        // Caution & Explanation Banner
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.teal)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("关于本机应用接管 (`--adopt` vs `--force`) 的注意事项：", "關於本機應用程式接管 (`--adopt` vs `--force`) 的注意事項：", "Notes on Cask Adopt (`--adopt` vs `--force`):"))
                        .font(.caption.weight(.semibold))
                    Text(
                        tr(
                            "1. Homebrew 的 `--adopt` 仅登记接管关系而**绝不覆盖** `/Applications` 下的原有文件。若本地版本低于 Cask 版本，请点击「接管并升级」自动退出旧应用并覆盖为新版。\n2. 部分开发者更重视 Mac App Store 渠道，且存在 iPad/iOS 包装应用与 Mac 原生 Cask 同名的情况（如 淘宝桌面版 / 哔哩哔哩 等），对不需要由 Brew 接管的应用请点击「忽略」。",
                            "1. Homebrew 的 `--adopt` 僅登記接管關係而**絕不覆蓋** `/Applications` 下的原有檔案。若本機版本低於 Cask 版本，請點擊「接管並升級」自動結束舊應用並覆蓋為新版。\n2. 部分開發者更重視 Mac App Store 管道，且存在 iPad/iOS 包裝應用與 Mac 原生 Cask 同名的情況，對不需要由 Brew 接管的應用請點擊「忽略」。",
                            "1. Homebrew's `--adopt` only registers the app in Caskroom without overwriting `/Applications`. When your local app is older than the Cask version, click \"Adopt & Upgrade\" (`--force`) to overwrite and update.\n2. Some apps come from the Mac App Store or are iOS/iPad wrapped apps — click \"Ignore\" for apps you do not wish Homebrew to manage."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Toggle(
                        tr(
                            "显示已忽略 (\(store.ignoredAdoptCandidatesList.count))",
                            "顯示已忽略 (\(store.ignoredAdoptCandidatesList.count))",
                            "Show Ignored (\(store.ignoredAdoptCandidatesList.count))"
                        ),
                        isOn: $store.showIgnoredAdoptCandidates
                    )
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .font(.caption)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.teal.opacity(0.08))

        Divider()

        if filteredAdoptCandidates.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 40))
                    .foregroundStyle(.teal)
                Text(tr("当前没有待处理的本机可接管应用", "目前沒有待處理的本機可接管應用程式", "No unmanaged local applications pending adoption"))
                    .font(.headline)
                if !store.ignoredAdoptCandidatesList.isEmpty && !store.showIgnoredAdoptCandidates {
                    Button(
                        tr(
                            "查看已忽略的 \(store.ignoredAdoptCandidatesList.count) 个应用",
                            "查看已忽略的 \(store.ignoredAdoptCandidatesList.count) 個應用程式",
                            "Show \(store.ignoredAdoptCandidatesList.count) ignored apps"
                        )
                    ) {
                        store.showIgnoredAdoptCandidates = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(filteredAdoptCandidates) { candidate in
                AdoptCandidateRow(
                    candidate: candidate,
                    onAdoptOnly: {
                        store.adoptCask(
                            token: candidate.caskToken,
                            displayName: candidate.caskDisplayName,
                            appBundles: [candidate.appName],
                            forceOverwriteToUpgrade: false
                        )
                    },
                    onAdoptAndUpgrade: {
                        store.adoptCask(
                            token: candidate.caskToken,
                            displayName: candidate.caskDisplayName,
                            appBundles: [candidate.appName],
                            forceOverwriteToUpgrade: true
                        )
                    },
                    onToggleIgnore: {
                        store.toggleIgnoreAdoptCandidate(caskToken: candidate.caskToken)
                    }
                )
                .padding(.vertical, 4)
            }
            .listStyle(.inset)
        }
    }
}

private struct SearchCatalogRow: View {
    let entry: CatalogEntry
    let installedPkg: BrewPackage?
    let adoptableApp: String?
    let isLocalOlderThanCask: Bool
    let onInstall: () -> Void
    let onAdopt: (Bool) -> Void
    let onIgnoreAdopt: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(entry.displayName)
                        .font(.system(.body, design: .default).weight(.semibold))

                    if entry.displayName != entry.name {
                        Text("(\(entry.name))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    BadgeView(
                        text: entry.type.rawValue,
                        color: entry.type == .cask ? .purple : .blue
                    )

                    if let installedPkg {
                        BadgeView(
                            text: "\(tr("已安装", "已安裝", "Installed")) \(installedPkg.installedVersion ?? "")",
                            color: .green
                        )
                    } else if let adoptableApp {
                        BadgeView(
                            text: "\(tr("本地已存在", "本機已存在", "Found locally:")) \(adoptableApp)",
                            color: .teal
                        )
                    }
                }

                if !entry.desc.isEmpty {
                    Text(entry.desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    if !entry.version.isEmpty {
                        Text("\(tr("最新版本", "最新版本", "Latest")): \(entry.version)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    if !entry.appBundles.isEmpty {
                        Text("\(tr("应用包", "應用程式套件", "App Bundle")): \(entry.appBundles.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let url = URL(string: entry.homepage), !entry.homepage.isEmpty {
                        Link(destination: url) {
                            HStack(spacing: 2) {
                                Text(tr("主页", "首頁", "Homepage"))
                                Image(systemName: "arrow.up.right.square")
                            }
                            .font(.caption)
                        }
                    }
                }
            }

            Spacer()

            // Action Buttons
            HStack(spacing: 8) {
                if installedPkg != nil {
                    Label(tr("已安装", "已安裝", "Installed"), systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                } else if adoptableApp != nil {
                    if isLocalOlderThanCask {
                        Button {
                            onAdopt(true)
                        } label: {
                            Label(tr("接管并升级", "接管並升級", "Adopt & Upgrade"), systemImage: "arrow.up.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.small)
                        .help(tr("本地版本较旧：将自动退出旧应用并执行 brew install --cask --force \(entry.name) 覆盖升级", "本機版本較舊：將自動結束舊應用並執行 brew install --cask --force \(entry.name) 覆蓋升級", "Local app is older: quits running app and runs brew install --cask --force \(entry.name)"))

                        Button {
                            onAdopt(false)
                        } label: {
                            Text(tr("仅认领", "僅認領", "Adopt Only"))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help(tr("执行 --adopt 仅登记接管关系但不覆盖本地旧版文件", "執行 --adopt 僅登記接管關係但不覆蓋本機舊版檔案", "Runs --adopt without overwriting local files"))
                    } else {
                        Button {
                            onAdopt(false)
                        } label: {
                            Label(tr("Adopt (接管)", "Adopt (接管)", "Adopt"), systemImage: "arrow.triangle.merge")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)
                        .controlSize(.small)
                        .help(tr("执行 brew install --cask --adopt \(entry.name) 接管本地已有应用", "執行 brew install --cask --adopt \(entry.name) 接管本機已有應用程式", "Run brew install --cask --adopt \(entry.name)"))

                        Button {
                            onInstall()
                        } label: {
                            Text(tr("覆盖重装", "覆蓋重裝", "Force Reinstall"))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help(tr("执行 brew install --cask --force \(entry.name) 覆盖安装", "執行 brew install --cask --force \(entry.name) 覆蓋安裝", "Run brew install --cask --force \(entry.name)"))
                    }

                    Button {
                        onIgnoreAdopt()
                    } label: {
                        Text(tr("忽略接管", "忽略接管", "Ignore"))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(tr("不再提示接管此应用", "不再提示接管此應用程式", "Do not suggest adopting this app"))
                } else {
                    Button {
                        onInstall()
                    } label: {
                        Label(tr("安装", "安裝", "Install"), systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
    }
}

private struct AdoptCandidateRow: View {
    let candidate: AdoptCandidate
    let onAdoptOnly: () -> Void
    let onAdoptAndUpgrade: () -> Void
    let onToggleIgnore: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: candidate.appPath))
                .resizable()
                .frame(width: 36, height: 36)
                .opacity(candidate.isIgnored ? 0.5 : 1.0)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(candidate.appName)
                        .font(.system(.body, design: .default).weight(.semibold))
                        .strikethrough(candidate.isIgnored)

                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    BadgeView(text: "cask: \(candidate.caskToken)", color: .teal)

                    if candidate.isLocalOlderThanCask {
                        BadgeView(text: tr("本地版本较旧", "本機版本較舊", "Local Outdated"), color: .orange)
                    }

                    if candidate.isIOSWrappedApp {
                        BadgeView(text: tr("iPad / iOS 应用包装", "iPad / iOS 應用包裝", "iOS / iPad App"), color: .orange)
                    } else if candidate.isAppStoreReceiptPresent {
                        BadgeView(text: tr("App Store 渠道", "App Store 管道", "Mac App Store"), color: .blue)
                    }

                    if candidate.isIgnored {
                        BadgeView(text: tr("已忽略", "已忽略", "Ignored"), color: .gray)
                    }
                }

                if !candidate.desc.isEmpty {
                    Text(candidate.desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 14) {
                    Text("\(tr("本地版本", "本機版本", "Local")): \(candidate.localVersion ?? tr("未知 (可能为 iOS 版)", "未知 (可能為 iOS 版)", "Unknown (iOS wrapper)"))")
                        .font(.caption.monospaced())
                        .foregroundStyle(candidate.isLocalOlderThanCask ? .orange : .secondary)

                    Text("\(tr("Brew Cask 版本", "Brew Cask 版本", "Cask")): \(candidate.caskVersion)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.teal)

                    Text(candidate.appPath)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                if !candidate.isIgnored {
                    if candidate.isLocalOlderThanCask {
                        Button {
                            onAdoptAndUpgrade()
                        } label: {
                            Label(tr("接管并升级", "接管並升級", "Adopt & Upgrade"), systemImage: "arrow.up.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.small)
                        .help(tr("本地版本低于 Cask 版本：将自动退出运行中的旧应用并执行 brew install --cask --force \(candidate.caskToken) 覆盖为新版", "本機版本低於 Cask 版本：將自動結束執行中的舊應用並執行 brew install --cask --force \(candidate.caskToken) 覆蓋為新版", "Local app is older: quits running app and runs brew install --cask --force \(candidate.caskToken)"))

                        Button {
                            onAdoptOnly()
                        } label: {
                            Text(tr("仅认领", "僅認領", "Adopt Only"))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help(tr("执行 --adopt 仅登记给 Brew 但保留本地旧版文件不覆盖", "執行 --adopt 僅登記給 Brew 但保留本機舊版檔案不覆蓋", "Runs --adopt without overwriting local files"))
                    } else {
                        Button {
                            onAdoptOnly()
                        } label: {
                            Label(tr("Adopt (接管)", "Adopt (接管)", "Adopt"), systemImage: "arrow.triangle.merge")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)
                        .controlSize(.small)
                        .help(tr("本地版本已是最新：执行 brew install --cask --adopt \(candidate.caskToken) 直接无损接管", "本機版本已是最新：執行 brew install --cask --adopt \(candidate.caskToken) 直接無損接管", "Local app is up to date: run brew install --cask --adopt \(candidate.caskToken)"))
                    }
                }

                Button {
                    onToggleIgnore()
                } label: {
                    Label(
                        candidate.isIgnored ? tr("恢复显示", "恢復顯示", "Unignore") : tr("忽略", "忽略", "Ignore"),
                        systemImage: candidate.isIgnored ? "eye" : "eye.slash"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(candidate.isIgnored ? tr("取消忽略该应用", "取消忽略該應用程式", "Restore this app to adoptable list") : tr("忽略该应用（如商店版或 iPad 同名版）", "忽略該應用程式（如商店版或 iPad 同名版）", "Ignore this app (e.g. App Store or iPad version)"))
            }
        }
    }
}
