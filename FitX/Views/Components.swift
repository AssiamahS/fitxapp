import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    var tint: Color = .blue

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct TrendBadge: View {
    let insight: ExerciseInsight

    var body: some View {
        if let (label, icon, color) = descriptor {
            Label(label, systemImage: icon)
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(0.15), in: Capsule())
                .foregroundStyle(color)
        }
    }

    private var descriptor: (String, String, Color)? {
        if insight.isStale, let weeks = insight.weeksSinceLast {
            return ("\(weeks)w off", "zzz", .gray)
        }
        switch insight.trend {
        case .improving: return ("+\(String(format: "%.0f", insight.trendPercent))%", "arrow.up.right", .green)
        case .declining: return ("\(String(format: "%.0f", insight.trendPercent))%", "arrow.down.right", .red)
        case .steady: return ("steady", "arrow.right", .blue)
        case .new: return nil
        }
    }
}

struct CoachCard: View {
    let message: CoachMessage

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(message.title)
                    .font(.subheadline.bold())
                Text(message.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private var icon: String {
        switch message.kind {
        case .stale: return "zzz"
        case .declining: return "chart.line.downtrend.xyaxis"
        case .improving: return "chart.line.uptrend.xyaxis"
        }
    }

    private var color: Color {
        switch message.kind {
        case .stale: return .gray
        case .declining: return .red
        case .improving: return .green
        }
    }
}

/// Fitbod-style recovery chip: how long since a muscle group was trained.
struct FreshnessChip: View {
    let group: MuscleGroup
    let daysSince: Int?

    var body: some View {
        VStack(spacing: 2) {
            Text(group.displayName)
                .font(.caption2.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.4)))
    }

    private var label: String {
        guard let daysSince else { return "fresh" }
        if daysSince == 0 { return "today" }
        if daysSince == 1 { return "1d ago" }
        return "\(daysSince)d ago"
    }

    private var color: Color {
        guard let daysSince else { return .green }
        switch daysSince {
        case 0...1: return .orange   // still recovering
        case 2...4: return .green    // recovered, ready to go
        default: return .teal        // fully fresh
        }
    }
}
