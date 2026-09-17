import SwiftUI

/// The "Nice work!" card shown right after a workout is finished: workout
/// number, muscles hit this session, the last-7-days check row, key numbers,
/// and a share button that renders the card to an image.
struct WorkoutCompleteView: View {
    @Environment(WorkoutStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    let workout: Workout
    @State private var shareImage: Image?

    private var workoutNumber: Int {
        // history is newest-first; this workout is already in it
        if let idx = store.history.firstIndex(where: { $0.id == workout.id }) {
            return store.history.count - idx
        }
        return store.history.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 6) {
                        Text("Nice work!")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        Text("This is your \(ordinal(workoutNumber)) workout")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    card
                        .padding(.horizontal, 20)

                    stats
                        .padding(.horizontal, 20)

                    if let shareImage {
                        ShareLink(item: shareImage,
                                  subject: Text("FitX workout"),
                                  message: Text("\(workout.title) · \(ordinal(workoutNumber)) workout on FitX"),
                                  preview: SharePreview("FitX workout", image: shareImage)) {
                            Label("Share workout", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.bordered)
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.bold()
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .background(.bar)
            }
            .task { renderShareImage() }
        }
        .sensoryFeedback(.success, trigger: workout.id)
    }

    // MARK: - Card (also what gets shared)

    private var card: some View {
        WorkoutShareCard(workout: workout,
                         workoutNumber: workoutNumber,
                         counts: Self.sessionMuscleCounts(workout),
                         weekDays: Self.weekRow(history: store.history),
                         handle: profileHandle)
    }

    private var profileHandle: String {
        workout.startDate.formatted(date: .abbreviated, time: .omitted)
    }

    private var stats: some View {
        HStack(spacing: 12) {
            stat("Duration", formatDuration(workout.duration))
            stat("Volume", Stats.formattedVolume(workout.totalVolume, unit: store.settings.weightUnit))
            stat("Sets", "\(workout.completedSetCount)")
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.weight(.bold)).minimumScaleFactor(0.7).lineLimit(1)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    @MainActor
    private func renderShareImage() {
        let renderer = ImageRenderer(content: card.frame(width: 360).padding(16).background(Color.black))
        renderer.scale = displayScale
        if let ui = renderer.uiImage { shareImage = Image(uiImage: ui) }
    }

    // MARK: - Helpers

    /// Working sets per muscle group for THIS workout only.
    static func sessionMuscleCounts(_ workout: Workout) -> [MuscleGroup: Int] {
        var counts: [MuscleGroup: Int] = [:]
        for wex in workout.exercises {
            let working = wex.sets.filter { $0.isCompleted && $0.type != .warmup }.count
            if working > 0 { counts[wex.exercise.muscleGroup, default: 0] += working }
        }
        return counts
    }

    /// Last 7 calendar days ending today: (weekday letter, trained?)
    static func weekRow(history: [Workout], asOf now: Date = Date()) -> [(String, Bool)] {
        let cal = Calendar.current
        let trained = Set(history.map { cal.startOfDay(for: $0.startDate) })
        let f = DateFormatter(); f.dateFormat = "EEEEE"
        return (0..<7).reversed().map { back in
            let day = cal.startOfDay(for: cal.date(byAdding: .day, value: -back, to: now) ?? now)
            return (f.string(from: day), trained.contains(day))
        }
    }

    private func ordinal(_ n: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .ordinal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        Stats.formattedDuration(t)
    }
}

/// The shareable card: body diagram lit by this session's sets + 7-day row.
struct WorkoutShareCard: View {
    let workout: Workout
    let workoutNumber: Int
    let counts: [MuscleGroup: Int]
    let weekDays: [(String, Bool)]
    let handle: String

    private var maxCount: Int { max(counts.values.max() ?? 0, 1) }
    private func intensity(_ g: MuscleGroup) -> Double { Double(counts[g] ?? 0) / Double(maxCount) }
    private var trainedCount: Int { weekDays.filter(\.1).count }

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 28) {
                BodyDiagram(side: .front, intensity: intensity(_:))
                BodyDiagram(side: .back, intensity: intensity(_:))
            }
            .frame(height: 220)
            .padding(.top, 8)

            VStack(spacing: 8) {
                HStack {
                    ForEach(Array(weekDays.enumerated()), id: \.offset) { _, day in
                        Text(day.0).font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }
                }
                HStack {
                    ForEach(Array(weekDays.enumerated()), id: \.offset) { _, day in
                        ZStack {
                            Circle().fill(day.1 ? Color.accentColor : Color.primary.opacity(0.12))
                            if day.1 { Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white) }
                        }
                        .frame(width: 30, height: 30)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 10)
                .background(Color.primary.opacity(0.06), in: Capsule())
            }

            Text("You worked out ")
                .font(.subheadline)
            + Text("\(trainedCount) time\(trainedCount == 1 ? "" : "s")").font(.subheadline.weight(.bold))
            + Text(" in the last 7 days").font(.subheadline)

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "dumbbell.fill")
                    Text("FitX").font(.headline.weight(.heavy))
                }
                Spacer()
                Text(handle).font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .background(
            LinearGradient(colors: [Color(red: 0.05, green: 0.08, blue: 0.16), Color(red: 0.02, green: 0.03, blue: 0.08)],
                           startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }
}
