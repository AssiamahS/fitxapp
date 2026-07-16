import SwiftUI

/// Front/back body diagram colored by how hard each muscle group was trained
/// recently. The body is drawn in code as placeholder art — swap the region
/// tables for real avatar artwork without touching the heat logic.
struct MuscleHeatmapView: View {
    let counts: [MuscleGroup: Int]

    private var maxCount: Int { max(counts.values.max() ?? 0, 1) }

    private func intensity(_ group: MuscleGroup) -> Double {
        Double(counts[group] ?? 0) / Double(maxCount)
    }

    var body: some View {
        VStack(spacing: 10) {
            if counts.isEmpty {
                Text("Complete sets and the body lights up.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
            if Muscle3DBodyView.isAvailable {
                Muscle3DBodyView(intensity: intensity(_:))
                Text("Drag to spin · pinch to zoom")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 28) {
                    VStack(spacing: 4) {
                        BodyDiagram(side: .front, intensity: intensity(_:))
                        Text("Front")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    VStack(spacing: 4) {
                        BodyDiagram(side: .back, intensity: intensity(_:))
                        Text("Back")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            legend
        }
    }

    private var legend: some View {
        HStack(spacing: 6) {
            Text("Rested")
                .font(.caption2)
                .foregroundStyle(.secondary)
            LinearGradient(colors: [BodyDiagram.heat(0), BodyDiagram.heat(0.5), BodyDiagram.heat(1)],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: 90, height: 8)
                .clipShape(Capsule())
            Text("Worked")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

/// Stylized body with tappable-scale muscle regions in a 0...1 unit space.
struct BodyDiagram: View {
    enum Side { case front, back }

    let side: Side
    let intensity: (MuscleGroup) -> Double

    static func heat(_ t: Double) -> Color {
        guard t > 0 else { return Color.primary.opacity(0.08) }
        return Color(red: 0.91, green: 0.31, blue: 0.28).opacity(0.25 + 0.75 * min(t, 1))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                silhouetteLayer(size: geo.size)
                regionLayer(size: geo.size)
            }
        }
        .aspectRatio(0.52, contentMode: .fit)
        .frame(maxHeight: 240)
    }

    private func silhouetteLayer(size: CGSize) -> some View {
        ZStack {
            ForEach(Array(Self.silhouette.enumerated()), id: \.offset) { _, part in
                RoundedRectangle(cornerRadius: part.height * size.height * 0.45)
                    .fill(Color.primary.opacity(0.05))
                    .frame(width: part.width * size.width, height: part.height * size.height)
                    .position(x: part.midX * size.width, y: part.midY * size.height)
            }
            Circle()
                .fill(Color.primary.opacity(0.05))
                .frame(width: 0.20 * size.width, height: 0.20 * size.width)
                .position(x: 0.5 * size.width, y: 0.055 * size.height)
        }
    }

    private func regionLayer(size: CGSize) -> some View {
        ForEach(regions, id: \.id) { region in
            RoundedRectangle(cornerRadius: region.rect.height * size.height * 0.35)
                .fill(Self.heat(intensity(region.group)))
                .frame(width: region.rect.width * size.width, height: region.rect.height * size.height)
                .position(x: region.rect.midX * size.width, y: region.rect.midY * size.height)
        }
    }

    private var regions: [MuscleRegion] {
        side == .front ? Self.frontRegions : Self.backRegions
    }

    struct MuscleRegion {
        let group: MuscleGroup
        let rect: CGRect
        var id: String { "\(group.rawValue)-\(rect.origin.x)" }

        /// The same region on the opposite limb.
        var mirrored: MuscleRegion {
            MuscleRegion(group: group,
                         rect: CGRect(x: 1 - rect.origin.x - rect.width,
                                      y: rect.origin.y,
                                      width: rect.width,
                                      height: rect.height))
        }
    }

    private static func paired(_ group: MuscleGroup, _ rect: CGRect) -> [MuscleRegion] {
        let region = MuscleRegion(group: group, rect: rect)
        return [region, region.mirrored]
    }

    // Neutral body parts behind the muscle regions (torso, arms, hips, legs).
    static let silhouette: [CGRect] = [
        CGRect(x: 0.44, y: 0.095, width: 0.12, height: 0.035),
        CGRect(x: 0.30, y: 0.13, width: 0.40, height: 0.31),
        CGRect(x: 0.165, y: 0.145, width: 0.115, height: 0.21),
        CGRect(x: 0.72, y: 0.145, width: 0.115, height: 0.21),
        CGRect(x: 0.145, y: 0.355, width: 0.10, height: 0.185),
        CGRect(x: 0.755, y: 0.355, width: 0.10, height: 0.185),
        CGRect(x: 0.32, y: 0.43, width: 0.36, height: 0.10),
        CGRect(x: 0.32, y: 0.52, width: 0.165, height: 0.235),
        CGRect(x: 0.515, y: 0.52, width: 0.165, height: 0.235),
        CGRect(x: 0.34, y: 0.75, width: 0.13, height: 0.21),
        CGRect(x: 0.53, y: 0.75, width: 0.13, height: 0.21),
    ]

    static let frontRegions: [MuscleRegion] = {
        var regions: [MuscleRegion] = []
        regions += paired(.shoulders, CGRect(x: 0.295, y: 0.145, width: 0.115, height: 0.055))
        regions += paired(.chest, CGRect(x: 0.355, y: 0.165, width: 0.14, height: 0.10))
        regions += paired(.biceps, CGRect(x: 0.18, y: 0.205, width: 0.095, height: 0.13))
        regions += paired(.forearms, CGRect(x: 0.155, y: 0.365, width: 0.088, height: 0.155))
        regions.append(MuscleRegion(group: .core, rect: CGRect(x: 0.375, y: 0.285, width: 0.25, height: 0.14)))
        regions += paired(.quads, CGRect(x: 0.335, y: 0.535, width: 0.145, height: 0.20))
        return regions
    }()

    static let backRegions: [MuscleRegion] = {
        var regions: [MuscleRegion] = []
        regions += paired(.shoulders, CGRect(x: 0.295, y: 0.145, width: 0.115, height: 0.055))
        regions.append(MuscleRegion(group: .back, rect: CGRect(x: 0.345, y: 0.155, width: 0.31, height: 0.26)))
        regions += paired(.triceps, CGRect(x: 0.18, y: 0.205, width: 0.095, height: 0.13))
        regions += paired(.forearms, CGRect(x: 0.155, y: 0.365, width: 0.088, height: 0.155))
        regions += paired(.glutes, CGRect(x: 0.345, y: 0.435, width: 0.145, height: 0.095))
        regions += paired(.hamstrings, CGRect(x: 0.335, y: 0.55, width: 0.145, height: 0.18))
        regions += paired(.calves, CGRect(x: 0.35, y: 0.765, width: 0.115, height: 0.16))
        return regions
    }()
}
