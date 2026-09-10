import SwiftUI
import RideGuardCore

#if targetEnvironment(simulator)
/// CI-only entry points render the actual feature views with labelled sample data.
struct CaptureScreen: View {
    let name: String
    @Environment(RideStore.self) private var store
    @Environment(\.modelContext) private var context
    var body: some View {
        NavigationStack {
            switch name {
            case "compare": ComparisonView(routes: store.routes)
            case "explain": ExplanationView(route: DemoData.routes()[0])
            case "reports": ReportsView()
            case "ride": RideView()
            case "voice": VoiceSettingsView()
            case "privacy": PolicyView(kind: .privacy)
            case "onboarding": OnboardingView(complete: {})
            default: HomeView()
            }
        }.tint(RG.green).task { store.configure(context: context) }
    }
}
#endif
