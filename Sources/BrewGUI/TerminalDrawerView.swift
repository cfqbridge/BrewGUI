import SwiftUI

public struct TerminalDrawerView: View {
    @ObservedObject var store: BrewStore

    public init(store: BrewStore) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Outcome Feedback Banner (shown when a task or batch finishes)
            if !store.isProcessingQueue, let feedback = store.latestOutcomeFeedback {
                Divider()
                outcomeFeedbackBanner(feedback)
            }

            Divider()

            // Compact Activity & Status Footer Bar
            HStack(spacing: 10) {
                if let current = store.currentTask, current.status == .running {
                    ProgressView()
                        .controlSize(.small)

                    Text(current.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)

                    if let dl = store.activeDownloadInfo {
                        HStack(spacing: 8) {
                            if let frac = dl.progressFraction {
                                ProgressView(value: frac)
                                    .controlSize(.small)
                                    .frame(width: 84)
                            }
                            BadgeView(text: "⬇︎ \(dl.formattedSummary)", color: .blue)
                        }
                    } else {
                        Text(tr("正在处理中…", "正在處理中…", "Processing…"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !store.taskQueue.isEmpty {
                        BadgeView(
                            text: tr("后续排队 \(store.taskQueue.count) 项", "後續排隊 \(store.taskQueue.count) 項", "\(store.taskQueue.count) queued"),
                            color: .orange
                        )
                    }
                } else if store.isProcessingQueue {
                    ProgressView()
                        .controlSize(.small)
                    Text(tr("正在刷新软件状态…", "正在重新整理軟體狀態…", "Refreshing package status…"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !store.taskQueue.isEmpty {
                        BadgeView(
                            text: tr("后续排队 \(store.taskQueue.count) 项", "後續排隊 \(store.taskQueue.count) 項", "\(store.taskQueue.count) queued"),
                            color: .orange
                        )
                    }
                } else {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green.opacity(0.75))
                            .frame(width: 7, height: 7)
                        Text(
                            store.installedPackages.isEmpty
                                ? tr("就绪", "就緒", "Ready")
                                : tr(
                                    "就绪 · 已纳管 \(store.installedPackages.filter(\.isTopLevel).count) 款软件",
                                    "就緒 · 已納管 \(store.installedPackages.filter(\.isTopLevel).count) 款軟體",
                                    "Ready · Managing \(store.installedPackages.filter(\.isTopLevel).count) packages"
                                )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Active Task Controls: Skip Current & Stop All
                if let current = store.currentTask, current.status == .running {
                    if !store.taskQueue.isEmpty {
                        Button {
                            store.skipCurrentTask()
                        } label: {
                            Label(tr("跳过当前项", "略過目前項", "Skip"), systemImage: "forward.end.fill")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        .controlSize(.mini)
                        .help(tr("跳过当前软件并继续队列中的下一项", "略過目前軟體並繼續佇列中的下一項", "Skip current item and continue with next"))
                    }

                    Button(role: .destructive) {
                        store.stopAllTasks()
                    } label: {
                        Label(
                            store.taskQueue.isEmpty ? tr("停止", "停止", "Stop") : tr("停止全部", "停止全部", "Stop All"),
                            systemImage: "stop.fill"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.mini)
                } else if !store.lastFailedOrSkippedTasks.isEmpty && store.latestOutcomeFeedback == nil {
                    Button {
                        store.retryFailedOrSkippedTasks()
                    } label: {
                        let count = max(1, store.lastFailedOrSkippedTasks.count)
                        Label(
                            count > 1
                                ? tr("重试未完成项 (\(count))", "重試未完成項 (\(count))", "Retry (\(count))")
                                : tr("重试", "重試", "Retry"),
                            systemImage: "arrow.clockwise"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .controlSize(.mini)
                }

                if store.isTerminalDrawerExpanded {
                    Button {
                        store.clearTerminalLog()
                    } label: {
                        Label(tr("清空日志", "清空日誌", "Clear"), systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        store.isTerminalDrawerExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "terminal")
                            .font(.caption2)
                        Text(
                            store.isTerminalDrawerExpanded
                                ? tr("收起控制台", "收起控制台", "Hide Console")
                                : tr("控制台日志", "控制台日誌", "Console Log")
                        )
                        .font(.caption)
                        Image(systemName: store.isTerminalDrawerExpanded ? "chevron.down" : "chevron.up")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .help(tr("查看或隐藏底层命令详细输出与排队列表", "檢視或隱藏底層命令詳細輸出與排隊列表", "Toggle detailed background command output"))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color(nsColor: .windowBackgroundColor))

            // Secondary Expandable Console Output (Hidden by default)
            if store.isTerminalDrawerExpanded {
                Divider()

                if !store.taskQueue.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Text("\(tr("等待队列", "等待佇列", "Pending Queue")) (\(store.taskQueue.count)):")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(store.taskQueue) { item in
                                HStack(spacing: 4) {
                                    Text(item.title)
                                        .font(.caption2)
                                        .lineLimit(1)
                                    Button {
                                        store.removeQueuedTask(id: item.id)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help(tr("从队列中移除", "從佇列中移除", "Remove from queue"))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                    }
                    .background(Color(nsColor: .windowBackgroundColor).opacity(0.7))

                    Divider()
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(
                                store.terminalLog.isEmpty
                                    ? tr(
                                        "暂无后台命令输出。所有安装、更新与清理任务的详细日志均会记录在此。",
                                        "暫無背景命令輸出。所有安裝、更新與清理任務的詳細日誌均會記錄在此。",
                                        "No background command output yet. Detailed logs appear here."
                                    )
                                    : store.terminalLog
                            )
                            .font(.system(size: 11.5, design: .monospaced))
                            .foregroundStyle(store.terminalLog.isEmpty ? .secondary : .primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)

                            Color.clear
                                .frame(height: 1)
                                .id("BOTTOM_ANCHOR")
                        }
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                    .frame(height: 190)
                    .onChange(of: store.terminalLog) { _, _ in
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo("BOTTOM_ANCHOR", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func outcomeFeedbackBanner(_ feedback: TaskOutcomeFeedback) -> some View {
        let accentColor: Color = feedback.isSuccess ? .green : .orange
        HStack(spacing: 12) {
            Image(systemName: feedback.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(feedback.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                if let sub = feedback.subtitle, !sub.isEmpty {
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let primary = feedback.primaryAction {
                Button {
                    store.performOutcomeAction(primary)
                } label: {
                    outcomeActionLabel(primary)
                }
                .buttonStyle(.borderedProminent)
                .tint(feedback.isSuccess ? .accentColor : .orange)
                .controlSize(.small)
            }

            if let secondary = feedback.secondaryAction {
                Button {
                    store.performOutcomeAction(secondary)
                } label: {
                    outcomeActionLabel(secondary)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    store.latestOutcomeFeedback = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .help(tr("关闭提示", "關閉提示", "Dismiss"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(accentColor.opacity(0.11))
    }

    @ViewBuilder
    private func outcomeActionLabel(_ action: TaskOutcomeAction) -> some View {
        switch action {
        case .openApp(_, let name):
            Label(tr("打开 \(name)", "打開 \(name)", "Open \(name)"), systemImage: "play.fill")
        case .switchMirrorAndRetry:
            Label(tr("切至国内镜像并重试", "切至國內鏡像並重試", "Switch Mirror & Retry"), systemImage: "bolt.horizontal.fill")
        case .retryTasks:
            Label(tr("立即重试", "立即重試", "Retry Now"), systemImage: "arrow.clockwise")
        case .openTerminalLog:
            Label(tr("查看日志", "檢視日誌", "View Log"), systemImage: "terminal")
        case .openAppManagementSettings:
            Label(tr("开启权限", "開啟權限", "Grant Permission"), systemImage: "lock.open.fill")
        }
    }
}
