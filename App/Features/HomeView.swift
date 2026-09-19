import SwiftUI
import MapKit
import RideGuardCore

struct HomeView: View {
    @Environment(RideStore.self) private var store
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var loading = false
    @State private var planningError: String?
    @State private var comparing = false
    @State private var explaining: RouteCandidate?
    @State private var searchTask: Task<Void, Never>?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Label("RIDEGUARD", systemImage: "bicycle").font(.headline).tracking(2)
                    Spacer()
                    if store.demoMode { DemoBadge() }
                }.foregroundStyle(RG.green)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Plan your cycling route.").font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("A little more confidence.\nEvery time you ride.").font(.title3).foregroundStyle(.secondary)
                }
                Panel {
                    VStack(alignment: .leading, spacing: 16) {
                        Eyebrow(text: "Where are you riding?")
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundStyle(RG.green)
                            TextField("Enter a destination", text: $query).submitLabel(.search).onSubmit { search() }
                            if loading { ProgressView() } else { Button(action: search) { Image(systemName: "arrow.right.circle.fill").font(.title2) }.accessibilityLabel("Search destination") }
                        }.padding(14).background(RG.canvas, in: RoundedRectangle(cornerRadius: 14))
                        HStack(spacing: 10) {
                            ForEach(["Home", "Work", "Saved"], id: \.self) { label in
                                Button {
                                    if store.demoMode { query = label == "Work" ? "Shoreditch" : "London Fields"; search() }
                                    else if let saved = store.snapshot.destinations.first(where: { $0.label == label }) { query = saved.query; search() }
                                    else { store.notice = "Add a destination in You → Saved places." }
                                } label: {
                                    Label(LocalizedStringKey(label), systemImage: label == "Home" ? "house" : label == "Work" ? "briefcase" : "bookmark")
                                        .font(.subheadline.weight(.medium)).padding(10).background(RG.canvas, in: Capsule())
                                }
                            }
                        }
                        if !store.demoMode {
                            Button("Use my location", systemImage: "location") { store.location.requestForPlanning() }
                            Text("Location is used to plan your route. Ride tracking begins only when you start.").font(.caption).foregroundStyle(.secondary)
                            if let error = store.location.error { Text(L10n.text(error)).font(.caption).foregroundStyle(RG.amber) }
                        }
                        if let planningError { Text(L10n.text(planningError)).font(.subheadline).foregroundStyle(RG.amber) }
                    }
                }
                if !results.isEmpty {
                    Panel {
                        VStack(spacing: 16) {
                            ForEach(Array(results.enumerated()), id: \.offset) { _, item in
                                Button { calculate(item) } label: { InfoRow(symbol: "mappin", title: item.name ?? "Destination", subtitle: item.placemark.title ?? "", verbatimTitle: true, verbatimSubtitle: true) }
                            }
                        }
                    }
                }
                if !store.routes.isEmpty {
                    HStack { Eyebrow(text: "Your route, your choice"); Spacer(); Button("Compare") { comparing = true }.font(.subheadline.weight(.semibold)) }
                    RouteMap(routes: store.routes, selected: store.selectedRouteID, reports: store.reports)
                        .frame(height: 260).clipShape(RoundedRectangle(cornerRadius: 26))
                    VStack(spacing: 12) {
                        ForEach(store.routes) { route in
                            RouteCard(route: route, selected: store.selectedRoute?.id == route.id,
                                      choose: { store.selectedRouteID = route.id }, explain: { explaining = route })
                        }
                    }
                    Button { store.selectedTab = 2 } label: { Label("Prepare my ride", systemImage: "arrow.up.right") }.buttonStyle(PrimaryButtonStyle())
                    Text(LocalizedStringKey(store.demoMode ? "Illustrative routes and scores. Do not use the demo to navigate." : "Route information cannot guarantee safety. Conditions and data coverage can change."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack { Eyebrow(text: store.demoMode ? "A look around · demo" : "Your local observations"); Spacer(); Button("View all") { store.selectedTab = 1 } }
                Panel {
                    InfoRow(symbol: "mappin.and.ellipse", title: L10n.format(store.demoMode ? "Sample reports: %lld" : "Saved reports: %lld", store.reports.count),
                            subtitle: store.demoMode ? "Explore how rider reports appear along a route." : "Reports are stored on this device. Community syncing is not connected.")
                }
                HStack(spacing: 16) {
                    Image("CyclistHero").resizable().scaledToFill().frame(width: 88, height: 112).clipped().clipShape(RoundedRectangle(cornerRadius: 16))
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Eyes on the road.\nHands on the bike.").font(.headline)
                        Text("Discover voice shortcuts in your ride settings.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }.padding(16).background(RG.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 24))
                if let notice = store.notice { Text(L10n.text(notice)).font(.subheadline).foregroundStyle(RG.green) }
            }.padding(22).frame(maxWidth: 760)
        }.frame(maxWidth: .infinity).background(RG.canvas).toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $comparing) { NavigationStack { ComparisonView(routes: store.routes) } }
            .sheet(item: $explaining) { route in NavigationStack { ExplanationView(route: route) } }
            .onDisappear { searchTask?.cancel(); loading = false }
    }
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        return hour < 12 ? "Good morning." : hour < 18 ? "Good afternoon." : "Good evening."
    }
    private func search() {
        searchTask?.cancel(); planningError = nil
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if store.demoMode {
            store.routes = DemoData.routes(); results = []
            store.notice = "Demo uses an illustrative London Fields journey. Switch off demo in You for real destination search."
            return
        }
        loading = true
        searchTask = Task {
            do {
                let found = try await store.routing.search(query, near: store.location.recentCoordinate)
                try Task.checkCancellation()
                results = found; loading = false
                if found.isEmpty { planningError = "No destinations found. Try a street or postcode." }
            } catch { if !Task.isCancelled { planningError = error.localizedDescription; loading = false } }
        }
    }
    private func calculate(_ destination: MKMapItem) {
        guard let origin = store.location.recentCoordinate else { planningError = "Tap Use my location, then choose a destination."; return }
        loading = true; results = []; planningError = nil
        searchTask?.cancel()
        searchTask = Task {
            do {
                let routes = try await store.routing.routes(from: origin, to: destination)
                try Task.checkCancellation()
                store.routes = routes; store.selectedRouteID = routes.first?.id; loading = false
            } catch { if !Task.isCancelled { planningError = error.localizedDescription; loading = false } }
        }
    }
}

