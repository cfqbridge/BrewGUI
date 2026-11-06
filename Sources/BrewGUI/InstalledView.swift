import SwiftUI

public enum InstalledFilterCategory: String, CaseIterable, Identifiable {
    case all = "全部"
    case outdated = "可更新"
    case formulae = "Formula"
    case casks = "Cask"

    public var id: String { rawValue }
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
                Picker("分类", selection: $store.installedCategory) {
                    ForEach(InstalledFilterCategory.allCases) { item in
                        if item == .outdated && store.outdatedCount > 0 {
                            Text("\(item.rawValue) (\(store.outdatedCount))").tag(item)
                        } else {
                            Text(item.rawValue).tag(item)
                        }
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()

                Toggle("显示全部依赖包", isOn: $store.showAllDependencies)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help("关闭时仅展示主动安装的顶层包 (brew leaves + Casks)")

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        Task { await store.refreshInstalled() }
                    } label: {
                        Label("刷新列表", systemImage: "arrow.clockwise")
                    }
                    .disabled(store.isLoadingInstalled)

                    Button {
                        store.checkUpdates()
                    } label: {
                        Label("检查更新 (update)", systemImage: "icloud.and.arrow.down")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        store.upgradeAll()
                    } label: {
                        if store.outdatedCount > 0 {
                            Label("全部升级 (\(store.outdatedCount))", systemImage: "arrow.up.circle.fill")
                        } else {
                            Label("全部升级 (upgrade)", systemImage: "arrow.up.circle")
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
                TextField("在已安装包中筛选名称或描述…", text: $store.installedSearchText)
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

                Text("共显示 \(filteredPackages.count) / \(store.installedPackages.count) 个包")
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
                    Text("正在读取已安装的 Homebrew 软件包…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredPackages.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("没有符合筛选条件的软件包")
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
            "确认卸载 \(store.packagePendingUninstall?.displayName ?? "")？",
            isPresented: Binding(
                get: { store.packagePendingUninstall != nil },
                set: { if !$0 { store.packagePendingUninstall = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let pkg = store.packagePendingUninstall {
                if pkg.type == .cask {
                    Button("普通卸载 (仅移除 /Applications 应用)", role: .destructive) {
                        store.uninstallPackage(pkg, zap: false)
                        store.packagePendingUninstall = nil
                    }
                    Button("彻底卸载 (--zap 含配置与缓存残留)", role: .destructive) {
                        store.uninstallPackage(pkg, zap: true)
                        store.packagePendingUninstall = nil
                    }
                } else {
                    Button("卸载 \(pkg.displayName)", role: .destructive) {
                        store.uninstallPackage(pkg, zap: false)
                        store.packagePendingUninstall = nil
                    }
                }
            }
            Button("取消", role: .cancel) {
                store.packagePendingUninstall = nil
            }
        } message: {
            if let pkg = store.packagePendingUninstall {
                if pkg.type == .cask {
                    Text("「普通卸载」执行 `brew uninstall --cask \(pkg.name)`；「彻底卸载」额外附加 `--zap` 参数清理 ~/Library 下的关联配置与缓存。")
                } else {
                    Text("将执行 `brew uninstall \(pkg.name)`。")
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
                        BadgeView(text: "依赖包", color: .gray)
                    }

                    if pkg.isPinned {
                        BadgeView(text: "已锁定 (Pinned)", color: .orange)
                    }

                    if pkg.hasBundleVersionMismatch {
                        BadgeView(text: "本地未覆盖 (需同步更新)", color: .orange)
                    }

                    if let sizeBytes = probedSizeBytes, sizeBytes > 0 {
                        let isLarge = sizeBytes >= 150 * 1024 * 1024
                        BadgeView(
                            text: isLarge
                                ? "📦 \(AppConstants.formatBytes(sizeBytes)) (大体积包，建议单独升级)"
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
                            Text("实际应用: \(pkg.actualBundleVersion ?? "?")")
                                .font(.caption.monospaced())
                                .foregroundStyle(.orange)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            Text("Brew 账面: \(pkg.latestVersion)")
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
                        Text("版本: \(pkg.installedVersion ?? pkg.latestVersion)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    if let url = URL(string: pkg.homepage), !pkg.homepage.isEmpty {
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

            // Right Actions
            HStack(spacing: 8) {
                if pkg.isOutdated || pkg.hasBundleVersionMismatch {
                    Button {
                        onUpgrade()
                    } label: {
                        Label(
                            pkg.hasBundleVersionMismatch && !pkg.isOutdated ? "覆盖升级" : "升级",
                            systemImage: "arrow.up.circle.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.small)
                    .disabled(pkg.isPinned)
                    .help(
                        pkg.hasBundleVersionMismatch && !pkg.isOutdated
                            ? "之前使用 --adopt 仅认领了旧版应用而未替换文件，点击将自动退出旧应用并执行 brew reinstall --cask --force 覆盖升级至 \(pkg.latestVersion)"
                            : "升级 \(pkg.displayName)"
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
                    .help(pkg.isPinned ? "解锁版本 (brew unpin)" : "锁定当前版本防止升级 (brew pin)")
                }

                Button(role: .destructive) {
                    onUninstall()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("卸载 \(pkg.name)")
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
