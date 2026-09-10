import SwiftUI
import RideGuardCore
import PhotosUI

struct ReportsView: View {
    @Environment(RideStore.self) private var store
    @State private var category: HazardCategory?
    @State private var sheet: ReportSheet?
    private var filtered: [HazardReport] {
        store.reports.filter { category == nil || $0.category == category }.sorted { $0.observedAt > $1.observedAt }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if store.demoMode { DemoBadge() }
                Text("A heads-up\nfrom the street.").font(.largeTitle.bold())
                Text(store.demoMode ? "Explore sample rider observations." : "Your observations, saved on this device.").foregroundStyle(.secondary)
                RouteMap(routes: store.routes, reports: filtered).frame(height: 240).clipShape(RoundedRectangle(cornerRadius: 24))
                Picker("Filter reports", selection: $category) {
                    Text("All reports").tag(nil as HazardCategory?)
                    ForEach(HazardCategory.allCases) { Text($0.title).tag(Optional($0)) }
                }.pickerStyle(.menu)
                if filtered.isEmpty { ContentUnavailableView("No reports yet", systemImage: "mappin.slash", description: Text("Unreported conditions may still exist. Add an observation when stationary.")) }
                ForEach(filtered) { report in
                    Button { sheet = .detail(report) } label: {
                        Panel {
                            InfoRow(symbol: report.category.symbol, title: report.category.title,
                                    subtitle: "\(report.isDemo ? "Sample · " : "Local · ")\(report.observedAt.formatted(.relative(presentation: .named)))\n\(report.confirmations) local confirmations")
                        }
                    }.buttonStyle(.plain)
                }
                Button { sheet = .compose } label: { Label("Report a hazard", systemImage: "plus") }.buttonStyle(PrimaryButtonStyle())
                    .disabled(store.isMoving)
                Text(store.isMoving ? "Stop before using the report form. Use a configured Siri shortcut for a brief hands-free report." : "Report when stationary, or use a configured voice shortcut. No report is automatically published.").font(.caption).foregroundStyle(.secondary)
            }.padding(22).frame(maxWidth: 760)
        }.frame(maxWidth: .infinity).background(RG.canvas).navigationTitle("Reports").navigationBarTitleDisplayMode(.inline)
            .sheet(item: $sheet) { item in NavigationStack { switch item { case .compose: ReportComposer(); case .detail(let report): ReportDetailView(report: report) } } }
    }
    enum ReportSheet: Identifiable {
        case compose, detail(HazardReport)
        var id: String { switch self { case .compose: "compose"; case .detail(let report): report.id.uuidString } }
    }
}

struct ReportComposer: View {
    @Environment(RideStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var category = HazardCategory.pothole
    @State private var description = ""
    @State private var severity = 1
    @State private var error: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var loadingPhoto = false
    var body: some View {
        Form {
            Section {
                if store.demoMode { DemoBadge() }
                Picker("Category", selection: $category) { ForEach(HazardCategory.allCases) { Text($0.title).tag($0) } }
                TextField("What did you observe?", text: $description, axis: .vertical).lineLimit(3...6)
                Picker("Impact", selection: $severity) { Text("Minor").tag(1); Text("Significant").tag(2); Text("Obstructed").tag(3) }
                PhotosPicker(selection: $selectedPhoto, matching: .images) { Label("Add an optional photo", systemImage: "photo") }
                if loadingPhoto { ProgressView("Preparing photo…") }
                if let photoData, let image = UIImage(data: photoData) {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180)
                    Button("Remove photo", role: .destructive) { self.photoData = nil; selectedPhoto = nil }
                }
            } header: { Text("Your observation") } footer: { Text("Saved at your current location and time. Describe road conditions, not identifiable people or vehicles.") }
            Section {
                Label(store.demoMode ? "Sample location · Shoreditch" : store.location.recentCoordinate == nil ? "Location needed" : "Current location available", systemImage: "location")
                if !store.demoMode { Button("Get current location") { store.location.requestForPlanning() } }
            }
            if let error { Text(error).foregroundStyle(RG.amber) }
            Button("Save report on this device") {
                do { try store.report(category, description: description, severity: severity, photo: photoData); dismiss() }
                catch { self.error = error.localizedDescription }
            }.disabled(store.isMoving || loadingPhoto)
        }.disabled(store.isMoving).navigationTitle("Report a hazard").toolbar { Button("Cancel") { dismiss() } }
            .task(id: selectedPhoto) {
                guard let selectedPhoto else { return }
                loadingPhoto = true
                defer { loadingPhoto = false }
                do {
                    guard let data = try await selectedPhoto.loadTransferable(type: Data.self), data.count <= 12_000_000,
                          let source = UIImage(data: data) else { error = "Choose a photo smaller than 12 MB."; return }
                    try Task.checkCancellation()
                    // Re-render pixels to a bounded image, omitting EXIF/location metadata.
                    let scale = min(1, 1600 / max(source.size.width, source.size.height))
                    let size = CGSize(width: source.size.width * scale, height: source.size.height * scale)
                    let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
                    photoData = UIGraphicsImageRenderer(size: size, format: format).image { _ in source.draw(in: CGRect(origin: .zero, size: size)) }.jpegData(compressionQuality: 0.8)
                } catch { if !Task.isCancelled { self.error = "The photo could not be loaded." } }
            }
    }
}
struct ReportDetailView: View {
    let report: HazardReport
    @Environment(RideStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            if report.isDemo { DemoBadge() }
            InfoRow(symbol: report.category.symbol, title: report.category.title, subtitle: report.description)
            if let data = store.snapshot.reportPhotos[report.id.uuidString], let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit().accessibilityLabel("Photo attached to this hazard report")
            }
            LabeledContent("Observed", value: report.observedAt.formatted())
            LabeledContent("Local confirmations", value: String(report.confirmations))
            Text("Observations lose relevance with age. Confirmations represent local test interactions, not verified community consensus.").font(.caption).foregroundStyle(.secondary)
            Section("What do you see?") {
                Button("Still there") { store.confirm(report, as: .stillThere); dismiss() }
                Button("Cleared") { store.confirm(report, as: .cleared); dismiss() }
                Button("Incorrect") { store.confirm(report, as: .incorrect); dismiss() }
            }.disabled(store.isMoving)
            if store.snapshot.reports.contains(where: { $0.id == report.id }) {
                Button("Delete my report", role: .destructive) { store.snapshot.reports.removeAll { $0.id == report.id }; store.snapshot.reportPhotos.removeValue(forKey: report.id.uuidString); store.persist(); dismiss() }
            }
        }.navigationTitle("Report details").toolbar { Button("Done") { dismiss() } }
    }
}
