import SwiftUI

struct WidgetSummaryView: View {
    let snapshot: WidgetSnapshot
    let date: Date
    var compact = false
    private let ink = Color(red: 0.08, green: 0.07, blue: 0.07)
    private let yellow = Color(red: 1, green: 212.0/255, blue: 64.0/255)
    private var status: String {
        switch snapshot.state {
        case .notConfigured: return "打开 App 连接服务器"
        case .syncing: return "等待 App 同步"
        case .loggedOut: return "打开 App 登录"
        case .selectServer: return "打开 App 选择协作空间"
        case .unavailable: return "同步失败 · 打开 App 重试"
        case .ready: return snapshot.isStale(at: date) ? "打开 App 更新" : (snapshot.partial ? "部分任务 · 已同步" : "已同步")
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.square.fill").foregroundStyle(ink)
                Text(snapshot.serverName ?? "Raft").font(.system(size: 14, weight: .black)).lineLimit(1)
                Spacer(minLength: 0)
                Circle().fill(snapshot.state == .ready && !snapshot.isStale(at: date) ? Color.green : Color.gray).frame(width: 6, height: 6)
            }
            if snapshot.state == .ready || snapshot.todo != nil {
                HStack(spacing: compact ? 5 : 10) {
                    metric("待办", snapshot.todo, section: "tasks")
                    metric("进行中", snapshot.inProgress, section: "tasks")
                    metric("待审核", snapshot.inReview, section: "tasks")
                }
                if compact {
                    activityLine
                } else {
                    HStack(spacing: 12) { activityLine; Spacer(minLength: 0); Text("未读消息 \(count(snapshot.unreadMessages))").font(.system(size: 11, weight: .medium)) }
                    if let task = snapshot.tasks.first {
                        Link(destination: snapshot.link(section: "tasks") ?? URL(string: "raftpersonal://open")!) {
                            HStack(spacing: 6) {
                                Image(systemName: task.status == "in_review" ? "eye" : "checklist").font(.system(size: 12))
                                Text("#\(task.number) \(task.title)").font(.system(size: 12, weight: .semibold)).lineLimit(1)
                                Spacer(minLength: 0)
                                Text(taskLabel(task.status)).font(.system(size: 10, weight: .bold)).padding(.horizontal, 5).padding(.vertical, 3).background(.white.opacity(0.65))
                            }.privacySensitive()
                        }
                    } else { Text("暂无未完成任务").font(.system(size: 12)).foregroundStyle(ink.opacity(0.65)) }
                }
            } else {
                Spacer(minLength: 0)
                Text(status).font(.system(size: compact ? 14 : 16, weight: .bold))
                Text("任务与通知会随 App 同步").font(.system(size: 11)).foregroundStyle(ink.opacity(0.65))
                Spacer(minLength: 0)
            }
            HStack(spacing: 4) {
                Text(status).lineLimit(1)
                Spacer(minLength: 0)
                if let updatedAt = snapshot.updatedAt { Text(updatedAt, style: .time).monospacedDigit() }
            }.font(.system(size: 9, weight: .medium)).foregroundStyle(ink.opacity(0.65))
        }.foregroundStyle(ink).padding(compact ? 12 : 14).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).background(yellow)
    }
    private var activityLine: some View {
        Link(destination: snapshot.link(section: "activity") ?? URL(string: "raftpersonal://open")!) {
            Label("通知 \(count(snapshot.unreadActivity))", systemImage: "bell").font(.system(size: 11, weight: .semibold))
        }
    }
    private func count(_ value: Int?) -> String { value.map { $0 > 999 ? "999+" : "\($0)" } ?? "—" }
    private func taskCount(_ value: Int?) -> String {
        guard let value else { return "—" }
        return value > 999 ? "999+" : "\(value)" + (snapshot.partial ? "+" : "")
    }
    private func metric(_ label: String, _ value: Int?, section: String) -> some View {
        Link(destination: snapshot.link(section: section) ?? URL(string: "raftpersonal://open")!) {
            VStack(alignment: .leading, spacing: 2) {
                Text(taskCount(value)).font(.system(size: compact ? (taskCount(value).count > 2 ? 14 : 20) : 23, weight: .black, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1).frame(height: compact ? 24 : 28, alignment: .leading)
                Text(label).font(.system(size: 9, weight: .semibold)).lineLimit(1)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 5).padding(.horizontal, compact ? 5 : 8).background(.white.opacity(0.7)).overlay(Rectangle().strokeBorder(ink, lineWidth: 1.5))
        }
    }
    private func taskLabel(_ status: String) -> String {
        switch status { case "todo": return "待办"; case "in_progress": return "进行中"; case "in_review": return "待审核"; default: return "已完成" }
    }
}
