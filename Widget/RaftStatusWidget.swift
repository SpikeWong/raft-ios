import SwiftUI
import WidgetKit

struct RaftWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}
struct RaftWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> RaftWidgetEntry { RaftWidgetEntry(date: Date(), snapshot: .empty) }
    func getSnapshot(in context: Context, completion: @escaping (RaftWidgetEntry) -> Void) {
        completion(RaftWidgetEntry(date: Date(), snapshot: WidgetSnapshotStore.shared.read()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<RaftWidgetEntry>) -> Void) {
        let snapshot = WidgetSnapshotStore.shared.read()
        let now = Date()
        var entries = [RaftWidgetEntry(date: now, snapshot: snapshot)]
        if let updatedAt = snapshot.updatedAt, updatedAt.addingTimeInterval(901) > now {
            entries.append(RaftWidgetEntry(date: updatedAt.addingTimeInterval(901), snapshot: snapshot))
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(30 * 60))))
    }
}
struct RaftWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RaftWidgetEntry
    var body: some View {
        WidgetSummaryView(snapshot: entry.snapshot, date: entry.date, compact: family == .systemSmall)
            .containerBackground(Color(red: 1, green: 212.0/255, blue: 64.0/255), for: .widget)
            .widgetURL(entry.snapshot.link(section: "tasks") ?? URL(string: "raftpersonal://open")!)
    }
}
@main
struct RaftStatusWidget: Widget {
    let kind = "RaftStatusWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RaftWidgetProvider()) { entry in RaftWidgetView(entry: entry) }
            .configurationDisplayName("Raft 任务与通知")
            .description("查看任务进度、未读通知和最近同步状态。")
            .supportedFamilies([.systemSmall, .systemMedium])
            .contentMarginsDisabled()
    }
}
