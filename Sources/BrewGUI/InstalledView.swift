import SwiftUI

public enum InstalledFilterCategory: String, CaseIterable, Identifiable {
    case all = "全部"
    case outdated = "可更新"
    case formulae = "Formula"
    case casks = "Cask"

    public var id: String { rawValue }

    public var localizedLabel: String {
        switch self {
        case .all:
            return tr("全部", "全部", "All")
        case .outdated:
            return tr("可更新", "可更新", "Outdated")
        case .formulae:
            return "Formula"
        case .casks:
            return "Cask"
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
                if !pkg.isOutdated && !pkg.hasBundleVersionMismatch { return false }
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
                return matchName || matchDisplay || matchDesc
            }
            return true
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Toolbar Bar
            HStack(spacing: 12) {
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

                Toggle(tr("显示全部依赖包", "顯示全部依賴套件", "Show All Dependencies"), isOn: $store.showAllDependencies)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help(tr("关闭时仅展示主动安装的顶层包 (brew leaves + Casks)", "關閉時僅展示主動安裝的頂層套件 (brew leaves + Casks)", "When off, only shows top-level installed packages (brew leaves + Casks)"))

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        Task { await store.refreshInstalled() }
                    } label: {
                        Label(tr("刷新列表", "重新整理", "Refresh"), systemImage: "arrow.clockwise")
                    }
                    .disabled(store.isLoadingInstalled)

                    Button {
                        store.checkUpdates()
                    } label: {
                        Label(tr("检查更新", "檢查更新", "Check Updates"), systemImage: "icloud.and.arrow.down")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        store.upgradeAll()
                    } label: {
                        if store.outdatedCount > 0 {
                            Label(
                                tr("全部升级 (\(store.outdatedCount))", "全部升級 (\(store.outdatedCount))", "Upgrade All (\(store.outdatedCount))"),
                                systemImage: "arrow.up.circle.fill"
                            )
                        } else {
                            Label(
                                tr("全部升级", "全部升級", "Upgrade All"),
                                systemImage: "arrow.up.circle"
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Search & Summary Sub-bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(
                    tr("在已安装包中筛选名称或描述…", "在已安裝套件中篩選名稱或描述…", "Filter installed packages by name or description…"),
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

                Text(
                    tr(
                        "共显示 \(filteredPackages.count) / \(store.installedPackages.count) 个包",
                        "共顯示 \(filteredPackages.count) / \(store.installedPackages.count) 個套件",
                        "Showing \(filteredPackages.count) / \(store.installedPackages.count) packages"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))

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

            // Package List
            if store.isLoadingInstalled && store.installedPackages.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(tr("正在读取已安装的 Homebrew 软件包…", "正在讀取已安裝的 Homebrew 軟體套件…", "Loading installed Homebrew packages…"))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredPackages.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text(tr("没有符合筛选条件的软件包", "沒有符合篩選條件的軟體套件", "No packages match the current filter"))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredPackages) { pkg in
                    InstalledPackageRow(
                        pkg: pkg,
                        probedSizeBytes: (pkg.isOutdated || pkg.hasBundleVersionMismatch) ? store.sizeBytes(for: pkg.name) : nil,
                        onUpgrade: { store.upgradePackage(pkg) },
                        onTogglePin: { store.togglePin(pkg) },
                        onUninstall: { store.packagePendingUninstall = pkg }
                    )
                    .padding(.vertical, 4)
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
                    Button(tr("普通卸载 (仅移除 /Applications 应用)", "一般解除安裝 (僅移除 /Applications 應用)", "Standard Uninstall (remove app only)"), role: .destructive) {
                        store.uninstallPackage(pkg, zap: false)
                        store.packagePendingUninstall = nil
                    }
                    Button(tr("彻底卸载 (--zap 含配置与缓存残留)", "徹底解除安裝 (--zap 含設定與快取殘留)", "Thorough Uninstall (--zap including prefs & caches)"), role: .destructive) {
                        store.uninstallPackage(pkg, zap: true)
                        store.packagePendingUninstall = nil
                    }
                } else {
                    Button("\(tr("卸载", "解除安裝", "Uninstall")) \(pkg.displayName)", role: .destructive) {
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
                            "「普通卸载」执行 `brew uninstall --cask \(pkg.name)`；「彻底卸载」额外附加 `--zap` 参数清理 ~/Library 下的关联配置与缓存。",
                            "「一般解除安裝」執行 `brew uninstall --cask \(pkg.name)`；「徹底解除安裝」額外附加 `--zap` 參數清理 ~/Library 下的關聯設定與快取。",
                            "Standard uninstall runs `brew uninstall --cask \(pkg.name)`; Thorough uninstall adds `--zap` to also remove related preferences and caches in ~/Library."
                        )
                    )
                } else {
                    Text(
                        tr(
                            "将执行 `brew uninstall \(pkg.name)`。",
                            "將執行 `brew uninstall \(pkg.name)`。",
                            "Will execute `brew uninstall \(pkg.name)`."
                        )
                    )
                }
            }
        }
    }
}

