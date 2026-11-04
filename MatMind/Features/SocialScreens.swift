import SwiftUI
import PhotosUI

struct SocialActivityScreen: View {
    @Environment(SocialAppModel.self) private var app
    var body: some View {
        ScrollView {
            LazyVStack(spacing:16) {
                if app.snapshot.posts.isEmpty { ContentUnavailableView("Train together. Share the memory.",systemImage:"photo.on.rectangle",description:Text("Completed sessions shared by your friends appear here.")) }
                ForEach(app.snapshot.posts.sorted { $0.text("published_at") > $1.text("published_at") }) { post in NavigationLink { SocialPostScreen(postID:post.id) } label: { SocialPostCard(post:post) }.buttonStyle(.plain) }
                if app.moreFeed && !app.snapshot.posts.isEmpty { Button("Load more") { Task { await app.loadMoreFeed() } }.disabled(app.busy) }
            }.padding()
        }
        .background(MMColor.bgApp).navigationTitle("mat monkey.")
        .toolbar { NavigationLink { SocialNotificationsScreen() } label: { Image(systemName:"bell") }.accessibilityLabel("Notifications") }
        .refreshable { await app.refresh() }
    }
}
struct SocialPostCard: View {
    @Environment(SocialAppModel.self) private var app
    let post: SocialRow
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            Text(post.text("title").isEmpty ? "Training together" : post.text("title")).mmFont(.display,22)
            if let media = app.snapshot.media.first(where:{$0.id==post.text("media_id")}) { CloudPhoto(objectKey:media.text("object_key")).frame(height:240).clipped() }
            Text(post.text("caption"))
            Text(app.postPeople(post.id).map(app.person).joined(separator:", ")).font(.caption).foregroundStyle(.secondary)
            Text(post.text("venue"))
            Text(post.date("occurred_at") ?? post.date("published_at") ?? Date(),style:.date).font(.caption).foregroundStyle(.secondary)
        }.padding(16).frame(maxWidth:.infinity,alignment:.leading).background(.white,in:RoundedRectangle(cornerRadius:24))
    }
}
struct CloudPhoto: View {
    @Environment(SocialAppModel.self) private var app
    let objectKey: String
    @State private var data: Data?
    var body: some View {
        Group {
            if let data,let image = UIImage(data:data) { Image(uiImage:image).resizable().scaledToFill() }
            else { Rectangle().fill(MMColor.paper2).overlay(Image(systemName:"photo")) }
        }.task(id:objectKey) { data = try? await app.backend.image(key:objectKey) }
    }
}
struct SocialPostScreen: View {
    @Environment(SocialAppModel.self) private var app
    let postID: String
    @State private var comment = ""
    @State private var caption = ""
    @State private var edit = false
    @State private var delete = false
    @State private var commentKey = UUID()
    var body: some View {
        if let post = app.snapshot.posts.first(where:{$0.id==postID}) {
            List {
                SocialPostCard(post:post).listRowInsets(EdgeInsets())
                let liked = app.snapshot.likes.contains { $0.text("post_id")==postID && $0.text("user_id")==app.userID }
                Button(liked ? "Unlike" : "Like") { Task { await app.perform("set_like",["post_id":postID,"liked":!liked]) } }
                Section("Comments") {
                    ForEach(app.snapshot.comments.filter { $0.text("post_id")==postID }.reversed()) { row in VStack(alignment:.leading) { Text(app.person(row.text("author"))).font(.caption.bold()); Text(row.text("body")) } }
                    Button("Load earlier comments") { Task { await app.loadMoreComments(postID) } }
                    TextField("Add a comment",text:$comment,axis:.vertical).onChange(of:comment) { _,_ in commentKey = UUID() }
                    Button("Send") { Task { if await app.perform("add_comment",["post_id":postID,"body":comment],key:commentKey) != nil { comment = "" } } }.disabled(comment.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || app.busy)
                }
                Section {
                    if post.text("author")==app.userID {
                        Button("Edit caption") { caption = post.text("caption"); edit = true }
                        Button("Delete shared post",role:.destructive) { delete = true }
                    }
                    Button("Remove me from this post") { Task { await app.perform("remove_tag",["post_id":postID]) } }
                }
            }.navigationTitle("Training memory")
            .sheet(isPresented:$edit) {
                NavigationStack { Form { TextField("Caption",text:$caption,axis:.vertical); Button("Save") { Task { if await app.perform("edit_post",["post_id":postID,"caption":caption,"version":post.number("version")]) != nil { edit = false } } } }.navigationTitle("Edit caption") }
            }
            .confirmationDialog("Delete this shared memory from every profile? Training attendance and streak credit remain.",isPresented:$delete,titleVisibility:.visible) { Button("Delete",role:.destructive) { Task { await app.perform("delete_post",["post_id":postID,"version":post.number("version")]) } } }
        } else { ContentUnavailableView("Post unavailable",systemImage:"photo",description:Text("It may have been removed or its visibility changed.")).task { await app.hydratePost(postID) } }
    }
}
struct SocialTrainingScreen: View {
    @Environment(SocialAppModel.self) private var app
    var body: some View {
        List {
            if app.snapshot.sessions.isEmpty { ContentUnavailableView("Make time for the mat",systemImage:"calendar",description:Text("Plan a training and invite a training partner.")) }
            ForEach(app.snapshot.sessions.sorted { ($0.date("starts_at") ?? .distantPast) > ($1.date("starts_at") ?? .distantPast) }) { s in
                NavigationLink { SocialSessionScreen(id:s.id) } label: {
                    VStack(alignment:.leading,spacing:6) { Text(s.text("title")).font(.headline); Text(s.date("starts_at") ?? .distantPast,style:.date); Text(s.text("venue") + " · " + s.text("status")).font(.caption).foregroundStyle(.secondary) }
                }
            }
        }.navigationTitle("Training").refreshable { await app.refresh() }
    }
}
struct SocialSessionScreen: View {
    @Environment(SocialAppModel.self) private var app
    let id: String
    @State private var complete = false
    @State private var inviteLink: URL?
    @State private var editing = false
    var body: some View {
        if let s = app.session(id) {
            List {
                Section(s.text("title")) {
                    if let date = s.date("starts_at") { Text(date,format:.dateTime.weekday().month().day().hour().minute().timeZone()) }
                    Text(s.text("timezone")); Text(s.text("venue")); Text(s.text("note"))
                }
                Section("Training partners") {
                    ForEach(app.attendees(id),id:\.id) { person in
                        HStack { Text(app.person(person.text("user_id"))); Spacer(); Text(person.text("rsvp")).foregroundStyle(.secondary) }
                        if s.text("organizer")==app.userID, person.text("user_id") != app.userID, s.text("status")=="planned" {
                            Button("Remove participant",role:.destructive) { Task { await app.perform("manage_participant",["session_id":id,"user_id":person.text("user_id"),"remove":true]) } }
                        }
                    }
                    if s.text("organizer")==app.userID, s.text("status")=="planned" {
                        ForEach(app.friendIDs.filter { fid in !app.attendees(id).contains { $0.text("user_id")==fid } },id:\.self) { friend in
                            Button("Add \(app.person(friend))") { Task { await app.perform("manage_participant",["session_id":id,"user_id":friend,"remove":false]) } }
                        }
                    }
                }
                if s.text("status")=="planned" {
                    if s.text("organizer")==app.userID {
                        Button("Edit session") { editing = true }
                        Button("Complete & share") { complete = true }.disabled((s.date("starts_at") ?? .distantFuture)>Date())
                        Button("Create invitation link") { Task { if let r = await app.perform("session_token",["session_id":id]), let token = r["token"]?.string { inviteLink = app.link(kind:"session",token:token) } } }
                        if let inviteLink { ShareLink(item:inviteLink) { Text("Share invitation") } }
                        Button("Cancel session",role:.destructive) { Task { await app.perform("cancel_session",["session_id":id]) } }
                    } else {
                        Button("Join") { Task { await app.perform("set_rsvp",["session_id":id,"rsvp":"going"]) } }
                        Button("Decline") { Task { await app.perform("set_rsvp",["session_id":id,"rsvp":"declined"]) } }
                    }
                } else if s.text("status")=="completed" {
                    Button("I did not attend — correct my attendance") { Task { await app.perform("correct_attendance",["session_id":id,"user_id":app.userID ?? "","attended":false]) } }
                }
            }.navigationTitle("Session").sheet(isPresented:$complete) { NavigationStack { SocialCompleteScreen(session:s) }.environment(app) }.sheet(isPresented:$editing) { NavigationStack { SocialEditSessionScreen(session:s) }.environment(app) }
        } else { ContentUnavailableView("Session unavailable",systemImage:"calendar") }
    }
}
private struct PlanningDraft: Codable, Equatable {
    var title = "Training together"
    var venue = ""
    var note = ""
    var starts = Date()
    var invited: [String] = []
    var key = UUID()
}
struct SocialCreateScreen: View {
    @Environment(SocialAppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var draft = PlanningDraft()
    var body: some View {
        Form {
            if app.userID == nil || app.me == nil { Text("Sign in and create your profile to invite training partners. You can save a draft here.") }
            TextField("Session title",text:$draft.title)
            DatePicker("When",selection:$draft.starts)
            Text("Time zone: \(TimeZone.current.identifier)").font(.caption)
            TextField("Gym or venue",text:$draft.venue)
            TextField("Training note",text:$draft.note,axis:.vertical)
            Section("Invite friends") {
                ForEach(app.friendIDs,id:\.self) { id in
                    Toggle(app.person(id),isOn:Binding(get:{draft.invited.contains(id)},set:{ selected in if selected { draft.invited.append(id) } else { draft.invited.removeAll{$0==id} } }))
                }
            }
            Button("Save session") { Task {
                let payload: [String:Any] = ["title":draft.title,"venue":draft.venue,"note":draft.note,"starts_at":ISO8601DateFormatter().string(from:draft.starts),"timezone":TimeZone.current.identifier,"invited":draft.invited]
                if await app.perform("create_session",payload,key:draft.key) != nil { app.clearDraft(key:"plan"); dismiss() }
            } }.disabled(app.userID == nil || app.me == nil || draft.title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || draft.venue.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || app.busy)
            Text("Past sessions can be logged using their actual date and time. Legacy archive records are never used here.").font(.caption).foregroundStyle(.secondary)
        }.navigationTitle("Plan a training")
        .toolbar { Button("Close") { dismiss() } }
        .onAppear { if let saved = app.draft(PlanningDraft.self,key:"plan") { draft = saved } }
        .onChange(of:draft) { old,new in
            if old.key == new.key { draft.key = UUID() }
            app.saveDraft(draft,key:"plan")
        }
    }
}
private struct CompletionDraft: Codable, Equatable {
    var caption = ""
    var attendees: [String] = []
    var photo: Data?
    var key = UUID()
    var mediaKey = UUID()
}
struct SocialCompleteScreen: View {
    @Environment(SocialAppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let session: SocialRow
    @State private var draft = CompletionDraft()
    @State private var photo: PhotosPickerItem?
    @State private var publishing = false
    @State private var published = false
    @State private var camera = false
    private var draftKey: String { "complete:" + session.id }
    var body: some View {
        Form {
            if published {
                ContentUnavailableView("Shared with the crew",systemImage:"checkmark.circle",description:Text("Your memory is in Activity. Weekly streaks have been updated from confirmed attendance."))
                Button("See Activity") { app.tab = 0; dismiss() }
            } else {
                TextField("What happened on the mat?",text:$draft.caption,axis:.vertical)
                PhotosPicker("Choose a training photo",selection:$photo,matching:.images)
                if UIImagePickerController.isSourceTypeAvailable(.camera) { Button("Take photo") { camera = true } }
                if let data = draft.photo, let image = UIImage(data:data) { Image(uiImage:image).resizable().scaledToFit().frame(maxHeight:250) }
                Section("Who actually trained?") {
                    ForEach(app.attendees(session.id).filter { $0.text("rsvp")=="going" },id:\.id) { person in
                        let id = person.text("user_id")
                        Toggle(app.person(id),isOn:Binding(get:{draft.attendees.contains(id)},set:{selected in if selected { draft.attendees.append(id) } else { draft.attendees.removeAll{$0==id} } })).disabled(id==app.userID)
                    }
                }
                Text("Shared with attendees and friends of tagged attendees. You can remove a profile tag later without changing attendance.").font(.caption)
                if !ShareRule.canPublish(hasPhoto: draft.photo != nil, caption: draft.caption) { Text("Add a photo, a few words, or both to share.").font(.caption) }
                Button("Publish to Activity") { Task { await publish() } }.disabled(publishing || app.busy || !ShareRule.canPublish(hasPhoto: draft.photo != nil, caption: draft.caption))
                if publishing { ProgressView("Uploading photo and publishing…") }
            }
        }.navigationTitle("Complete & share")
        .onAppear {
            draft = app.draft(CompletionDraft.self,key:draftKey) ?? CompletionDraft(attendees:app.attendees(session.id).filter{$0.text("rsvp")=="going"}.map{$0.text("user_id")})
        }
        .onChange(of:draft) { old,new in if old.key == new.key { draft.key = UUID() }; app.saveDraft(draft,key:draftKey) }
        .task(id:photo) {
            guard let photo else { return }
            do {
                guard let bytes = try await photo.loadTransferable(type:Data.self), let image = UIImage(data:bytes), let data = normalizedPhoto(image) else { throw CloudError(message:"Could not read photo.") }
                draft.photo = data; draft.mediaKey = UUID()
            } catch { app.error = error.localizedDescription }
        }
        .sheet(isPresented:$camera) { TrainingCamera { image in if let image { draft.photo = normalizedPhoto(image); draft.mediaKey = UUID() }; camera = false } }
    }
    private func normalizedPhoto(_ image: UIImage) -> Data? {
        let scale = min(1,1600/max(image.size.width,image.size.height))
        let size = CGSize(width:image.size.width*scale,height:image.size.height*scale)
        // Rendering strips original EXIF, including location, and normalizes orientation.
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size:size,format:format).image { _ in image.draw(in:CGRect(origin:.zero,size:size)) }.jpegData(compressionQuality:0.8)
    }
    private func publish() async {
        publishing = true; defer { publishing = false }
        do {
            var payload: [String:Any] = ["session_id":session.id,"caption":draft.caption,"attendees":draft.attendees]
            if let data = draft.photo {
                let media = try await app.backend.command("prepare_media",payload:["session_id":session.id],key:draft.mediaKey)
                guard let id = media["id"]?.string, let key = media["object_key"]?.string else { throw CloudError(message:"Could not prepare photo.") }
                do { try await app.backend.upload(data,objectKey:key) }
                catch { let existing = try await app.backend.image(key:key); guard existing == data else { throw error } }
                payload["media_id"] = id
            }
            if await app.perform("complete_and_publish",payload,key:draft.key) != nil { app.clearDraft(key:draftKey); published = true }
        } catch { app.error = "Could not publish: \(error.localizedDescription). Your draft is saved for retry." }
    }
}
private struct TrainingCamera: UIViewControllerRepresentable {
    let completed: (UIImage?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completed:completed) }
    func makeUIViewController(context:Context) -> UIImagePickerController { let c = UIImagePickerController(); c.sourceType = .camera; c.delegate = context.coordinator; return c }
    func updateUIViewController(_ controller:UIImagePickerController,context:Context) {}
    final class Coordinator: NSObject,UIImagePickerControllerDelegate,UINavigationControllerDelegate {
        let completed: (UIImage?) -> Void
        init(completed:@escaping(UIImage?)->Void) { self.completed = completed }
        func imagePickerControllerDidCancel(_ picker:UIImagePickerController) { completed(nil) }
        func imagePickerController(_ picker:UIImagePickerController,didFinishPickingMediaWithInfo info:[UIImagePickerController.InfoKey:Any]) { completed(info[.originalImage] as? UIImage) }
    }
}

struct SocialEditSessionScreen: View {
    @Environment(SocialAppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let session: SocialRow
    @State private var title = ""
    @State private var venue = ""
    @State private var note = ""
    @State private var starts = Date()
    var body: some View {
        Form {
            TextField("Title",text:$title)
            DatePicker("When",selection:$starts)
            TextField("Venue",text:$venue)
            TextField("Note",text:$note,axis:.vertical)
            Button("Save changes") { Task {
                if await app.perform("edit_session",["session_id":session.id,"version":session.number("version"),"title":title,"venue":venue,"note":note,"starts_at":ISO8601DateFormatter().string(from:starts),"timezone":session.text("timezone")]) != nil { dismiss() }
            } }.disabled(app.busy || title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || venue.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
        }.navigationTitle("Edit session")
        .onAppear { title=session.text("title");venue=session.text("venue");note=session.text("note");starts=session.date("starts_at") ?? Date() }
    }
}
