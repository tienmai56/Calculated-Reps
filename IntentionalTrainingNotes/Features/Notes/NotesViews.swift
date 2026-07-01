import SwiftUI
import UIKit

struct NotesListView: View {
    @ObservedObject var store: NotebookStore
    @State private var selectedNote: Note?
    @State private var isCreatingNote = false
    @State private var isEditingNote = false
    @State private var actionSheetNoteId: String?
    @State private var confirmDeleteNoteId: String?

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all)
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("NOTES")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .tracking(1.5)
                        .foregroundColor(AppColors.secondaryLabel)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                if store.sortedNotes.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "note.text")
                            .font(.system(size: 40, design: .rounded))
                            .foregroundColor(Color(.systemGray3))
                        Text("No notes yet")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(AppColors.secondaryLabel)
                        Text("Tap + to start writing.")
                            .font(.matMindBody(size: 15))
                            .foregroundColor(Color(.systemGray2))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(store.sortedNotes) { note in
                                ZStack(alignment: .topTrailing) {
                                    NoteRowView(note: note)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedNote = note
                                            isEditingNote = true
                                        }

                                    // 3-dots menu button
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            actionSheetNoteId = actionSheetNoteId == note.id ? nil : note.id
                                        }
                                    }) {
                                        Image(systemName: "ellipsis")
                                            .foregroundColor(AppColors.label)
                                            .frame(width: 32, height: 32)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(.trailing, 8)
                                    .padding(.top, 8)

                                    // Dropdown menu overlay
                                    if actionSheetNoteId == note.id {
                                        VStack(alignment: .leading, spacing: 0) {
                                            Button(action: {
                                                withAnimation(.easeInOut(duration: 0.15)) {
                                                    actionSheetNoteId = nil
                                                }
                                                confirmDeleteNoteId = note.id
                                            }) {
                                                HStack(spacing: 10) {
                                                    Image(systemName: "trash")
                                                        .font(.matMindBody(size: 14))
                                                        .foregroundColor(AppColors.coral)
                                                    Text("Delete")
                                                        .font(.matMindBody(size: 15))
                                                        .foregroundColor(AppColors.coral)
                                                    Spacer()
                                                }
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 12)
                                                .contentShape(Rectangle())
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                        .background(AppColors.background)
                                        .cornerRadius(12)
                                        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
                                        .frame(width: 160)
                                        .offset(x: -8, y: 36)
                                        .transition(.opacity)
                                        .zIndex(10)
                                    }
                                }
                                .zIndex(actionSheetNoteId == note.id ? 10 : 0)
                            }
                        }
                        .background(AppColors.background)
                        .cornerRadius(10)
                        .padding(.horizontal, 16)
                    }
                }
            }

            // Floating compose button (centered bottom, like Apple Notes)
            VStack {
                Spacer()
                Button(action: {
                    selectedNote = nil
                    isCreatingNote = true
                }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(AppColors.indigo)
                        .clipShape(Circle())
                        .shadow(color: AppColors.indigo.opacity(0.35), radius: 8, x: 0, y: 4)
                }
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $isEditingNote) {
            NoteEditorView(store: store, noteId: selectedNote?.id, onDone: {
                isEditingNote = false
            })
        }
        .sheet(isPresented: $isCreatingNote) {
            NoteEditorView(store: store, noteId: nil, onDone: {
                isCreatingNote = false
            })
        }
        .alert(isPresented: Binding(
            get: { confirmDeleteNoteId != nil },
            set: { if !$0 { confirmDeleteNoteId = nil } }
        )) {
            Alert(
                title: Text("Delete Note"),
                message: Text("This note will be permanently deleted."),
                primaryButton: .destructive(Text("Delete")) {
                    if let id = confirmDeleteNoteId {
                        store.deleteNote(id: id)
                    }
                    confirmDeleteNoteId = nil
                },
                secondaryButton: .cancel()
            )
        }
    }
}

struct NoteRowView: View {
    var note: Note

    private var previewSnippet: String {
        let plain = note.body.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\[image: [^\\]]+\\]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if plain.isEmpty { return "No additional text" }
        return String(plain.prefix(80))
    }

    private var displayTitle: String {
        let t = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "New Note" : t
    }

    private var dateLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(note.updatedAt) {
            return DateFormatter.clockTime.string(from: note.updatedAt)
        } else if cal.isDateInYesterday(note.updatedAt) {
            return "Yesterday"
        } else {
            return DateFormatter.monthDay.string(from: note.updatedAt)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(displayTitle)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.label)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(dateLabel)
                        .font(.matMindBody(size: 14))
                        .foregroundColor(AppColors.secondaryLabel)
                    Text(previewSnippet)
                        .font(.matMindBody(size: 14))
                        .foregroundColor(AppColors.secondaryLabel)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().padding(.leading, 16)
        }
    }
}