struct RouteMap: View {
    let routes: [RouteCandidate]
    var selected: UUID?
    let reports: [HazardReport]
    var body: some View {
        Map {
            ForEach(routes) { route in
                MapPolyline(coordinates: route.coordinates.map(\.cl))
                    .stroke(route.id == (selected ?? routes.first?.id) ? RG.green : .secondary.opacity(0.4), style: StrokeStyle(lineWidth: route.id == (selected ?? routes.first?.id) ? 6 : 3, lineCap: .round, lineJoin: .round))
            }
            ForEach(Array(reports.prefix(30))) { report in
                Annotation(report.category.title, coordinate: report.coordinate.cl) {
                    Image(systemName: report.category.symbol).font(.caption).foregroundStyle(.white).padding(9).background(RG.amber, in: Circle())
                }
            }
            if let end = routes.first?.coordinates.last { Marker("Destination", systemImage: "flag.checkered", coordinate: end.cl).tint(RG.green) }
        }.mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
            .overlay(alignment: .topLeading) { if routes.contains(where: \.isDemo) { DemoBadge().padding(12) } }
            .accessibilityLabel("Route overview with \(reports.count) available reports")
    }
}

struct RouteCard: View {
    let route: RouteCandidate
    let selected: Bool
    let choose: () -> Void
    let explain: () -> Void
    private var assessment: RiskAssessment { RouteRiskEngine().assess(route.factors, allowDemo: route.isDemo) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: choose) {
                HStack(alignment: .top) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.title2)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.text(route.name).localizedUppercase).font(.caption.weight(.bold)).tracking(1.5)
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text("\(Int(route.duration / 60))").font(.system(size: 32, weight: .bold, design: .rounded))
                            Text("min").font(.subheadline)
                            Text("· \(route.distance.milesText)").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(assessment.overallRiskScore.map(String.init) ?? "—").font(.system(size: 30, weight: .bold, design: .rounded))
                        Text(LocalizedStringKey(route.isDemo ? "Demo risk score" : "Risk score")).font(.caption2)
                    }
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
            HStack {
                Text(L10n.text(assessment.label)).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Why this route?", action: explain).font(.caption.weight(.semibold))
            }
        }.padding(18).background(selected ? RG.green.opacity(0.07) : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(selected ? RG.green : .primary.opacity(0.08), lineWidth: selected ? 1.5 : 1))
            .foregroundStyle(selected ? RG.green : .primary)
    }
}
