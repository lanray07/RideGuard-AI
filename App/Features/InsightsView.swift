import SwiftUI
import RideGuardCore

struct InsightsView: View {
    @Environment(RideStore.self) private var store
    private var rides: [RideSession] { store.snapshot.history.filter { $0.route.isDemo == store.demoMode } }
    var body: some View {
        List {
            Section {
                Text("Your everyday\njourneys, understood.").font(.largeTitle.bold()).padding(.vertical, 12)
                if store.demoMode { DemoBadge() }
            }
            if rides.isEmpty {
                ContentUnavailableView("Your story starts with a ride", systemImage: "bicycle", description: Text("Complete a ride to see your recorded distance, reports and personal route feedback."))
            } else {
                Section("Recorded on this device") {
                    LabeledContent("Completed rides", value: String(rides.count))
                    LabeledContent("Recorded distance", value: rides.reduce(0) { $0 + $1.travelledMetres }.milesText)
                    LabeledContent("Reports saved during rides", value: String(rides.reduce(0) { $0 + $1.reportCount }))
                    Text("Infrastructure coverage and encountered hazards are not calculated without supporting data.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Ride history") {
                    ForEach(rides) { ride in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(ride.route.destination).font(.headline)
                            Text("\(ride.startedAt.formatted(date: .abbreviated, time: .shortened)) · \(ride.travelledMetres.milesText)").font(.subheadline).foregroundStyle(.secondary)
                            if let feedback = store.snapshot.feedback[ride.id.uuidString] { Text(L10n.format("Your comfort: %@", L10n.text(feedback))).font(.caption) }
                        }.padding(.vertical, 4).swipeActions { Button("Delete", role: .destructive) { store.snapshot.history.removeAll { $0.id == ride.id }; store.snapshot.feedback.removeValue(forKey: ride.id.uuidString); store.persist() } }
                    }
                }
            }
        }.navigationTitle("Riding insights")
    }
}
