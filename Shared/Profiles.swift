import Foundation

/// Local accounts, Netflix-style: up to three profiles, each with its own
/// workout + nutrition store directory. The first profile keeps the original
/// store location so existing data survives the upgrade untouched. No
/// passwords, no network — Apple/Google sign-in arrives with cloud sync.
struct Profile: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var emoji: String = "💪"
    /// The founding profile reads the legacy store directory.
    var isPrimary: Bool = false
}

@Observable
final class ProfileManager {
    static let maxProfiles = 3
    private static let defaultsKey = "FitXProfiles"

    private(set) var profiles: [Profile]

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode([Profile].self, from: data),
           !saved.isEmpty {
            profiles = saved
        } else {
            profiles = [Profile(name: "Sly", isPrimary: true)]
            persist()
        }
    }

    @discardableResult
    func addProfile(name: String, emoji: String) -> Profile? {
        guard profiles.count < Self.maxProfiles else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let profile = Profile(name: trimmed, emoji: emoji)
        profiles.append(profile)
        persist()
        return profile
    }

    func removeProfile(_ profile: Profile) {
        // The primary profile owns the legacy data and can't be deleted.
        guard !profile.isPrimary else { return }
        profiles.removeAll { $0.id == profile.id }
        persist()
        try? FileManager.default.removeItem(at: Self.directory(for: profile))
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    /// Primary → the original store directory (data predating profiles).
    /// Everyone else → an isolated subdirectory.
    static func directory(for profile: Profile) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let root = base.appendingPathComponent("FitX", isDirectory: true)
        return profile.isPrimary
            ? root
            : root.appendingPathComponent("profiles/\(profile.id.uuidString)", isDirectory: true)
    }
}
