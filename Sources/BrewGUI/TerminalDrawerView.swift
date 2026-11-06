import SwiftUI

public struct TerminalDrawerView: View {
    @ObservedObject var store: BrewStore

    public init(store: BrewStore) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            Divider()

            // Status Header Bar (Always Visible)
            HStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.isTerminalDrawerExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: store.isTerminalDrawerExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.bold))
                        Image(systemName: "terminal")
                            .font(.callout)
                        Text(tr("终端输出与任务队列", "終端機輸出與任務佇列", "Terminal & Task Queue"))
                            .font(.callout.weight(.medium))
                    }
                }
                .buttonStyle(.plain)

                if let current = store.currentTask {
                    Divider()
                        .frame(height: 14)

                    HStack(spacing: 6) {
                        switch current.status {
                        case .running:
                            ProgressView()
                                .controlSize(.small)
                        case .succeeded:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        case .failed:
                            Image(systemName: "xmark.octagon.fill")
                                .foregroundStyle(.red)
                        case .cancelled:
                            Image(systemName: "stop.circle.fill")
                                .foregroundStyle(.orange)
                        case .skipped:
                            Image(systemName: "forward.end.fill")
                                .foregroundStyle(.orange)
                        case .queued:
                            Image(systemName: "clock")
                                .foregroundStyle(.secondary)
                        }

                        Text(current.title)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)

                        if let dl = store.activeDownloadInfo, current.status == .running {
                            HStack(spacing: 6) {
                                BadgeView(text: "⬇︎ \(dl.formattedSummary)", color: .blue)
                                if let frac = dl.progressFraction {
                                    ProgressView(value: frac)
                                        .controlSize(.small)
                                        .frame(width: 72)
                                }
                            }
                        } else {
                            Text("(\(current.commandDescription))")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                } else {
                    Text(tr("空闲", "閒置", "Idle"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !store.taskQueue.isEmpty {
                    BadgeView(text: "\(tr("排队中", "排隊中", "Queued")): \(store.taskQueue.count)", color: .orange)
                }

                Spacer()

                // Active Task Controls: Skip Current & Stop All
                if let current = store.currentTask, current.status == .running {
                    if !store.taskQueue.isEmpty {
                        Button {
                            store.skipCurrentTask()
                        } label: {
                            Label(tr("跳过当前包", "略過目前套件", "Skip Current"), systemImage: "forward.end.fill")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        .controlSize(.mini)
                        .help(tr("终止当前卡住的包并立即开始队列中的下一个任务", "終止目前卡住的套件並立即開始佇列中的下一個任務", "Skip the current task and move to the next queued item"))
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
                    .help(tr("立即终止当前运行的 brew / curl 进程并清空等待队列", "立即終止目前執行的 brew / curl 程序並清空等待佇列", "Terminate running brew/curl processes and clear the queue"))
                } else if !store.lastFailedOrSkippedTasks.isEmpty
                            || (store.currentTask?.status == .failed || store.currentTask?.status == .cancelled || store.currentTask?.status == .skipped) {
                    Button {
                        store.retryFailedOrSkippedTasks()
                    } label: {
                        let count = max(1, store.lastFailedOrSkippedTasks.count)
                        Label(
                            count > 1
                                ? tr("重试未完成项 (\(count))", "重試未完成項 (\(count))", "Retry Incomplete (\(count))")
                                : tr("重试", "重試", "Retry"),
                            systemImage: "arrow.clockwise"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.mini)
                }

                if store.isTerminalDrawerExpanded {
                    Button {
                        store.clearTerminalLog()
                    } label: {
                        Label(tr("清空日志", "清空日誌", "Clear Log"), systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.isTerminalDrawerExpanded.toggle()
                    }
                } label: {
                    Text(store.isTerminalDrawerExpanded ? tr("收起", "收起", "Collapse") : tr("展开", "展開", "Expand"))
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color(nsColor: .windowBackgroundColor))

            // Expandable Terminal Output Area
            if store.isTerminalDrawerExpanded {
                Divider()

                // Queued Tasks Strip (allows removing individual queued items)
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
                                    .help(tr("从等待队列中移除此任务", "從等待佇列中移除此任務", "Remove this task from queue"))
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
                                        "暂无命令执行输出。执行 update / upgrade / install / adopt / cleanup 时将在此实时流式展示终端输出。",
                                        "暫無命令執行輸出。執行 update / upgrade / install / adopt / cleanup 時將在此即時展示終端機輸出。",
                                        "No terminal output yet. Real-time streaming output from update / upgrade / install / adopt / cleanup will appear here."
                                    )
                                    : store.terminalLog
                            )
                            .font(.system(size: 12, design: .monospaced))
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
                    .frame(height: 200)
                    .onChange(of: store.terminalLog) { _, _ in
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo("BOTTOM_ANCHOR", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
}
