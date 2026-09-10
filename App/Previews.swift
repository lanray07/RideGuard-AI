import SwiftUI

#Preview("Explore · light") {
    NavigationStack { HomeView() }.environment(RideStore()).preferredColorScheme(.light)
}
#Preview("Explore · dark") {
    NavigationStack { HomeView() }.environment(RideStore()).preferredColorScheme(.dark)
}
#Preview("Onboarding · large type") {
    OnboardingView(complete: {}).environment(\.dynamicTypeSize, .accessibility1)
}
