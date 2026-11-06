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
                        Text("终端输出与任务队列")
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
                    Text("空闲")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !store.taskQueue.isEmpty {
                    BadgeView(text: "排队中: \(store.taskQueue.count)", color: .orange)
                }

                Spacer()

                // Active Task Controls: Skip Current & Stop All
                if let current = store.currentTask, current.status == .running {
                    if !store.taskQueue.isEmpty {
                        Button {
                            store.skipCurrentTask()
                        } label: {
                            Label("跳过当前包", systemImage: "forward.end.fill")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        .controlSize(.mini)
                        .help("终止当前卡住的包并立即开始队列中的下一个任务")
                    }

                    Button(role: .destructive) {
                        store.stopAllTasks()
                    } label: {
                        Label(store.taskQueue.isEmpty ? "停止" : "停止全部", systemImage: "stop.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.mini)
                    .help("立即终止当前运行的 brew / curl 进程并清空等待队列")
                } else if !store.lastFailedOrSkippedTasks.isEmpty
                            || (store.currentTask?.status == .failed || store.currentTask?.status == .cancelled || store.currentTask?.status == .skipped) {
                    Button {
                        store.retryFailedOrSkippedTasks()
                    } label: {
                        let count = max(1, store.lastFailedOrSkippedTasks.count)
                        Label(count > 1 ? "重试未完成项 (\(count))" : "重试", systemImage: "arrow.clockwise")
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
                        Label("清空日志", systemImage: "trash")
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
                    Text(store.isTerminalDrawerExpanded ? "收起" : "展开")
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
                            Text("等待队列 (\(store.taskQueue.count)):")
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
                                    .help("从等待队列中移除此任务")
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
                            Text(store.terminalLog.isEmpty ? "暂无命令执行输出。执行 update / upgrade / install / adopt / cleanup 时将在此实时流式展示终端输出。" : store.terminalLog)
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
