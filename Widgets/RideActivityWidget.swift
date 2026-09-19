import SwiftUI
import WidgetKit
import ActivityKit

@main
struct RideActivityBundle: WidgetBundle {
    var body: some Widget { RideActivityWidget() }
}
struct RideActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RideActivityAttributes.self) { context in
            HStack(spacing: 16) {
                Image(systemName: "bicycle").font(.largeTitle).foregroundStyle(.mint)
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(context.attributes.isDemo ? "RIDEGUARD · DEMO" : "RIDEGUARD")).font(.caption2.bold())
                    Text(context.attributes.destination).font(.headline)
                    Text(L10n.text(context.isStale ? "Update stale · open RideGuard" : context.state.status)).font(.caption)
                }
                Spacer()
                VStack { Text("ETA").font(.caption2); Text(context.state.arrival, style: .time).font(.title3.bold()) }
            }.padding().activityBackgroundTint(.black.opacity(0.9)).activitySystemActionForegroundColor(.white).foregroundStyle(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Image(systemName: "bicycle").foregroundStyle(.mint) }
                DynamicIslandExpandedRegion(.trailing) { Text(context.state.arrival, style: .time) }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.attributes.isDemo ? L10n.text("Demo · ") : "")\(context.attributes.destination) · \(L10n.text(context.isStale ? "Update stale" : context.state.status))").font(.caption)
                }
            } compactLeading: { Image(systemName: "bicycle").foregroundStyle(.mint) }
            compactTrailing: { Text(context.state.arrival, style: .time).font(.caption2) }
            minimal: { Image(systemName: "bicycle").foregroundStyle(.mint) }
        }
    }
}
