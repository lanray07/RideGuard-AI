import SwiftUI
import SwiftData

@main
struct RideGuardApp: App {
    @State private var store = RideStore.shared
    var body: some Scene {
        WindowGroup {
            Group {
                #if targetEnvironment(simulator)
                if let screen = ProcessInfo.processInfo.environment["RIDEGUARD_SCREENSHOT_SCREEN"] {
                    CaptureScreen(name: screen)
                } else { RootView() }
                #else
                RootView()
                #endif
            }.environment(store)
        }
            .modelContainer(for: LocalRecord.self)
    }
}

struct RootView: View {
    @Environment(RideStore.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("onboardingComplete") private var onboarded = false
    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.selectedTab) {
            NavigationStack { HomeView() }.tabItem { Label("Explore", systemImage: "map") }.tag(0)
            NavigationStack { ReportsView() }.tabItem { Label("Reports", systemImage: "mappin.and.ellipse") }.tag(1)
            NavigationStack { RideView() }.tabItem { Label("Ride", systemImage: "bicycle") }.tag(2)
            NavigationStack { InsightsView() }.tabItem { Label("Insights", systemImage: "chart.bar.xaxis") }.tag(3)
            NavigationStack { SettingsView() }.tabItem { Label("You", systemImage: "person.crop.circle") }.tag(4)
        }
        .tint(RG.green)
        .fullScreenCover(isPresented: Binding(get: { !onboarded }, set: { onboarded = !$0 })) {
            OnboardingView { onboarded = true }
        }
        .alert("RideGuard", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("OK") { store.error = nil }
        } message: { Text(L10n.text(store.error ?? "")) }
        .task { store.configure(context: context); await store.subscriptions.start() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { store.tick() } }
    }
}
