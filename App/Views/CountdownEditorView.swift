import PhotosUI
import SwiftUI

struct CountdownEditorView: View {
    let original: Countdown?
    @Environment(CountdownStore.self) private var store
    @Environment(OutlookService.self) private var outlook
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Countdown
    @State private var photoItem: PhotosPickerItem?
    @State private var newImageData: Data?
    @State private var removeImage = false
    @State private var addToCalendar = false
    @State private var showCalendarSheet = false
    @State private var isSaving = false

    init(original: Countdown?) {
        self.original = original
        let start = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now
        _draft = State(initialValue: original ?? Countdown(title: "", targetDate: start))
    }

    private var previewImage: UIImage? {
        if let newImageData { return UIImage(data: newImageData) }
        if removeImage { return nil }
        return draft.imageKey.flatMap { ImageStore.image(for: $0, maxPixel: 900) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    preview
                        .listRowInsets(EdgeInsets())
                }

                Section("Event") {
                    TextField("Title", text: $draft.title)
                        .font(.headline)
                    TextField("Emoji (optional)", text: Binding(
                        get: { draft.emoji ?? "" },
                        set: { draft.emoji = String($0.prefix(2)).isEmpty ? nil : String($0.prefix(2)) }
                    ))
                    Toggle("All-day", isOn: $draft.isAllDay)
                    DatePicker("Date", selection: $draft.targetDate,
                               displayedComponents: draft.isAllDay ? [.date] : [.date, .hourAndMinute])
                    TextField("Notes", text: $draft.notes, axis: .vertical)
                        .lineLimit(1...4)
                }

                Section("Look") {
                    PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                        Label(previewImage == nil ? "Choose a photo" : "Change photo", systemImage: "photo")
                    }
                    if previewImage != nil {
                        Button("Remove photo", systemImage: "trash", role: .destructive) {
                            newImageData = nil
                            removeImage = true
                            photoItem = nil
                        }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(CountdownTheme.allCases) { theme in
                                Circle()
                                    .fill(theme.gradient)
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        if draft.theme == theme {
                                            Circle().strokeBorder(.primary, lineWidth: 3)
                                        }
                                    }
                                    .onTapGesture { draft.theme = theme }
                                    .accessibilityLabel(theme.name)
                                    .accessibilityAddTraits(draft.theme == theme ? .isSelected : [])
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if original == nil {
                    Section {
                        Toggle(outlook.isConfigured ? "Add to Outlook" : "Add to my calendar", isOn: $addToCalendar)
                    } footer: {
                        if outlook.isConfigured {
                            Text(outlook.isConnected
                                 ? "Adds this event to \(outlook.accountName ?? "your Outlook") calendar with a reminder the day before."
                                 : outlook.usesMicrosoftSignIn
                                    ? "You'll sign in to your Microsoft account once, then events go straight to Outlook."
                                    : "Uses the Outlook account on your iPhone. You'll be asked to allow calendar access once.")
                        } else {
                            Text("After saving, pick your Outlook or Exchange calendar in the next screen.")
                        }
                    }
                }
            }
            .navigationTitle(original == nil ? "New Countdown" : "Edit Countdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(draft.title.trimmed.isEmpty || isSaving)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                if original == nil && outlook.isConnected { addToCalendar = outlook.autoAdd }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let prepared = ImageStore.prepareForStorage(data) {
                        newImageData = prepared
                        removeImage = false
                    }
                }
            }
            .sheet(isPresented: $showCalendarSheet, onDismiss: { dismiss() }) {
                AddToCalendarSheet(countdown: draft) { _ in showCalendarSheet = false }
                    .ignoresSafeArea()
            }
        }
    }

    private var preview: some View {
        ZStack(alignment: .bottomLeading) {
            ZStack {
                draft.theme.gradient
                if let previewImage {
                    Image(uiImage: previewImage).resizable().scaledToFill()
                    LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                }
            }
            .frame(height: 180)
            .clipped()

            HStack(alignment: .bottom) {
                VStack(alignment: .leading) {
                    if let emoji = draft.emoji { Text(emoji).font(.largeTitle) }
                    Text(draft.title.isEmpty ? "Your event" : draft.title)
                        .font(.title3.bold())
                }
                Spacer()
                let days = DayMath.days(from: .now, to: draft.targetDate)
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(abs(days))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text(DayMath.caption(for: days))
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                }
            }
            .foregroundStyle(.white)
            .padding(20)
        }
        .animation(.smooth, value: draft.targetDate)
    }

    private func save() async {
        draft.title = draft.title.trimmed
        if addToCalendar && outlook.isConfigured {
            isSaving = true
            if !outlook.isConnected { await outlook.connect() }
            isSaving = false
            store.save(draft, newImage: newImageData, removeImage: removeImage,
                       addToOutlook: outlook.isConnected)
            dismiss()
            return
        }
        store.save(draft, newImage: newImageData, removeImage: removeImage)
        if addToCalendar {
            showCalendarSheet = true
        } else {
            dismiss()
        }
    }
}
