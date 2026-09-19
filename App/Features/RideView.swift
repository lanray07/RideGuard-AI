import SwiftUI
import RideGuardCore

struct RideView: View {
    @Environment(RideStore.self) private var store
    @State private var endConfirmation = false
    @State private var emergency = false
    @State private var sharing = false
    @State private var showVoice = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let ride = store.activeRide {
                    active(ride)
                } else if let completed = store.lastCompleted {
                    summary(completed)
                } else {
                    preparation
                }
                Button { emergency = true } label: { Label("Emergency options", systemImage: "cross.case") }.frame(maxWidth: .infinity).padding(12)
                if let notice = store.notice { Text(L10n.text(notice)).font(.subheadline).foregroundStyle(.secondary) }
            }.padding(22).frame(maxWidth: 760)
        }.frame(maxWidth: .infinity).background(RG.canvas).navigationTitle("Your ride").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $emergency) { NavigationStack { EmergencyView() } }
            .sheet(isPresented: $sharing) { NavigationStack { SharingView() } }
            .sheet(isPresented: $showVoice) { NavigationStack { VoiceSettingsView() } }
            .confirmationDialog("End this ride?", isPresented: $endConfirmation, titleVisibility: .visible) {
                Button("End ride") { store.apply(.end) }
                Button("Keep riding", role: .cancel) {}
            } message: { Text("Location tracking and ride reminders will stop. No contact message is sent automatically.") }
            .task {
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(15)) } catch { return }
                    store.tick()
                }
            }
    }
    private var preparation: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Prepare your bike ride.").font(.largeTitle.bold())
            if let route = store.selectedRoute {
                if route.isDemo { DemoBadge() }
                RouteMap(routes: [route], reports: store.reports).frame(height: 240).clipShape(RoundedRectangle(cornerRadius: 24))
                Panel {
                    VStack(alignment: .leading, spacing: 16) {
                        InfoRow(symbol: "flag.checkered", title: route.destination, subtitle: "\(Int(route.duration / 60)) min · \(route.distance.milesText)", verbatimTitle: true)
                        Divider()
                        InfoRow(symbol: "person.crop.circle.badge.checkmark", title: "Only you can see this ride", subtitle: "Live location sharing is not connected. No trusted contact is being notified.")
                        Button("Sharing & check-in options") { sharing = true }
                    }
                }
                Panel { InfoRow(symbol: "waveform", title: "Eyes on the road. Hands on the bike.", subtitle: "Set up Siri shortcuts before riding. Alerts use short spoken updates.") }
                Button("Voice & audio settings") { showVoice = true }
                Button { store.startRide() } label: { Label(LocalizedStringKey(route.isDemo ? "Start demo ride" : "Start ride"), systemImage: "bicycle") }.buttonStyle(PrimaryButtonStyle())
                Text(LocalizedStringKey(route.isDemo ? "A simulation for exploring the controls. It does not guide a real journey." : "Location tracking continues during this ride, including while the screen is locked. End the ride to stop it. Turn-by-turn guidance is not available in this build.")).font(.caption).foregroundStyle(.secondary)
            } else {
                ContentUnavailableView("Choose a destination", systemImage: "map", description: Text("Plan a cycling route in Explore before starting."))
                Button("Plan a ride") { store.selectedTab = 0 }.buttonStyle(PrimaryButtonStyle())
            }
        }
    }
    @ViewBuilder private func active(_ ride: RideSession) -> some View {
        if ride.route.isDemo { DemoBadge() }
        HStack { Label(LocalizedStringKey(ride.status == .overdue ? "CHECK-IN DUE" : ride.status == .arrived ? "NEAR DESTINATION" : "RIDE IN PROGRESS"), systemImage: "circle.fill").font(.caption.weight(.bold)).tracking(1).foregroundStyle(RG.green); Spacer(); Image(systemName: "waveform").foregroundStyle(RG.green) }
        Text(ride.route.destination).font(.largeTitle.bold())
        Panel {
            VStack(alignment: .leading, spacing: 16) {
                Eyebrow(text: "Estimated arrival")
                Text(ride.expectedArrival, style: .time).font(.system(size: 58, weight: .bold, design: .rounded)).minimumScaleFactor(0.6)
                Text(L10n.format("Last update %@", ride.lastUpdate.formatted(date: .omitted, time: .shortened))).font(.caption).foregroundStyle(.secondary)
                Label("Sharing off", systemImage: "lock.shield").font(.subheadline)
            }
        }
        if ride.status == .overdue {
            Panel { InfoRow(symbol: "clock", title: "Everything okay?", subtitle: "Your ride is taking longer than expected. No accident is inferred and no contact has been notified.") }
        }
        if ride.status == .arrived {
            Panel { InfoRow(symbol: "mappin.circle", title: "Looks like you’ve arrived.", subtitle: "Check in or end your ride when you’re ready.") }
        }
        Button { store.voice.say(store.whatsAhead(), enabled: store.voiceEnabled); store.notice = store.whatsAhead() } label: { Label("What’s ahead?", systemImage: "waveform") }.buttonStyle(PrimaryButtonStyle())
        HStack {
            Button("I’m OK") { store.apply(.imOkay) }.buttonStyle(.bordered).controlSize(.large)
            Button("+15 minutes") { store.apply(.moreTime(900)) }.buttonStyle(.bordered).controlSize(.large)
        }.frame(maxWidth: .infinity)
        Button("Check-in options") { sharing = true }.buttonStyle(.bordered).controlSize(.large).frame(maxWidth: .infinity)
        Button("Resume updates") { store.resumeRide() }.font(.subheadline).frame(maxWidth: .infinity)
        Button("End ride") { endConfirmation = true }.font(.headline).frame(maxWidth: .infinity).padding(16).background(.quaternary, in: RoundedRectangle(cornerRadius: 18))
        Text("Use voice shortcuts or stop before interacting with the screen.").font(.caption).foregroundStyle(.secondary)
    }
    @ViewBuilder private func summary(_ ride: RideSession) -> some View {
        Image(systemName: "checkmark.circle.fill").font(.system(size: 52)).foregroundStyle(RG.green)
        Text("One more journey.\nA little more insight.").font(.largeTitle.bold())
        if ride.route.isDemo { DemoBadge() }
        Panel {
            VStack(spacing: 16) {
                LabeledContent("Ride duration", value: "\(max(0, Int((ride.endedAt ?? .now).timeIntervalSince(ride.startedAt) / 60))) min")
                LabeledContent("Recorded distance", value: ride.travelledMetres.milesText)
                LabeledContent("Reports saved", value: String(ride.reportCount))
                LabeledContent("Check-in delivery", value: L10n.text("Not verified"))
            }
        }
        Text("How did this route feel?").font(.headline)
        ForEach(["Very comfortable", "Comfortable", "Mixed", "Uncomfortable"], id: \.self) { response in
            Button { store.snapshot.feedback[ride.id.uuidString] = response; store.persist() } label: {
                HStack { Text(L10n.text(response)); Spacer(); if store.snapshot.feedback[ride.id.uuidString] == response { Image(systemName: "checkmark") } }.padding(12)
            }.buttonStyle(.bordered)
        }
        Text("Comfort is your personal experience, separate from measured route factors.").font(.caption).foregroundStyle(.secondary)
        Button("Plan another ride") { store.lastCompleted = nil; store.selectedTab = 0 }.buttonStyle(PrimaryButtonStyle())
    }
}