private struct InstalledPackageRow: View {
    let pkg: BrewPackage
    let probedSizeBytes: Int64?
    let onUpgrade: () -> Void
    let onTogglePin: () -> Void
    let onUninstall: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Left Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(pkg.displayName)
                        .font(.system(.body, design: .default).weight(.semibold))

                    if pkg.displayName != pkg.name {
                        Text("(\(pkg.name))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    BadgeView(
                        text: pkg.type.rawValue,
                        color: pkg.type == .cask ? .purple : .blue
                    )

                    if !pkg.isTopLevel {
                        BadgeView(text: tr("依赖包", "依賴套件", "Dependency"), color: .gray)
                    }

                    if pkg.isPinned {
                        BadgeView(text: tr("已锁定 (Pinned)", "已鎖定 (Pinned)", "Pinned"), color: .orange)
                    }

                    if pkg.hasBundleVersionMismatch {
                        BadgeView(text: tr("本地未覆盖 (需同步更新)", "本機未覆蓋 (需同步更新)", "On-disk mismatch (Needs sync)"), color: .orange)
                    }

                    if let sizeBytes = probedSizeBytes, sizeBytes > 0 {
                        let isLarge = sizeBytes >= 150 * 1024 * 1024
                        BadgeView(
                            text: isLarge
                                ? "📦 \(AppConstants.formatBytes(sizeBytes)) \(tr("(大体积包，建议单独升级)", "(大體積套件，建議單獨升級)", "(Large installer)"))"
                                : "📦 \(AppConstants.formatBytes(sizeBytes))",
                            color: isLarge ? .orange : .teal
                        )
                    }
                }

                if !pkg.desc.isEmpty {
                    Text(pkg.desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 12) {
                    if pkg.hasBundleVersionMismatch {
                        HStack(spacing: 4) {
                            Text("\(tr("实际应用", "實際應用", "On-disk")): \(pkg.actualBundleVersion ?? "?")")
                                .font(.caption.monospaced())
                                .foregroundStyle(.orange)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            Text("\(tr("Brew 账面", "Brew 帳面", "Brew Cask")): \(pkg.latestVersion)")
                                .font(.caption.monospaced().weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                    } else if pkg.isOutdated {
                        HStack(spacing: 4) {
                            Text(pkg.installedVersion ?? "")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            Text(pkg.latestVersion)
                                .font(.caption.monospaced().weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                    } else {
                        Text("\(tr("版本", "版本", "Version")): \(pkg.installedVersion ?? pkg.latestVersion)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    if let url = URL(string: pkg.homepage), !pkg.homepage.isEmpty {
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

            // Right Actions
            HStack(spacing: 8) {
                if pkg.isOutdated || pkg.hasBundleVersionMismatch {
                    Button {
                        onUpgrade()
                    } label: {
                        Label(
                            pkg.hasBundleVersionMismatch && !pkg.isOutdated
                                ? tr("覆盖升级", "覆蓋升級", "Force Sync")
                                : tr("升级", "升級", "Upgrade"),
                            systemImage: "arrow.up.circle.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.small)
                    .disabled(pkg.isPinned)
                    .help(
                        pkg.hasBundleVersionMismatch && !pkg.isOutdated
                            ? tr("之前使用 --adopt 仅认领了旧版应用而未替换文件，点击将自动退出旧应用并执行 brew reinstall --cask --force 覆盖升级至 \(pkg.latestVersion)", "之前使用 --adopt 僅認領了舊版應用而未替換檔案，點擊將自動結束舊應用並執行 brew reinstall --cask --force 覆蓋升級至 \(pkg.latestVersion)", "Previously adopted without overwriting files. Click to quit running app and run brew reinstall --cask --force to update to \(pkg.latestVersion)")
                            : "\(tr("升级", "升級", "Upgrade")) \(pkg.displayName)"
                    )
                }

                if pkg.type == .formula {
                    Button {
                        onTogglePin()
                    } label: {
                        Image(systemName: pkg.isPinned ? "pin.slash.fill" : "pin")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(pkg.isPinned ? tr("解锁版本 (brew unpin)", "解鎖版本 (brew unpin)", "Unpin version (brew unpin)") : tr("锁定当前版本防止升级 (brew pin)", "鎖定目前版本防止升級 (brew pin)", "Pin version to prevent upgrades (brew pin)"))
                }

                Button(role: .destructive) {
                    onUninstall()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("\(tr("卸载", "解除安裝", "Uninstall")) \(pkg.name)")
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
