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
            // Top Header Bar with Segmented Sub-Tab Picker
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("清理与维护", "清理與維護", "Cleanup & Maintenance"))
                        .font(.headline)
                        .fixedSize(horizontal: true, vertical: false)
                    Text(
                        tr(
                            "缓存清理 · 卸载残留 · 后台服务 · 环境体检",
                            "快取清理 · 殘留清理 · 背景服務 · 環境體檢",
                            "Caches · Leftovers · Services · Doctor"
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer()

                Picker(tr("维护模块", "維護模組", "Maintenance Mode"), selection: $store.maintenanceSubTab) {
                    ForEach(MaintenanceSubTab.allCases) { tab in
                        switch tab {
                        case .cacheAndOrphans:
                            Text(tab.localizedLabel).tag(tab)
                        case .appLeftovers:
                            let count = store.appLeftovers.count
                            Text(count > 0 ? "\(tab.localizedLabel) (\(count))" : tab.localizedLabel).tag(tab)
                        case .services:
                            let count = store.brewServices.count
                            Text(count > 0 ? "\(tab.localizedLabel) (\(count))" : tab.localizedLabel).tag(tab)
                        case .doctorAndTaps:
                            Text(tab.localizedLabel).tag(tab)
                        }
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            switch store.maintenanceSubTab {
            case .cacheAndOrphans:
                cacheAndOrphansContent
            case .appLeftovers:
                appLeftoversContent
            case .services:
                servicesContent
            case .doctorAndTaps:
                doctorAndTapsContent
            }
        }
        .onAppear {
            guard !WindowPolicyManager.isCLIMode else { return }
            store.scanCachedDownloads()
            if store.appLeftovers.isEmpty && !store.isScanningLeftovers {
                Task { await store.scanAppLeftovers() }
            }
        }
    }

    // MARK: - Sub-Tab 1: Cache & Orphan Dependencies

    @ViewBuilder
    private var cacheAndOrphansContent: some View {
        // Action Bar for Cache & Orphans
        HStack(spacing: 10) {
            if !store.appLeftovers.isEmpty {
                Button {
                    store.maintenanceSubTab = .appLeftovers
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "paintbrush.pointed.fill")
                            .foregroundStyle(.purple)
                        Text(
                            tr(
                                "发现 \(store.appLeftovers.count) 项已卸载残留（\(AppConstants.formatBytes(store.totalLeftoversBytes))），点击清理 →",
                                "發現 \(store.appLeftovers.count) 項已解除安裝殘留（\(AppConstants.formatBytes(store.totalLeftoversBytes))），點擊清理 →",
                                "Found \(store.appLeftovers.count) leftovers (\(AppConstants.formatBytes(store.totalLeftoversBytes))) — clean →"
                            )
                        )
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.purple)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text(
                    tr(
                        "管理 `~/Library/Caches/Homebrew/downloads` 历史安装包与 `brew autoremove` 孤儿依赖",
                        "管理 `~/Library/Caches/Homebrew/downloads` 歷史安裝包與 `brew autoremove` 孤兒依賴",
                        "Inspect `~/Library/Caches/Homebrew/downloads` archives and `brew autoremove` orphan formulae"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                store.scanCachedDownloads()
                Task {
                    await store.scanOrphanFormulae()
                    await store.scanAppLeftovers()
                }
            } label: {
                Label(tr("重新扫描", "重新掃描", "Rescan"), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(store.isScanningOrphans)

            Button {
                let dir = FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Library/Caches/Homebrew/downloads")
                NSWorkspace.shared.open(dir)
            } label: {
                Label(tr("打开缓存目录", "打開快取目錄", "Open Cache Folder"), systemImage: "folder")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                store.runCleanupAllCaches()
            } label: {
                if store.totalCachedDownloadsBytes > 0 {
                    Label(
                        tr(
                            "一键清理缓存 (\(AppConstants.formatBytes(store.totalCachedDownloadsBytes)))",
                            "一鍵清理快取 (\(AppConstants.formatBytes(store.totalCachedDownloadsBytes)))",
                            "Clean Caches (\(AppConstants.formatBytes(store.totalCachedDownloadsBytes)))"
                        ),
                        systemImage: "sparkles"
                    )
                } else {
                    Label(tr("清理全部缓存", "清理全部快取", "Clean All Caches"), systemImage: "sparkles")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))

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
            .frame(minWidth: 340, maxWidth: .infinity, maxHeight: .infinity)

            // Right: Orphan Formulae (brew autoremove) & Tips
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: "shippingbox.and.arrow.backward.fill")
                        .foregroundStyle(.teal)
                    Text(tr("无用孤儿依赖包", "無用孤兒依賴套件", "Orphan Dependencies"))
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
                                    "一键清理 \(store.orphanFormulae.count) 个孤儿依赖",
                                    "一鍵清理 \(store.orphanFormulae.count) 個孤兒依賴",
                                    "Remove \(store.orphanFormulae.count) Orphan Dependencies"
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
                                "• Homebrew 默认会将已安装软件的 `.dmg` / `.zip` / `.bottle.tar.gz` 安装包保留 120 天。点击右上角「一键清理缓存」将安全清除所有历史安装包缓存及旧版运行库。\n• 若您过去曾直接将应用拖入废纸篓或未使用 `--zap` 卸载，可切换至上方「卸载残留」扫描遗留在 `~/Library` 下的孤儿配置与缓存目录。",
                                "• Homebrew 預設會將已安裝軟體的 `.dmg` / `.zip` / `.bottle.tar.gz` 安裝包保留 120 天。點擊右上角「一鍵清理快取」將安全清除所有歷史安裝包快取及舊版執行庫。\n• 若您過去曾直接將應用拖入垃圾桶或未使用 `--zap` 解除安裝，可切換至上方「殘留清理」掃描遺留在 `~/Library` 下的孤兒設定與快取目錄。",
                                "• Homebrew keeps downloaded archives for 120 days by default. Clicking \"Clean Caches\" safely reclaims disk space.\n• Switch to \"Leftovers\" above to scan and clean leftover `~/Library` folders from previously uninstalled apps."
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
            .frame(minWidth: 240, idealWidth: 300, maxWidth: 380, maxHeight: .infinity)
        }
    }

    // MARK: - Sub-Tab 2: Uninstalled App Leftovers (:zap)

    @ViewBuilder
    private var appLeftoversContent: some View {
        VStack(spacing: 0) {
            // Top Banner & Controls
            HStack(spacing: 12) {
                Image(systemName: "shield.checkered")
                    .font(.title3)
                    .foregroundStyle(.purple)

                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        tr(
                            "基于 Homebrew Cask `:zap` 规则交叉比对：仅列出「当前未安装且不在 /Applications 中」的已卸载软件孤儿残留目录",
                            "基於 Homebrew Cask `:zap` 規則交叉比對：僅列出「目前未安裝且不在 /Applications 中」的已解除安裝軟體孤兒殘留目錄",
                            "Cross-referenced with Homebrew Cask `:zap` rules: only lists `~/Library` folders of apps neither installed in Brew nor present in `/Applications`"
                        )
                    )
                    .font(.caption.weight(.semibold))
                    Text(
                        tr(
                            "安全保护：已自动排除所有正在运行的应用、同系列多版本共享目录及系统基础目录。默认「移至废纸篓」支持随时从废纸篓还原。",
                            "安全保護：已自動排除所有正在執行的應用、同系列多版本共享目錄及系統基礎目錄。預設「移至垃圾桶」支援隨時從垃圾桶還原。",
                            "Safety guard: excludes running apps, shared vendor folders, and installed variants. \"Move to Trash\" lets you restore from macOS Trash anytime."
                        )
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if !store.appLeftovers.isEmpty {
                    Button {
                        let allSelected = store.selectedLeftoversCount == store.appLeftovers.count
                        store.setAllLeftoversSelection(!allSelected)
                    } label: {
                        Text(
                            store.selectedLeftoversCount == store.appLeftovers.count
                                ? tr("取消全选", "取消全選", "Deselect All")
                                : tr("全选 (\(store.appLeftovers.count))", "全選 (\(store.appLeftovers.count))", "Select All (\(store.appLeftovers.count))")
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button {
                    Task { await store.scanAppLeftovers() }
                } label: {
                    Label(tr("重新扫描", "重新掃描", "Rescan"), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(store.isScanningLeftovers)

                if store.selectedLeftoversCount > 0 {
                    Button {
                        store.cleanSelectedLeftovers(moveToTrash: true)
                    } label: {
                        Label(
                            tr(
                                "移至废纸篓 (\(store.selectedLeftoversCount) 项 · \(AppConstants.formatBytes(store.totalSelectedLeftoversBytes)))",
                                "移至垃圾桶 (\(store.selectedLeftoversCount) 項 · \(AppConstants.formatBytes(store.totalSelectedLeftoversBytes)))",
                                "Move to Trash (\(store.selectedLeftoversCount) · \(AppConstants.formatBytes(store.totalSelectedLeftoversBytes)))"
                            ),
                            systemImage: "trash.circle.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .controlSize(.small)

                    Button(role: .destructive) {
                        store.cleanSelectedLeftovers(moveToTrash: false)
                    } label: {
                        Text(tr("彻底删除", "徹底刪除", "Delete Permanently"))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.purple.opacity(0.07))

            Divider()

            if store.isScanningLeftovers {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(tr("正在扫描 `~/Library` 下的已卸载软件残留目录…", "正在掃描 `~/Library` 下的已解除安裝軟體殘留目錄…", "Scanning `~/Library` for uninstalled app leftovers…"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.appLeftovers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 42))
                        .foregroundStyle(.green)
                    Text(tr("未发现已卸载软件的孤儿残留目录", "未發現已解除安裝軟體的孤兒殘留目錄", "No Uninstalled App Leftovers Found"))
                        .font(.headline)
                    Text(
                        tr(
                            "您的 `~/Library/{Application Support,Caches,Preferences,Saved Application State}` 下没有检测到属于已卸载 Cask 软件的残留数据。",
                            "您的 `~/Library/{Application Support,Caches,Preferences,Saved Application State}` 下沒有偵測到屬於已解除安裝 Cask 軟體的殘留資料。",
                            "No leftover directories from uninstalled Cask apps were detected in `~/Library`."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(store.appLeftovers) { item in
                    HStack(spacing: 12) {
                        Button {
                            store.toggleLeftoverSelection(id: item.id)
                        } label: {
                            Image(systemName: item.isSelected ? "checkmark.square.fill" : "square")
                                .font(.system(size: 16))
                                .foregroundStyle(item.isSelected ? Color.purple : Color.secondary)
                        }
                        .buttonStyle(.plain)

                        Image(nsImage: NSWorkspace.shared.icon(forFile: item.fullPath))
                            .resizable()
                            .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text(item.displayPath)
                                    .font(.system(.callout, design: .monospaced).weight(.medium))
                                    .lineLimit(1)

                                BadgeView(
                                    text: "\(tr("原属软件", "原屬軟體", "Uninstalled")): \(item.caskDisplayName) (\(item.caskToken))",
                                    color: .purple
                                )
                            }

                            Text("\(tr("最后修改时间", "最後修改時間", "Last Modified")): \(Self.dateFormatter.string(from: item.modifiedAt)) · \(item.fullPath)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        BadgeView(
                            text: AppConstants.formatBytes(item.sizeBytes),
                            color: item.sizeBytes >= 50 * 1024 * 1024 ? .orange : .blue
                        )

                        Button {
                            store.revealLeftoverInFinder(item)
                        } label: {
                            Image(systemName: "magnifyingglass.circle")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help(tr("在 Finder 中查看该残留目录", "在 Finder 中查看該殘留目錄", "Reveal in Finder"))
                    }
                    .padding(.vertical, 3)
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - Sub-Tab 3: Background Services (`brew services`)

    @ViewBuilder
    private var servicesContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "gearshape.2.fill")
                    .font(.title3)
                    .foregroundStyle(.teal)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Homebrew 后台守护服务管理", "Homebrew 背景守護服務管理", "Homebrew Background Services"))
                    .font(.caption.weight(.semibold))
                    Text(
                        tr(
                            "可视化查看、启动、停止或重启数据库、Web 服务器及同步工具（如 MySQL、Redis、PostgreSQL、Nginx、Ollama、Syncthing）。",
                            "視覺化查看、啟動、停止或重啟資料庫、Web 伺服器及同步工具（如 MySQL、Redis、PostgreSQL、Nginx、Ollama、Syncthing）。",
                            "Inspect, start, stop, or restart Homebrew-managed background daemons (MySQL, Redis, PostgreSQL, Nginx, Ollama, Syncthing)."
                        )
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                BadgeView(
                    text: tr(
                        "运行中 \(store.runningServicesCount) / 共 \(store.brewServices.count) 个服务",
                        "執行中 \(store.runningServicesCount) / 共 \(store.brewServices.count) 個服務",
                        "\(store.runningServicesCount) running / \(store.brewServices.count) total"
                    ),
                    color: store.runningServicesCount > 0 ? .green : .secondary
                )

                Button {
                    Task { await store.refreshServices() }
                } label: {
                    Label(tr("刷新服务状态", "重新整理服務狀態", "Refresh Services"), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(store.isLoadingServices)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.teal.opacity(0.07))

            Divider()

            if store.isLoadingServices && store.brewServices.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(tr("正在读取 `brew services list --json` 状态…", "正在讀取 `brew services list --json` 狀態…", "Loading `brew services list --json`…"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.brewServices.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 40))
                        .foregroundStyle(.teal)
                    Text(tr("当前没有已安装的 Homebrew 后台服务", "目前沒有已安裝的 Homebrew 背景服務", "No Homebrew Background Services Installed"))
                        .font(.headline)
                    Text(
                        tr(
                            "当您通过 Homebrew 安装带有守护进程的软件（如数据库、缓存或本地 AI 引擎）后，即可在此处一键启停并配置开机自启。",
                            "當您透過 Homebrew 安裝帶有守護行程的軟體（如資料庫、快取或本機 AI 引擎）後，即可在此處一鍵啟停並設定開機自啟。",
                            "Install any Formula that includes a launchd service (databases, web servers, local AI engines) to start, stop, or restart it here."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)

                    HStack(spacing: 8) {
                        Text(tr("常见后台服务：", "常見背景服務：", "Popular Services:"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(["redis", "mysql", "postgresql@17", "nginx", "ollama", "syncthing"], id: \.self) { pkg in
                            Button {
                                store.catalogTypeFilter = .all
                                store.selectedSearchCategory = .all
                                store.catalogSearchQuery = pkg
                                store.selectedTab = .search
                            } label: {
                                Text(pkg)
                                    .font(.caption.monospaced())
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(store.brewServices) { svc in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(svc.isRunning ? Color.green : (svc.isError ? Color.red : Color.gray.opacity(0.45)))
                            .frame(width: 10, height: 10)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(svc.name)
                                    .font(.system(.body, design: .monospaced).weight(.semibold))

                                if let zhMeta = ChineseSearchIndex.meta(for: svc.name),
                                   AppLanguage.current.resolved != .en {
                                    BadgeView(text: zhMeta.zhName, color: .teal)
                                }

                                BadgeView(
                                    text: svc.statusBadgeText,
                                    color: svc.isRunning ? .green : (svc.isError ? .red : .secondary)
                                )

                                if let user = svc.user, !user.isEmpty {
                                    BadgeView(text: "user: \(user)", color: .blue)
                                }
                            }

                            if let file = svc.file, !file.isEmpty {
                                Text(file)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        if let file = svc.file, !file.isEmpty {
                            Button {
                                store.revealServicePlistInFinder(svc)
                            } label: {
                                Image(systemName: "magnifyingglass.circle")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help(tr("在 Finder 中定位 plist 服务配置文件", "在 Finder 中定位 plist 服務設定檔", "Reveal launchd plist in Finder"))
                        }

                        if svc.isRunning {
                            Button {
                                store.controlService(svc, action: "restart")
                            } label: {
                                Label(tr("重启", "重啟", "Restart"), systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button(role: .destructive) {
                                store.controlService(svc, action: "stop")
                            } label: {
                                Label(tr("停止", "停止", "Stop"), systemImage: "stop.fill")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        } else {
                            Button {
                                store.controlService(svc, action: "start")
                            } label: {
                                Label(tr("启动 (自启)", "啟動 (自啟)", "Start"), systemImage: "play.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.teal)
                            .controlSize(.small)
                            .help(tr("执行 brew services start \(svc.name) 启动并注册登录自启", "執行 brew services start \(svc.name) 啟動並註冊登入自啟", "Run brew services start \(svc.name)"))

                            Button {
                                store.controlService(svc, action: "run")
                            } label: {
                                Text(tr("单次运行", "單次執行", "Run Once"))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help(tr("执行 brew services run \(svc.name) 仅本次启动但不注册开机自启", "執行 brew services run \(svc.name) 僅本次啟動但不註冊開機自啟", "Run service without registering launch at login"))
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - Sub-Tab 4: Doctor Diagnostics & Tap Repositories

    @ViewBuilder
    private var doctorAndTapsContent: some View {
        HSplitView {
            // Left: brew doctor Health Diagnostics
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: "stethoscope")
                        .foregroundStyle(.green)
                    Text(tr("Homebrew 环境健康体检", "Homebrew 環境健康體檢", "Environment Health Check"))
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Button {
                        Task { await store.runBrewDoctor() }
                    } label: {
                        Label(
                            store.doctorState.isRunning
                                ? tr("正在体检…", "正在體檢…", "Checking…")
                                : tr("立即运行体检", "立即執行體檢", "Run Diagnostics"),
                            systemImage: "waveform.path.ecg"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                    .controlSize(.small)
                    .disabled(store.doctorState.isRunning)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    switch store.doctorState {
                    case .idle:
                        VStack(spacing: 12) {
                            Image(systemName: "stethoscope.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.teal)
                            Text(tr("一键检查 Homebrew 环境配置与潜在冲突", "一鍵檢查 Homebrew 環境設定與潛在衝突", "Diagnose Homebrew Environment & Potential Issues"))
                                .font(.headline)
                            Text(
                                tr(
                                    "点击右上角「立即运行体检」将执行 `brew doctor`，自动检测 PATH 环境变量优先级、Command Line Tools 版本、断开的符号链接及权限异常。",
                                    "點擊右上角「立即執行體檢」將執行 `brew doctor`，自動偵測 PATH 環境變數優先級、Command Line Tools 版本、斷開的符號連結及權限異常。",
                                    "Click \"Run brew doctor\" to check PATH configuration, Command Line Tools status, broken symlinks, and directory permissions."
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 440)

                            Button {
                                Task { await store.runBrewDoctor() }
                            } label: {
                                Label(tr("开始全面体检", "開始全面體檢", "Start Diagnostics"), systemImage: "play.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.teal)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    case .running:
                        VStack(spacing: 12) {
                            ProgressView()
                            Text(tr("正在执行 `brew doctor` 环境诊断（约需 3~10 秒）…", "正在執行 `brew doctor` 環境診斷（約需 3~10 秒）…", "Running `brew doctor` diagnostics (takes 3–10 seconds)…"))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    case .healthy(let output):
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title2)
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tr("环境非常健康 (Your system is ready to brew)", "環境非常健康 (Your system is ready to brew)", "Your system is ready to brew"))
                                    .font(.callout.weight(.bold))
                                Text(tr("未检测到任何阻塞性配置冲突或损坏的符号链接。", "未偵測到任何阻塞性設定衝突或損壞的符號連結。", "No configuration conflicts or broken symlinks detected."))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        ScrollView {
                            Text(output)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                        }
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    case .warnings(let cards, let fullText):
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title3)
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(
                                    tr(
                                        "发现 \(cards.count) 项环境提示 (非致命 Warning，通常不影响日常安装)",
                                        "發現 \(cards.count) 項環境提示 (非致命 Warning，通常不影響日常安裝)",
                                        "Found \(cards.count) diagnostic warnings (usually non-fatal)"
                                    )
                                )
                                .font(.callout.weight(.semibold))
                                Text(tr("您可按下方建议处理，或点击右侧按钮自动清理失效符号链接。", "您可按下方建議處理，或點擊右側按鈕自動清理失效符號連結。", "Review the suggestions below or run cleanup to prune dead symlinks."))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(fullText, forType: .string)
                            } label: {
                                Label(tr("复制诊断报告", "複製診斷報告", "Copy Report"), systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button {
                                store.runCleanupAllCaches()
                            } label: {
                                Label(tr("立即清理缓存", "立即清理快取", "Clean Caches"), systemImage: "wrench.and.screwdriver.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .controlSize(.small)
                        }
                        .padding(10)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(cards.enumerated()), id: \.offset) { _, card in
                                    Text(card)
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                        .padding(10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(nsColor: .controlBackgroundColor))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }

                    case .failed(let err):
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.octagon.fill")
                                .foregroundStyle(.red)
                            Text(err)
                                .font(.caption)
                        }
                        .padding(12)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(minWidth: 340, maxWidth: .infinity, maxHeight: .infinity)

            // Right: Third-Party Tap Repository Manager (`brew tap`)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .foregroundStyle(.blue)
                    Text(tr("软件源仓库管理", "軟體源倉庫管理", "Tap Repositories"))
                        .font(.caption.weight(.semibold))
                    Spacer()
                    if store.isLoadingTaps {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        BadgeView(
                            text: tr("\(store.tappedRepositories.count) 个已启用", "\(store.tappedRepositories.count) 個已啟用", "\(store.tappedRepositories.count) active"),
                            color: .blue
                        )
                    }
                    Button {
                        Task { await store.refreshTaps() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text(
                        tr(
                            "Tap 是 Homebrew 的第三方扩展软件源（GitHub `user/repo`）。现代 Homebrew 4.x+ 已通过 JSON API 自动拉取官方 core/cask 索引，无需再手动 tap 官方仓库。",
                            "Tap 是 Homebrew 的第三方擴充軟體源（GitHub `user/repo`）。現代 Homebrew 4.x+ 已透過 JSON API 自動拉取官方 core/cask 索引，無需再手動 tap 官方倉庫。",
                            "Taps are third-party package repositories (`user/repo`). Homebrew 4.x+ fetches official core/cask catalogs via JSON API automatically."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    // Add new tap bar
                    HStack(spacing: 8) {
                        TextField(
                            tr("输入 user/repo 或直接粘贴 brew tap 命令…", "輸入 user/repo 或直接貼上 brew tap 命令…", "Enter user/repo or paste `brew tap ...` command…"),
                            text: $store.newTapInput
                        )
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                        .onSubmit {
                            store.addTap(store.newTapInput)
                        }

                        Button {
                            store.addTap(store.newTapInput)
                        } label: {
                            Label(tr("添加 Tap", "新增 Tap", "Add Tap"), systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(!store.newTapInput.contains("/"))
                    }

                    // Current Taps List
                    if store.tappedRepositories.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.teal)
                            Text(tr("当前使用纯官方 JSON API 模式，未挂载额外第三方 Tap", "目前使用純官方 JSON API 模式，未掛載額外第三方 Tap", "Using standard JSON API mode (no extra Taps mounted)"))
                                .font(.caption)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.teal.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(store.tappedRepositories, id: \.self) { repo in
                                    let isOfficial = repo.hasPrefix("homebrew/")
                                    HStack {
                                        Image(systemName: isOfficial ? "checkmark.seal.fill" : "shippingbox")
                                            .foregroundStyle(isOfficial ? .teal : .blue)
                                        Text(repo)
                                            .font(.system(.callout, design: .monospaced))
                                            .lineLimit(1)
                                        Spacer()
                                        if isOfficial {
                                            BadgeView(text: tr("官方源", "官方源", "Official"), color: .teal)
                                        }
                                        Button(role: .destructive) {
                                            store.removeTap(repo)
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.mini)
                                        .help(tr("执行 brew untap \(repo) 移除该仓库", "執行 brew untap \(repo) 移除該倉庫", "Run brew untap \(repo)"))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }
                    }

                    Spacer()
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(minWidth: 240, idealWidth: 300, maxWidth: 380, maxHeight: .infinity)
        }
    }
}
