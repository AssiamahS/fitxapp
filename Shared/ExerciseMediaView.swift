import SwiftUI

/// Flips between the two demonstration photos so the movement reads like a GIF.
struct ExerciseMediaView: View {
    let exerciseID: String
    var animated: Bool = true

    var body: some View {
        let frames = ExerciseInfo.frames(for: exerciseID)
        if frames.isEmpty {
            placeholder
        } else if frames.count == 1 || !animated {
            Image(uiImage: frames[0])
                .resizable()
                .scaledToFit()
        } else {
            TimelineView(.periodic(from: .now, by: 0.8)) { context in
                let index = Int(context.date.timeIntervalSinceReferenceDate / 0.8) % frames.count
                Image(uiImage: frames[index])
                    .resizable()
                    .scaledToFit()
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(0.5))
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
        }
    }
}

/// Small square thumbnail (first frame) for list rows.
struct ExerciseThumbnail: View {
    let exerciseID: String
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let frame = ExerciseInfo.frames(for: exerciseID).first {
                Image(uiImage: frame)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Rectangle().fill(.quaternary.opacity(0.5))
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
