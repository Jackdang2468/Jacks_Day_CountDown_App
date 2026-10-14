import SwiftUI
import WidgetKit

struct SettingsView: View {
    @Environment(AuthService.self) private var auth
    @Environment(CountdownStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var confirmSignOut = false

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if let email = auth.email {
                        LabeledContent("Signed in as", value: email)
                    } else {
                        Text("Sync isn't set up. Countdowns stay on this phone.")
                            .foregroundStyle(.secondary)
                    }
                    if let last = store.lastSynced {
                        LabeledContent("Last synced") {
                            Text(last, style: .relative) + Text(" ago")
                        }
                    }
                    if auth.email != nil {
                        Button("Sync now", systemImage: "arrow.triangle.2.circlepath") {
                            Task { await store.syncNow() }
                        }
                        .disabled(store.isSyncing)
                    }
                }

                Section {
                    Button("Refresh widgets", systemImage: "rectangle.3.group") {
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                    if !SharedContainer.isShared {
                        Label("Widgets can't read your countdowns because the App Group isn't active in this build.",
                              systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text("Widgets")
                } footer: {
                    Text("Long-press your Home Screen or Lock Screen, tap Edit or Customize, then add a Day Counter widget. Long-press a widget and choose Edit Widget to pick which countdown it shows.")
                }

                if auth.email != nil {
                    Section {
                        Button("Sign out", role: .destructive) { confirmSignOut = true }
                    }
                }

                Section {
                    LabeledContent("Version",
                                   value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Sign out?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) {
                    Task {
                        await auth.signOut()
                        dismiss()
                    }
                }
            } message: {
                Text("Countdowns are removed from this phone and its widgets. They stay safe in your account.")
            }
        }
    }
}
