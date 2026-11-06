import SwiftUI
import AppKit

public enum SearchTypeFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case formulae = "Formula (命令行)"
    case casks = "Cask (图形应用)"
    case adoptable = "本机可接管"

    public var id: String { rawValue }
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
                            ? "筛选本机可接管应用名称或 Cask Token…"
                            : "搜索 Formula 或 Cask（支持包名、应用名、关键词实时过滤）…",
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

                Picker("类型", selection: $store.catalogTypeFilter) {
                    ForEach(SearchTypeFilter.allCases) { item in
                        if item == .adoptable {
                            let count = store.activeAdoptCandidates.count
                            Text(count > 0 ? "本机可接管 (\(count))" : "本机可接管").tag(item)
                        } else {
                            Text(item.rawValue).tag(item)
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
                        Label("重新扫描", systemImage: "arrow.clockwise")
                    }
                    .help("重新扫描 /Applications 下的本地应用")
                } else {
                    Button {
                        Task { await store.refreshCatalog(forceRebuild: true) }
                    } label: {
                        Label("重建索引", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(store.isLoadingCatalog)
                    .help("从本地 Homebrew API 缓存重新生成全量搜索索引")
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
                Text("正在构建本地全量元数据索引…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("本地索引库共 \(store.catalogEntries.count) 个软件包（显示前 \(searchResults.count) 条匹配结果）")
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
                        Text("发现 \(store.activeAdoptCandidates.count) 个本机应用可一键接管，点击查看")
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
                Text("未找到匹配的软件包")
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
                    Text("关于本机应用接管 (`--adopt` vs `--force`) 的注意事项：")
                        .font(.caption.weight(.semibold))
                    Text("1. Homebrew 的 `--adopt` 仅登记接管关系而**绝不覆盖** `/Applications` 下的原有文件。若本地版本低于 Cask 版本，请点击「接管并升级」自动退出旧应用并覆盖为新版。\n2. 部分开发者更重视 Mac App Store 渠道，且存在 iPad/iOS 包装应用与 Mac 原生 Cask 同名的情况（如 淘宝桌面版 / 哔哩哔哩 等），对不需要由 Brew 接管的应用请点击「忽略」。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Toggle("显示已忽略 (\(store.ignoredAdoptCandidatesList.count))", isOn: $store.showIgnoredAdoptCandidates)
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
                Text("当前没有待处理的本机可接管应用")
                    .font(.headline)
                if !store.ignoredAdoptCandidatesList.isEmpty && !store.showIgnoredAdoptCandidates {
                    Button("查看已忽略的 \(store.ignoredAdoptCandidatesList.count) 个应用") {
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
                            text: "已安装 \(installedPkg.installedVersion ?? "")",
                            color: .green
                        )
                    } else if let adoptableApp {
                        BadgeView(
                            text: "本地已存在 \(adoptableApp)",
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
                        Text("最新版本: \(entry.version)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    if !entry.appBundles.isEmpty {
                        Text("应用包: \(entry.appBundles.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let url = URL(string: entry.homepage), !entry.homepage.isEmpty {
                        Link(destination: url) {
                            HStack(spacing: 2) {
                                Text("主页")
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
                    Label("已安装", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                } else if adoptableApp != nil {
                    if isLocalOlderThanCask {
                        Button {
                            onAdopt(true)
                        } label: {
                            Label("接管并升级", systemImage: "arrow.up.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.small)
                        .help("本地版本较旧：将自动退出旧应用并执行 brew install --cask --force \(entry.name) 覆盖升级")

                        Button {
                            onAdopt(false)
                        } label: {
                            Text("仅认领")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("执行 --adopt 仅登记接管关系但不覆盖本地旧版文件")
                    } else {
                        Button {
                            onAdopt(false)
                        } label: {
                            Label("Adopt (接管)", systemImage: "arrow.triangle.merge")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)
                        .controlSize(.small)
                        .help("执行 brew install --cask --adopt \(entry.name) 接管本地已有应用")

                        Button {
                            onInstall()
                        } label: {
                            Text("覆盖重装")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("执行 brew install --cask --force \(entry.name) 覆盖安装")
                    }

                    Button {
                        onIgnoreAdopt()
                    } label: {
                        Text("忽略接管")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("不再提示接管此应用")
                } else {
                    Button {
                        onInstall()
                    } label: {
                        Label("安装", systemImage: "arrow.down.circle")
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
                        BadgeView(text: "本地版本较旧", color: .orange)
                    }

                    if candidate.isIOSWrappedApp {
                        BadgeView(text: "iPad / iOS 应用包装", color: .orange)
                    } else if candidate.isAppStoreReceiptPresent {
                        BadgeView(text: "App Store 渠道", color: .blue)
                    }

                    if candidate.isIgnored {
                        BadgeView(text: "已忽略", color: .gray)
                    }
                }

                if !candidate.desc.isEmpty {
                    Text(candidate.desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 14) {
                    Text("本地版本: \(candidate.localVersion ?? "未知 (可能为 iOS 版)")")
                        .font(.caption.monospaced())
                        .foregroundStyle(candidate.isLocalOlderThanCask ? .orange : .secondary)

                    Text("Brew Cask 版本: \(candidate.caskVersion)")
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
                            Label("接管并升级", systemImage: "arrow.up.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.small)
                        .help("本地版本低于 Cask 版本：将自动退出运行中的旧应用并执行 brew install --cask --force \(candidate.caskToken) 覆盖为新版")

                        Button {
                            onAdoptOnly()
                        } label: {
                            Text("仅认领")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("执行 --adopt 仅登记给 Brew 但保留本地旧版文件不覆盖")
                    } else {
                        Button {
                            onAdoptOnly()
                        } label: {
                            Label("Adopt (接管)", systemImage: "arrow.triangle.merge")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)
                        .controlSize(.small)
                        .help("本地版本已是最新：执行 brew install --cask --adopt \(candidate.caskToken) 直接无损接管")
                    }
                }

                Button {
                    onToggleIgnore()
                } label: {
                    Label(
                        candidate.isIgnored ? "恢复显示" : "忽略",
                        systemImage: candidate.isIgnored ? "eye" : "eye.slash"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(candidate.isIgnored ? "取消忽略该应用" : "忽略该应用（如商店版或 iPad 同名版）")
            }
        }
    }
}
