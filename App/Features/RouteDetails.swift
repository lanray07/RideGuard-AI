import SwiftUI
import RideGuardCore

struct ExplanationView: View {
    let route: RouteCandidate
    @Environment(\.dismiss) private var dismiss
    private var assessment: RiskAssessment { RouteRiskEngine().assess(route.factors, allowDemo: route.isDemo) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if route.isDemo { DemoBadge() }
                Text("Understand your route.").font(.largeTitle.bold())
                Panel {
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: "RideGuard risk indicator")
                        Text(assessment.overallRiskScore.map { "\($0) / 100" } ?? "Not available").font(.system(.largeTitle, design: .rounded, weight: .bold)).foregroundStyle(RG.green)
                        Text(assessment.label).font(.headline)
                        Text("Data confidence: \(assessment.confidence.rawValue)").font(.subheadline)
                        Text("This experimental indicator is not a probability of a collision. A lower score cannot guarantee safety.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                ForEach(assessment.factors) { factor in
                    Panel {
                        VStack(alignment: .leading, spacing: 10) {
                            InfoRow(symbol: "chart.bar.doc.horizontal", title: factor.kind.title, subtitle: factor.explanation)
                            Text("Source: \(factor.source)").font(.caption).foregroundStyle(.secondary)
                            Text("Observed \(factor.observedAt.formatted(date: .abbreviated, time: .shortened)) · coverage \(Int(factor.coverage * 100))%").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Panel {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(symbol: "info.circle", title: "What we don’t know")
                        ForEach(assessment.missingData, id: \.self) { Text("• \($0.title)").font(.subheadline).foregroundStyle(.secondary) }
                        Text("Unknown factors are excluded, never treated as zero risk. At least three current factors and 25% total coverage are needed. Available factors are weighted by coverage.").font(.caption)
                    }
                }
            }.padding(22).frame(maxWidth: 760)
        }.background(RG.canvas).navigationTitle("Why this route").navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
    }
}
struct ComparisonView: View {
    let routes: [RouteCandidate]
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("A few minutes.\nA different journey.").font(.largeTitle.bold())
                if routes.contains(where: \.isDemo) { DemoBadge() }
                ForEach(routes) { route in
                    Panel {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(route.name).font(.title2.bold()).foregroundStyle(RG.green)
                            LabeledContent("Estimated time", value: "\(Int(route.duration / 60)) min")
                            LabeledContent("Distance", value: route.distance.milesText)
                            LabeledContent("Risk indicator", value: RouteRiskEngine().assess(route.factors, allowDemo: route.isDemo).overallRiskScore.map(String.init) ?? "Unavailable")
                            if let fastest = routes.min(by: { $0.duration < $1.duration }) {
                                Text(CyclingSafetyAIService().compareRoutes(route, with: fastest)).font(.subheadline).foregroundStyle(.secondary)
                            }
                            Text("Measured protected-lane coverage, major-road distance, junction counts, elevation and traffic are not available in this build.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }.padding(22)
        }.background(RG.canvas).navigationTitle("Compare routes").navigationBarTitleDisplayMode(.inline).toolbar { Button("Done") { dismiss() } }
    }
}
