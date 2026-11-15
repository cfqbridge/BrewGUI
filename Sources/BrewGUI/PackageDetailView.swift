import SwiftUI
import AppKit

@MainActor
public final class AppIconProvider {
    public static let shared = AppIconProvider()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 400
    }

    public func icon(forAppPath path: String) -> NSImage {
        let key = path as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let img = NSWorkspace.shared.icon(forFile: path)
        cache.setObject(img, forKey: key)
        return img
    }

    public func resolveExistingAppPath(for bundles: [String]) -> String? {
        guard !bundles.isEmpty else { return nil }
        let fm = FileManager.default
        let homeApps = fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        for bundle in bundles {
            let sysPath = "/Applications/\(bundle)"
            if fm.fileExists(atPath: sysPath) {
                return sysPath
            }
            let usrPath = (homeApps as NSString).appendingPathComponent(bundle)
            if fm.fileExists(atPath: usrPath) {
                return usrPath
            }
        }
        return nil
    }
}

public struct PackageIconView: View {
    public let token: String
    public let type: PackageType
    public let desc: String
    public let appPath: String?
    public let size: CGFloat

    public init(
        token: String,
        type: PackageType,
        desc: String,
        appPath: String? = nil,
        size: CGFloat = 36
    ) {
        self.token = token
        self.type = type
        self.desc = desc
        self.appPath = appPath
        self.size = size
    }

    private var fallbackSpec: (symbol: String, color: Color) {
        let cat = ChineseSearchIndex.primaryCategory(for: token.lowercased(), descLower: desc.lowercased())
        switch cat {
        case .screenshot:
            return ("camera.viewfinder", .indigo)
        case .archive:
            return ("archivebox.fill", .orange)
        case .media:
            return ("play.tv.fill", .pink)
        case .translate:
            return ("character.book.closed.fill", .teal)
        case .productivity:
            return ("macwindow.on.rectangle", .blue)
        case .dev:
            return ("terminal.fill", .cyan)
        case .ai:
            return ("sparkles", .purple)
        case .network:
            return ("network", .teal)
        case .cleanup:
            return ("paintbrush.pointed.fill", .mint)
        case .essentials:
            return (type == .cask ? "app.badge.checkmark.fill" : "cube.box.fill", .orange)
        case .all, .none:
            return type == .cask
                ? ("macwindow", .purple)
                : ("terminal.fill", .blue)
        }
    }

    public var body: some View {
        if let path = appPath, !path.isEmpty {
            Image(nsImage: AppIconProvider.shared.icon(forAppPath: path))
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
        } else {
            let spec = fallbackSpec
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [spec.color.opacity(0.22), spec.color.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                            .stroke(spec.color.opacity(0.28), lineWidth: 1)
                    )
                Image(systemName: spec.symbol)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(spec.color)
            }
            .frame(width: size, height: size)
        }
    }
}

public struct PackageDetailSheetView: View {
    @ObservedObject var store: BrewStore
    let target: InspectedPackageTarget

    public init(store: BrewStore, target: InspectedPackageTarget) {
        self.store = store
        self.target = target
    }

    private var resolvedAppPath: String? {
        target.resolvedAppPath ?? AppIconProvider.shared.resolveExistingAppPath(for: target.appBundles)
    }

