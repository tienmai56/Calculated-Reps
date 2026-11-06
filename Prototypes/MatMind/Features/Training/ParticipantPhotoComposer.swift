import SwiftUI
import PhotosUI
import UIKit

/// A participant's one session photo. Picking a replacement is only a local draft
/// until Post/Replace succeeds; the host's Activity composer remains separate.
struct ParticipantPhotoComposer: View {
    @Environment(AppModel.self) private var mm
    @Environment(\.dismiss) private var dismiss
    let draft: ParticipantPhotoDraft
    private var sessionID: String { draft.sessionID }
    private var replacingPhotoID: String? { draft.replacingPhotoID }
    @State private var library = false
    @State private var samplePicker = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var photo: String?
    @State private var draftFiles: [URL] = []
    @State private var reading = false
    @State private var posting = false
    @State private var posted = false
    @State private var error: String?

    var body: some View {
        if let session = mm.findSession(sessionID) {
            MMScreen {
                MMHeader(title: replacingPhotoID == nil ? "Add your photo" : "Replace your photo", leading: {
                    MMIconButton("x", label: "Cancel photo") { dismiss() }.disabled(posting)
                })
            } content: {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: MMSpace.s5) {
                        Text(session.title).mmFont(.display, 22)
                        summaryRow("map-pin", session.gym)
                        summaryRow("user", "Hosted by \(mm.person(session.organizer).name)")
                        summaryRow(session.privacy == .link ? "globe" : "lock", session.privacy == .link ? "Session access: anyone with the link" : "Friends only")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(MMSpace.s6)
                    .mmCardSurface(radius: MMRadius.lg)
                    .padding(.top, MMSpace.s2)
                    if let photo {
                        MMPhotoTile(photo: photo, height: 330, radius: 26) {
                            MMIconButton("repeat-2", variant: .overlay, label: "Change photo") { choosePhoto() }
                                .disabled(posting || reading)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                .padding(MMSpace.s5)
                        }
                        .padding(.top, MMLayout.sectionGap)
                    } else {
                        MMButton("Choose a photo", variant: .secondary, iconLeft: "image-plus", fullWidth: true) { choosePhoto() }
                            .disabled(reading || posting)
                            .padding(.top, MMLayout.sectionGap)
                    }
                    Text("\(mm.me.name) (you)").mmFont(.body, 15, .bold).padding(.top, MMSpace.s5)
                    Text("One photo per person, per session.")
                        .mmFont(.body, 13).foregroundStyle(MMColor.textTertiary).padding(.top, MMSpace.s4)
                    if reading { ProgressView("Reading photo…").padding(.top, MMSpace.s5) }
                    if let error {
                        Text(error).mmFont(.body, 13).foregroundStyle(MMColor.danger500)
                            .padding(.top, MMSpace.s5)
                    }
                }
                .padding(.horizontal, MMSpace.s6)
                .padding(.bottom, MMSpace.s6)
            } footer: {
                VStack(spacing: MMSpace.s4) {
                    Text("Shared with the same people as this session.")
                        .mmFont(.body, 13).foregroundStyle(MMColor.textSecondary).multilineTextAlignment(.center)
                    MMButton(posting ? "Posting…" : replacingPhotoID == nil ? "Post photo" : "Replace photo",
                             size: .lg, iconLeft: "check", fullWidth: true) { post() }
                        .disabled(photo == nil || reading || posting || mm.busy || !mm.canPostParticipantPhoto(session))
                }
            }
            .interactiveDismissDisabled(posting)
            .photosPicker(isPresented: $library, selection: $pickerItem, matching: .images)
            .task { choosePhoto() }
            .task(id: pickerItem) {
                guard let pickerItem else { return }
                reading = true
                defer { reading = false }
                do {
                    guard let data = try await pickerItem.loadTransferable(type: Data.self),
                          !Task.isCancelled, let image = UIImage(data: data),
                          let jpeg = AppModel.goalPhotoJPEG(image) else {
                        if !Task.isCancelled { error = "Couldn't read that photo. Choose another." }
                        return
                    }
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent("participant-\(UUID().uuidString).jpg")
                    try jpeg.write(to: url, options: .atomic)
                    draftFiles.append(url)
                    photo = url.path
                    error = nil
                } catch { if !Task.isCancelled { self.error = "Couldn't read that photo. Choose another." } }
            }
            .mmSheet(isPresented: $samplePicker, title: "Recent photos", description: "Sample photos for the app preview.") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: MMSpace.s3), count: 3), spacing: MMSpace.s3) {
                    ForEach(mm.cameraRoll, id: \.self) { source in
                        Button {
                            photo = source
                            error = nil
                            samplePicker = false
                        } label: {
                            Color.clear.aspectRatio(1, contentMode: .fit)
                                .overlay { Image(source).resizable().scaledToFill() }
                                .clipShape(RoundedRectangle(cornerRadius: MMRadius.sm))
                        }
                        .accessibilityLabel("Choose training photo")
                    }
                }
            }
            .onDisappear {
                // The runtime keeps the successful source as its private image cache.
                for file in draftFiles where !posted || file.path != photo { try? FileManager.default.removeItem(at: file) }
            }
        }
    }

    private func choosePhoto() {
        if mm.isLive { library = true } else { samplePicker = true }
    }

    private func summaryRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: MMSpace.s4) {
            MMIcon(icon, size: 16, color: MMColor.textTertiary).padding(.top, MMSpace.s1)
            Text(text).mmFont(.body, 15).foregroundStyle(MMColor.textSecondary)
        }
    }

    private func post() {
        guard let photo, !posting else { return }
        posting = true
        error = nil
        Task {
            let saved = await mm.postParticipantPhoto(sessionID, photo: photo, replacing: replacingPhotoID)
            posting = false
            if saved { posted = true; dismiss() }
            else { error = "Couldn't post your photo. Try again, or reopen the session if it changed." }
        }
    }
}
