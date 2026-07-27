import SwiftUI

/// Dark profile-picker login. One tap in, no passwords — each profile is a
/// fully separate local account (own history, templates, macros). Derived
/// from the login-dark-theme-ios template.
struct LoginView: View {
    var manager: ProfileManager
    var onSelect: (Profile) -> Void

    @State private var showingAdd = false
    @State private var newName = ""
    @State private var newEmoji = "💪"
    @State private var appeared = false

    private static let accent = Color(red: 0xE8/255.0, green: 0x6A/255.0, blue: 0x4E/255.0) // FitX coral
    private static let emojiChoices = ["💪", "🏋️", "🔥", "⚡️", "🦍", "🏃"]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.07, green: 0.07, blue: 0.09), .black],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 6) {
                    Text("f")
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .foregroundStyle(Self.accent)
                    Text("Who's lifting?")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }

                HStack(spacing: 20) {
                    ForEach(manager.profiles) { profile in
                        profileBubble(profile)
                    }
                    if manager.profiles.count < ProfileManager.maxProfiles {
                        addBubble
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                Text("Apple & Google sign-in arrive with cloud sync.\nEverything stays on this iPhone for now.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.5)) { appeared = true }
        }
        .sheet(isPresented: $showingAdd) { addSheet }
    }

    private func profileBubble(_ profile: Profile) -> some View {
        Button {
            onSelect(profile)
        } label: {
            VStack(spacing: 8) {
                Text(profile.emoji)
                    .font(.system(size: 40))
                    .frame(width: 84, height: 84)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Self.accent.opacity(profile.isPrimary ? 0.9 : 0.35), lineWidth: 2)
                    )
                Text(profile.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !profile.isPrimary {
                Button("Delete Profile", role: .destructive) {
                    manager.removeProfile(profile)
                }
            }
        }
    }

    private var addBubble: some View {
        Button {
            newName = ""
            newEmoji = "💪"
            showingAdd = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 84, height: 84)
                    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.white.opacity(0.15), style: StrokeStyle(lineWidth: 2, dash: [6]))
                    )
                Text("Add")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var addSheet: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $newName)
                Picker("Emoji", selection: $newEmoji) {
                    ForEach(Self.emojiChoices, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .navigationTitle("New Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        if let profile = manager.addProfile(name: newName, emoji: newEmoji) {
                            showingAdd = false
                            onSelect(profile)
                        }
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingAdd = false }
                }
            }
        }
        .presentationDetents([.height(220)])
        .preferredColorScheme(.dark)
    }
}
