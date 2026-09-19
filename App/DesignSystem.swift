import SwiftUI

enum RG {
    static let green = Color("Evergreen")
    static let canvas = Color("Canvas")
    static let amber = Color(red: 0.80, green: 0.40, blue: 0.15)
    static let muted = Color.secondary
}
struct Eyebrow: View {
    let text: String
    var body: some View { Text(L10n.text(text).localizedUppercase).font(.caption.weight(.bold)).tracking(2).foregroundStyle(.secondary) }
}
struct DemoBadge: View {
    var body: some View { Label("DEMO · SAMPLE DATA", systemImage: "sparkle").font(.caption2.weight(.bold)).tracking(1).padding(.horizontal, 10).padding(.vertical, 7).background(.regularMaterial, in: Capsule()).accessibilityLabel("Demo. All routes and reports shown are illustrative sample data.") }
}
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity).padding(18)
            .background(RG.green.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 18))
            .foregroundStyle(Color("OnGreen"))
    }
}
struct Panel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { content.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(.background, in: RoundedRectangle(cornerRadius: 24)).overlay(RoundedRectangle(cornerRadius: 24).stroke(.primary.opacity(0.06))) }
}
struct InfoRow: View {
    let symbol: String
    let title: String
    var subtitle: String = ""
    var verbatimTitle = false
    var verbatimSubtitle = false
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).font(.title3).foregroundStyle(RG.green).frame(width: 26, height: 28)
            VStack(alignment: .leading, spacing: 5) { Text(verbatimTitle ? title : L10n.text(title)).font(.headline); if !subtitle.isEmpty { Text(verbatimSubtitle ? subtitle : L10n.text(subtitle)).font(.subheadline).foregroundStyle(.secondary) } }
            Spacer(minLength: 0)
        }
    }
}
extension Double {
    var milesText: String { String(format: "%.1f mi", self / 1609.344) }
}
