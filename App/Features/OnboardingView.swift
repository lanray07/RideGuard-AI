import SwiftUI

struct OnboardingView: View {
    var complete: () -> Void
    @State private var page = 0
    private let titles = ["Every ride deserves a little more confidence.", "Fastest isn’t always your only option.", "Know what riders ahead are seeing.", "Someone can know you’re on your way.", "Check in without having to remember.", "Your location is personal."]
    private let messages = ["Compare cycling route factors, understand rider reports and prepare for your everyday journey.", "Explore explainable route comparisons. Demo scores are illustrative, never a promise of safety.", "Mark potholes, roadworks and blocked lanes. Reports in this build stay on your device.", "Prepare a ride and keep an eye on your ETA. Secure live sharing needs a connected service and is unavailable in this build.", "Set a reminder for an overdue ride. You choose whether to send a check-in using your phone’s sharing options.", "Planning uses location on request. Tracking runs only during rides you start. No location is shared automatically. Delete or export local records at any time."]
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ZStack(alignment: .bottomLeading) {
                        Image("CyclistHero").resizable().scaledToFill().frame(height: min(geometry.size.height * 0.42, 390)).clipped()
                        LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
                        Label("RIDEGUARD AI", systemImage: "bicycle").font(.headline).tracking(3).foregroundStyle(.white).padding(24)
                    }.clipShape(RoundedRectangle(cornerRadius: 30))
                    HStack { ForEach(0..<6) { index in Capsule().fill(index == page ? RG.green : RG.green.opacity(0.15)).frame(width: index == page ? 28 : 8, height: 5) }; Spacer(); Text("\(page + 1) / 6").font(.caption).foregroundStyle(.secondary) }
                    Text(titles[page]).font(.system(.largeTitle, design: .rounded, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                    Text(messages[page]).font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button { if page < 5 { page += 1 } else { complete() } } label: { Text(page == 0 ? "Get started" : page == 5 ? "Explore RideGuard" : "Continue") }.buttonStyle(PrimaryButtonStyle())
                    if page < 5 { Button("Skip introduction", action: complete).frame(maxWidth: .infinity).font(.subheadline) }
                }.padding(24).frame(maxWidth: 600)
            }.frame(maxWidth: .infinity).background(RG.canvas)
        }
    }
}
