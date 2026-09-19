import SwiftUI
import RideGuardCore

struct SettingsView: View {
    @Environment(RideStore.self) private var store
    @State private var deleteConfirmation = false
    @State private var exportURL: URL?
    var body: some View {
        @Bindable var store = store
        List {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.fill").font(.system(size: 44)).foregroundStyle(RG.green)
                    VStack(alignment: .leading, spacing: 4) { Text("Your everyday ride.").font(.title3.bold()); Text("Guest · on this device").font(.subheadline).foregroundStyle(.secondary) }
                }.padding(.vertical, 10)
                Toggle("Explore with demo data", isOn: Binding(get: { store.demoMode }, set: { store.changeMode($0) })).disabled(store.activeRide != nil)
                Text("Demo routes, scores and reports are illustrative. End your ride before switching modes.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Ride") {
                NavigationLink { VoiceSettingsView() } label: { Label("Voice & audio", systemImage: "waveform") }
                NavigationLink { ContactsView() } label: { Label("Trusted contacts", systemImage: "person.2") }
                NavigationLink { SavedPlacesView() } label: { Label("Saved places", systemImage: "bookmark") }
                Stepper("Check-in grace: \(store.snapshot.graceMinutes) min", value: $store.snapshot.graceMinutes, in: 5...60, step: 5)
                    .onChange(of: store.snapshot.graceMinutes) { _, _ in store.persist() }
                Text("Applies to new rides. A local reminder asks you to check in; it does not notify a trusted person.").font(.caption).foregroundStyle(.secondary)
            }
            Section {
                NavigationLink { PaywallView() } label: { InfoRow(symbol: "sparkles", title: "RideGuard Pro", subtitle: "More information for your everyday journeys") }
            }
            Section("Privacy & data") {
                NavigationLink("Privacy details") { PolicyView(kind: .privacy) }
                Button("Prepare data export") {
                    Task {
                        do { try await PrivacyUnlock.authenticate(); exportURL = try store.exportData() }
                        catch { store.error = error.localizedDescription }
                    }
                }
                if let exportURL { ShareLink("Share export…", item: exportURL) }
                Button("Delete all local data", role: .destructive) { deleteConfirmation = true }
                Text("No analytics, cloud account, microphone capture or third-party AI service is enabled. Local records remain until you delete them. System backups may retain copies according to your device settings.").font(.caption).foregroundStyle(.secondary)
            }
            Section("About") {
                NavigationLink("Data sources & limitations") { PolicyView(kind: .sources) }
                NavigationLink("Terms") { PolicyView(kind: .terms) }
                Text("RideGuard AI · Version 1.0").font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("Made for your ride").confirmationDialog("Delete all local data?", isPresented: $deleteConfirmation, titleVisibility: .visible) {
            Button("Delete history, reports and contacts", role: .destructive) {
                if let exportURL { try? FileManager.default.removeItem(at: exportURL); self.exportURL = nil }
                store.deleteAll()
            }
        } message: { Text("This ends an active ride and removes local records. Copies you exported or sent to others cannot be recalled.") }
    }
}

struct VoiceSettingsView: View {
    @Environment(RideStore.self) private var store
    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                Text("Cycling voice shortcuts.").font(.title.bold())
                Text("Enable RideGuard actions in the Shortcuts app, then invoke them with Siri. Supported wording and locked-device behaviour depend on Siri and your device settings.").font(.subheadline)
            }
            Section("Audio") {
                Toggle("Voice guidance", isOn: $store.snapshot.voice.enabled)
                Toggle("Hazard alerts", isOn: $store.snapshot.voice.hazards)
                Toggle("Check-in prompts", isOn: $store.snapshot.voice.checkIns)
                Toggle("Report confirmation", isOn: $store.snapshot.voice.confirmations)
                Text("Volume is controlled by your iPhone. Turn-by-turn navigation speech is not available yet.").font(.caption).foregroundStyle(.secondary)
                Button("Test spoken guidance") { store.voice.say("Reported roadworks ahead. This is an audio test.", enabled: store.voiceEnabled) }
            }
            Section("Available shortcuts") {
                Label("Report a hazard", systemImage: "mappin.and.ellipse")
                Label("What’s ahead?", systemImage: "waveform")
                Label("What’s my ETA?", systemImage: "clock")
                Label("I’m okay", systemImage: "checkmark.circle")
                Label("End my ride · confirmation required", systemImage: "stop.circle")
            }
            Section("Voice privacy") {
                Text("RideGuard synthesises spoken responses on your device. It does not record raw audio, save transcripts or send language to an AI service. Siri’s own processing and privacy settings are managed by Apple.")
            }
        }.navigationTitle("Voice & audio").onDisappear { store.persist(); if !store.voiceEnabled { store.voice.stop() } }
    }
}

