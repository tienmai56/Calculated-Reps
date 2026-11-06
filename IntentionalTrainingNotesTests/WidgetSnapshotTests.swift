import XCTest
@testable import IntentionalTrainingNotes

/// The home-screen widgets read a snapshot the app writes. These cover what they show:
/// sessions vs days, which session is "next", when it moves on, and where taps land.
final class WidgetSnapshotTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        c.firstWeekday = 2; c.minimumDaysInFirstWeek = 4
        return c
    }

    private func date(_ day: Int, _ hour: Int = 9, month: Int = 11) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func session(_ id: String, start: Date, cancelled: Bool = false, partners: [String] = ["Sarah"]) -> WidgetSnapshot.Session {
        WidgetSnapshot.Session(id: id, title: id, venue: "Tidewater BJJ", start: start, end: start.addingTimeInterval(2 * 3600),
                               hostedByMe: false, hostName: "Sarah", hostHue: "sky",
                               partners: partners.map { WidgetSnapshot.Partner(firstName: $0, initials: String($0.prefix(2)), hue: "sky") },
                               cancelled: cancelled)
    }

    // MARK: Your rhythm

    func testSessionsCountEveryEntryButDaysCountOncePerDate() {
        let entries = ["2026-10-31": 1, "2026-11-01": 1, "2026-11-02": 2, "2026-11-03": 1, "2026-11-05": 1, "2026-11-09": 3]
        let summary = RhythmSummary(entries: entries, now: date(6), calendar: calendar)
        XCTAssertEqual(summary.sessionsThisMonth, 5, "October and future days are left out")
        XCTAssertEqual(summary.daysThisMonth, 4, "Two sessions on Nov 2 fill one day")
        XCTAssertEqual(summary.today, 0)

        let twice = RhythmSummary(entries: entries.merging(["2026-11-06": 2]) { $1 }, now: date(6), calendar: calendar)
        XCTAssertEqual(twice.sessionsThisMonth, 7)
        XCTAssertEqual(twice.daysThisMonth, 5)
        XCTAssertEqual(twice.today, 2)
    }

    func testCountResetsOnTheFirstWithoutTheApp() {
        let summary = RhythmSummary(entries: ["2026-11-30": 2], now: date(1, month: 12), calendar: calendar)
        XCTAssertEqual(summary.sessionsThisMonth, 0)
        XCTAssertEqual(summary.daysThisMonth, 0)
    }

    func testWeeksRunMondayToSundayEndingThisWeek() {
        let weeks = WidgetCalendar.weeks(5, endingAt: date(6), calendar: calendar)
        XCTAssertEqual(weeks.count, 5)
        XCTAssertTrue(weeks.allSatisfy { $0.count == 7 })
        XCTAssertEqual(WidgetCalendar.key(weeks.last![0], calendar: calendar), "2026-11-02", "This week starts Monday")
        XCTAssertEqual(WidgetCalendar.key(weeks.last![6], calendar: calendar), "2026-11-08")
        XCTAssertEqual(WidgetCalendar.key(weeks[0][0], calendar: calendar), "2026-10-05", "Oldest week on the left")
    }

    // MARK: Next session

    func testNextSessionStaysUntilItsEndThenAdvances() {
        let lunch = session("lunch", start: date(6, 12))
        let open = session("open", start: date(7, 10))
        let sessions = [open, lunch]
        XCTAssertEqual(NextSessionPicker.current(sessions, at: date(6, 9))?.id, "lunch")
        XCTAssertEqual(NextSessionPicker.current(sessions, at: date(6, 13))?.id, "lunch", "Shown as Now while it runs")
        XCTAssertEqual(NextSessionPicker.current(sessions, at: date(6, 14))?.id, "open", "Moves on at the end time")
        XCTAssertNil(NextSessionPicker.current(sessions, at: date(7, 13)))
    }

    func testCancelledSessionShowsUntilItsStartAndNamesTheNextOne() {
        let cancelled = session("cancelled", start: date(7, 10), cancelled: true)
        let tuesday = session("tuesday", start: date(10, 19))
        let sessions = [cancelled, tuesday]
        let shown = NextSessionPicker.current(sessions, at: date(6, 21))
        XCTAssertEqual(shown?.id, "cancelled")
        XCTAssertEqual(NextSessionPicker.following(shown!, in: sessions, at: date(6, 21))?.id, "tuesday")
        XCTAssertEqual(NextSessionPicker.current(sessions, at: date(7, 10, month: 11).addingTimeInterval(1))?.id, "tuesday")
    }

    func testTimelineChangesAtStartsEndsAndMidnights() {
        let lunch = session("lunch", start: date(6, 12))
        let marks = NextSessionPicker.boundaries([lunch], after: date(6, 9), calendar: calendar)
        XCTAssertTrue(marks.contains(lunch.start))
        XCTAssertTrue(marks.contains(lunch.end))
        XCTAssertTrue(marks.contains(calendar.startOfDay(for: date(7))), "Tomorrow flips to Today at midnight")
        XCTAssertEqual(marks, marks.sorted())
    }

    func testFriendlyDaysAndPartnerLines() {
        let now = date(6, 9)
        XCTAssertEqual(WidgetWording.relativeDay(date(6, 18), now: now, calendar: calendar), "Today")
        XCTAssertEqual(WidgetWording.relativeDay(date(7, 10), now: now, calendar: calendar), "Tomorrow")
        XCTAssertEqual(WidgetWording.partners([]), "Just you. The mat’s all yours.")
        XCTAssertEqual(WidgetWording.partners(["Kenji", "Lena"]), "with Kenji & Lena")
        XCTAssertEqual(WidgetWording.partners(["Sarah", "Alex", "Priya"]), "with Sarah, Alex & Priya")
        XCTAssertEqual(WidgetWording.partners(["Sarah", "Alex", "Priya", "Kenji", "Lena", "Rafa", "Maya"]), "with Sarah, Alex +5")
    }

    // MARK: Store and links

    func testStoreOnlyReportsChangesThatWidgetsShow() throws {
        let suite = "widget-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var snapshot = WidgetSnapshot(signedIn: true, updatedAt: date(6, 9),
                                      rhythm: .init(quickLogAvailable: true, entries: ["2026-11-05": 1]), sessions: [])
        XCTAssertTrue(WidgetStore.write(snapshot, to: defaults))
        snapshot.updatedAt = date(6, 10)
        XCTAssertFalse(WidgetStore.write(snapshot, to: defaults), "A newer timestamp alone doesn't reload widgets")
        XCTAssertEqual(WidgetStore.read(from: defaults)?.updatedAt, date(6, 10))
        snapshot.rhythm?.entries["2026-11-06"] = 1
        XCTAssertTrue(WidgetStore.write(snapshot, to: defaults))
        XCTAssertEqual(WidgetStore.read(from: defaults), snapshot)
    }

    func testWidgetLinksRoundTripAndLeaveInvitationLinksAlone() {
        for destination: WidgetDestination in [.quickLog, .rhythm, .session("abc-123"), .plan, .home] {
            XCTAssertEqual(WidgetDestination(url: destination.url), destination)
        }
        XCTAssertNil(WidgetDestination(url: URL(string: "matmind://friend/token")!))
        XCTAssertNil(WidgetDestination(url: URL(string: "matmind://widget/session")!), "A session link needs an id")
    }

    func testLogTrainingRequestIsUsedOnceAndExpires() throws {
        let suite = "widget-launch-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let now = date(6, 9)
        WidgetLaunchRequest.post(.quickLog, defaults: defaults, now: now)
        XCTAssertEqual(WidgetLaunchRequest.take(defaults: defaults, now: now.addingTimeInterval(5)), .quickLog)
        XCTAssertNil(WidgetLaunchRequest.take(defaults: defaults, now: now.addingTimeInterval(6)), "Consumed")
        WidgetLaunchRequest.post(.quickLog, defaults: defaults, now: now)
        XCTAssertNil(WidgetLaunchRequest.take(defaults: defaults, now: now.addingTimeInterval(120)), "A later plain launch stays put")
    }

    // MARK: App side

    @MainActor
    func testAppSnapshotShowsHostedAndAcceptedSessionsOnly() {
        let ui = AppModel(live: true)
        ui.isSignedIn = true
        ui.quickTrainingLogBackendAvailable = true
        let now = Date()
        ui.people = ["sarah": Person(id: "sarah", name: "Sarah Lee", belt: .blue, stripes: 3, gym: "", hue: .sky)]
        func plan(_ id: String, organizer: String, rsvp: RSVP, hours: Double) -> Session {
            Session(id: id, title: id, day: "Sat", date: 7, month: "Nov", time: "10:00 AM", gym: "Tidewater BJJ",
                    organizer: organizer, people: [Attendee(id: "me", status: rsvp), Attendee(id: "sarah", status: .going)],
                    startsAt: now.addingTimeInterval(hours * 3600))
        }
        ui.upcoming = [plan("accepted", organizer: "sarah", rsvp: .going, hours: 20),
                       plan("pending", organizer: "sarah", rsvp: .invited, hours: 2),
                       plan("declined", organizer: "sarah", rsvp: .declined, hours: 3),
                       plan("hosted", organizer: "me", rsvp: .going, hours: 4),
                       plan("ended", organizer: "me", rsvp: .going, hours: -3)]
        ui.trainingInvitations = [TrainingInvitation(id: "invite", organizer: "sarah")]
        let snapshot = ui.widgetSnapshot(now: now)
        XCTAssertTrue(snapshot.signedIn)
        XCTAssertEqual(snapshot.sessions.map(\.id), ["hosted", "accepted"], "Never pending, declined or ended sessions")
        XCTAssertEqual(snapshot.sessions.first?.hostHue, "coral", "Your own sessions use coral")
        XCTAssertEqual(snapshot.sessions.last?.hostHue, "sky", "A friend keeps their hue")
        XCTAssertEqual(snapshot.sessions.last?.partners.map(\.firstName), ["Sarah"], "You are never listed as a partner")
        XCTAssertEqual(snapshot.invitationHost, "Sarah", "Invitations reveal the host only")
        XCTAssertEqual(snapshot.rhythm?.quickLogAvailable, true)

        ui.isSignedIn = false
        XCTAssertEqual(ui.widgetSnapshot(now: now), .signedOut, "Nothing personal stays after sign-out")
    }

    @MainActor
    func testQuickLogsFillTheirDayInTheAppSnapshot() {
        let ui = AppModel(live: true)
        ui.isSignedIn = true
        ui.quickTrainingLogBackendAvailable = true
        let now = Date()
        let today = TrainingCalendar.key(now)
        ui.quickLogs = [QuickLog(id: "a", loggedOn: today, loggedAt: now, timezone: TimeZone.current.identifier),
                        QuickLog(id: "b", loggedOn: today, loggedAt: now, timezone: TimeZone.current.identifier)]
        XCTAssertEqual(ui.widgetSnapshot(now: now).rhythm?.entries[today], 2)
    }
}
