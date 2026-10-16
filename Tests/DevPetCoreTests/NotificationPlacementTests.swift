import XCTest
@testable import DevPetCore

final class NotificationPlacementTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func sample(_ remaining: Double, at date: Date? = nil, reset: Date? = nil, service: Service = .codex, kind: WindowKind = .fiveHour) -> UsageSnapshot {
        UsageSnapshot(service: service, windows: [try! QuotaWindow(kind: kind, used: 100 - remaining, resetsAt: reset ?? now.addingTimeInterval(1000))], refreshedAt: date ?? now, connection: .connected)
    }
    var preferences: Preferences { var p = Preferences(); p.notifications = true; return p }
    func testWarningsProgressOnceAndSurviveRestart() throws {
        var tracker = QuotaNotificationTracker()
        for (remaining, expected) in [(60.0, nil), (25.0, QuotaNoticeKind.early), (24.0, nil), (15.0, .critical), (10.0, nil), (0.0, .exhausted), (0.0, nil)] {
            let events = tracker.notices(for: sample(remaining), preferences: preferences, now: now)
            XCTAssertEqual(events.first?.kind, expected)
            events.forEach { event in
                XCTAssertTrue(tracker.needsDelivery(event))
                tracker.delivered(event)
                XCTAssertFalse(tracker.needsDelivery(event))
            }
            tracker = try JSONDecoder().decode(QuotaNotificationTracker.self, from: JSONEncoder().encode(tracker))
        }
    }
    func testFirstCriticalOrExhaustedSampleDoesNotSendOlderLevelsLater() {
        for remaining in [12.0, 0.0] {
            var tracker = QuotaNotificationTracker()
            let event = tracker.notices(for: sample(remaining), preferences: preferences, now: now).first!
            tracker.delivered(event)
            XCTAssertTrue(tracker.notices(for: sample(22), preferences: preferences, now: now).isEmpty)
            XCTAssertTrue(tracker.notices(for: sample(remaining), preferences: preferences, now: now).isEmpty)
        }
    }
    func testFailedDeliveryCanRetryIncludingConfirmedReset() {
        var tracker = QuotaNotificationTracker()
        let critical = tracker.notices(for: sample(10), preferences: preferences, now: now)
        XCTAssertEqual(critical.first?.id, tracker.notices(for: sample(10), preferences: preferences, now: now).first?.id)
        let later = now.addingTimeInterval(1100)
        let resetSample = sample(100, at: later, reset: later.addingTimeInterval(18000))
        let renewal = tracker.notices(for: resetSample, preferences: preferences, now: later).first!
        XCTAssertEqual(renewal.kind, .reset)
        XCTAssertEqual(tracker.notices(for: resetSample, preferences: preferences, now: later).first?.id, renewal.id)
        tracker.delivered(renewal)
        XCTAssertTrue(tracker.notices(for: resetSample, preferences: preferences, now: later).isEmpty)
        XCTAssertEqual(tracker.notices(for: sample(24, at: later, reset: later.addingTimeInterval(18000)), preferences: preferences, now: later).first?.kind, .early)
    }
    func testResetAfterRestartAndTemporaryDisconnect() throws {
        var tracker = QuotaNotificationTracker()
        let old = tracker.notices(for: sample(0), preferences: preferences, now: now).first!
        tracker.delivered(old)
        tracker = try JSONDecoder().decode(QuotaNotificationTracker.self, from: JSONEncoder().encode(tracker))
        XCTAssertTrue(tracker.notices(for: UsageSnapshot(service: .codex, connection: .failed), preferences: preferences, now: now).isEmpty)
        let later = now.addingTimeInterval(1200)
        XCTAssertEqual(tracker.notices(for: sample(99, at: later, reset: later.addingTimeInterval(18000)), preferences: preferences, now: later).first?.kind, .reset)
    }
    func testMissingResetNeverInventsRenewalAndClockExpiryIsNotReset() {
        var tracker = QuotaNotificationTracker()
        _ = tracker.notices(for: sample(20), preferences: preferences, now: now)
        let later = now.addingTimeInterval(1100)
        XCTAssertTrue(tracker.notices(for: sample(20), preferences: preferences, now: later).isEmpty)
        var unknown = sample(100, at: later); unknown.windows[0].resetsAt = nil
        XCTAssertTrue(tracker.notices(for: unknown, preferences: preferences, now: later).isEmpty)
    }
    func testNotificationsRespectSelectionsDemoFreshnessAndSwitches() {
        var tracker = QuotaNotificationTracker()
        for setting in ["notifications", "demo", "provider", "window", "low"] {
            var p = preferences
            switch setting {
            case "notifications": p.notifications = false
            case "demo": p.demo = true
            case "provider": p.codexEnabled = false
            case "window": p.fiveHourEnabled = false
            default: p.lowWarnings = false
            }
            XCTAssertTrue(tracker.notices(for: sample(10), preferences: p, now: now).isEmpty, setting)
        }
        XCTAssertTrue(tracker.notices(for: sample(10, at: now.addingTimeInterval(-1000)), preferences: preferences, now: now).isEmpty)
        var p = preferences; p.lowWarnings = false
        XCTAssertEqual(tracker.notices(for: sample(0), preferences: p, now: now).first?.kind, .exhausted)
        p.exhaustedNotifications = false
        XCTAssertTrue(tracker.notices(for: sample(0), preferences: p, now: now).isEmpty)
    }
    func testProviderAndWindowWarningCyclesAreIndependent() {
        var tracker = QuotaNotificationTracker()
        for service in Service.allCases {
            for kind in WindowKind.allCases {
                let event = tracker.notices(for: sample(23, service: service, kind: kind), preferences: preferences, now: now).first!
                tracker.delivered(event)
                XCTAssertTrue(tracker.notices(for: sample(23, service: service, kind: kind), preferences: preferences, now: now).isEmpty)
            }
        }
    }
    func testLateSampleDoesNotRollBackCycle() {
        var tracker = QuotaNotificationTracker()
        _ = tracker.notices(for: sample(40), preferences: preferences, now: now)
        XCTAssertTrue(tracker.notices(for: sample(10, at: now.addingTimeInterval(-1)), preferences: preferences, now: now).isEmpty)
    }
    func testDisplayRearrangementAndResolutionPreserveCornerPlacement() throws {
        let old = DisplayArea(id: "external", frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080))
        let new = DisplayArea(id: "external", frame: CGRect(x: 1440, y: 0, width: 2560, height: 1440))
        let placement = SavedWindowPlacement(frame: CGRect(x: -200, y: 980, width: 200, height: 100), display: old)
        let persisted = try JSONDecoder().decode(SavedWindowPlacement.self, from: JSONEncoder().encode(placement))
        let restored = persisted.restored(on: [new], size: CGSize(width: 300, height: 150))
        XCTAssertEqual(restored.maxX, new.frame.maxX)
        XCTAssertEqual(restored.maxY, new.frame.maxY)
        XCTAssertEqual(restored.size, CGSize(width: 300, height: 150))
    }
    func testUnpluggedDisplayFallbackDoesNotAlterRememberedPlacement() {
        let external = DisplayArea(id: "external", frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080))
        let builtin = DisplayArea(id: "builtin", frame: CGRect(x: 0, y: 0, width: 1440, height: 900))
        let original = CGRect(x: -1820, y: 400, width: 200, height: 100)
        let placement = SavedWindowPlacement(frame: original, display: external)
        XCTAssertTrue(builtin.frame.contains(placement.restored(on: [builtin])))
        XCTAssertEqual(placement.restored(on: [builtin, external]), original)
        XCTAssertEqual(placement.restored(on: []), original)
    }
    func testNotificationPreferencesMigrateAndBoundThresholds() throws {
        let suite = "DevPet.Notifications.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data(#"{"threshold":20,"language":"tr","notifications":true}"#.utf8), forKey: "preferences")
        let p = SettingsStore(defaults: defaults).load()
        XCTAssertTrue(p.notifications); XCTAssertTrue(p.exhaustedNotifications)
        XCTAssertEqual(p.earlyWarningThreshold, 25); XCTAssertEqual(p.threshold, 20); XCTAssertEqual(p.language, "tr")
        var invalid = p; invalid.threshold = 35; invalid.earlyWarningThreshold = 10; invalid.sanitize()
        XCTAssertEqual(invalid.earlyWarningThreshold, 35)
    }
}
