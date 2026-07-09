import UIKit

/// Bundled demo photos + how-to text for the built-in exercise library
/// (frames + instructions from the public-domain free-exercise-db dataset).
enum ExerciseInfo {
    struct Entry: Decodable {
        let source: String
        let instructions: [String]
    }

    static let all: [String: Entry] = {
        guard let url = Bundle.main.url(forResource: "exercise-info", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else {
            return [:]
        }
        return decoded
    }()

    static func instructions(for exerciseID: String) -> [String] {
        all[exerciseID]?.instructions ?? []
    }

    // MARK: - Demo frames

    private static var frameCache: [String: [UIImage]] = [:]

    /// The two demonstration frames (start / end position), if bundled.
    static func frames(for exerciseID: String) -> [UIImage] {
        if let cached = frameCache[exerciseID] { return cached }
        var frames: [UIImage] = []
        for index in 0...1 {
            if let url = Bundle.main.url(forResource: "\(exerciseID)_\(index)", withExtension: "jpg"),
               let image = UIImage(contentsOfFile: url.path) {
                frames.append(image)
            }
        }
        frameCache[exerciseID] = frames
        return frames
    }

    static func hasMedia(for exerciseID: String) -> Bool {
        Bundle.main.url(forResource: "\(exerciseID)_0", withExtension: "jpg") != nil
    }
}
