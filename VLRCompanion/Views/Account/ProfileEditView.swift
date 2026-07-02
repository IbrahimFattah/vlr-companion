import SwiftUI

/// Edit the signed-in profile: username + avatar.
struct ProfileEditView: View {
    @Environment(AccountStore.self) private var account
    @Environment(\.dismiss) private var dismiss

    @State private var username: String
    @State private var emoji: String
    @State private var color: String
    @State private var error: String?
    @State private var busy = false

    init(account: Account) {
        _username = State(initialValue: account.username)
        _emoji = State(initialValue: account.avatarEmoji)
        _color = State(initialValue: account.avatarColor)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack { Spacer(); AccountAvatar(emoji: emoji, colorHex: color, size: 72); Spacer() }
                        .listRowBackground(Color.clear)
                }
                Section("Username") {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("Avatar") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(AvatarChoices.emojis, id: \.self) { e in
                                Text(e).font(.title2).frame(width: 40, height: 40)
                                    .background(emoji == e ? Color(hex: color).opacity(0.3) : Theme.elevated, in: Circle())
                                    .overlay(Circle().strokeBorder(emoji == e ? Color(hex: color) : .clear, lineWidth: 2))
                                    .onTapGesture { emoji = e }
                            }
                        }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(AvatarChoices.colors, id: \.self) { c in
                                Circle().fill(Color(hex: c)).frame(width: 34, height: 34)
                                    .overlay(Circle().strokeBorder(.white, lineWidth: color == c ? 2 : 0))
                                    .onTapGesture { color = c }
                            }
                        }
                    }
                }
                if let error {
                    Section { Text(error).foregroundStyle(Theme.live).font(.footnote) }
                }
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: save).disabled(busy || username.count < 3)
                }
            }
        }
    }

    private func save() {
        error = nil; busy = true
        Task {
            do {
                try await account.updateProfile(username: username, emoji: emoji, color: color)
                dismiss()
            } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
}
