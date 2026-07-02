import SwiftUI

/// Sign-in sheet. Dev username login is the working path today; the Sign in
/// with Apple button is present but disabled until the Apple capability is set
/// up server- and app-side (see api-server/README.md).
struct SignInView: View {
    @Environment(AccountStore.self) private var account
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var emoji = AvatarChoices.emojis.first!
    @State private var color = AvatarChoices.colors.first!
    @State private var error: String?
    @State private var busy = false

    private var canSubmit: Bool {
        username.count >= 3 && username.count <= 20 && !busy
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        AccountAvatar(emoji: emoji, colorHex: color, size: 76)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Username") {
                    TextField("3–20 letters, numbers, _", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Avatar") {
                    emojiPicker
                    colorPicker
                }

                if let error {
                    Section {
                        Text(error).foregroundStyle(Theme.live).font(.footnote)
                    }
                }

                Section {
                    Button(action: submit) {
                        HStack {
                            Spacer()
                            if busy { ProgressView() } else { Text("Continue").fontWeight(.semibold) }
                            Spacer()
                        }
                    }
                    .disabled(!canSubmit)
                } footer: {
                    Text("A quick username sign-in for now. Sign in with Apple arrives with the App Store build. By posting you agree to the community rules — be civil, no harassment; abusive content is removed.")
                }

                Section {
                    appleButton
                }
            }
            .navigationTitle("Sign in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var emojiPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(AvatarChoices.emojis, id: \.self) { choice in
                    Text(choice)
                        .font(.title2)
                        .frame(width: 40, height: 40)
                        .background(emoji == choice ? Color(hex: color).opacity(0.3) : Theme.elevated,
                                    in: Circle())
                        .overlay(Circle().strokeBorder(emoji == choice ? Color(hex: color) : .clear, lineWidth: 2))
                        .onTapGesture { emoji = choice }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var colorPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(AvatarChoices.colors, id: \.self) { choice in
                    Circle()
                        .fill(Color(hex: choice))
                        .frame(width: 34, height: 34)
                        .overlay(Circle().strokeBorder(.white, lineWidth: color == choice ? 2 : 0))
                        .onTapGesture { color = choice }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var appleButton: some View {
        HStack {
            Image(systemName: "apple.logo")
            Text("Sign in with Apple")
            Spacer()
            Text("soon").font(.caption).foregroundStyle(.secondary)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private func submit() {
        error = nil
        busy = true
        Task {
            do {
                try await account.signInDev(username: username, emoji: emoji, color: color)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            busy = false
        }
    }
}