// MARK: - Note Editor (Apple Notes style)

struct NoteEditorView: View {
    @ObservedObject var store: NotebookStore
    var noteId: String?
    var onDone: () -> Void

    @State private var title: String = ""
    @State private var bodyText: String = ""
    @State private var showDeleteConfirm = false
    @State private var noteWasDeleted = false
    @State private var showImagePicker = false
    @State private var focusBody = false
    @State private var saveTimer: Timer?
    @State private var isKeyboardVisible = false

    private var isNewNote: Bool { noteId == nil }
    @State private var createdNoteId: String?

    private var effectiveNoteId: String? { noteId ?? createdNoteId }

    var body: some View {
        VStack(spacing: 0) {
            // Top navigation bar — mirrors Apple Notes
            noteEditorTopBar

            Divider()

            // Scrollable content area
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Title field
                    NotesTitleField(title: $title, onChanged: scheduleSave, onReturn: {
                        focusBody = true
                    })
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 4)

                    // Date stamp (like Apple Notes shows date under title)
                    if let noteId = effectiveNoteId,
                       let note = store.notebook.notes.first(where: { $0.id == noteId }) {
                        Text(noteDateStamp(note.updatedAt))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(Color(.systemGray2))
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                    }

                    // Body editor
                    // Attached images (above body so they appear near cursor context)
                    if let noteId = effectiveNoteId,
                       let note = store.notebook.notes.first(where: { $0.id == noteId }),
                       !note.imageFileNames.isEmpty,
                       let persistence = store.persistence as? JSONNotebookPersistence {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(note.imageFileNames, id: \.self) { fileName in
                                if let data = persistence.loadNoteImage(
                                    accountId: store.notebook.accountId,
                                    noteId: noteId,
                                    fileName: fileName
                                ), let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }

                    NoteBodyEditor(text: $bodyText, onImageRequest: {
                        showImagePicker = true
                    }, onTextChanged: scheduleSave, shouldFocus: $focusBody)
                    .frame(minHeight: 200)
                    .padding(.horizontal, 16)
                }
            }

        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
        .onAppear {
            if let noteId = noteId, let note = store.notebook.notes.first(where: { $0.id == noteId }) {
                title = note.title
                bodyText = note.body
            }
        }
        .onDisappear {
            saveTimer?.invalidate()
            saveNote()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .alert(isPresented: $showDeleteConfirm) {
            Alert(
                title: Text("Delete Note"),
                message: Text("This note will be permanently deleted."),
                primaryButton: .destructive(Text("Delete")) {
                    noteWasDeleted = true
                    if let id = effectiveNoteId {
                        store.deleteNote(id: id)
                    }
                    onDone()
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showImagePicker) {
            NoteImagePicker(onImageSelected: { imageData in
                if let id = effectiveNoteId ?? createNoteIfNeeded(),
                   let persistence = store.persistence as? JSONNotebookPersistence {
                    let fileName = "\(UUID().uuidString).jpg"
                    _ = try? persistence.saveNoteImage(
                        accountId: store.notebook.accountId,
                        noteId: id,
                        imageData: imageData,
                        fileName: fileName
                    )
                    var fileNames = store.notebook.notes.first(where: { $0.id == id })?.imageFileNames ?? []
                    fileNames.append(fileName)
                    store.updateNote(id: id, title: title, body: bodyText, imageFileNames: fileNames)
                    scheduleSave()
                }
            })
        }
    }

    // MARK: Top bar — < back, undo, share, ⋯, yellow done checkmark
    private var noteEditorTopBar: some View {
        HStack(spacing: 16) {
            // Back button
            Button(action: {
                saveNote()
                onDone()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.indigo)
            }

            Spacer()

            // Done checkmark (yellow, like Apple Notes)
            if isKeyboardVisible {
                Button(action: {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    saveNote()
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24, weight: .regular, design: .rounded))
                        .foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.0))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func noteDateStamp(_ date: Date) -> String {
        return DateFormatter.fullDateTimeAt.string(from: date)
    }

    private func createNoteIfNeeded() -> String? {
        if let existing = effectiveNoteId { return existing }
        let note = store.addNote(title: title, body: bodyText)
        createdNoteId = note.id
        return note.id
    }

    private func scheduleSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            DispatchQueue.main.async {
                saveNote()
            }
        }
    }

    private func saveNote() {
        guard !noteWasDeleted else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty || !trimmedBody.isEmpty else { return }

        if let id = effectiveNoteId {
            store.updateNote(id: id, title: title, body: bodyText, imageFileNames: nil)
        } else {
            let note = store.addNote(title: title, body: bodyText)
            createdNoteId = note.id
        }
    }
}

// MARK: - Notes Title Field (iOS 13 compatible)

struct NotesTitleField: UIViewRepresentable {
    @Binding var title: String
    var onChanged: () -> Void
    var onReturn: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.font = UIFont.systemFont(ofSize: 26, weight: .medium)
        field.textColor = UIColor.label
        field.placeholder = "Title"
        field.borderStyle = .none
        field.returnKeyType = .next
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != title { uiView.text = title }
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: NotesTitleField
        init(_ parent: NotesTitleField) { self.parent = parent }
        @objc func textChanged(_ sender: UITextField) {
            parent.title = sender.text ?? ""
            parent.onChanged()
        }
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onReturn?()
            return false
        }
    }
}

