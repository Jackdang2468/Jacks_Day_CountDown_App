import SwiftUI
import WidgetKit

struct SettingsView: View {
    @Environment(AuthService.self) private var auth
    @Environment(CountdownStore.self) private var store
    @Environment(OutlookService.self) private var outlook
    @Environment(AppLock.self) private var appLock
    @State private var remindersOn = ReminderScheduler.isEnabled
    @State private var reminderHour = ReminderScheduler.hour
    @State private var liveActivitiesAuto = LiveActivityManager.autoStart
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

                if outlook.isConfigured {
                    Section {
                        if let account = outlook.accountName {
                            LabeledContent("Connected", value: account)
                            if !outlook.usesMicrosoftSignIn && outlook.writableCalendars.count > 1 {
                                Picker("Calendar", selection: Binding(
                                    get: { outlook.phoneCalendarID ?? "" },
                                    set: { id in
                                        if let calendar = outlook.writableCalendars.first(where: { $0.calendarIdentifier == id }) {
                                            outlook.choosePhoneCalendar(calendar)
                                        }
                                    }
                                )) {
                                    ForEach(outlook.writableCalendars, id: \.calendarIdentifier) { calendar in
                                        Text("\(calendar.title) (\(calendar.source.title))").tag(calendar.calendarIdentifier)
                                    }
                                }
                            }
                            Toggle("Add new countdowns automatically", isOn: Bindable(outlook).autoAdd)
                            Button("Disconnect Outlook", role: .destructive) { outlook.disconnect() }
                        } else {
                            Button {
                                Task { await outlook.connect() }
                            } label: {
                                HStack {
                                    Label("Connect Outlook", systemImage: "envelope.badge.shield.half.filled")
                                    Spacer()
                                    if outlook.isWorking { ProgressView() }
                                }
                            }
                            .disabled(outlook.isWorking)
                        }
                        if let error = outlook.errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    } header: {
                        Text("Outlook")
                    } footer: {
                        Text(outlook.usesMicrosoftSignIn
                             ? "Sign in with your Microsoft work, school, or personal account. Events you add or edit here appear in your Outlook calendar, with a reminder the day before. Deleting a countdown removes its Outlook event."
                             : "Uses the Outlook account on this iPhone (Settings > Calendar > Accounts). Events you add or edit here appear in your Outlook calendar, with a reminder the day before. Deleting a countdown removes its Outlook event.")
                    }
                }

                Section {
                    Toggle("Reminders", isOn: $remindersOn)
                    if remindersOn {
                        Picker("All-day reminders at", selection: $reminderHour) {
                            ForEach(5..<23) { hour in
                                Text(Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now)!,
                                     format: .dateTime.hour())
                                    .tag(hour)
                            }
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("1 week before, 1 day before, and on the day. Turn reminders off for a single countdown in its edit screen.")
                }
                .onChange(of: remindersOn) { _, on in
                    ReminderScheduler.isEnabled = on
                    store.refreshSystemFeatures()
                }
                .onChange(of: reminderHour) { _, hour in
                    ReminderScheduler.hour = hour
                    store.refreshSystemFeatures()
                }

                Section {
                    Toggle("Start automatically", isOn: $liveActivitiesAuto)
                        .onChange(of: liveActivitiesAuto) { _, on in
                            LiveActivityManager.autoStart = on
                            store.refreshSystemFeatures()
                        }
                } header: {
                    Text("Live Activities")
                } footer: {
                    Text("In the last 8 hours before an event, a live timer appears on your Lock Screen and in the Dynamic Island. It starts when you open the app during that window, or from a countdown's ••• menu.")
                }

                Section {
                    Toggle("Require \(appLock.biometryName)", isOn: Binding(
                        get: { appLock.isEnabled },
                        set: { on in Task { await appLock.setEnabled(on) } }
                    ))
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Locks the app whenever you leave it. Widgets stay visible.")
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
