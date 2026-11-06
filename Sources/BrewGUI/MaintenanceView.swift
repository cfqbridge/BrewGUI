import SwiftUI
import AppKit

public struct MaintenanceView: View {
    @ObservedObject var store: BrewStore

    public init(store: BrewStore) {
        self.store = store
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    public var body: some View {
        VStack(spacing: 0) {
            // Top Header Bar
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("清理与维护 (Cleanup & Maintenance)", "清理與維護 (Cleanup & Maintenance)", "Cleanup & Maintenance"))
                        .font(.headline)
                    Text(
                        tr(
                            "管理 Homebrew 下载缓存 (`~/Library/Caches/Homebrew/downloads`) 与无用孤儿依赖包，释放磁盘空间。",
                            "管理 Homebrew 下載快取 (`~/Library/Caches/Homebrew/downloads`) 與無用孤兒依賴套件，釋放磁碟空間。",
                            "Manage Homebrew download caches (`~/Library/Caches/Homebrew/downloads`) and unused orphan dependencies to free up disk space."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    store.scanCachedDownloads()
                    Task { await store.scanOrphanFormulae() }
                } label: {
                    Label(tr("重新扫描", "重新掃描", "Rescan"), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(store.isScanningOrphans)

                Button {
                    let dir = FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent("Library/Caches/Homebrew/downloads")
                    NSWorkspace.shared.open(dir)
                } label: {
                    Label(tr("打开缓存目录", "打開快取目錄", "Open Cache Folder"), systemImage: "folder")
                }
                .buttonStyle(.bordered)

                Button {
                    store.runCleanupAllCaches()
                } label: {
                    if store.totalCachedDownloadsBytes > 0 {
                        Label(
                            tr(
                                "一键清理全部缓存 (\(AppConstants.formatBytes(store.totalCachedDownloadsBytes)))",
                                "一鍵清理全部快取 (\(AppConstants.formatBytes(store.totalCachedDownloadsBytes)))",
                                "Clean All Caches (\(AppConstants.formatBytes(store.totalCachedDownloadsBytes)))"
                            ),
                            systemImage: "sparkles"
                        )
                    } else {
                        Label(tr("执行 brew cleanup", "執行 brew cleanup", "Run brew cleanup"), systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            HSplitView {
                // Left: Cached Downloads Breakdown
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "internaldrive.fill")
                            .foregroundStyle(.orange)
                        Text(
                            tr(
                                "安装包下载缓存明细 (\(store.cachedDownloadFiles.count) 个文件)",
                                "安裝包下載快取明細 (\(store.cachedDownloadFiles.count) 個檔案)",
                                "Cached Installer Files (\(store.cachedDownloadFiles.count))"
                            )
                        )
                        .font(.caption.weight(.semibold))
                        Spacer()
                        BadgeView(
                            text: tr(
                                "共占用 \(AppConstants.formatBytes(store.totalCachedDownloadsBytes))",
                                "共佔用 \(AppConstants.formatBytes(store.totalCachedDownloadsBytes))",
                                "Total \(AppConstants.formatBytes(store.totalCachedDownloadsBytes))"
                            ),
                            color: store.totalCachedDownloadsBytes > 500 * 1024 * 1024 ? .orange : .secondary
                        )
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

                    Divider()

                    if store.cachedDownloadFiles.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 38))
                                .foregroundStyle(.green)
                            Text(tr("下载缓存非常干净", "下載快取非常乾淨", "Download Cache is Clean"))
                                .font(.headline)
                            Text(
                                tr(
                                    "`~/Library/Caches/Homebrew/downloads` 下暂无残留安装包文件",
                                    "`~/Library/Caches/Homebrew/downloads` 下暫無殘留安裝包檔案",
                                    "No cached installer archives in `~/Library/Caches/Homebrew/downloads`"
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(store.cachedDownloadFiles) { file in
                            HStack(spacing: 10) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: file.fullPath))
                                    .resizable()
                                    .frame(width: 28, height: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(file.fileName)
                                        .font(.system(.callout, design: .default).weight(.medium))
                                        .lineLimit(1)
                                    Text("\(tr("缓存时间", "快取時間", "Cached")): \(Self.dateFormatter.string(from: file.modifiedAt))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                BadgeView(
                                    text: AppConstants.formatBytes(file.sizeBytes),
                                    color: file.sizeBytes >= 150 * 1024 * 1024 ? .orange : .blue
                                )

                                Button {
                                    store.revealCachedFileInFinder(file)
                                } label: {
                                    Image(systemName: "magnifyingglass.circle")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .help(tr("在 Finder 中显示该文件", "在 Finder 中顯示該檔案", "Reveal in Finder"))

                                Button(role: .destructive) {
                                    store.deleteSingleCachedFile(file)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(store.isProcessingQueue)
                                .help(
                                    store.isProcessingQueue
                                        ? tr("后台任务正在执行，为防误删预下载安装包，请待任务完成后再删除", "背景任務正在執行，為防誤刪預先下載安裝包，請待任務完成後再刪除", "Disabled while tasks are running to avoid deleting prefetched installers")
                                        : tr("直接删除此缓存安装包", "直接刪除此快取安裝包", "Delete this cached file")
                                )
                            }
                            .padding(.vertical, 3)
                        }
                        .listStyle(.inset)
                    }
                }
                .frame(minWidth: 460, maxWidth: .infinity, maxHeight: .infinity)

                // Right: Orphan Formulae (brew autoremove) & Tips
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Image(systemName: "shippingbox.and.arrow.backward.fill")
                            .foregroundStyle(.teal)
                        Text(tr("无用孤儿依赖包 (`brew autoremove`)", "無用孤兒依賴套件 (`brew autoremove`)", "Orphan Dependencies (`brew autoremove`)"))
                            .font(.caption.weight(.semibold))
                        Spacer()
                        if store.isScanningOrphans {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            BadgeView(
                                text: tr("\(store.orphanFormulae.count) 个可清理", "\(store.orphanFormulae.count) 個可清理", "\(store.orphanFormulae.count) removable"),
                                color: store.orphanFormulae.isEmpty ? .green : .orange
                            )
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text(
                            tr(
                                "当卸载某个软件后，曾作为其前置依赖自动安装、但现在已不再被任何顶层软件引用的底层库会成为「孤儿依赖」。",
                                "當解除安裝某個軟體後，曾作為其前置依賴自動安裝、但現在已不再被任何頂層軟體引用的底層函式庫會成為「孤兒依賴」。",
                                "Orphan dependencies are libraries automatically installed as prerequisites for packages that have since been uninstalled and are no longer required by any top-level package."
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        if store.orphanFormulae.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text(tr("当前没有无用的孤儿依赖包", "目前沒有無用的孤兒依賴套件", "No unused orphan dependencies found"))
                                    .font(.callout.weight(.medium))
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(store.orphanFormulae, id: \.self) { name in
                                        HStack {
                                            Image(systemName: "cube.box")
                                                .foregroundStyle(.orange)
                                            Text(name)
                                                .font(.system(.callout, design: .monospaced))
                                            Spacer()
                                            BadgeView(text: tr("孤儿依赖", "孤兒依賴", "Orphan"), color: .orange)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color(nsColor: .controlBackgroundColor))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                            }
                            .frame(maxHeight: 220)

                            Button {
                                store.runAutoremoveOrphans()
                            } label: {
                                Label(
                                    tr(
                                        "一键清理 \(store.orphanFormulae.count) 个孤儿依赖 (brew autoremove)",
                                        "一鍵清理 \(store.orphanFormulae.count) 個孤兒依賴 (brew autoremove)",
                                        "Remove \(store.orphanFormulae.count) Orphan Dependencies (brew autoremove)"
                                    ),
                                    systemImage: "trash.fill"
                                )
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }

                        Spacer()

                        Divider()

                        // Explanation Card
                        VStack(alignment: .leading, spacing: 6) {
                            Label(
                                tr("关于 Homebrew 缓存与彻底卸载说明", "關於 Homebrew 快取與徹底解除安裝說明", "About Homebrew Cache & Zap Uninstall"),
                                systemImage: "info.circle.fill"
                            )
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.teal)
                            Text(
                                tr(
                                    "• Homebrew 默认会将已安装软件的 `.dmg` / `.zip` / `.bottle.tar.gz` 安装包保留 120 天。点击右上角「一键清理全部缓存」将执行 `brew cleanup --prune=all`，安全清除所有历史安装包缓存及旧版运行库。\n• 在「已安装与更新」页面卸载 Cask 桌面应用时，现已支持选择「彻底卸载 (`--zap`)」，一并清理应用在 `~/Library` 下的配置与缓存残留。",
                                    "• Homebrew 預設會將已安裝軟體的 `.dmg` / `.zip` / `.bottle.tar.gz` 安裝包保留 120 天。點擊右上角「一鍵清理全部快取」將執行 `brew cleanup --prune=all`，安全清除所有歷史安裝包快取及舊版執行庫。\n• 在「已安裝與更新」頁面解除安裝 Cask 桌面應用時，現已支援選擇「徹底解除安裝 (`--zap`)」，一併清理應用在 `~/Library` 下的設定與快取殘留。",
                                    "• Homebrew keeps downloaded `.dmg` / `.zip` / `.bottle.tar.gz` archives for 120 days by default. Clicking \"Clean All Caches\" runs `brew cleanup --prune=all` to safely reclaim disk space.\n• When uninstalling Cask GUI apps in \"Installed & Updates\", you can choose \"Thorough Uninstall (`--zap`)\" to also remove app preferences and caches in `~/Library`."
                                )
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(Color.teal.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(minWidth: 280, idealWidth: 340, maxWidth: 420, maxHeight: .infinity)
            }
        }
        .onAppear {
            guard !WindowPolicyManager.isCLIMode else { return }
            store.scanCachedDownloads()
        }
    }
}
