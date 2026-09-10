import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(RideStore.self) private var store
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image("CyclistHero").resizable().scaledToFill().frame(height: 250).clipped().clipShape(RoundedRectangle(cornerRadius: 26))
                Eyebrow(text: "RideGuard Pro")
                Text("Ride with more\ninformation.").font(.largeTitle.bold())
                Text("A premium home for route insights, connected rides and the people you trust.").foregroundStyle(.secondary)
                Panel {
                    VStack(spacing: 18) {
                        InfoRow(symbol: "map", title: "Understand route factors", subtitle: "Explainable scores with visible data confidence")
                        InfoRow(symbol: "person.2", title: "Stay connected", subtitle: "Planned: secure Live Ride and trusted contact updates")
                        InfoRow(symbol: "waveform", title: "Hear what’s ahead", subtitle: "Brief alerts and supported Siri shortcuts")
                        InfoRow(symbol: "applewatch", title: "Glance at your ride", subtitle: "Companion status and quick actions")
                    }
                }
                Text("Development preview: subscriptions are not offered for sale until the advertised services and production terms are ready.").font(.subheadline).foregroundStyle(RG.amber)
                if store.subscriptions.isLoading { ProgressView("Loading StoreKit products…") }
                ForEach(store.subscriptions.products) { product in
                    LabeledContent(product.displayName, value: product.displayPrice)
                }
                if store.subscriptions.products.isEmpty { Text("StoreKit plans are not configured. No production prices are assumed.").font(.caption).foregroundStyle(.secondary) }
                if store.subscriptions.hasPro { Label("Verified Pro entitlement", systemImage: "checkmark.seal") }
                Button("Restore purchases") { Task { await store.subscriptions.restore() } }
                if let error = store.subscriptions.error { Text(error).font(.caption).foregroundStyle(RG.amber) }
                HStack { NavigationLink("Terms") { PolicyView(kind: .terms) }; Spacer(); NavigationLink("Privacy") { PolicyView(kind: .privacy) } }.font(.caption)
            }.padding(24).frame(maxWidth: 700)
        }.navigationTitle("RideGuard Pro").navigationBarTitleDisplayMode(.inline).background(RG.canvas)
    }
}