struct SharingView: View {
    @Environment(RideStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            Section {
                InfoRow(symbol: "lock.shield", title: "You control what leaves your phone", subtitle: "Secure live location links and automatic contact messages are not connected. No one can follow this ride through RideGuard.")
            }
            if let ride = store.activeRide {
                Section("Send a status yourself") {
                    Text("Review the recipient and message in the system share sheet. RideGuard cannot verify delivery.").font(.subheadline)
                    ShareLink(item: L10n.format(ride.route.isDemo ? "RideGuard demo: I’m riding to %@. Estimated arrival: %@. This is a status message, not live tracking." : "I’m riding to %@. Estimated arrival: %@. This is a status message, not live tracking.", ride.route.destination, ride.expectedArrival.formatted(date: .omitted, time: .shortened))) { Label("Share ride status…", systemImage: "square.and.arrow.up") }
                    ShareLink(item: L10n.format(ride.route.isDemo ? "RideGuard demo: I’m checking in at %@." : "I’m checking in at %@.", Date.now.formatted(date: .omitted, time: .shortened))) { Label("Share a check-in…", systemImage: "checkmark.message") }
                }
            }
            Section("Trusted people · saved locally") {
                if store.snapshot.contacts.isEmpty { Text("Add a trusted person in You → Trusted contacts.") }
                ForEach(store.snapshot.contacts) { contact in InfoRow(symbol: "person.circle", title: contact.name, subtitle: "No automatic messages enabled", verbatimTitle: true) }
            }
        }.navigationTitle("Stay connected").toolbar { Button("Done") { dismiss() } }
    }
}

struct EmergencyView: View {
    @Environment(RideStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            Section {
                Text("If you need urgent help").font(.title.bold())
                Text("Use your iPhone’s Emergency SOS or the Phone app to call your local emergency number. RideGuard is not an emergency-response service.")
                Text("On supported iPhones, hold the side button and a volume button to access Emergency SOS and Medical ID. Device settings may change this behaviour.").font(.subheadline).foregroundStyle(.secondary)
            }
            Section("Trusted people") {
                ForEach(store.snapshot.contacts) { contact in
                    if let url = URL(string: "tel:\(contact.phone.filter { $0.isNumber || $0 == "+" })") {
                        Link(destination: url) { Label(L10n.format("Call %@", contact.name), systemImage: "phone.fill") }
                    }
                }
                if store.snapshot.contacts.isEmpty { Text("No trusted contacts saved.") }
            }
            if let coordinate = store.location.recentCoordinate {
                ShareLink(item: L10n.format("My current location: %@", "https://maps.apple.com/?ll=\(coordinate.latitude),\(coordinate.longitude)")) { Label("Share current location…", systemImage: "location.fill") }
                Text("This message contains a precise location. Choose the recipient in the share sheet.").font(.caption)
            }
        }.navigationTitle("Emergency options").toolbar { Button("Done") { dismiss() } }
    }
}
