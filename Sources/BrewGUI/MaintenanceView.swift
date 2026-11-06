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
                    Text("清理与维护 (Cleanup & Maintenance)")
                        .font(.headline)
                    Text("管理 Homebrew 下载缓存 (`~/Library/Caches/Homebrew/downloads`) 与无用孤儿依赖包，释放磁盘空间。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    store.scanCachedDownloads()
                    Task { await store.scanOrphanFormulae() }
                } label: {
                    Label("重新扫描", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(store.isScanningOrphans)

                Button {
                    let dir = FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent("Library/Caches/Homebrew/downloads")
                    NSWorkspace.shared.open(dir)
                } label: {
                    Label("打开缓存目录", systemImage: "folder")
                }
                .buttonStyle(.bordered)

                Button {
                    store.runCleanupAllCaches()
                } label: {
                    if store.totalCachedDownloadsBytes > 0 {
                        Label(
                            "一键清理全部缓存 (\(AppConstants.formatBytes(store.totalCachedDownloadsBytes)))",
                            systemImage: "sparkles"
                        )
                    } else {
                        Label("执行 brew cleanup", systemImage: "sparkles")
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
                        Text("安装包下载缓存明细 (\(store.cachedDownloadFiles.count) 个文件)")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        BadgeView(
                            text: "共占用 \(AppConstants.formatBytes(store.totalCachedDownloadsBytes))",
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
                            Text("下载缓存非常干净")
                                .font(.headline)
                            Text("`~/Library/Caches/Homebrew/downloads` 下暂无残留安装包文件")
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
                                    Text("缓存时间: \(Self.dateFormatter.string(from: file.modifiedAt))")
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
                                .help("在 Finder 中显示该文件")

                                Button(role: .destructive) {
                                    store.deleteSingleCachedFile(file)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(store.isProcessingQueue)
                                .help(store.isProcessingQueue ? "后台任务正在执行，为防误删预下载安装包，请待任务完成后再删除" : "直接删除此缓存安装包")
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
                        Text("无用孤儿依赖包 (`brew autoremove`)")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        if store.isScanningOrphans {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            BadgeView(
                                text: "\(store.orphanFormulae.count) 个可清理",
                                color: store.orphanFormulae.isEmpty ? .green : .orange
                            )
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("当卸载某个软件后，曾作为其前置依赖自动安装、但现在已不再被任何顶层软件引用的底层库会成为「孤儿依赖」。")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if store.orphanFormulae.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("当前没有无用的孤儿依赖包")
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
                                            BadgeView(text: "孤儿依赖", color: .orange)
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
                                Label("一键清理 \(store.orphanFormulae.count) 个孤儿依赖 (brew autoremove)", systemImage: "trash.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }

                        Spacer()

                        Divider()

                        // Explanation Card
                        VStack(alignment: .leading, spacing: 6) {
                            Label("关于 Homebrew 缓存与彻底卸载说明", systemImage: "info.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.teal)
                            Text("• Homebrew 默认会将已安装软件的 `.dmg` / `.zip` / `.bottle.tar.gz` 安装包保留 120 天。点击右上角「一键清理全部缓存」将执行 `brew cleanup --prune=all`，安全清除所有历史安装包缓存及旧版运行库。\n• 在「已安装与更新」页面卸载 Cask 桌面应用时，现已支持选择「彻底卸载 (`--zap`)」，一并清理应用在 `~/Library` 下的配置与缓存残留。")
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