// MARK: - Note Body Editor (UITextView Wrapper)

struct NoteBodyEditor: UIViewRepresentable {
    @Binding var text: String
    var onImageRequest: () -> Void
    var onTextChanged: (() -> Void)?
    @Binding var shouldFocus: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.textColor = UIColor.label
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.delegate = context.coordinator
        textView.textContainerInset = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)

        // Formatting toolbar above keyboard (bold, italic, bullets, heading)
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        toolbar.sizeToFit()

        let textStyle = UIBarButtonItem(image: UIImage(systemName: "textformat.alt"), style: .plain, target: nil, action: nil)
        let checklist = UIBarButtonItem(image: UIImage(systemName: "checklist"), style: .plain, target: context.coordinator, action: #selector(Coordinator.insertBullet))
        let attachment = UIBarButtonItem(image: UIImage(systemName: "paperclip"), style: .plain, target: context.coordinator, action: #selector(Coordinator.requestImage))
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        let spacer = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        spacer.width = 20
        toolbar.items = [flex, textStyle, spacer, checklist, spacer, attachment, flex]
        textView.inputAccessoryView = toolbar

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        if shouldFocus {
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
                self.shouldFocus = false
            }
        }
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: NoteBodyEditor
        weak var textView: UITextView?

        init(_ parent: NoteBodyEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            self.textView = textView
            parent.text = textView.text
            parent.onTextChanged?()
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            self.textView = textView
        }

        @objc func toggleBold() {
            insertMarkers(around: "**")
        }

        @objc func toggleItalic() {
            insertMarkers(around: "_")
        }

        @objc func toggleUnderline() {
            insertMarkers(around: "__")
        }

        @objc func toggleStrikethrough() {
            insertMarkers(around: "~~")
        }

        @objc func insertBullet() {
            let needsNewline = !parent.text.isEmpty && !parent.text.hasSuffix("\n")
            parent.text += (needsNewline ? "\n" : "") + "• "
        }

        @objc func toggleHeading() {
            let needsNewline = !parent.text.isEmpty && !parent.text.hasSuffix("\n")
            parent.text += (needsNewline ? "\n" : "") + "# "
        }

        @objc func increaseIndent() {
            parent.text += "    "
        }

        @objc func requestImage() {
            parent.onImageRequest()
        }

        private func insertMarkers(around marker: String) {
            guard let tv = textView, let selectedRange = tv.selectedTextRange else {
                parent.text += "\(marker)text\(marker)"
                return
            }
            let selectedText = tv.text(in: selectedRange) ?? ""
            if selectedText.isEmpty {
                parent.text += "\(marker)text\(marker)"
            } else {
                let replacement = "\(marker)\(selectedText)\(marker)"
                tv.replace(selectedRange, withText: replacement)
                parent.text = tv.text
            }
        }
    }
}

// MARK: - Note Image Picker

// MARK: - UIKit Image Picker (presented directly to avoid nested-sheet bug on iOS 13/14)

final class UIKitImagePicker: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private static var active: UIKitImagePicker?
    private let onPick: (Data) -> Void

    private init(onPick: @escaping (Data) -> Void) {
        self.onPick = onPick
    }

    static func present(onPick: @escaping (Data) -> Void) {
        guard let root = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        let presenter = UIKitImagePicker(onPick: onPick)
        active = presenter
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = presenter
        top.present(picker, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let image = info[.originalImage] as? UIImage,
           let data = image.jpegData(compressionQuality: 0.8) {
            onPick(data)
        }
        picker.dismiss(animated: true)
        UIKitImagePicker.active = nil
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        UIKitImagePicker.active = nil
    }
}

struct NoteImagePicker: UIViewControllerRepresentable {
    var onImageSelected: (Data) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: NoteImagePicker

        init(_ parent: NoteImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.8) {
                parent.onImageSelected(data)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Goals

// MARK: - Add Goal Sheet