    private var isInstalled: Bool {
        target.installedVersion != nil
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Header
            HStack(alignment: .center, spacing: 16) {
                PackageIconView(
                    token: target.name,
                    type: target.type,
                    desc: target.desc,
                    appPath: resolvedAppPath,
                    size: 54
                )

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(target.displayName)
                            .font(.title3.weight(.bold))

                        BadgeView(
                            text: target.type.localizedHumanLabel,
                            color: target.type == .cask ? .purple : .blue
                        )

                        if let tap = target.tap, !tap.isEmpty {
                            BadgeView(
                                text: "\(tr("第三方源", "第三方源", "Third-Party")): \(tap)",
                                color: .indigo
                            )
                        }
                    }

                    let zhDesc = ChineseSearchIndex.meta(for: target.name)?.zhDesc
                    if let zhDesc, !zhDesc.isEmpty, AppLanguage.current.resolved != .en {
                        Text(zhDesc)
                            .font(.callout)
                            .foregroundStyle(.primary)
                    }
                    if !target.desc.isEmpty {
                        Text(target.desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Button {
                    store.inspectedTarget = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(tr("关闭详情", "關閉詳情", "Close"))
            }
            .padding(20)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 1. Visual Overview Grid (Version, Status, Size, Source)
                    HStack(spacing: 12) {
                        detailMetricCard(
                            icon: "tag.fill",
                            color: .blue,
                            title: tr("当前状态", "目前狀態", "Status"),
                            value: isInstalled
                                ? "\(tr("已安装", "已安裝", "Installed")) (\(target.installedVersion ?? ""))"
                                : (resolvedAppPath != nil ? tr("本机已有应用", "本機已有應用", "Found on Mac") : tr("未安装", "未安裝", "Not Installed"))
                        )

                        detailMetricCard(
                            icon: "sparkles",
                            color: .teal,
                            title: tr("官方最新版本", "官方最新版本", "Latest Version"),
                            value: target.latestVersion.isEmpty ? "—" : target.latestVersion
                        )

                        let knownSize = store.formattedSize(for: target.name) ?? store.inspectedDetailInfo?.installedDiskSize
                        detailMetricCard(
                            icon: "internaldrive.fill",
                            color: .orange,
                            title: isInstalled ? tr("占用/安装包体积", "佔用/安裝包體積", "Package Size") : tr("安装包体积", "安裝包體積", "Installer Size"),
                            value: knownSize ?? tr("按需获取", "按需取得", "On demand")
                        )
                    }

                    // 2. Quick Primary Actions Bar
                    HStack(spacing: 10) {
                        if let appPath = resolvedAppPath {
                            Button {
                                store.openInstalledApp(at: appPath)
                            } label: {
                                Label(tr("打开应用", "打開應用", "Open App"), systemImage: "play.fill")
                            }
                            .buttonStyle(.borderedProminent)

                            Button {
                                store.revealPathInFinder(appPath)
                            } label: {
                                Label(tr("在 Finder 中显示", "在 Finder 中顯示", "Show in Finder"), systemImage: "folder")
                            }
                            .buttonStyle(.bordered)
                        } else if !isInstalled && !target.isDisabled {
                            Button {
                                if let entry = store.catalogEntries.first(where: { $0.type == target.type && $0.nameLower == target.name.lowercased() }) {
                                    store.installCatalogEntry(entry)
                                    store.inspectedTarget = nil
                                }
                            } label: {
                                Label(tr("立即安装", "立即安裝", "Install Now"), systemImage: "arrow.down.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        if let url = URL(string: target.homepage), !target.homepage.isEmpty {
                            Link(destination: url) {
                                Label(tr("访问软件官网", "造訪軟體官網", "Official Website"), systemImage: "safari")
                            }
                            .buttonStyle(.bordered)
                        }

                        if target.hasQuarantine, let pkg = store.installedPackages.first(where: { $0.id == target.id }) {
                            Button {
                                store.removeQuarantine(for: pkg)
                            } label: {
                                Label(tr("解除“已损坏”安全拦截", "解除「已損毀」安全攔截", "Fix Gatekeeper Prompt"), systemImage: "checkmark.shield.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.teal)
                        }

                        Spacer()
                    }

                    // 3. Caveats (Post-install configuration notes) — shown only when present
                    if store.isLoadingPackageDetail {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(tr("正在读取组件依赖与配置说明…", "正在讀取元件依賴與設定說明…", "Loading dependencies & configuration notes…"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    } else if let detail = store.inspectedDetailInfo {
                        if let caveats = detail.caveats, !caveats.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Label(
                                        tr("使用与配置提示 (Caveats)", "使用與設定提示 (Caveats)", "Configuration Notes (Caveats)"),
                                        systemImage: "lightbulb.fill"
                                    )
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(.orange)

                                    Spacer()

                                    Button {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(caveats, forType: .string)
                                    } label: {
                                        Label(tr("复制说明", "複製說明", "Copy"), systemImage: "doc.on.doc")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                }

                                Text(caveats)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(nsColor: .textBackgroundColor))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .padding(12)
                            .background(Color.orange.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // 4. Dependencies Card
                        VStack(alignment: .leading, spacing: 8) {
                            Label(
                                tr("关联运行组件", "關聯執行元件", "Required Components"),
                                systemImage: "square.stack.3d.up.fill"
                            )
                            .font(.callout.weight(.semibold))

                            if detail.dependencies.isEmpty {
                                Text(
                                    tr(
                                        "独立运行，无需安装额外底层依赖库。",
                                        "獨立執行，無需安裝額外底層依賴函式庫。",
                                        "Self-contained; no additional dependency libraries required."
                                    )
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            } else {
                                Text(
                                    tr(
                                        "该软件依赖以下 \(detail.dependencies.count) 个基础组件（安装时会自动配置）：",
                                        "該軟體依賴以下 \(detail.dependencies.count) 個基礎元件（安裝時會自動設定）：",
                                        "Requires \(detail.dependencies.count) foundational components (automatically managed):"
                                    )
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
                                    ForEach(detail.dependencies, id: \.self) { dep in
                                        HStack(spacing: 4) {
                                            Image(systemName: "cube.box")
                                                .font(.caption2)
                                                .foregroundStyle(.blue)
                                            Text(dep)
                                                .font(.caption.monospaced())
                                                .lineLimit(1)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(nsColor: .controlBackgroundColor))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // 5. Technical Identity & CLI Equivalence (Collapsed low-burden footer)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(tr("技术标识与终端命令", "技術識別與終端機命令", "Technical Identifier & CLI"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        let cliCmd = target.type == .cask
                            ? "brew install --cask \(target.qualifiedName)"
                            : "brew install \(target.qualifiedName)"

                        HStack(spacing: 10) {
                            Text("Token: \(target.qualifiedName)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)

                            Divider()
                                .frame(height: 12)

                            Text(cliCmd)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)

                            Spacer()

                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(cliCmd, forType: .string)
                            } label: {
                                Label(tr("复制命令", "複製命令", "Copy CLI"), systemImage: "doc.on.doc")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    }
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(20)
            }
        }
        .frame(width: 580, height: 480)
    }

    @ViewBuilder
    private func detailMetricCard(icon: String, color: Color, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
