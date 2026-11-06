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
                    Text("批量识别与安装 (Batch Install)")
                        .font(.headline)
                    Text("一次性粘贴多个包名（支持换行、空格、逗号分隔，甚至可直接粘贴 `brew install xxx yyy` 命令），自动识别 Formula / Cask / 本机可接管 / 已安装状态。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    Button {
                        let cmd = store.exportInstalledCommands(twoLines: true)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(cmd, forType: .string)
                        store.batchInputText = cmd
                        store.parseBatchInput()
                        store.batchExportCopiedMessage = "已导出并复制分行指令"
                    } label: {
                        Label("导出分行命令 (Formula 与 Cask 分两行)", systemImage: "text.alignleft")
                    }

                    Button {
                        let cmd = store.exportInstalledCommands(twoLines: false)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(cmd, forType: .string)
                        store.batchInputText = cmd
                        store.parseBatchInput()
                        store.batchExportCopiedMessage = "已导出并复制单行指令"
                    } label: {
                        Label("导出单行合并命令", systemImage: "line.3.horizontal")
                    }
                } label: {
                    Label("导出本机安装指令", systemImage: "square.and.arrow.up")
                }
                .menuStyle(.borderedButton)
                .fixedSize()
                .help("将本机所有已托管顶层应用导出为 brew install 命令并复制到剪贴板，方便重装系统或换新机迁移")

                Button {
                    if let str = NSPasteboard.general.string(forType: .string) {
                        store.batchInputText = str
                        store.batchExportCopiedMessage = nil
                        store.parseBatchInput()
                    }
                } label: {
                    Label("从剪贴板粘贴并识别", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)

                Button {
                    store.parseBatchInput()
                } label: {
                    Label("识别包名", systemImage: "text.magnifyingglass")
                }
                .buttonStyle(.bordered)

                Button {
                    store.executeSelectedBatchInstall()
                } label: {
                    Label("一键排队安装 (\(selectedInstallableCount))", systemImage: "arrow.down.circle.fill")
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
                        Text("输入或粘贴包名列表")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        if let msg = store.batchExportCopiedMessage {
                            BadgeView(text: "\(msg) (已复制)", color: .green)
                        }
                        Spacer()
                        if !store.batchInputText.isEmpty {
                            Button("清空输入") {
                                store.batchInputText = ""
                                store.batchExportCopiedMessage = nil
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

                    Text("示例：`wget jq ripgrep visual-studio-code iina`")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .frame(minWidth: 200, idealWidth: 230, maxWidth: 260, maxHeight: .infinity)

                // Right Parsed Results
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Text("识别结果 (\(store.batchItems.count) 项，已勾选 \(selectedInstallableCount) 项)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                        if selectedKnownTotalBytes > 0 {
                            BadgeView(
                                text: "已知下载量 ≈ \(AppConstants.formatBytes(selectedKnownTotalBytes))",
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
                            Button("仅勾选轻量包 (<100MB)") {
                                store.selectOnlyLightweightBatchItems(maxBytes: 100 * 1024 * 1024)
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .help("取消勾选大于 100MB 的大体积安装包，先快速安装轻量软件")

                            Text("·")
                                .foregroundStyle(.tertiary)

                            Button("全选可安装项") {
                                for idx in store.batchItems.indices {
                                    switch store.batchItems[idx].status {
                                    case .readyToInstall, .readyToAdopt:
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
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

                    Divider()

                    if store.batchItems.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "list.bullet.clipboard")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)
                            Text("在左侧粘贴包名后将自动在此处展示识别结果")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Text("执行时将自动把 Formula 合并为单条命令统一解析依赖，并将 Cask 逐个排队以便单包跳过与立即可用。")
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
                    onToggleSelect()
                } label: {
                    Image(systemName: item.isSelected ? "checkmark.square.fill" : "square")
                        .foregroundStyle(item.isSelected ? Color.accentColor : .secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(entry.displayName)
                            .font(.body.weight(.medium))
                        if entry.displayName != entry.name {
                            Text("(\(entry.name))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        BadgeView(text: entry.type.rawValue, color: entry.type == .cask ? .purple : .blue)
                        BadgeView(text: "可安装 \(entry.version)", color: .blue)
                        if let sizeBytes = probedSizeBytes, sizeBytes > 0 {
                            let isLarge = sizeBytes >= 100 * 1024 * 1024
                            BadgeView(
                                text: "📦 \(AppConstants.formatBytes(sizeBytes))",
                                color: isLarge ? .orange : .teal
                            )
                        }
                    }
                    if !entry.desc.isEmpty {
                        Text(entry.desc)
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

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(entry.displayName)
                            .font(.body.weight(.medium))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        BadgeView(text: "Cask", color: .purple)
                            .fixedSize()
                        BadgeView(text: "检测到本地 \(localApp)", color: .teal)
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
                        Text(entry.desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button {
                    onToggleAdoptMode()
                } label: {
                    Text(item.useAdoptIfAvailable ? "模式: Adopt 接管" : "模式: 全新安装")
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

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(pkg.displayName)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                        BadgeView(text: pkg.type.rawValue, color: .gray)
                        BadgeView(text: "已安装 (\(pkg.installedVersion ?? ""))，自动跳过", color: .green)
                    }
                }

            case .notFound:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.title3)

                HStack(spacing: 6) {
                    Text(item.rawToken)
                        .font(.body.monospaced().weight(.medium))
                    BadgeView(text: "未找到匹配的 Formula 或 Cask", color: .orange)
                }
            }

            Spacer()
        }
    }
}
