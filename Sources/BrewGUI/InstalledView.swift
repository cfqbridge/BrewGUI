import SwiftUI
import AppKit

public enum InstalledFilterCategory: String, CaseIterable, Identifiable {
    case all = "全部"
    case outdated = "可更新"
    case casks = "Cask"
    case formulae = "Formula"

    public var id: String { rawValue }

    public var localizedLabel: String {
        switch self {
        case .all:
            return tr("全部", "全部", "All")
        case .outdated:
            return tr("待更新", "待更新", "Updates")
        case .casks:
            return tr("桌面应用", "桌面應用", "Desktop Apps")
        case .formulae:
            return tr("命令行", "命令列", "CLI Tools")
        }
    }
}

public struct InstalledView: View {
    @ObservedObject var store: BrewStore

    public init(store: BrewStore) {
        self.store = store
    }

    private var filteredPackages: [BrewPackage] {
        store.installedPackages.filter { pkg in
            if !store.showAllDependencies && !pkg.isTopLevel {
                return false
            }
            switch store.installedCategory {
            case .all:
                break
            case .outdated:
                let isOutdatedNow = pkg.isOutdated || (store.includeGreedyOutdated && pkg.isGreedyOutdated)
                if !isOutdatedNow && !pkg.hasBundleVersionMismatch { return false }
            case .formulae:
                if pkg.type != .formula { return false }
            case .casks:
                if pkg.type != .cask { return false }
            }
            if !store.installedSearchText.isEmpty {
                let q = store.installedSearchText.lowercased()
                let matchName = pkg.name.lowercased().contains(q)
                let matchDisplay = pkg.displayName.lowercased().contains(q)
                let matchDesc = pkg.desc.lowercased().contains(q)
                let matchZh = ChineseSearchIndex.meta(for: pkg.name)?.zhNameLower.contains(q) ?? false
                return matchName || matchDisplay || matchDesc || matchZh
            }
            return true
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Toolbar Bar
            HStack(spacing: 10) {
                Picker(tr("分类", "分類", "Category"), selection: $store.installedCategory) {
                    ForEach(InstalledFilterCategory.allCases) { item in
                        if item == .outdated && store.outdatedCount > 0 {
                            Text("\(item.localizedLabel) (\(store.outdatedCount))").tag(item)
                        } else {
                            Text(item.localizedLabel).tag(item)
                        }
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()

                // Compact View Options Menu (Replaces technical switches in main bar)
                Menu {
                    Toggle(
                        store.greedyOnlyOutdatedCount > 0
                            ? tr("检测应用内自更新软件 (+\(store.greedyOnlyOutdatedCount) 款可更)", "偵測應用內自更新軟體 (+\(store.greedyOnlyOutdatedCount) 款可更)", "Include Self-Updating Apps (+\(store.greedyOnlyOutdatedCount))")
                            : tr("检测应用内自更新软件", "偵測應用內自更新軟體", "Include Self-Updating Apps"),
                        isOn: $store.includeGreedyOutdated
                    )

                    Toggle(
                        tr("显示底层运行依赖库", "顯示底層執行依賴函式庫", "Show Underlying Libraries"),
                        isOn: $store.showAllDependencies
                    )
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                        Text(tr("筛选选项", "篩選選項", "Options"))
                        if store.includeGreedyOutdated || store.showAllDependencies {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 6, height: 6)
                        }
                    }
                }
                .menuStyle(.borderedButton)
                .controlSize(.small)
                .fixedSize()

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        store.checkUpdates()
                    } label: {
                        Label(tr("检查更新", "檢查更新", "Check Updates"), systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(store.isLoadingInstalled)

                    Button {
                        store.upgradeAll()
                    } label: {
                        if store.outdatedCount > 0 {
                            Label(
                                tr("全部更新 (\(store.outdatedCount))", "全部更新 (\(store.outdatedCount))", "Update All (\(store.outdatedCount))"),
                                systemImage: "arrow.up.circle.fill"
                            )
                        } else {
                            Label(
                                tr("全部更新", "全部更新", "Update All"),
                                systemImage: "arrow.up.circle"
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Search & Contextual Summary Sub-bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(
                    tr("在已安装软件中搜索名称、中文名或功能描述…", "在已安裝軟體中搜尋名稱、中文名或功能描述…", "Filter installed apps or tools…"),
                    text: $store.installedSearchText
                )
                .textFieldStyle(.plain)
                if !store.installedSearchText.isEmpty {
                    Button {
                        store.installedSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if !store.includeGreedyOutdated && store.greedyOnlyOutdatedCount > 0 {
                    Button {
                        store.includeGreedyOutdated = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            Text(
                                tr(
                                    "另有 \(store.greedyOnlyOutdatedCount) 款内置自更新软件有新版，点击一并显示",
                                    "另有 \(store.greedyOnlyOutdatedCount) 款內建自更新軟體有新版，點擊一併顯示",
                                    "+\(store.greedyOnlyOutdatedCount) self-updating apps have new versions — click to show"
                                )
                            )
                        }
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.indigo.opacity(0.12))
                        .foregroundStyle(.indigo)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(
                        tr(
                            "共 \(filteredPackages.count) 款软件",
                            "共 \(filteredPackages.count) 款軟體",
                            "\(filteredPackages.count) items"
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if let errorMessage = store.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(errorMessage)
                        .font(.callout)
                    Spacer()
                }
                .padding(12)
                .background(Color.orange.opacity(0.12))
            }

            // Contextual Adopt Callout in InstalledView (educates users where they manage apps)
            if !store.activeAdoptCandidates.isEmpty
                && !store.isInstalledAdoptBannerDismissed
                && store.installedSearchText.isEmpty
                && (store.installedCategory == .all || store.installedCategory == .casks) {
                let previewCandidates = Array(store.activeAdoptCandidates.prefix(4))
                let recommendedCount = store.activeAdoptCandidates.filter { !$0.isSuggestedToIgnore }.count
                HStack(spacing: 12) {
                    HStack(spacing: -6) {
                        ForEach(previewCandidates) { cand in
                            let hasDiskIcon = FileManager.default.fileExists(atPath: cand.appPath)
                            PackageIconView(
                                token: cand.caskToken,
                                type: .cask,
                                desc: cand.desc,
                                appPath: hasDiskIcon ? cand.appPath : nil,
                                size: 24
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5)
                            )
                        }
                    }

                    Text(
                        recommendedCount > 0
                            ? tr(
                                "本机还有 \(store.activeAdoptCandidates.count) 款手动安装的应用（其中 \(recommendedCount) 款推荐纳入）可交由 BrewGUI 统一更新",
                                "本機還有 \(store.activeAdoptCandidates.count) 款手動安裝的應用（其中 \(recommendedCount) 款推薦納入）可交由 BrewGUI 統一更新",
                                "\(store.activeAdoptCandidates.count) manually installed apps on this Mac (\(recommendedCount) recommended) can be managed here"
                            )
                            : tr(
                                "本机还有 \(store.activeAdoptCandidates.count) 款手动安装的应用可纳入统一更新管理",
                                "本機還有 \(store.activeAdoptCandidates.count) 款手動安裝的應用可納入統一更新管理",
                                "\(store.activeAdoptCandidates.count) manually installed apps on this Mac can be managed here"
                            )
                    )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary.opacity(0.9))
                    .lineLimit(1)

                    Spacer()

                    Button {
                        store.selectedTab = .search
                        store.catalogTypeFilter = .adoptable
                    } label: {
                        Text(tr("前往纳入管理 →", "前往納入管理 →", "Review & Adopt →"))
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.teal)
                    .controlSize(.mini)

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            store.isInstalledAdoptBannerDismissed = true
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(tr("本次隐藏此提示", "本次隱藏此提示", "Dismiss"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.teal.opacity(0.08))

                Divider()
            }

            // Package List
            if store.isLoadingInstalled && store.installedPackages.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(tr("正在读取本机已纳管的软件列表…", "正在讀取本機已納管的軟體列表…", "Loading managed software list…"))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredPackages.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: store.installedCategory == .outdated ? "checkmark.seal.fill" : "shippingbox")
                        .font(.system(size: 38))
                        .foregroundStyle(store.installedCategory == .outdated ? .green : .secondary)
                    Text(
                        store.installedCategory == .outdated
                            ? tr("所有软件均为最新版本", "所有軟體均為最新版本", "All software is up to date")
                            : tr("没有符合当前筛选条件的软件", "沒有符合目前篩選條件的軟體", "No software matches the current filter")
                    )
                    .font(.headline)
                    .foregroundStyle(.secondary)

                    if store.installedCategory == .outdated && !store.includeGreedyOutdated && store.greedyOnlyOutdatedCount > 0 {
                        Button {
                            store.includeGreedyOutdated = true
                        } label: {
                            Label(
                                tr(
                                    "查看 \(store.greedyOnlyOutdatedCount) 款支持应用内自更新的软件新版",
                                    "檢視 \(store.greedyOnlyOutdatedCount) 款支援應用內自更新的軟體新版",
                                    "Show \(store.greedyOnlyOutdatedCount) updates for self-updating apps"
                                ),
                                systemImage: "sparkles"
                            )
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredPackages) { pkg in
                    let isEffectivelyOutdated = pkg.isOutdated || (store.includeGreedyOutdated && pkg.isGreedyOutdated)
                    InstalledPackageRow(
                        pkg: pkg,
                        includeGreedy: store.includeGreedyOutdated,
                        probedSizeBytes: (isEffectivelyOutdated || pkg.hasBundleVersionMismatch) ? store.sizeBytes(for: pkg.name) : nil,
                        isRunningTask: store.isPackageCurrentlyRunning(pkg.name),
                        isQueuedTask: store.isPackageQueued(pkg.name),
                        downloadProgress: store.isPackageCurrentlyRunning(pkg.name) ? store.activeDownloadInfo?.progressFraction : nil,
                        onUpgrade: { store.upgradePackage(pkg) },
                        onTogglePin: { store.togglePin(pkg) },
                        onRemoveQuarantine: { store.removeQuarantine(for: pkg) },
                        onUninstall: { store.packagePendingUninstall = pkg },
                        onOpenApp: { path in store.openInstalledApp(at: path) },
                        onRevealInFinder: { path in store.revealPathInFinder(path) },
                        onInspectDetail: { store.inspectPackage(pkg) }
                    )
                    .padding(.vertical, 5)
                }
                .listStyle(.inset)
            }
        }
        .confirmationDialog(
            tr(
                "确认卸载 \(store.packagePendingUninstall?.displayName ?? "")？",
                "確認解除安裝 \(store.packagePendingUninstall?.displayName ?? "")？",
                "Uninstall \(store.packagePendingUninstall?.displayName ?? "")?"
            ),
            isPresented: Binding(
                get: { store.packagePendingUninstall != nil },
                set: { if !$0 { store.packagePendingUninstall = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let pkg = store.packagePendingUninstall {
                if pkg.type == .cask {
                    Button(tr("彻底卸载（同时清理配置与缓存残留）", "徹底解除安裝（同時清理設定與快取殘留）", "Complete Uninstall (remove app, preferences & caches)"), role: .destructive) {
                        store.uninstallPackage(pkg, zap: true)
                        store.packagePendingUninstall = nil
                    }
                    Button(tr("仅移除应用（保留个人配置数据）", "僅移除應用（保留個人設定資料）", "Remove App Only (keep personal settings)"), role: .destructive) {
                        store.uninstallPackage(pkg, zap: false)
                        store.packagePendingUninstall = nil
                    }
                } else {
                    Button("\(tr("确认卸载", "確認解除安裝", "Uninstall")) \(pkg.displayName)", role: .destructive) {
                        store.uninstallPackage(pkg, zap: false)
                        store.packagePendingUninstall = nil
                    }
                }
            }
            Button(tr("取消", "取消", "Cancel"), role: .cancel) {
                store.packagePendingUninstall = nil
            }
        } message: {
            if let pkg = store.packagePendingUninstall {
                if pkg.type == .cask {
                    Text(
                        tr(
                            "「彻底卸载」在移除应用程序的同时，会将该软件在个人目录下的缓存与配置文件一并移至废纸篓；「仅移除应用」则保留个人配置以便日后重装。",
                            "「徹底解除安裝」在移除應用程式的同時，會將該軟體在個人目錄下的快取與設定檔一併移至垃圾桶；「僅移除應用」則保留個人設定以便日後重裝。",
                            "Complete Uninstall also moves associated user preferences and caches to the Trash; Remove App Only keeps your personal configuration."
                        )
                    )
                } else {
                    Text(
                        tr(
                            "将从本机移除命令行工具 \(pkg.displayName)。",
                            "將從本機移除命令列工具 \(pkg.displayName)。",
                            "Will remove the command-line tool \(pkg.displayName) from your Mac."
                        )
                    )
                }
            }
        }
    }
}

private struct InstalledPackageRow: View {
    let pkg: BrewPackage
    let includeGreedy: Bool
    let probedSizeBytes: Int64?
    let isRunningTask: Bool
    let isQueuedTask: Bool
    let downloadProgress: Double?
    let onUpgrade: () -> Void
    let onTogglePin: () -> Void
    let onRemoveQuarantine: () -> Void
    let onUninstall: () -> Void
    let onOpenApp: (String) -> Void
    let onRevealInFinder: (String) -> Void
    let onInspectDetail: () -> Void

    private var isEffectivelyOutdated: Bool {
        pkg.isOutdated || (includeGreedy && pkg.isGreedyOutdated)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // 1. Visual Icon Anchor
            Button {
                onInspectDetail()
            } label: {
                PackageIconView(
                    token: pkg.name,
                    type: pkg.type,
                    desc: pkg.desc,
                    appPath: pkg.resolvedAppPath,
                    size: 38
                )
            }
            .buttonStyle(.plain)

            // 2. Clean Title + Localized Description + Version Line
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Button {
                        onInspectDetail()
                    } label: {
                        Text(pkg.displayName)
                            .font(.system(.body, design: .default).weight(.semibold))
                    }
                    .buttonStyle(.plain)

                    if let tap = pkg.tap, !tap.isEmpty {
                        BadgeView(text: tr("第三方源", "第三方源", "3rd-Party"), color: .indigo)
                    }

                    if !pkg.isTopLevel {
                        BadgeView(text: tr("底层依赖", "底層依賴", "Library"), color: .gray)
                    }

                    if pkg.isPinned {
                        BadgeView(text: tr("🔒 已固定版本", "🔒 已固定版本", "🔒 Pinned"), color: .orange)
                    }

                    if pkg.isAppBundleMissingOnDisk {
                        BadgeView(text: tr("应用已从磁盘移走", "應用已從磁碟移走", "App Removed from Disk"), color: .orange)
                    } else if pkg.hasBundleVersionMismatch {
                        BadgeView(text: tr("版本需同步覆盖", "版本需同步覆蓋", "Needs Sync"), color: .orange)
                    }

                    if let sizeBytes = probedSizeBytes, sizeBytes > 0 {
                        let isLarge = sizeBytes >= 150 * 1024 * 1024
                        BadgeView(
                            text: "📦 \(AppConstants.formatBytes(sizeBytes))",
                            color: isLarge ? .orange : .teal
                        )
                    }
                }

                let localizedDesc = ChineseSearchIndex.localizedDescription(for: pkg)
                if !localizedDesc.isEmpty {
                    Text(localizedDesc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 10) {
                    Text(pkg.type.localizedHumanLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if pkg.hasBundleVersionMismatch && !isEffectivelyOutdated {
                        HStack(spacing: 4) {
                            Text("\(tr("本机实际", "本機實際", "On Mac")): \(pkg.actualBundleVersion ?? "?")")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.orange)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.orange)
                            Text("\(tr("可同步至", "可同步至", "Sync to")): \(pkg.latestVersion)")
                                .font(.caption2.monospaced().weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                    } else if isEffectivelyOutdated {
                        HStack(spacing: 4) {
                            Text(pkg.installedVersion ?? "")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.orange)
                            Text(pkg.latestVersion)
                                .font(.caption2.monospaced().weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                    } else {
                        Text("v\(pkg.installedVersion ?? pkg.latestVersion)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // 3. Contextual Right Actions (No Icon Clutter)
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
                            Text(tr("更新中…", "更新中…", "Updating…"))
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
                } else {
                    if isEffectivelyOutdated || pkg.hasBundleVersionMismatch {
                        Button {
                            onUpgrade()
                        } label: {
                            Label(
                                pkg.hasBundleVersionMismatch && !isEffectivelyOutdated
                                    ? tr("同步更新", "同步更新", "Sync")
                                    : tr("更新", "更新", "Update"),
                                systemImage: "arrow.up.circle.fill"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.small)
                        .disabled(pkg.isPinned)
                    } else if let appPath = pkg.resolvedAppPath {
                        Button {
                            onOpenApp(appPath)
                        } label: {
                            Label(tr("打开", "打開", "Open"), systemImage: "play.fill")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                // Secondary Actions Consolidated into Clean `···` Menu
                Menu {
                    Button {
                        onInspectDetail()
                    } label: {
                        Label(tr("查看详情与配置说明", "檢視詳情與設定說明", "Details & Notes"), systemImage: "info.circle")
                    }

                    if let appPath = pkg.resolvedAppPath {
                        Button {
                            onOpenApp(appPath)
                        } label: {
                            Label(tr("打开应用", "打開應用", "Open App"), systemImage: "play")
                        }

                        Button {
                            onRevealInFinder(appPath)
                        } label: {
                            Label(tr("在 Finder 中显示", "在 Finder 中顯示", "Show in Finder"), systemImage: "folder")
                        }
                    }

                    if let url = URL(string: pkg.homepage), !pkg.homepage.isEmpty {
                        Link(destination: url) {
                            Label(tr("访问软件主页", "造訪軟體首頁", "Visit Website"), systemImage: "safari")
                        }
                    }

                    Divider()

                    if pkg.type == .formula {
                        Button {
                            onTogglePin()
                        } label: {
                            Label(
                                pkg.isPinned
                                    ? tr("取消固定版本（允许更新）", "取消固定版本（允許更新）", "Unpin Version")
                                    : tr("固定当前版本（跳过更新）", "固定目前版本（略過更新）", "Pin Current Version"),
                                systemImage: pkg.isPinned ? "pin.slash" : "pin"
                            )
                        }
                    } else if !pkg.appBundles.isEmpty && !pkg.isAppBundleMissingOnDisk {
                        Button {
                            onRemoveQuarantine()
                        } label: {
                            Label(
                                tr("解除“已损坏”安全拦截", "解除「已損毀」安全攔截", "Remove Gatekeeper Quarantine"),
                                systemImage: "checkmark.shield"
                            )
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        onUninstall()
                    } label: {
                        Label(tr("卸载…", "解除安裝…", "Uninstall…"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(tr("更多操作", "更多操作", "More Actions"))
            }
        }
    }
}

public struct BadgeView: View {
    public let text: String
    public let color: Color

    public init(text: String, color: Color) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
