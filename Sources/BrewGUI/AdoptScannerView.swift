import SwiftUI
import AppKit

public struct BatchInstallView: View {
    @ObservedObject var store: BrewStore

    public init(store: BrewStore) {
        self.store = store
    }

    private var selectedInstallableCount: Int {
        store.batchItems.filter { $0.isSelected }.count
    }

    private var selectedKnownTotalBytes: Int64 {
        var total: Int64 = 0
        for item in store.batchItems where item.isSelected {
            switch item.status {
            case .readyToInstall(let entry):
                if let b = store.sizeBytes(for: entry.name) {
                    total += b
                }
            case .readyToAdopt(let entry, _):
                if !item.useAdoptIfAvailable, let b = store.sizeBytes(for: entry.name) {
                    total += b
                }
            default:
                break
            }
        }
        return total
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Header
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("批量装机与备份迁移", "批次裝機與備份遷移", "Batch Install & Backup Migration"))
                        .font(.headline)
                    Text(
                        tr(
                            "一键备份本机已装软件清单，或粘贴软件名、导入备份文件快速恢复新机环境。",
                            "一鍵備份本機已裝軟體清單，或貼上軟體名、匯入備份檔案快速恢復新機環境。",
                            "Backup your Mac's software list in one click, or paste package names / import a backup file to restore on a new Mac."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    Button {
                        store.saveBrewfileWithPanel()
                    } label: {
                        Label(tr("备份本机软件清单到文件 (Brewfile)…", "備份本機軟體清單到檔案 (Brewfile)…", "Save Backup List to File (Brewfile)…"), systemImage: "square.and.arrow.down")
                    }

                    Button {
                        let bf = store.exportInstalledBrewfile()
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(bf, forType: .string)
                        store.batchInputText = bf
                        store.parseBatchInput()
                        store.batchExportCopiedMessage = tr("已生成并复制备份清单", "已產生並複製備份清單", "Copied Backup List")
                        store.latestOutcomeFeedback = TaskOutcomeFeedback(
                            isSuccess: true,
                            title: tr("已生成并复制本机软件备份清单", "已產生並複製本機軟體備份清單", "Copied Software Backup List"),
                            subtitle: tr("已包含全部桌面应用、主动安装的命令行工具及第三方源", "已包含全部桌面應用、主動安裝的命令列工具及第三方源", "Includes all desktop apps, top-level CLI tools, and third-party taps")
                        )
                    } label: {
                        Label(tr("生成并复制备份清单 (Brewfile)", "產生並複製備份清單 (Brewfile)", "Generate & Copy Backup List (Brewfile)"), systemImage: "doc.on.doc")
                    }

                    Divider()

                    Button {
                        let cmd = store.exportInstalledCommands(twoLines: true)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(cmd, forType: .string)
                        store.batchInputText = cmd
                        store.parseBatchInput()
                        store.batchExportCopiedMessage = tr("已导出并复制分行指令", "已匯出並複製分行指令", "Exported & copied 2-line commands")
                    } label: {
                        Label(tr("导出为终端安装脚本（桌面与命令行分行）", "匯出為終端安裝腳本（桌面與命令列分行）", "Export as 2-Line Terminal Script"), systemImage: "text.alignleft")
                    }

                    Button {
                        let cmd = store.exportInstalledCommands(twoLines: false)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(cmd, forType: .string)
                        store.batchInputText = cmd
                        store.parseBatchInput()
                        store.batchExportCopiedMessage = tr("已导出并复制单行指令", "已匯出並複製單行指令", "Exported & copied 1-line command")
                    } label: {
                        Label(tr("导出为单行终端安装命令", "匯出為單行終端安裝命令", "Export as Single-Line Terminal Command"), systemImage: "line.3.horizontal")
                    }
                } label: {
                    Label(tr("备份本机清单", "備份本機清單", "Backup This Mac"), systemImage: "archivebox")
                }
                .menuStyle(.borderedButton)
                .fixedSize()
                .help(tr("将本机所有已纳管的桌面应用、顶层命令行工具及第三方源导出备份，方便换新机或重装系统恢复", "將本機所有已納管的桌面應用、頂層命令列工具及第三方源匯出備份，方便換新機或重灌系統恢復", "Export all managed desktop apps, top-level CLI tools, and third-party sources for easy migration"))

                Menu {
                    Button {
                        store.importBrewfileWithPanel()
                    } label: {
                        Label(tr("从文件导入备份清单 (Brewfile)…", "從檔案匯入備份清單 (Brewfile)…", "Import Backup File (Brewfile)…"), systemImage: "folder")
                    }

                    Button {
                        if let str = NSPasteboard.general.string(forType: .string) {
                            store.batchInputText = str
                            store.batchExportCopiedMessage = nil
                            store.parseBatchInput()
                        }
                    } label: {
                        Label(tr("从剪贴板粘贴并自动识别", "從剪貼簿貼上並自動識別", "Paste from Clipboard & Parse"), systemImage: "doc.on.clipboard")
                    }
                } label: {
                    Label(tr("导入 / 粘贴", "匯入 / 貼上", "Import / Paste"), systemImage: "square.and.arrow.down.on.square")
                }
                .menuStyle(.borderedButton)
                .fixedSize()

                Button {
                    store.parseBatchInput()
                } label: {
                    Label(tr("识别包名", "識別套件名", "Parse"), systemImage: "text.magnifyingglass")
                }
                .buttonStyle(.bordered)

                Button {
                    store.executeSelectedBatchInstall()
                } label: {
                    Label(
                        tr(
                            "一键排队安装 (\(selectedInstallableCount))",
                            "一鍵排隊安裝 (\(selectedInstallableCount))",
                            "Queue Install (\(selectedInstallableCount))"
                        ),
                        systemImage: "arrow.down.circle.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedInstallableCount == 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Split Area: Left TextEditor, Right Parsed Table
            HSplitView {
                // Left Input Box
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(tr("输入或粘贴包名列表", "輸入或貼上套件名清單", "Input or Paste Package Names"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        if let msg = store.batchExportCopiedMessage {
                            BadgeView(text: msg, color: .green)
                        }
                        Spacer()
                        if !store.batchInputText.isEmpty {
                            Button(tr("清空输入", "清空輸入", "Clear")) {
                                store.batchInputText = ""
                                store.batchExportCopiedMessage = nil
                                store.batchDetectedMissingTaps = []
                                store.batchItems = []
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }

                    TextEditor(text: $store.batchInputText)
                        .font(.system(size: 13, design: .monospaced))
                        .padding(6)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                        )
                        .onChange(of: store.batchInputText) { _, _ in
                            store.parseBatchInput()
                        }

                    Text(tr("支持命令或 Brewfile：`brew \"jq\"` / `cask \"iina\"` / `wget ripgrep`", "支援命令或 Brewfile：`brew \"jq\"` / `cask \"iina\"` / `wget ripgrep`", "Supports CLI or Brewfile: `brew \"jq\"` / `cask \"iina\"` / `wget ripgrep`"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .frame(minWidth: 200, idealWidth: 230, maxWidth: 260, maxHeight: .infinity)

                // Right Parsed Results
                VStack(spacing: 0) {
                    if !store.batchDetectedMissingTaps.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "shippingbox.and.arrow.backward.fill")
                                .foregroundStyle(.indigo)
                            Text(
                                tr(
                                    "检测到清单包含 \(store.batchDetectedMissingTaps.count) 个尚未添加的 Tap 源 (\(store.batchDetectedMissingTaps.joined(separator: ", ")))，建议先添加以识别其中的包",
                                    "偵測到清單包含 \(store.batchDetectedMissingTaps.count) 個尚未新增的 Tap 源 (\(store.batchDetectedMissingTaps.joined(separator: ", ")))，建議先新增以識別其中的套件",
                                    "Detected \(store.batchDetectedMissingTaps.count) missing Tap(s) (\(store.batchDetectedMissingTaps.joined(separator: ", "))); add them first to resolve their packages"
                                )
                            )
                            .font(.caption)
                            Spacer()
                            Button {
                                store.addMissingBatchTaps()
                            } label: {
                                Label(tr("一键添加缺失 Tap", "一鍵新增缺失 Tap", "Add Missing Taps"), systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.indigo)
                            .controlSize(.small)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.indigo.opacity(0.1))

                        Divider()
                    }
                    HStack(spacing: 10) {
                        Text(
                            tr(
                                "识别结果 (\(store.batchItems.count) 项，已勾选 \(selectedInstallableCount) 项)",
                                "識別結果 (\(store.batchItems.count) 項，已勾選 \(selectedInstallableCount) 項)",
                                "Parsed (\(store.batchItems.count) items, \(selectedInstallableCount) selected)"
                            )
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        if selectedKnownTotalBytes > 0 {
                            BadgeView(
                                text: tr(
                                    "已知下载量 ≈ \(AppConstants.formatBytes(selectedKnownTotalBytes))",
                                    "已知下載量 ≈ \(AppConstants.formatBytes(selectedKnownTotalBytes))",
                                    "Est. Download ≈ \(AppConstants.formatBytes(selectedKnownTotalBytes))"
                                ),
                                color: selectedKnownTotalBytes > 500 * 1024 * 1024 ? .orange : .teal
                            )
                            .fixedSize()
                        }
                        if store.isProbingSizes {
                            ProgressView()
                                .controlSize(.mini)
                        }
                        Spacer()
                        if !store.batchItems.isEmpty {
                            Button(tr("仅勾选轻量包 (<100MB)", "僅勾選輕量套件 (<100MB)", "Select Lightweight Only (<100MB)")) {
                                store.selectOnlyLightweightBatchItems(maxBytes: 100 * 1024 * 1024)
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .help(tr("取消勾选大于 100MB 的大体积安装包，先快速安装轻量软件", "取消勾選大於 100MB 的大體積安裝包，先快速安裝輕量軟體", "Uncheck installers larger than 100MB to install lightweight packages first"))

                            Text("·")
                                .foregroundStyle(.tertiary)

                            Button(tr("全选可安装项", "全選可安裝項", "Select All Installable")) {
                                for idx in store.batchItems.indices {
                                    switch store.batchItems[idx].status {
                                    case .readyToInstall(let entry):
                                        store.batchItems[idx].isSelected = !entry.isDisabled
                                    case .readyToAdopt:
                                        store.batchItems[idx].isSelected = true
                                    case .alreadyInstalled, .notFound:
                                        store.batchItems[idx].isSelected = false
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor))

                    Divider()

                    if store.batchItems.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "arrow.left.arrow.right.square")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)
                            Text(tr("在左侧输入软件名称，或点击右上角「备份本机清单 / 导入」开始", "在左側輸入軟體名稱，或點擊右上角「備份本機清單 / 匯入」開始", "Paste package names on the left or click Backup / Import above"))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Text(
                                tr(
                                    "执行安装时，命令行工具将自动合并解析依赖，桌面应用将逐个独立排队下载。",
                                    "執行安裝時，命令列工具將自動合併解析依賴，桌面應用將逐個獨立排隊下載。",
                                    "CLI tools are installed together for shared dependency resolution, while desktop apps are queued individually."
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(Array(store.batchItems.enumerated()), id: \.element.id) { index, item in
                                let entryToken: String? = {
                                    switch item.status {
                                    case .readyToInstall(let e), .readyToAdopt(let e, _):
                                        return e.name
                                    default:
                                        return nil
                                    }
                                }()
                                BatchItemRow(
                                    item: item,
                                    probedSizeBytes: entryToken.flatMap { store.sizeBytes(for: $0) },
                                    onToggleSelect: {
                                        store.batchItems[index].isSelected.toggle()
                                    },
                                    onToggleAdoptMode: {
                                        store.batchItems[index].useAdoptIfAvailable.toggle()
                                    }
                                )
                                .padding(.vertical, 3)
                            }
                        }
                        .listStyle(.inset)
                    }
                }
                .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct BatchItemRow: View {
    let item: BatchInstallItem
    let probedSizeBytes: Int64?
    let onToggleSelect: () -> Void
    let onToggleAdoptMode: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            switch item.status {
            case .readyToInstall(let entry):
                Button {
                    if !entry.isDisabled {
                        onToggleSelect()
                    }
                } label: {
                    Image(systemName: entry.isDisabled ? "nosign" : (item.isSelected ? "checkmark.square.fill" : "square"))
                        .foregroundStyle(entry.isDisabled ? .red : (item.isSelected ? Color.accentColor : .secondary))
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(entry.isDisabled)

                PackageIconView(
                    token: entry.name,
                    type: entry.type,
                    desc: entry.desc,
                    appPath: nil,
                    size: 30
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(entry.displayName)
                            .font(.body.weight(.medium))
                            .strikethrough(entry.isDisabled)
                            .foregroundStyle(entry.isDisabled ? .secondary : .primary)
                        BadgeView(text: entry.type.localizedHumanLabel, color: entry.type == .cask ? .purple : .blue)
                        if let tap = entry.tap, !tap.isEmpty {
                            BadgeView(text: tr("第三方源", "第三方源", "3rd-Party"), color: .indigo)
                        }
                        if entry.isDisabled {
                            BadgeView(text: tr("已禁用", "已停用", "Disabled"), color: .red)
                        } else if entry.isDeprecated {
                            BadgeView(text: tr("已弃用", "已棄用", "Deprecated"), color: .orange)
                            BadgeView(text: "\(tr("可安装", "可安裝", "Ready")) \(entry.version)", color: .blue)
                        } else {
                            BadgeView(text: "\(tr("可安装", "可安裝", "Ready")) \(entry.version)", color: .blue)
                        }
                        if !entry.isDisabled, let sizeBytes = probedSizeBytes, sizeBytes > 0 {
                            let isLarge = sizeBytes >= 100 * 1024 * 1024
                            BadgeView(
                                text: "📦 \(AppConstants.formatBytes(sizeBytes))",
                                color: isLarge ? .orange : .teal
                            )
                        }
                    }
                    if entry.isDisabled {
                        Text("\(tr("官方源已停止分发", "官方源已停止分發", "Disabled in Homebrew"))：\(entry.localizedLifecycleReason ?? "")")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(1)
                    } else if !entry.desc.isEmpty {
                        let localizedDesc = ChineseSearchIndex.localizedDescription(for: entry)
                        Text(localizedDesc.isEmpty ? entry.desc : localizedDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

            case .readyToAdopt(let entry, let localApp):
                Button {
                    onToggleSelect()
                } label: {
                    Image(systemName: item.isSelected ? "checkmark.square.fill" : "square")
                        .foregroundStyle(item.isSelected ? Color.teal : .secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)

                PackageIconView(
                    token: entry.name,
                    type: entry.type,
                    desc: entry.desc,
                    appPath: AppIconProvider.shared.resolveExistingAppPath(for: entry.appBundles),
                    size: 30
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(entry.displayName)
                            .font(.body.weight(.medium))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        BadgeView(text: entry.type.localizedHumanLabel, color: .purple)
                            .fixedSize()
                        if let tap = entry.tap, !tap.isEmpty {
                            BadgeView(text: tr("第三方源", "第三方源", "3rd-Party"), color: .indigo)
                                .fixedSize()
                        }
                        BadgeView(text: "\(tr("本机已有", "本機已有", "On Mac:")) \(localApp)", color: .teal)
                            .fixedSize()
                        if let sizeBytes = probedSizeBytes, sizeBytes > 0 {
                            BadgeView(
                                text: "📦 \(AppConstants.formatBytes(sizeBytes))",
                                color: sizeBytes >= 100 * 1024 * 1024 ? .orange : .teal
                            )
                            .fixedSize()
                        }
                    }
                    if !entry.desc.isEmpty {
                        let localizedDesc = ChineseSearchIndex.localizedDescription(for: entry)
                        Text(localizedDesc.isEmpty ? entry.desc : localizedDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button {
                    onToggleAdoptMode()
                } label: {
                    Text(item.useAdoptIfAvailable ? tr("模式: 直接纳入", "模式: 直接納入", "Mode: Adopt") : tr("模式: 重新安装", "模式: 重新安裝", "Mode: Reinstall"))
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(item.useAdoptIfAvailable ? .teal : .blue)
                .controlSize(.mini)
                .fixedSize()

            case .alreadyInstalled(let pkg):
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)

                PackageIconView(
                    token: pkg.name,
                    type: pkg.type,
                    desc: pkg.desc,
                    appPath: pkg.resolvedAppPath,
                    size: 30
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(pkg.displayName)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                        BadgeView(text: pkg.type.localizedHumanLabel, color: .gray)
                        BadgeView(
                            text: tr("已安装 (\(pkg.installedVersion ?? ""))，自动跳过", "已安裝 (\(pkg.installedVersion ?? ""))，自動略過", "Installed (\(pkg.installedVersion ?? "")), skipped"),
                            color: .green
                        )
                    }
                }

            case .notFound:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.title3)

                HStack(spacing: 6) {
                    Text(item.rawToken)
                        .font(.body.monospaced().weight(.medium))
                    BadgeView(text: tr("未找到匹配的软件包", "找不到符合的軟體套件", "Package not found"), color: .orange)
                }
            }

            Spacer()
        }
    }
}
