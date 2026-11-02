import SwiftUI
import CoreImage.CIFilterBuiltins
import VisionKit
import AVFoundation

struct SocialFriendsScreen: View {
    @Environment(SocialAppModel.self) private var app
    var body: some View {
        List {
            if app.snapshot.friendships.isEmpty { ContentUnavailableView("Find your training partners",systemImage:"person.2",description:Text("Connect after class using a friend code.")) }
            ForEach(app.snapshot.friendships) { friendship in
                let other = friendship.text("a")==app.userID ? friendship.text("b"):friendship.text("a")
                NavigationLink {
                    List {
                        let streak = app.streak(friendship)
                        Text("\(streak.current) week streak · best \(streak.best)")
                        Text("Monday–Sunday · \(friendship.text("timezone"))").font(.caption)
                        Text("A week counts when you both attend at least one completed session together.")
                        Button("Block this user",role:.destructive) { Task { await app.perform("block_user",["user_id":other]) } }
                        ForEach(app.snapshot.posts.filter{app.postPeople($0.id).contains(other) && app.postPeople($0.id).contains(app.userID ?? "")}) { post in NavigationLink { SocialPostScreen(postID:post.id) } label:{ Text(post.text("caption").isEmpty ? "Training memory":post.text("caption")) } }
                    }.navigationTitle(app.person(other))
                } label: {
                    let streak = app.streak(friendship)
                    HStack { Text(app.person(other)); Spacer(); Label("\(streak.current) weeks",systemImage:"flame.fill").foregroundStyle(MMColor.flame500) }
                }
            }
        }.navigationTitle("Friends")
        .toolbar { NavigationLink { SocialFriendCodeScreen() } label: { Image(systemName:"qrcode") }.accessibilityLabel("Add friends") }
        .refreshable { await app.refresh() }
    }
}
struct SocialFriendCodeScreen: View {
    @Environment(SocialAppModel.self) private var app
    @State private var url: URL?
    @State private var input = ""
    @State private var scanning = false
    @State private var cameraAllowed = false
    var body: some View {
        List {
            if app.userID == nil { Text("Sign in from Profile to connect with friends.") }
            if let url {
                if let image = qrImage(url.absoluteString) { Image(uiImage:image).interpolation(.none).resizable().scaledToFit().padding(24).accessibilityLabel("Your friend QR code") }
                ShareLink(item:url) { Text("Share friend code") }
                Text("This code connects a partner instantly and expires after one day. Generating a new code revokes the old one.").font(.caption)
            }
            Button("Generate my code") { Task { if let r = await app.perform("friend_token",[:]),let token = r["token"]?.string { url = app.link(kind:"friend",token:token) } } }.disabled(app.userID == nil || app.busy)
            Button("Scan a partner’s code") { Task { cameraAllowed = await AVCaptureDevice.requestAccess(for:.video); if cameraAllowed && DataScannerViewController.isSupported && DataScannerViewController.isAvailable { scanning = true } else { app.error = "Camera scanning is unavailable. Paste the partner’s invitation link below." } } }
            TextField("Paste invitation link",text:$input).textInputAutocapitalization(.never).autocorrectionDisabled()
            Button("Open invitation") { if let url = URL(string:input) { app.handle(url); Task { await app.redeemPendingLink() } } }.disabled(input.isEmpty || app.userID == nil)
        }.navigationTitle("Add friends")
        .sheet(isPresented:$scanning) { PartnerScanner { value in scanning = false; if let url = URL(string:value) { app.handle(url); Task { await app.redeemPendingLink() } } } }
    }
    private func qrImage(_ text:String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator(); filter.message = Data(text.utf8)
        guard let image = filter.outputImage?.transformed(by:CGAffineTransform(scaleX:8,y:8)),let cg = CIContext().createCGImage(image,from:image.extent) else { return nil }
        return UIImage(cgImage:cg)
    }
}
private struct PartnerScanner: UIViewControllerRepresentable {
    let found: (String)->Void
    func makeCoordinator()->Coordinator { Coordinator(found:found) }
    func makeUIViewController(context:Context)->DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes:[.barcode(symbologies:[.qr])],qualityLevel:.balanced,recognizesMultipleItems:false,isHighlightingEnabled:true)
        scanner.delegate = context.coordinator
        do { try scanner.startScanning() } catch { context.coordinator.found("") }
        return scanner
    }
    func updateUIViewController(_ controller:DataScannerViewController,context:Context) {}
    static func dismantleUIViewController(_ controller:DataScannerViewController,coordinator:Coordinator) { controller.stopScanning() }
    final class Coordinator:NSObject,DataScannerViewControllerDelegate {
        let found:(String)->Void
        var done=false
        init(found:@escaping(String)->Void){self.found=found}
        func dataScanner(_ scanner:DataScannerViewController,didAdd addedItems:[RecognizedItem],allItems:[RecognizedItem]) {
            guard !done else{return}
            for item in addedItems { if case .barcode(let barcode)=item,let value=barcode.payloadStringValue { done=true;scanner.stopScanning();found(value);return } }
        }
    }
}
struct SocialProfileScreen: View {
    @Environment(SocialAppModel.self) private var app
    var body: some View {
        List {
            if let me=app.me {
                Section { Text(me.text("name")).mmFont(.display,30); Text(me.text("gym")); Text("\(me.text("belt").capitalized) belt · \(me.number("stripes")) stripes") }
                Section("Activity") {
                    ForEach(app.snapshot.posts.filter{app.postPeople($0.id).contains(app.userID ?? "")}) { post in NavigationLink { SocialPostScreen(postID:post.id) } label:{ Text(post.text("caption").isEmpty ? "Training memory":post.text("caption")) } }
                }
            } else {
                Text("Welcome to Mat Mind").mmFont(.display,28)
                Text("Connect with your partners and plan your next session.")
                if app.userID == nil {
                    Button("Continue with Apple") { Task { await app.authenticate("apple") } }.disabled(app.busy)
                    Button("Continue with Google") { Task { await app.authenticate("google") } }.disabled(app.busy)
                } else { NavigationLink("Create your profile") { SocialSettingsScreen() } }
            }
        }.navigationTitle("Profile")
        .toolbar { NavigationLink { SocialSettingsScreen() } label: { Image(systemName:"gearshape") }.accessibilityLabel("Settings") }
    }
}
struct SocialSettingsScreen: View {
    @Environment(SocialAppModel.self) private var app
    @State private var name=""
    @State private var gym=""
    @State private var belt="white"
    @State private var stripes=0
    @State private var delete=false
    var body: some View {
        Form {
            if app.userID != nil {
                Section("Profile") {
                    TextField("Name",text:$name); TextField("Home gym",text:$gym)
                    Picker("Belt",selection:$belt) { ForEach(["white","blue","purple","brown","black","coral","red","grey","yellow","orange","green"],id:\.self){Text($0.capitalized).tag($0)} }
                    Stepper("Stripes: \(stripes)",value:$stripes,in:0...4)
                    Button("Save profile") { Task { await app.perform("save_profile",["name":name,"gym":gym,"belt":belt,"stripes":stripes,"timezone":TimeZone.current.identifier]) } }.disabled(name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || app.busy)
                }
                Section {
                    Button("Enable notifications") { Task { await SocialPushCoordinator.register(in:app) } }
                    Button("Sign out") { Task { await app.logout() } }
                    Button("Delete cloud account",role:.destructive) { delete=true }
                }
            }
            // The sole production entry to legacy data. No archive tab, home card,
            // onboarding branch, social import or demo-data fallback exists.
            if !app.archive.archives.isEmpty {
                Section { NavigationLink("Previous training data") { PreviousTrainingDataScreen(model:app.archive) } }
            }
            if app.archive.loading { ProgressView("Checking local data…") }
            if !app.archive.issues.isEmpty {
                Section("Local data recovery") {
                    ForEach(app.archive.issues,id:\.self){Text($0).font(.footnote)}
                    Button("Retry local data check") { Task { await app.archive.discover() } }
                }
            }
            if let message=app.message { Text(message).foregroundStyle(.secondary) }
        }.navigationTitle("Settings")
        .onAppear { name=app.me?.text("name") ?? ""; gym=app.me?.text("gym") ?? ""; belt=app.me?.text("belt") ?? "white"; stripes=app.me?.number("stripes") ?? 0 }
        .confirmationDialog("Delete your cloud account and social data? This cannot be undone. Local training archives stay on this device.",isPresented:$delete,titleVisibility:.visible) { Button("Delete cloud account",role:.destructive) { Task { await app.deleteAccount() } } }
    }
}
struct SocialNotificationsScreen: View {
    @Environment(SocialAppModel.self) private var app
    var body: some View {
        List(app.snapshot.notifications) { row in
            VStack(alignment:.leading) { Text(app.person(row.text("actor")) + " " + row.text("message")); if let date=row.date("created_at"){Text(date,style:.relative).font(.caption)} }
            if row.text("kind")=="invite" || row.text("kind")=="joined" { NavigationLink("Open session") { SocialSessionScreen(id:row.text("entity_id")) } }
            else { NavigationLink("Open memory") { SocialPostScreen(postID:row.text("entity_id")) } }
        }.navigationTitle("Notifications").task { await app.perform("read_notifications",[:]) }
    }
}
