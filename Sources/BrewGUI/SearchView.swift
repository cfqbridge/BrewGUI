import SwiftUI
import AppKit

public enum SearchTypeFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case casks = "桌面应用"
    case formulae = "命令行"
    case adoptable = "本机可接管"

    public var id: String { rawValue }

    public var localizedLabel: String {
        switch self {
        case .all:
            return tr("全部", "全部", "All")
        case .casks:
            return tr("桌面应用", "桌面應用", "Desktop Apps")
        case .formulae:
            return tr("命令行", "命令列", "CLI Tools")
        case .adoptable:
            return tr("本机可接管", "本機可接管", "On This Mac")
        }
    }
}

public struct SearchView: View {
    @ObservedObject var store: BrewStore

    public init(store: BrewStore) {
        self.store = store
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
                            ? tr("筛选本机可接管应用名称或中文名…", "篩選本機可接管應用程式名稱或中文名…", "Filter unmanaged local apps…")
                            : tr("搜索软件名、中文别名或功能词（如：截图、解压、播放器、翻译、终端、微信）…", "搜尋軟體名、中文別名或功能詞（如：截圖、解壓、播放器、翻譯、終端、微信）…", "Search apps or tools (by name, Chinese alias, or functional keyword)…"),
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
                    .help(tr("重新扫描本机已安装的桌面应用", "重新掃描本機已安裝的桌面應用程式", "Rescan local applications"))
                } else {
                    Button {
                        Task { await store.refreshCatalog(forceRebuild: true) }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .disabled(store.isLoadingCatalog)
                    .help(tr("刷新本地软件索引库", "重新整理本機軟體索引庫", "Refresh local package catalog"))
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
        // Quick Category Recommendation Pills Bar
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(SearchCategoryPreset.allCases) { cat in
                    let isSelected = (store.selectedSearchCategory == cat)
                    Button {
                        store.selectedSearchCategory = cat
                    } label: {
                        Text(cat.label)
                            .font(.caption.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.primary.opacity(isSelected ? 0 : 0.1), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
        }
        .background(Color(nsColor: .windowBackgroundColor))

        Divider()

        HStack {
            if store.isLoadingCatalog {
                ProgressView()
                    .controlSize(.small)
                Text(tr("正在更新本地软件索引库…", "正在更新本機軟體索引庫…", "Updating local package catalog…"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                let resultCount = store.filteredCatalogEntries.count
                let totalCount = store.catalogEntries.count
                let isBrowsingDefault = store.catalogSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && store.selectedSearchCategory == .all
                HStack(spacing: 5) {
                    Image(systemName: isBrowsingDefault ? "sparkles" : "line.3.horizontal.decrease.circle")
                        .font(.caption2)
                        .foregroundStyle(isBrowsingDefault ? .orange : .secondary)
                    Text(
                        isBrowsingDefault
                            ? tr("常用软件精选 · 共收录 \(totalCount) 款工具，支持中文功能词直接检索", "常用軟體精選 · 共收錄 \(totalCount) 款工具，支援中文功能詞直接檢索", "Featured Picks · \(totalCount) packages indexed")
                            : tr("找到 \(resultCount) 款匹配的软件", "找到 \(resultCount) 款符合的軟體", "Found \(resultCount) matching packages")
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            Spacer()

            let isBrowsingDefaultToggle = store.catalogSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && store.selectedSearchCategory == .all
            if isBrowsingDefaultToggle {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        store.showAllDefaultCatalogList.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: store.showAllDefaultCatalogList ? "square.grid.2x2.fill" : "list.bullet")
                        Text(
                            store.showAllDefaultCatalogList
                                ? tr("精选卡片视图", "精選卡片檢視", "Featured Grid")
                                : tr("列表浏览", "列表瀏覽", "List View")
                        )
                    }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if !store.activeAdoptCandidates.isEmpty {
                Button {
                    store.catalogTypeFilter = .adoptable
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.merge")
                        Text(
                            tr(
                                "本机可接管 (\(store.activeAdoptCandidates.count)) →",
                                "本機可接管 (\(store.activeAdoptCandidates.count)) →",
                                "On This Mac (\(store.activeAdoptCandidates.count)) →"
                            )
                        )
                    }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.teal.opacity(0.12))
                    .foregroundStyle(.teal)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))

        Divider()

        let shouldShowFeaturedGrid = store.catalogSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && store.selectedSearchCategory == .all
            && !store.showAllDefaultCatalogList
            && (!store.featuredEssentialEntries.isEmpty || !store.featuredDeveloperEntries.isEmpty)

        if store.filteredCatalogEntries.isEmpty && !store.isLoadingCatalog {
            VStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text(tr("未找到匹配的软件", "找不到符合的軟體", "No matching packages found"))
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if shouldShowFeaturedGrid {
            discoveryShowcaseContent
        } else {
            List(store.filteredCatalogEntries) { entry in
                let adoptApp = store.adoptableAppName(for: entry)
                let installedPkg = store.installedPackage(for: entry)
                SearchCatalogRow(
                    entry: entry,
                    installedPkg: installedPkg,
                    adoptableApp: adoptApp,
                    isLocalOlderThanCask: store.adoptCandidate(for: entry.name)?.isLocalOlderThanCask ?? false,
                    isRunningTask: store.isPackageCurrentlyRunning(entry.name),
                    isQueuedTask: store.isPackageQueued(entry.name),
                    downloadProgress: store.isPackageCurrentlyRunning(entry.name) ? store.activeDownloadInfo?.progressFraction : nil,
                    onInstall: { store.installCatalogEntry(entry, forceOverwrite: adoptApp != nil) },
                    onAdopt: { forceUpgrade in
                        store.adoptCask(
                            token: entry.qualifiedName,
                            displayName: entry.displayName,
                            appBundles: entry.appBundles,
                            forceOverwriteToUpgrade: forceUpgrade
                        )
                    },
                    onIgnoreAdopt: { store.toggleIgnoreAdoptCandidate(caskToken: entry.name) },
                    onSearchReplacement: { repl in store.catalogSearchQuery = repl },
                    onOpenInstalledApp: { path in store.openInstalledApp(at: path) },
                    onInspectDetail: { store.inspectCatalogEntry(entry) }
                )
                .padding(.vertical, 5)
            }
            .listStyle(.inset)
        }
    }

    @ViewBuilder
    private var discoveryShowcaseContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 1. Adoptable Apps Callout Card (if any local unmanaged apps exist)
                if !store.activeAdoptCandidates.isEmpty {
                    let previewCandidates = Array(store.activeAdoptCandidates.prefix(4))
                    let recommendedCount = store.activeAdoptCandidates.filter { !$0.isSuggestedToIgnore }.count
                    HStack(spacing: 14) {
                        HStack(spacing: -8) {
                            ForEach(previewCandidates) { cand in
                                let hasDiskIcon = FileManager.default.fileExists(atPath: cand.appPath)
                                PackageIconView(
                                    token: cand.caskToken,
                                    type: .cask,
                                    desc: cand.desc,
                                    appPath: hasDiskIcon ? cand.appPath : nil,
                                    size: 32
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 2)
                                )
                            }
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(
                                    tr(
                                        "发现本机有 \(store.activeAdoptCandidates.count) 款应用可纳入统一更新",
                                        "發現本機有 \(store.activeAdoptCandidates.count) 款應用可納入統一更新",
                                        "Found \(store.activeAdoptCandidates.count) Local Apps Ready for Unified Updates"
                                    )
                                )
                                .font(.callout.weight(.semibold))

                                if recommendedCount > 0 {
                                    BadgeView(
                                        text: tr("推荐纳入 \(recommendedCount) 款", "推薦納入 \(recommendedCount) 款", "\(recommendedCount) Recommended"),
                                        color: .teal
                                    )
                                }
                            }
                            Text(
                                tr(
                                    "您之前通过安装包手动拖入「应用程序」的软件，可一键交由 BrewGUI 统一检测更新，无需重装。",
                                    "您之前透過安裝包手動拖入「應用程式」的軟體，可一鍵交由 BrewGUI 統一偵測更新，無需重裝。",
                                    "Apps you manually installed in /Applications can be adopted for one-click updates without reinstalling."
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        }

                        Spacer()

                        Button {
                            store.catalogTypeFilter = .adoptable
                        } label: {
                            Label(tr("立即查看", "立即檢視", "Review Apps"), systemImage: "arrow.right.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)
                        .controlSize(.small)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.teal.opacity(0.12), Color.blue.opacity(0.05)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.teal.opacity(0.24), lineWidth: 1)
                    )
                }

                // 2. Essential Mac Apps Grid
                if !store.featuredEssentialEntries.isEmpty {
                    showcaseGridSection(
                        icon: "flame.fill",
                        iconColor: .orange,
                        title: tr("Mac 装机必备精选", "Mac 裝機必備精選", "Essential Mac Picks"),
                        subtitle: tr("口碑极佳的高频效率、影音、截图与系统增强工具", "口碑極佳的高頻效率、影音、截圖與系統增強工具", "Top-rated productivity, media, screenshot, and system utilities"),
                        entries: store.featuredEssentialEntries
                    )
                }

                // 3. Developer & AI Tools Grid
                if !store.featuredDeveloperEntries.isEmpty {
                    showcaseGridSection(
                        icon: "cpu.fill",
                        iconColor: .indigo,
                        title: tr("开发者与 AI 效率利器", "開發者與 AI 效率利器", "Developer & AI Power Tools"),
                        subtitle: tr("主流本地大模型客户端、现代终端与高频命令行工具", "主流本機大模型用戶端、現代終端與高頻命令列工具", "Popular AI desktop clients, modern terminals, and CLI essentials"),
                        entries: store.featuredDeveloperEntries
                    )
                }

                // 4. Footer Switch to Full List
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            store.showAllDefaultCatalogList = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "list.bullet.rectangle")
                            Text(
                                tr(
                                    "切换为完整列表浏览（共收录 \(store.catalogEntries.count) 款软件）→",
                                    "切換為完整列表瀏覽（共收錄 \(store.catalogEntries.count) 款軟體）→",
                                    "Browse Full Package List (\(store.catalogEntries.count) packages) →"
                                )
                            )
                        }
                        .font(.callout.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                .padding(.top, 4)
                .padding(.bottom, 12)
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func showcaseGridSection(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        entries: [CatalogEntry]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.headline)
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
            }

            let columns = [
                GridItem(.flexible(minimum: 260), spacing: 12),
                GridItem(.flexible(minimum: 260), spacing: 12)
            ]

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(entries) { entry in
                    let adoptApp = store.adoptableAppName(for: entry)
                    let installedPkg = store.installedPackage(for: entry)
                    FeaturedDiscoveryCard(
                        entry: entry,
                        installedPkg: installedPkg,
                        adoptableApp: adoptApp,
                        isLocalOlderThanCask: store.adoptCandidate(for: entry.name)?.isLocalOlderThanCask ?? false,
                        isRunningTask: store.isPackageCurrentlyRunning(entry.name),
                        isQueuedTask: store.isPackageQueued(entry.name),
                        downloadProgress: store.isPackageCurrentlyRunning(entry.name) ? store.activeDownloadInfo?.progressFraction : nil,
                        onInstall: { store.installCatalogEntry(entry, forceOverwrite: adoptApp != nil) },
                        onAdopt: { forceUpgrade in
                            store.adoptCask(
                                token: entry.qualifiedName,
                                displayName: entry.displayName,
                                appBundles: entry.appBundles,
                                forceOverwriteToUpgrade: forceUpgrade
                            )
                        },
                        onOpenInstalledApp: { path in store.openInstalledApp(at: path) },
                        onInspectDetail: { store.inspectCatalogEntry(entry) }
                    )
                }
            }
        }
    }

    // MARK: - Subview: Adopt Scanner Mode

    @ViewBuilder
    private var adoptModeContent: some View {
        let recommendedCount = store.activeAdoptCandidates.filter { !$0.isSuggestedToIgnore }.count
        let cautionOrIgnoreCount = store.suggestedIgnoreAdoptCandidates.count

        // Compact Visual Summary Bar
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "macwindow.badge.plus")
                    .font(.title3)
                    .foregroundStyle(.teal)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(tr("将本机手动安装的应用纳入统一更新", "將本機手動安裝的應用納入統一更新", "Manage Existing Local Apps"))
                            .font(.callout.weight(.semibold))

                        if recommendedCount > 0 {
                            BadgeView(
                                text: tr("推荐纳入 \(recommendedCount) 款", "推薦納入 \(recommendedCount) 款", "\(recommendedCount) Recommended"),
                                color: .teal
                            )
                        }
                        if cautionOrIgnoreCount > 0 {
                            BadgeView(
                                text: tr("建议忽略 \(cautionOrIgnoreCount) 款", "建議忽略 \(cautionOrIgnoreCount) 款", "\(cautionOrIgnoreCount) Suggest Ignore"),
                                color: .indigo
                            )
                        }
                    }

                    Text(
                        tr(
                            "已自动识别商店应用与内置更新软件。推荐对开源/通用工具点击「升级并纳入」，对其余标蓝项点击「忽略」。",
                            "已自動識別商店應用與內建更新軟體。推薦對開源/通用工具點擊「升級並納入」，對其餘標藍項點擊「忽略」。",
                            "App Store and self-updating apps are automatically flagged. Click \"Adopt & Upgrade\" for standard tools or \"Ignore\" for flagged apps."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }

            Spacer()

            if !store.suggestedIgnoreAdoptCandidates.isEmpty {
                Button {
                    store.ignoreAllSuggestedAdoptCandidates()
                } label: {
                    Label(
                        tr(
                            "一键忽略 \(store.suggestedIgnoreAdoptCandidates.count) 个不推荐项",
                            "一鍵忽略 \(store.suggestedIgnoreAdoptCandidates.count) 個不推薦項",
                            "Ignore \(store.suggestedIgnoreAdoptCandidates.count) Flagged"
                        ),
                        systemImage: "eye.slash.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .controlSize(.small)
            }

            Button {
                store.showAdoptGuideSheet = true
            } label: {
                Label(tr("接管说明", "接管說明", "Guide"), systemImage: "questionmark.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Toggle(
                tr(
                    "显示已忽略 (\(store.ignoredAdoptCandidatesList.count))",
                    "顯示已忽略 (\(store.ignoredAdoptCandidatesList.count))",
                    "Ignored (\(store.ignoredAdoptCandidatesList.count))"
                ),
                isOn: $store.showIgnoredAdoptCandidates
            )
            .toggleStyle(.switch)
            .controlSize(.mini)
            .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.teal.opacity(0.07))
        .sheet(isPresented: $store.showAdoptGuideSheet) {
            AdoptDecisionGuideSheet(store: store)
        }

        Divider()

        if store.filteredAdoptCandidatesList.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(.teal)
                Text(tr("本机应用均已处理完毕", "本機應用程式均已處理完畢", "All local applications have been reviewed"))
                    .font(.headline)
                if !store.ignoredAdoptCandidatesList.isEmpty && !store.showIgnoredAdoptCandidates {
                    Button(
                        tr(
                            "查看已忽略的 \(store.ignoredAdoptCandidatesList.count) 款应用",
                            "查看已忽略的 \(store.ignoredAdoptCandidatesList.count) 款應用程式",
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
            List(store.filteredAdoptCandidatesList) { candidate in
                AdoptCandidateRow(
                    candidate: candidate,
                    isRunningTask: store.isPackageCurrentlyRunning(candidate.caskToken),
                    isQueuedTask: store.isPackageQueued(candidate.caskToken),
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
                .padding(.vertical, 5)
            }
            .listStyle(.inset)
        }
    }
}

private struct FeaturedDiscoveryCard: View {
    let entry: CatalogEntry
    let installedPkg: BrewPackage?
    let adoptableApp: String?
    let isLocalOlderThanCask: Bool
    let isRunningTask: Bool
    let isQueuedTask: Bool
    let downloadProgress: Double?
    let onInstall: () -> Void
    let onAdopt: (Bool) -> Void
    let onOpenInstalledApp: (String) -> Void
    let onInspectDetail: () -> Void

    private var resolvedAppPath: String? {
        if let p = installedPkg?.resolvedAppPath {
            return p
        }
        return AppIconProvider.shared.resolveExistingAppPath(for: entry.appBundles)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                onInspectDetail()
            } label: {
                PackageIconView(
                    token: entry.name,
                    type: entry.type,
                    desc: entry.desc,
                    appPath: resolvedAppPath,
                    size: 40
                )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Button {
                        onInspectDetail()
                    } label: {
                        Text(entry.displayName)
                            .font(.system(.callout, design: .default).weight(.semibold))
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)

                    if AppLanguage.current.resolved != .en,
                       let zhBadge = ChineseSearchIndex.displayBadge(for: entry),
                       zhBadge.lowercased() != entry.displayLower {
                        BadgeView(text: zhBadge, color: .orange)
                    }
                }

                let localizedDesc = ChineseSearchIndex.localizedDescription(for: entry)
                Text(localizedDesc.isEmpty ? entry.desc : localizedDesc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(entry.type.localizedHumanLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)

                    if let installedPkg {
                        Text("· \(tr("已安装", "已安裝", "Installed")) \(installedPkg.installedVersion ?? "")")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.green)
                    } else if !entry.version.isEmpty {
                        Text("· v\(entry.version)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer(minLength: 4)

            if isRunningTask {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.mini)
                    if let frac = downloadProgress {
                        Text("\(Int(frac * 100))%")
                            .font(.caption2.monospaced().weight(.semibold))
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(Capsule())
            } else if isQueuedTask {
                Text(tr("排队中", "排隊中", "Queued"))
                    .font(.caption2)
                    .foregroundStyle(.orange)
            } else if installedPkg != nil {
                if let appPath = resolvedAppPath {
                    Button {
                        onOpenInstalledApp(appPath)
                    } label: {
                        Text(tr("打开", "打開", "Open"))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    BadgeView(text: tr("已安装", "已安裝", "Installed"), color: .green)
                }
            } else if adoptableApp != nil {
                Button {
                    onAdopt(isLocalOlderThanCask)
                } label: {
                    Text(isLocalOlderThanCask ? tr("升级纳入", "升級納入", "Adopt") : tr("纳入", "納入", "Adopt"))
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .controlSize(.small)
            } else {
                Button {
                    onInstall()
                } label: {
                    Text(tr("获取", "取得", "Get"))
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct SearchCatalogRow: View {
    let entry: CatalogEntry
    let installedPkg: BrewPackage?
    let adoptableApp: String?
    let isLocalOlderThanCask: Bool
    let isRunningTask: Bool
    let isQueuedTask: Bool
    let downloadProgress: Double?
    let onInstall: () -> Void
    let onAdopt: (Bool) -> Void
    let onIgnoreAdopt: () -> Void
    let onSearchReplacement: (String) -> Void
    let onOpenInstalledApp: (String) -> Void
    let onInspectDetail: () -> Void

    private var resolvedAppPath: String? {
        if let p = installedPkg?.resolvedAppPath {
            return p
        }
        return AppIconProvider.shared.resolveExistingAppPath(for: entry.appBundles)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // 1. Visual Icon Anchor
            Button {
                onInspectDetail()
            } label: {
                PackageIconView(
                    token: entry.name,
                    type: entry.type,
                    desc: entry.desc,
                    appPath: resolvedAppPath,
                    size: 38
                )
            }
            .buttonStyle(.plain)

            // 2. Concise Title + Localized Description + Clean Metadata Line
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Button {
                        onInspectDetail()
                    } label: {
                        Text(entry.displayName)
                            .font(.system(.body, design: .default).weight(.semibold))
                            .strikethrough(entry.isDisabled && installedPkg == nil)
                            .foregroundStyle(entry.isDisabled && installedPkg == nil ? .secondary : .primary)
                    }
                    .buttonStyle(.plain)

                    if AppLanguage.current.resolved != .en,
                       let zhBadge = ChineseSearchIndex.displayBadge(for: entry),
                       zhBadge.lowercased() != entry.displayLower {
                        BadgeView(text: zhBadge, color: .orange)
                    }

                    if let tap = entry.tap, !tap.isEmpty {
                        BadgeView(text: tr("第三方源", "第三方源", "3rd-Party"), color: .indigo)
                    }

                    if entry.isDisabled {
                        BadgeView(text: tr("已停止分发", "已停止分發", "Discontinued"), color: .red)
                    } else if entry.isDeprecated {
                        BadgeView(text: tr("即将停更", "即將停更", "Deprecated"), color: .orange)
                    }

                    if let installedPkg {
                        BadgeView(
                            text: "\(tr("已安装", "已安裝", "Installed")) \(installedPkg.installedVersion ?? "")",
                            color: .green
                        )
                    } else if adoptableApp != nil {
                        BadgeView(
                            text: tr("本机已有此应用", "本機已有此應用", "On This Mac"),
                            color: .teal
                        )
                    }
                }

                let localizedDesc = ChineseSearchIndex.localizedDescription(for: entry)
                if !localizedDesc.isEmpty {
                    Text(localizedDesc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if entry.isDisabled {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        let reasonPart = entry.localizedLifecycleReason ?? tr("官方源已停止分发", "官方源已停止分發", "Disabled upstream")
                        let replPart = entry.replacementPackage.map { " · \(tr("推荐替代", "推薦替代", "Try")): \($0)" } ?? ""
                        Text("\(reasonPart)\(replPart)")
                            .font(.caption2)
                    }
                    .foregroundStyle(.red)
                } else {
                    HStack(spacing: 10) {
                        Text(entry.type.localizedHumanLabel)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        if !entry.version.isEmpty {
                            Text("v\(entry.version)")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }

                        if entry.displayName.lowercased() != entry.nameLower {
                            Text(entry.name)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            Spacer()

            // 3. Contextual Action Area (with live inline task status)
            HStack(spacing: 8) {
                if isRunningTask {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        if let frac = downloadProgress {
                            Text("\(Int(frac * 100))%")
                                .font(.caption.monospaced().weight(.semibold))
                                .foregroundStyle(.blue)
                        } else {
                            Text(tr("处理中…", "處理中…", "Working…"))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Capsule())
                } else if isQueuedTask {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(tr("排队中", "排隊中", "Queued"))
                            .font(.caption)
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                } else if installedPkg != nil {
                    if let appPath = resolvedAppPath {
                        Button {
                            onOpenInstalledApp(appPath)
                        } label: {
                            Label(tr("打开", "打開", "Open"), systemImage: "play.fill")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Label(tr("已安装", "已安裝", "Installed"), systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                    }
                } else if adoptableApp != nil {
                    if isLocalOlderThanCask {
                        Button {
                            onAdopt(true)
                        } label: {
                            Label(tr("升级并纳入", "升級並納入", "Upgrade & Manage"), systemImage: "arrow.up.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.small)
                    } else {
                        Button {
                            onAdopt(false)
                        } label: {
                            Label(tr("纳入管理", "納入管理", "Manage"), systemImage: "arrow.triangle.merge")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)
                        .controlSize(.small)
                    }

                    Menu {
                        if isLocalOlderThanCask {
                            Button {
                                onAdopt(false)
                            } label: {
                                Label(tr("仅登记管理（保留当前旧版本）", "僅登記管理（保留目前舊版本）", "Manage Without Updating"), systemImage: "checkmark.circle")
                            }
                        } else {
                            Button {
                                onInstall()
                            } label: {
                                Label(tr("重新下载并覆盖安装", "重新下載並覆蓋安裝", "Force Reinstall"), systemImage: "arrow.clockwise")
                            }
                        }
                        Button {
                            onIgnoreAdopt()
                        } label: {
                            Label(tr("忽略此本机应用", "忽略此本機應用", "Ignore This App"), systemImage: "eye.slash")
                        }
                        Divider()
                        Button {
                            onInspectDetail()
                        } label: {
                            Label(tr("查看软件详情", "檢視軟體詳情", "Package Details"), systemImage: "info.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                } else if entry.isDisabled {
                    if let repl = entry.replacementPackage, !repl.isEmpty {
                        Button {
                            onSearchReplacement(repl)
                        } label: {
                            Label("\(tr("看替代品", "看替代品", "Try")): \(repl)", systemImage: "arrow.right.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)
                        .controlSize(.small)
                    }

                    let fallbackURLString = !entry.homepage.isEmpty ? entry.homepage : (entry.downloadURL ?? "")
                    if let url = URL(string: fallbackURLString), !fallbackURLString.isEmpty {
                        Link(destination: url) {
                            Label(tr("前往官网", "前往官網", "Website"), systemImage: "safari")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                } else {
                    if let repl = entry.replacementPackage, !repl.isEmpty, entry.isDeprecated {
                        Button {
                            onSearchReplacement(repl)
                        } label: {
                            Text("\(tr("替代", "替代", "Try")): \(repl)")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Button {
                        onInstall()
                    } label: {
                        Label(tr("安装", "安裝", "Install"), systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                Button {
                    onInspectDetail()
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(tr("查看软件详情、配置提示与依赖", "檢視軟體詳情、設定提示與依賴", "Inspect details, caveats & dependencies"))
            }
        }
    }
}

private struct AdoptCandidateRow: View {
    let candidate: AdoptCandidate
    let isRunningTask: Bool
    let isQueuedTask: Bool
    let onAdoptOnly: () -> Void
    let onAdoptAndUpgrade: () -> Void
    let onToggleIgnore: () -> Void

    private var advisoryColor: Color {
        switch candidate.advisory {
        case .safeToAdopt:
            return .teal
        case .safeToAdoptAndUpgrade:
            return .orange
        case .cautionProductionVersion:
            return .purple
        case .suggestIgnoreAppStore:
            return .blue
        case .suggestIgnoreIOSWrapper, .suggestIgnoreVersionCollision:
            return .red
        case .suggestIgnoreCaskLagging, .suggestIgnoreDomesticUpdater:
            return .indigo
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            PackageIconView(
                token: candidate.caskToken,
                type: .cask,
                desc: candidate.desc,
                appPath: FileManager.default.fileExists(atPath: candidate.appPath) ? candidate.appPath : nil,
                size: 38
            )
            .opacity(candidate.isIgnored ? 0.5 : 1.0)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(candidate.caskDisplayName)
                        .font(.system(.body, design: .default).weight(.semibold))
                        .strikethrough(candidate.isIgnored)

                    if candidate.advisory != .safeToAdopt && candidate.advisory != .safeToAdoptAndUpgrade {
                        BadgeView(text: candidate.advisory.badgeText, color: advisoryColor)
                    } else if candidate.isLocalOlderThanCask {
                        BadgeView(text: tr("有新版本可升", "有新版本可升", "Update Available"), color: .orange)
                    } else {
                        BadgeView(text: tr("版本一致 · 可直接纳入", "版本一致 · 可直接納入", "Ready to Manage"), color: .teal)
                    }

                    if candidate.isIgnored {
                        BadgeView(text: tr("已忽略", "已忽略", "Ignored"), color: .gray)
                    }
                }

                let zhDesc = ChineseSearchIndex.meta(for: candidate.caskToken)?.zhDesc
                let displayDesc = (AppLanguage.current.resolved != .en && zhDesc != nil) ? zhDesc! : candidate.desc
                if !displayDesc.isEmpty {
                    Text(displayDesc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // Visual Version Comparison Strip
                HStack(spacing: 8) {
                    Text("\(tr("本机版本", "本機版本", "On Mac")): \(candidate.localVersion ?? tr("未知", "未知", "Unknown"))")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(candidate.isLocalOlderThanCask ? .orange : .secondary)

                    Text("\(tr("官方源版本", "官方源版本", "Latest")): \(candidate.caskVersion)")
                        .font(.caption2.monospaced().weight(candidate.isLocalOlderThanCask ? .semibold : .regular))
                        .foregroundStyle(candidate.isLocalOlderThanCask ? .orange : .teal)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                if isRunningTask {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text(tr("正在处理…", "正在處理…", "Working…"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if isQueuedTask {
                    Text(tr("排队中", "排隊中", "Queued"))
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if !candidate.isIgnored {
                    if candidate.isLocalOlderThanCask {
                        if candidate.isSuggestedToIgnore || candidate.isProductionVersionSensitive {
                            Button {
                                onAdoptAndUpgrade()
                            } label: {
                                Label(tr("升级并纳入", "升級並納入", "Upgrade & Manage"), systemImage: "arrow.up.circle")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        } else {
                            Button {
                                onAdoptAndUpgrade()
                            } label: {
                                Label(tr("升级并纳入", "升級並納入", "Upgrade & Manage"), systemImage: "arrow.up.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .controlSize(.small)
                        }

                        Button {
                            onAdoptOnly()
                        } label: {
                            Text(tr("仅保留旧版纳入", "僅保留舊版納入", "Keep Version"))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        if candidate.isSuggestedToIgnore {
                            Button {
                                onAdoptOnly()
                            } label: {
                                Label(tr("纳入管理", "納入管理", "Manage"), systemImage: "arrow.triangle.merge")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        } else {
                            Button {
                                onAdoptOnly()
                            } label: {
                                Label(tr("纳入管理", "納入管理", "Manage"), systemImage: "arrow.triangle.merge")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.teal)
                            .controlSize(.small)
                        }
                    }
                }

                if candidate.isSuggestedToIgnore && !candidate.isIgnored {
                    Button {
                        onToggleIgnore()
                    } label: {
                        Label(tr("忽略 (推荐)", "忽略 (推薦)", "Ignore (Rec.)"), systemImage: "eye.slash.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .controlSize(.small)
                } else {
                    Button {
                        onToggleIgnore()
                    } label: {
                        Label(
                            candidate.isIgnored ? tr("恢复", "恢復", "Restore") : tr("忽略", "忽略", "Ignore"),
                            systemImage: candidate.isIgnored ? "eye" : "eye.slash"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }
}

public struct AdoptDecisionGuideSheet: View {
    @ObservedObject var store: BrewStore

    public init(store: BrewStore) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .font(.system(size: 28))
                    .foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("本机软件接管 (Adopt) 避坑与决策指南", "本機軟體接管 (Adopt) 避坑與決策指南", "Local App Adoption Decision Guide"))
                        .font(.title3.weight(.bold))
                    Text(tr("旧机器首次使用必读：一图看懂哪些软件该「接管升级」、哪些该「忽略」", "舊機器首次使用必讀：一圖看懂哪些軟體該「接管升級」、哪些該「忽略」", "Essential guide for existing Macs: which apps to Adopt & Upgrade vs. Ignore"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    store.showAdoptGuideSheet = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            Text(tr("一、 遇到以下 4 类软件，强烈建议点击【忽略】（或【仅认领】）：", "一、 遇到以下 4 類軟體，強烈建議點擊【忽略】（或【僅認領】）：", "1. Click [Ignore] (or [Adopt Only]) for these 4 categories:"))
                .font(.callout.weight(.semibold))

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                guideCard(
                    icon: "bag.fill",
                    color: .blue,
                    title: tr("1. Mac App Store 渠道应用", "1. Mac App Store 管道應用", "1. Mac App Store Apps"),
                    examples: tr("例：网易有道翻译、Xcode、GoodNotes", "例：網易有道翻譯、Xcode、GoodNotes", "e.g. Youdao Dict, Xcode, MAS apps"),
                    reason: tr("商店版自动更新更积极，且含沙盒权限与内购收据。若用 Brew 覆盖会丢失商店收据。", "商店版自動更新更積極，且含沙盒權限與內購收據。若用 Brew 覆蓋會遺失商店收據。", "App Store handles updates and receipts. Overwriting via Cask breaks MAS receipts."),
                    actionBadge: tr("建议动作：忽略 (系统已自动识别)", "建議動作：忽略 (系統已自動識別)", "Action: Ignore (Auto-detected)")
                )

                guideCard(
                    icon: "hammer.fill",
                    color: .purple,
                    title: tr("2. 生产力版本锁定 / 老版本插件兼容", "2. 生產力版本鎖定 / 老版本外掛相容", "2. Version-Locked Pro & Plugin Apps"),
                    examples: tr("例：Blender (工程兼容)、Eagle (旧版插件)", "例：Blender (工程相容)、Eagle (舊版外掛)", "e.g. Blender, Eagle, Unity, OBS"),
                    reason: tr("生产环境常需锁定特定小版本以兼容团队工程或第三方插件，盲目升级会导致插件失效。", "生產環境常需鎖定特定小版本以相容團隊工程或第三方外掛，盲目升級會導致外掛失效。", "Upgrading may break third-party plugins or project compatibility."),
                    actionBadge: tr("建议动作：忽略（或点「仅认领」后锁定版本）", "建議動作：忽略（或點「僅認領」後鎖定版本）", "Action: Ignore (or Adopt Only + Pin)")
                )

                guideCard(
                    icon: "arrow.triangle.2.circlepath.circle.fill",
                    color: .indigo,
                    title: tr("3. 国内内建热更新更快的软件", "3. 國內內建熱更新更快的軟體", "3. Apps with Faster Built-in Updaters"),
                    examples: tr("例：网易云音乐、微信、飞书、百度网盘", "例：網易雲音樂、微信、飛書、百度網盤", "e.g. NeteaseMusic, WeChat, Feishu"),
                    reason: tr("此类应用内置增量更新往往比 Homebrew Cask 社区维护更新更快（甚至本地版本已高于 Cask）。", "此類應用內建增量更新往往比 Homebrew Cask 社群維護更新更快（甚至本機版本已高於 Cask）。", "Official built-in updaters often outpace community Cask definitions."),
                    actionBadge: tr("建议动作：忽略 (系统已自动识别)", "建議動作：忽略 (系統已自動識別)", "Action: Ignore (Auto-detected)")
                )

                guideCard(
                    icon: "exclamationmark.octagon.fill",
                    color: .red,
                    title: tr("4. 同名软件撞库 / 版本号悬殊", "4. 同名軟體撞庫 / 版本號懸殊", "4. Name Collisions & Version Mismatch"),
                    examples: tr("例：本地自封装应用 1.0.0 vs Cask 741.1", "例：本機自封裝應用 1.0.0 vs Cask 741.1", "e.g. Local wrapper 1.0.0 vs Cask 741.1"),
                    reason: tr("部分网页封装应用或同名工具刚好与 Cask 里的其他软件重名，强制升级会把原软件替换成别的软件。", "部分網頁封裝應用或同名工具剛好與 Cask 裡的其他軟體重名，強制升級會把原軟體替換成別的軟體。", "Different apps sharing the same bundle name. Upgrading would overwrite the wrong app."),
                    actionBadge: tr("建议动作：忽略 (系统已自动预警)", "建議動作：忽略 (系統已自動預警)", "Action: Ignore (Auto-warned)")
                )
            }

            Divider()

            // Safe to Adopt & Button Comparison
            VStack(alignment: .leading, spacing: 8) {
                Label(
                    tr("二、 哪些软件最适合交给 BrewGUI 管理？", "二、 哪些軟體最適合交給 BrewGUI 管理？", "2. Which apps are best managed by BrewGUI?"),
                    systemImage: "checkmark.seal.fill"
                )
                .font(.callout.weight(.semibold))
                .foregroundStyle(.teal)

                Text(
                    tr(
                        "开源工具与国际主流软件（如 Google Chrome、IINA、Clash Verge、ChatGPT、MacZip、BambuStudio、VS Code 等），Cask 源版本纯净且更新极快，直接点击「接管并升级」或「Adopt (接管)」即可！",
                        "開源工具與國際主流軟體（如 Google Chrome、IINA、Clash Verge、ChatGPT、MacZip、BambuStudio、VS Code 等），Cask 源版本純淨且更新極快，直接點擊「接管並升級」或「Adopt (接管)」即可！",
                        "Open-source & international apps (Chrome, IINA, Clash Verge, ChatGPT, MacZip, BambuStudio, VS Code, etc.) have clean, fast-updating Casks — click \"Adopt & Upgrade\" or \"Adopt\"!"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.teal.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                if !store.suggestedIgnoreAdoptCandidates.isEmpty {
                    Button {
                        store.ignoreAllSuggestedAdoptCandidates()
                        store.showAdoptGuideSheet = false
                    } label: {
                        Label(
                            tr(
                                "一键忽略当前识别出的 \(store.suggestedIgnoreAdoptCandidates.count) 个不推荐项",
                                "一鍵忽略目前識別出的 \(store.suggestedIgnoreAdoptCandidates.count) 個不推薦項",
                                "Ignore All \(store.suggestedIgnoreAdoptCandidates.count) Flagged Apps Now"
                            ),
                            systemImage: "eye.slash.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                }

                Spacer()

                Button(tr("我知道了", "我知道了", "Got It")) {
                    store.showAdoptGuideSheet = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 680)
    }

    @ViewBuilder
    private func guideCard(icon: String, color: Color, title: String, examples: String, reason: String, actionBadge: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.weight(.bold))
                Spacer()
            }
            Text(examples)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
            Text(reason)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 2)
            BadgeView(text: actionBadge, color: color)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(color.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.22), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
