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

    public var body: some View {
        VStack(spacing: 0) {
            // Top Search Bar & Filter
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(
                        store.catalogTypeFilter == .adoptable
                            ? tr("筛选本机可接管应用名称、中文名或 Cask Token…", "篩選本機可接管應用程式名稱、中文名或 Cask Token…", "Filter adoptable apps or Cask tokens…")
                            : tr("搜索包名、中文名或功能词（如：截图、解压、播放器、翻译、终端、微信）…", "搜尋套件名、中文名或功能詞（如：截圖、解壓、播放器、翻譯、終端、微信）…", "Search Formulae or Casks (by name, Chinese alias, or functional keyword)…"),
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
                Text(tr("正在构建本地全量元数据索引…", "正在建構本機全量中繼資料索引…", "Building local full catalog index…"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                let resultCount = store.filteredCatalogEntries.count
                let totalCount = store.catalogEntries.count
                Text(
                    tr(
                        "本地索引库共 \(totalCount) 个软件包 · 已内置中文别名与场景词典（显示前 \(resultCount) 条结果）",
                        "本機索引庫共 \(totalCount) 個軟體套件 · 已內建中文別名與場景詞典（顯示前 \(resultCount) 筆結果）",
                        "\(totalCount) packages indexed locally with bilingual alias & category tags (showing top \(resultCount) matches)"
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

        if store.filteredCatalogEntries.isEmpty && !store.isLoadingCatalog {
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
            List(store.filteredCatalogEntries) { entry in
                let adoptApp = store.adoptableAppName(for: entry)
                SearchCatalogRow(
                    entry: entry,
                    installedPkg: store.installedPackage(for: entry),
                    adoptableApp: adoptApp,
                    isLocalOlderThanCask: store.adoptCandidate(for: entry.name)?.isLocalOlderThanCask ?? false,
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
                    onSearchReplacement: { repl in store.catalogSearchQuery = repl }
                )
                .padding(.vertical, 4)
            }
            .listStyle(.inset)
        }
    }

    // MARK: - Subview: Adopt Scanner Mode

    @ViewBuilder
    private var adoptModeContent: some View {
        // Caution & Explanation Banner with Visual Decision Guide & One-Click Ignore
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.teal)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(tr("本机应用接管智能避坑提示 (`--adopt` vs `--force`)：", "本機應用程式接管智慧避坑提示 (`--adopt` vs `--force`)：", "Smart Cask Adopt Guide (`--adopt` vs `--force`):"))
                            .font(.caption.weight(.semibold))

                        Button {
                            store.showAdoptGuideSheet = true
                        } label: {
                            Label(tr("📖 接管避坑图文指南 (哪些该忽略？)", "📖 接管避坑圖文指南 (哪些該忽略？)", "📖 Adopt Decision Guide (What to Ignore?)"), systemImage: "questionmark.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)
                        .controlSize(.mini)

                        if !store.suggestedIgnoreAdoptCandidates.isEmpty {
                            Button {
                                store.ignoreAllSuggestedAdoptCandidates()
                            } label: {
                                Label(
                                    tr(
                                        "一键忽略 \(store.suggestedIgnoreAdoptCandidates.count) 个不推荐项",
                                        "一鍵忽略 \(store.suggestedIgnoreAdoptCandidates.count) 個不推薦項",
                                        "Ignore \(store.suggestedIgnoreAdoptCandidates.count) Suggested"
                                    ),
                                    systemImage: "eye.slash.fill"
                                )
                            }
                            .buttonStyle(.bordered)
                            .tint(.indigo)
                            .controlSize(.mini)
                            .help(tr("自动忽略已识别出的 App Store 渠道、国内内置更新更快及疑似同名撞库的应用", "自動忽略已識別出的 App Store 管道、國內內建更新更快及疑似同名撞庫的應用", "Automatically ignore App Store apps, faster self-updating apps, and version collisions"))
                        }
                    }

                    Text(
                        tr(
                            "• 开源与国际通用工具（如 Chrome / IINA / Clash / MacZip）推荐直接点击「接管并升级」或「Adopt」。\n• 对 App Store 渠道、需保留特定生产版本/老插件兼容（如 Blender / Eagle）、国内内建热更新更快（如网易云音乐）或版本号悬殊撞库的应用，系统已为您自动标记提示，建议点击「忽略」或「仅认领」。",
                            "• 開源與國際通用工具（如 Chrome / IINA / Clash / MacZip）推薦直接點擊「接管並升級」或「Adopt」。\n• 對 App Store 管道、需保留特定生產版本/老外掛相容（如 Blender / Eagle）、國內內建熱更新更快（如網易雲音樂）或版本號懸殊撞庫的應用，系統已為您自動標記提示，建議點擊「忽略」或「僅認領」。",
                            "• Open-source & global utilities (Chrome, IINA, Clash, MacZip) are great for \"Adopt & Upgrade\".\n• For App Store apps, version-locked pro/plugin apps (Blender, Eagle), faster self-updating domestic apps, or version collisions, check the smart badges and click \"Ignore\" or \"Adopt Only\"."
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
        .sheet(isPresented: $store.showAdoptGuideSheet) {
            AdoptDecisionGuideSheet(store: store)
        }

        Divider()

        if store.filteredAdoptCandidatesList.isEmpty {
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
            List(store.filteredAdoptCandidatesList) { candidate in
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
    let onSearchReplacement: (String) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(entry.displayName)
                        .font(.system(.body, design: .default).weight(.semibold))
                        .strikethrough(entry.isDisabled && installedPkg == nil)
                        .foregroundStyle(entry.isDisabled && installedPkg == nil ? .secondary : .primary)

                    if entry.displayName != entry.name {
                        Text("(\(entry.name))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if AppLanguage.current.resolved != .en,
                       let zhBadge = ChineseSearchIndex.displayBadge(for: entry),
                       zhBadge.lowercased() != entry.displayLower {
                        BadgeView(text: zhBadge, color: .orange)
                    }

                    BadgeView(
                        text: entry.type.rawValue,
                        color: entry.type == .cask ? .purple : .blue
                    )

                    if let tap = entry.tap, !tap.isEmpty {
                        BadgeView(text: "Tap: \(tap)", color: .indigo)
                    }

                    if entry.isDisabled {
                        BadgeView(
                            text: tr("已禁用", "已停用", "Disabled"),
                            color: .red
                        )
                    } else if entry.isDeprecated {
                        BadgeView(
                            text: tr("已弃用", "已棄用", "Deprecated"),
                            color: .orange
                        )
                    }

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

                let localizedDesc = ChineseSearchIndex.localizedDescription(for: entry)
                if !localizedDesc.isEmpty {
                    Text(localizedDesc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if entry.isDisabled {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        let datePart = entry.disableDate.map { " (\($0))" } ?? ""
                        let reasonPart = entry.localizedLifecycleReason ?? tr("已被官方标记为不可用", "已被官方標記為不可用", "Disabled by Homebrew")
                        let replPart = entry.replacementPackage.map { " · \(tr("推荐替代包", "推薦替代套件", "Replacement")): \($0)" } ?? ""
                        Text("\(tr("Homebrew 已禁用此包安装", "Homebrew 已停用此套件安裝", "Disabled in Homebrew"))\(datePart)：\(reasonPart)\(replPart)")
                            .font(.caption)
                    }
                    .foregroundStyle(.red)
                } else if entry.isDeprecated {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.caption2)
                        let reasonPart = entry.localizedLifecycleReason ?? tr("即将停止维护", "即將停止維護", "Deprecated upstream")
                        let replPart = entry.replacementPackage.map { " · \(tr("推荐替代包", "推薦替代套件", "Replacement")): \($0)" } ?? ""
                        if let futureDisable = entry.disableDate, !futureDisable.isEmpty {
                            Text("\(tr("将于 \(futureDisable) 禁用", "將於 \(futureDisable) 停用", "Will be disabled on \(futureDisable)"))：\(reasonPart)\(replPart)")
                                .font(.caption)
                        } else {
                            let depDatePart = entry.deprecateDate.map { " (\($0))" } ?? ""
                            Text("\(tr("已标记弃用", "已標記棄用", "Deprecated"))\(depDatePart)：\(reasonPart)\(replPart)")
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(.orange)
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
                } else if entry.isDisabled {
                    if let repl = entry.replacementPackage, !repl.isEmpty {
                        Button {
                            onSearchReplacement(repl)
                        } label: {
                            Label("\(tr("搜替代包", "搜尋替代套件", "Replacement")): \(repl)", systemImage: "arrow.right.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)
                        .controlSize(.small)
                        .help(tr("搜索并查看官方推荐替代包 \(repl)", "搜尋並檢視官方推薦替代套件 \(repl)", "Search for recommended replacement package \(repl)"))
                    }

                    let fallbackURLString = !entry.homepage.isEmpty ? entry.homepage : (entry.downloadURL ?? "")
                    if let url = URL(string: fallbackURLString), !fallbackURLString.isEmpty {
                        Link(destination: url) {
                            Label(tr("前往官网下载", "前往官網下載", "Get from Website"), systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help(
                            tr(
                                "Homebrew 已禁用该包的命令安装（\(entry.localizedLifecycleReason ?? "")）。请前往官网或 GitHub Releases 手动下载安装（首次打开若遇拦截可在「系统设置 → 隐私与安全性」点击仍要打开）。",
                                "Homebrew 已停用該套件的命令安裝（\(entry.localizedLifecycleReason ?? "")）。請前往官網或 GitHub Releases 手動下載安裝（首次開啟若遇攔截可在「系統設定 → 隱私權與安全性」點擊仍要打開）。",
                                "Disabled in Homebrew (\(entry.localizedLifecycleReason ?? "")). Please download directly from the official website or GitHub Releases."
                            )
                        )
                    } else {
                        Label(tr("已禁用", "已停用", "Disabled"), systemImage: "nosign")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 8)
                    }
                } else {
                    if let repl = entry.replacementPackage, !repl.isEmpty, entry.isDeprecated {
                        Button {
                            onSearchReplacement(repl)
                        } label: {
                            Text("\(tr("替代包", "替代套件", "Try")): \(repl)")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help(tr("查看推荐替代包 \(repl)", "檢視推薦替代套件 \(repl)", "Search replacement package \(repl)"))
                    }

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
            Image(nsImage: NSWorkspace.shared.icon(forFile: candidate.appPath))
                .resizable()
                .frame(width: 36, height: 36)
                .opacity(candidate.isIgnored ? 0.5 : 1.0)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(candidate.appName)
                        .font(.system(.body, design: .default).weight(.semibold))
                        .strikethrough(candidate.isIgnored)

                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    BadgeView(text: "cask: \(candidate.caskToken)", color: .teal)

                    if candidate.isLocalOlderThanCask && !candidate.isSuspiciousVersionCollision {
                        BadgeView(text: tr("本地版本较旧", "本機版本較舊", "Local Outdated"), color: .orange)
                    } else if candidate.isLocalNewerThanCask {
                        BadgeView(text: tr("本地版本更新", "本機版本更新", "Local Newer"), color: .indigo)
                    }

                    if candidate.advisory != .safeToAdopt && candidate.advisory != .safeToAdoptAndUpgrade {
                        BadgeView(text: candidate.advisory.badgeText, color: advisoryColor)
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
                        .foregroundStyle(candidate.isLocalOlderThanCask ? .orange : (candidate.isLocalNewerThanCask ? .indigo : .secondary))

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
                        if candidate.isSuggestedToIgnore || candidate.isProductionVersionSensitive {
                            Button {
                                onAdoptAndUpgrade()
                            } label: {
                                Label(tr("接管并升级", "接管並升級", "Adopt & Upgrade"), systemImage: "arrow.up.circle")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help(tr("将退出运行中的旧应用并执行 brew install --cask --force \(candidate.caskToken) 覆盖为新版", "將結束執行中的舊應用並執行 brew install --cask --force \(candidate.caskToken) 覆蓋為新版", "Quits running app and runs brew install --cask --force \(candidate.caskToken)"))
                        } else {
                            Button {
                                onAdoptAndUpgrade()
                            } label: {
                                Label(tr("接管并升级", "接管並升級", "Adopt & Upgrade"), systemImage: "arrow.up.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .controlSize(.small)
                            .help(tr("本地版本低于 Cask 版本：将自动退出运行中的旧应用并执行 brew install --cask --force \(candidate.caskToken) 覆盖为新版", "本機版本低於 Cask 版本：將自動結束執行中的舊應用並執行 brew install --cask --force \(candidate.caskToken) 覆蓋為新版", "Local app is older: quits running app and runs brew install --cask --force \(candidate.caskToken)"))
                        }

                        Button {
                            onAdoptOnly()
                        } label: {
                            Text(tr("仅认领", "僅認領", "Adopt Only"))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help(tr("执行 --adopt 仅登记给 Brew 但保留本地旧版文件不覆盖", "執行 --adopt 僅登記給 Brew 但保留本機舊版檔案不覆蓋", "Runs --adopt without overwriting local files"))
                    } else {
                        if candidate.isSuggestedToIgnore {
                            Button {
                                onAdoptOnly()
                            } label: {
                                Label(tr("Adopt (接管)", "Adopt (接管)", "Adopt"), systemImage: "arrow.triangle.merge")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help(tr("执行 brew install --cask --adopt \(candidate.caskToken) 接管", "執行 brew install --cask --adopt \(candidate.caskToken) 接管", "Run brew install --cask --adopt \(candidate.caskToken)"))
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
                    .help(candidate.advisory.badgeText)
                } else {
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
                    .help(candidate.isIgnored ? tr("取消忽略该应用", "取消忽略該應用程式", "Restore this app to adoptable list") : tr("忽略该应用（如商店版或不需要 Brew 管理的软件）", "忽略該應用程式（如商店版或不需要 Brew 管理的軟體）", "Ignore this app"))
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