struct ContactsView: View {
    @Environment(RideStore.self) private var store
    @State private var name = ""
    @State private var phone = ""
    var body: some View {
        List {
            Section {
                Text("Saved on this device for quick access. Adding someone does not send an invitation or enable location sharing.").font(.subheadline)
                ForEach(store.snapshot.contacts) { contact in InfoRow(symbol: "person.circle", title: contact.name, subtitle: contact.phone, verbatimTitle: true, verbatimSubtitle: true) }
                    .onDelete { store.snapshot.contacts.remove(atOffsets: $0); store.persist() }
            }
            Section("Add a trusted person") {
                TextField("Name", text: $name).textContentType(.name)
                TextField("Phone number", text: $phone).keyboardType(.phonePad).textContentType(.telephoneNumber)
                Button("Save contact") {
                    store.snapshot.contacts.append(TrustedContact(name: name.trimmingCharacters(in: .whitespaces), phone: phone))
                    store.persist(); name = ""; phone = ""
                }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || phone.filter(\.isNumber).count < 5)
            }
        }.navigationTitle("Trusted contacts")
    }
}

struct SavedPlacesView: View {
    @Environment(RideStore.self) private var store
    @State private var label = "Home"
    @State private var query = ""
    var body: some View {
        List {
            ForEach(store.snapshot.destinations) { destination in InfoRow(symbol: "mappin", title: destination.label, subtitle: destination.query, verbatimSubtitle: true) }
                .onDelete { store.snapshot.destinations.remove(atOffsets: $0); store.persist() }
            Section("Save a place") {
                Picker("Shortcut", selection: $label) { ForEach(["Home", "Work", "Saved"], id: \.self) { Text(LocalizedStringKey($0)) } }
                TextField("Address or place", text: $query)
                Button("Save place") {
                    store.snapshot.destinations.removeAll { $0.label == label }
                    store.snapshot.destinations.append(SavedDestination(label: label, query: query)); store.persist(); query = ""
                }.disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.navigationTitle("Saved places")
    }
}

struct PolicyView: View {
    enum Kind { case privacy, terms, sources }
    let kind: Kind
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(LocalizedStringKey(title)).font(.largeTitle.bold())
                Text(LocalizedStringKey(copy)).font(.body).textSelection(.enabled)
            }.padding(24).frame(maxWidth: 720)
        }.navigationTitle(LocalizedStringKey(title)).navigationBarTitleDisplayMode(.inline)
    }
    private var title: String { switch kind { case .privacy: "Your location is personal."; case .terms: "Development terms"; case .sources: "Behind the information" } }
    private var copy: String {
        switch kind {
        case .privacy:
            "Planning requests use a location you authorise. Map search and directions communicate with Apple. Active ride tracking runs until you end the ride, including background updates. No trusted contact receives your location automatically.\n\nRide history, reports, contacts and preferences stay in SwiftData on this device. This development build has no account, analytics, remote AI, community upload or live sharing service. RideGuard does not retain audio or transcripts. Siri is governed by Apple’s settings and policies.\n\nYou can delete individual rides or reports, export your records, or delete all local data. Records are retained until deletion; system backups and exported copies are outside these controls. Exports contain sensitive locations. A system share sheet sends only the content you choose.\n\nOperator: O. Bankole. Privacy policy: https://github.com/lanray07/RideGuard-AI/blob/main/docs/privacy.md. Support: https://github.com/lanray07/RideGuard-AI/issues."
        case .terms:
            "RideGuard provides contextual information, not a guarantee of safety, crash detection or emergency response. Risk indicators are experimental, not calibrated collision probabilities. Reports may be incomplete, stale or inaccurate. Follow applicable road rules and use your judgement.\n\nDo not use demo routes for navigation. Interact with detailed screens only when stationary. Configure voice actions before riding.\n\nThis is a development preview. Cloud sharing, automated contact escalation and community publication are unavailable. No message is described as delivered without provider confirmation.\n\nProduction subscription terms, operator identity, support contact and privacy URLs must be configured before sale."
        case .sources:
            "Apple MapKit: destination search, cycling route geometry and estimated travel time where supported. Attribution stays visible on the map. Cycling route requests require iOS 26 and service coverage. Apple route data alone is not used to calculate a RideGuard risk score.\n\nRideGuard demo fixtures: synthetic routes and reports, visibly labelled and excluded from non-demo risk calculations. They describe no verified street conditions.\n\nLocal rider observations: supplied by the user and saved on the device. Confirmation totals count local interactions only. No community statistics are fabricated.\n\nInfrastructure, collision, lighting, weather, traffic, closure and road-surface feeds have not been connected. Missing factors remain unknown. The risk engine averages current valid factors by coverage and requires a minimum evidence threshold; its model requires calibration and independent validation before production."
        }
    }
}
