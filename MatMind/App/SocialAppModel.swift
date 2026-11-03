import SwiftUI
import SwiftData

@MainActor @Observable final class SocialAppModel {
    let backend: BackendClient
    let archive = LocalArchiveModel()
    var snapshot = SocialSnapshot()
    var userID: String?
    var error: String?
    var message: String?
    var busy = false
    var moreFeed = true
    var tab = 0
    var pendingLink: URL?
    private var epoch = UUID()
    @ObservationIgnored private var refreshRequest: (id: UUID, task: Task<SocialSnapshot, Error>)?
    private var cache: ModelContainer?
    private let signIn = NativeCloudSignIn()
    init(backend: BackendClient = BackendClient()) {
        self.backend = backend
        do {
            _ = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            cache = try ModelContainer(for: CachedSocialState.self, LocalSocialDraft.self)
        }
        catch { self.error = "Local cache could not open: \(error.localizedDescription). Original training files are unchanged." }
        _ = MMFont.registered
    }
    var me: SocialRow? { snapshot.profiles.first { $0.id == userID } }
    var friendIDs: [String] { snapshot.friendships.map { $0.text("a") == userID ? $0.text("b") : $0.text("a") } }
    func person(_ id: String) -> String { snapshot.profiles.first { $0.id == id }?.text("name") ?? "Training partner" }
    func attendees(_ session: String) -> [SocialRow] { snapshot.participants.filter { $0.text("session_id") == session } }
    func session(_ id: String) -> SocialRow? { snapshot.sessions.first { $0.id == id } }
    func postPeople(_ id: String) -> [String] { snapshot.tags.filter { $0.text("post_id") == id }.map { $0.text("user_id") } }
    func start() async {
        await archive.discover()
        userID = await backend.identity()
        if let userID { restoreCache(userID); await refresh() }
    }
    func refresh(force: Bool = false) async {
        guard userID != nil else { return }
        if force { refreshRequest?.task.cancel(); refreshRequest = nil }
        let generation = epoch
        let request: (id: UUID, task: Task<SocialSnapshot, Error>)
        if let refreshRequest {
            request = refreshRequest
        } else {
            // This read belongs to the signed-in model. SwiftUI can cancel its
            // calling view task while switching from Google sign-in to setup.
            request = (UUID(), Task { [backend] in try await backend.snapshot() })
            refreshRequest = request
        }
        defer { if refreshRequest?.id == request.id { refreshRequest = nil } }
        do {
            let latest = try await request.task.value
            guard generation == epoch, refreshRequest?.id == request.id else { return }
            snapshot = latest; moreFeed = latest.posts.count == 30; persistCache()
        } catch {
            guard generation == epoch, refreshRequest?.id == request.id else { return }
            let failure = error as NSError
            guard !(error is CancellationError),
                  !(failure.domain == NSURLErrorDomain && failure.code == NSURLErrorCancelled) else { return }
            self.error = error.localizedDescription
        }
    }
    func hydratePost(_ id: String) async {
        let generation = epoch
        do {
            let rows = try await backend.postDetails(id)
            guard generation == epoch else { return }
            func merged(_ old: [SocialRow], _ new: [SocialRow]) -> [SocialRow] { old.filter { item in !new.contains(where:{$0.id==item.id}) } + new }
            snapshot.posts = merged(snapshot.posts,rows["posts"] ?? [])
            snapshot.profiles = merged(snapshot.profiles,rows["profiles"] ?? [])
            snapshot.media = merged(snapshot.media,rows["media"] ?? [])
            snapshot.comments = merged(snapshot.comments,rows["comments"] ?? [])
            snapshot.likes = merged(snapshot.likes,rows["likes"] ?? [])
            snapshot.tags = merged(snapshot.tags,rows["participants"] ?? [])
            persistCache()
        } catch { if generation == epoch { self.error = error.localizedDescription } }
    }
    func loadMoreFeed() async {
        guard !busy,let last = snapshot.posts.sorted(by:{$0.text("published_at") > $1.text("published_at")}).last else { return }
        busy=true; defer {busy=false}
        let generation=epoch
        do {
            let rows=try await backend.feed(before:last)
            guard generation==epoch else{return}
            moreFeed=rows.count==30
            for row in rows { await hydratePost(row.id) }
        } catch { if generation==epoch { self.error=error.localizedDescription } }
    }
    func loadMoreComments(_ post: String) async {
        guard let last=snapshot.comments.filter({$0.text("post_id")==post}).sorted(by:{$0.text("created_at")<$1.text("created_at")}).first else{return}
        let generation=epoch
        do { let rows=try await backend.comments(post:post,before:last); guard generation==epoch else{return}; snapshot.comments += rows.filter { row in !snapshot.comments.contains{$0.id==row.id} } }
        catch { if generation==epoch { self.error=error.localizedDescription } }
    }
    func authenticate(_ provider: String) async {
        guard !busy else { return }; busy = true; error = nil; defer { busy = false }
        do {
            guard let config = BackendConfiguration.configured else { throw CloudError(message:"Cloud configuration missing.") }
            if provider == "apple" {
                let (token,nonce) = try await signIn.apple()
                _ = try await backend.signIn(provider:"apple",idToken:token,nonce:nonce)
            } else {
                try await backend.requireGoogleSignIn()
                let (code,verifier) = try await signIn.google(configuration:config)
                try await backend.exchange(code:code,verifier:verifier)
            }
            userID = await backend.identity(); epoch = UUID()
            refreshRequest?.task.cancel(); refreshRequest = nil
            snapshot = SocialSnapshot()
            if let userID { restoreCache(userID) }
            await refresh()
        } catch CloudSignInError.cancelled {
            // Closing the provider sheet leaves the user on Welcome.
        } catch { self.error = error.localizedDescription }
    }
    @discardableResult func perform(_ operation: String, _ payload: [String:Any], key: UUID = UUID()) async -> [String:ArchiveValue]? {
        guard !busy else { return nil }; busy = true; error = nil; defer { busy = false }
        let generation = epoch
        do {
            let result = try await backend.command(operation,payload:payload,key:key)
            guard generation == epoch else { return nil }
            // A read begun before this write may contain the previous profile.
            await refresh(force: true)
            message = "Saved."
            return result
        } catch { if generation == epoch { self.error = error.localizedDescription }; return nil }
    }
    func logout() async {
        error = nil; message = nil
        epoch = UUID(); let old = userID; userID = nil; SocialPushCoordinator.pending = nil; snapshot = SocialSnapshot(); pendingLink = nil
        refreshRequest?.task.cancel(); refreshRequest = nil
        if let cache, let old {
            let context = ModelContext(cache)
            do {
                for row in try context.fetch(FetchDescriptor<CachedSocialState>()) where row.owner == old { context.delete(row) }
                try context.save()
            } catch { self.error = "Could not clear the local social cache: \(error.localizedDescription)" }
        }
        if let token = SocialPushCoordinator.token { _ = try? await backend.command("unregister_device", payload:["token":token]) }
        SocialPushCoordinator.forget()
        await backend.signOut()
    }
    func deleteAccount() async {
        do { try await backend.deleteAccount(); await logout(); message = "Cloud account deleted. Local training archives remain on this device." }
        catch { self.error = error.localizedDescription }
    }
    func saveDraft<T: Encodable>(_ value: T, key: String) {
        guard let cache else { return }
        do {
            let context = ModelContext(cache); let scoped = (userID ?? "guest") + ":" + key
            let data = try JSONEncoder().encode(value)
            if let row = try context.fetch(FetchDescriptor<LocalSocialDraft>()).first(where:{$0.key == scoped}) { row.payload = data }
            else { context.insert(LocalSocialDraft(key:scoped,payload:data)) }
            try context.save()
        } catch { self.error = "Could not save draft: \(error.localizedDescription)" }
    }
    func draft<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let cache else { return nil }
        do {
            let scoped = (userID ?? "guest") + ":" + key
            guard let row = try ModelContext(cache).fetch(FetchDescriptor<LocalSocialDraft>()).first(where:{$0.key == scoped}) else { return nil }
            return try JSONDecoder().decode(type,from:row.payload)
        } catch { self.error = "Could not read saved draft: \(error.localizedDescription)"; return nil }
    }
    func clearDraft(key: String) {
        guard let cache else { return }
        do {
            let context = ModelContext(cache); let scoped = (userID ?? "guest") + ":" + key
            for row in try context.fetch(FetchDescriptor<LocalSocialDraft>()) where row.key == scoped { context.delete(row) }
            try context.save()
        } catch { self.error = error.localizedDescription }
    }
    private func restoreCache(_ owner: String) {
        guard let cache else { return }
        do {
            if let row = try ModelContext(cache).fetch(FetchDescriptor<CachedSocialState>()).first(where:{$0.owner==owner}) { snapshot = try JSONDecoder().decode(SocialSnapshot.self,from:row.payload) }
        } catch { self.error = "Could not read cached social data: \(error.localizedDescription)" }
    }
    private func persistCache() {
        guard let cache, let owner = userID else { return }
        do {
            let context = ModelContext(cache); let data = try JSONEncoder().encode(snapshot)
            if let row = try context.fetch(FetchDescriptor<CachedSocialState>()).first(where:{$0.owner==owner}) { row.payload = data }
            else { context.insert(CachedSocialState(owner:owner,payload:data)) }
            try context.save()
        } catch { self.error = "Could not cache social data: \(error.localizedDescription)" }
    }
    func handle(_ url: URL) {
        guard ["matmind","https"].contains(url.scheme ?? "") else { return }
        // HTTPS host must be explicitly configured; never redeem arbitrary web URLs.
        if url.scheme == "https", url.host != Bundle.main.object(forInfoDictionaryKey:"AppLinkHost") as? String { return }
        if url.scheme == "matmind", !["friend","session","goal"].contains(url.host ?? "") { return }
        pendingLink = url
    }
    func redeemPendingLink() async {
        guard let url = pendingLink, userID != nil else { return }
        let pieces = url.pathComponents.filter { $0 != "/" }
        let kind = url.scheme == "matmind" ? url.host : pieces.first
        let token = pieces.last ?? ""
        guard token.count == 64, token.allSatisfy({$0.isHexDigit}), ["friend","session","goal"].contains(kind ?? "") else { error = "Invalid invitation link."; pendingLink = nil; return }
        let operation = kind == "friend" ? "redeem_friend" : kind == "goal" ? "redeem_goal_link" : "join_link"
        if await perform(operation,["token":token]) != nil { pendingLink = nil }
    }
    func link(kind: String, token: String) -> URL {
        InvitationLinks.make(kind: kind, token: token,
            host: Bundle.main.object(forInfoDictionaryKey: "AppLinkHost") as? String,
            httpsEnabled: Bundle.main.object(forInfoDictionaryKey: "AppLinksEnabled") as? Bool ?? false)
    }
    func streak(_ friendship: SocialRow) -> (current:Int,best:Int,weeks:Int) {
        let credits = snapshot.credits.filter { $0.text("friendship_id") == friendship.id }
        let buckets = Set(credits.map { $0.text("week_start") })
        var calendar = Calendar(identifier:.gregorian); calendar.timeZone = TimeZone(identifier:friendship.text("timezone")) ?? TimeZone(secondsFromGMT:0)!; calendar.firstWeekday = 2; calendar.minimumDaysInFirstWeek = 4
        let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone; formatter.locale = Locale(identifier:"en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"
        let clock = ISO8601DateFormatter(); clock.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let serverNow = snapshot.server_time.flatMap { clock.date(from:$0) ?? ISO8601DateFormatter().date(from:$0) } ?? Date()
        let currentWeek = calendar.dateInterval(of:.weekOfYear,for:serverNow)!.start
        var end = currentWeek
        if !buckets.contains(formatter.string(from:end)) { end = calendar.date(byAdding:.weekOfYear,value:-1,to:end)! }
        var current = 0
        while buckets.contains(formatter.string(from:end)) { current += 1; end = calendar.date(byAdding:.weekOfYear,value:-1,to:end)! }
        var best = 0; var run = 0; var previous: Date?
        for date in buckets.compactMap({formatter.date(from:$0)}).sorted() {
            if let previous, calendar.date(byAdding:.weekOfYear,value:1,to:previous) == date { run += 1 } else { run = 1 }
            best = max(best,run); previous = date
        }
        return (current,best,buckets.count)
    }
}
