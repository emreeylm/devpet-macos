import XCTest
import CoreGraphics
@testable import DevPetCore

final class UsageTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func quota(_ remaining: Double, reset: Date? = nil, kind: WindowKind = .fiveHour) -> QuotaWindow { try! QuotaWindow(kind: kind, used: 100 - remaining, resetsAt: reset) }
    func snapshot(_ remaining: Double, service: Service = .codex, age: Double = 0, connection: Connection = .connected) -> UsageSnapshot {
        UsageSnapshot(service: service, windows: [quota(remaining, reset: now.addingTimeInterval(1000))], refreshedAt: now.addingTimeInterval(-age), connection: connection)
    }
    func testNormalizationAndInvalidValues() throws {
        XCTAssertEqual(try QuotaWindow(kind: .fiveHour, used: 23.5, resetsAt: nil).remaining, 76.5)
        for used in [-1.0, 101, .nan, .infinity] { XCTAssertThrowsError(try QuotaWindow(kind: .weekly, used: used, resetsAt: nil)) }
    }
    func testEveryThresholdBoundary() {
        for (remaining, expected) in [(100.0, Mood.happy), (50.001, .happy), (50, .tired), (40, .tired), (15, .tired), (14.999, .sleeping), (0.001, .sleeping), (0, .sleeping)] {
            XCTAssertEqual(UsageLogic.mood([snapshot(remaining)], services: [.codex], now: now), expected)
        }
    }
    func testWeeklyQuotaNeverAffectsActivity() {
        var data = snapshot(80)
        data.windows.append(quota(0, reset: now.addingTimeInterval(10000), kind: .weekly))
        XCTAssertEqual(UsageLogic.mood([data], services: [.codex], now: now), .happy)
        XCTAssertEqual(UsageLogic.mood([data, snapshot(30, service: .claude)], services: [.codex, .claude], now: now), .tired)
        XCTAssertEqual(UsageLogic.mood([data, snapshot(0, service: .claude)], services: [.codex], now: now), .happy)
        data.windows = [quota(10), quota(100, kind: .weekly)]
        XCTAssertEqual(UsageLogic.mood([data], services: [.codex], now: now), .sleeping)
    }
    func testWeeklyCannotReplaceUnavailableFiveHourQuota() {
        var data = snapshot(90)
        data.windows = [quota(90, kind: .weekly)]
        XCTAssertEqual(UsageLogic.mood([data], services: [.codex], now: now), .unknown)
        data.windows.append(quota(70, reset: now))
        XCTAssertEqual(UsageLogic.mood([data], services: [.codex], now: now), .unknown)
    }
    func testUnavailableStaleAndFutureAreUnknown() {
        for data in [snapshot(90, age: 901), snapshot(90, connection: .failed), snapshot(90, age: -100)] {
            XCTAssertEqual(UsageLogic.mood([data], services: [.codex], now: now), .unknown)
        }
        XCTAssertEqual(UsageLogic.mood([], services: [.claude], now: now), .unknown)
        XCTAssertEqual(UsageLogic.mood([snapshot(90)], services: [], now: now), .unknown)
    }
    func testPartialAvailabilityAndExpiredWindow() {
        XCTAssertEqual(UsageLogic.mood([snapshot(25), UsageSnapshot(service: .claude)], services: [.codex, .claude], now: now), .tired)
        var data = snapshot(90); data.windows = [quota(90, reset: now)]
        XCTAssertEqual(UsageLogic.mood([data], services: [.codex], now: now), .unknown)
    }
    func testResetRequiresNewCycleAndElapsedOldCycle() {
        let old = quota(10, reset: now.addingTimeInterval(-1))
        let new = quota(90, reset: now.addingTimeInterval(18000))
        XCTAssertTrue(UsageLogic.confirmedReset(previous: old, current: new, observedAt: now))
        XCTAssertFalse(UsageLogic.confirmedReset(previous: old, current: quota(90, reset: old.resetsAt), observedAt: now))
        XCTAssertFalse(UsageLogic.confirmedReset(previous: quota(10, reset: now.addingTimeInterval(500)), current: new, observedAt: now))
        XCTAssertFalse(UsageLogic.confirmedReset(previous: nil, current: new, observedAt: now))
        XCTAssertFalse(UsageLogic.confirmedReset(previous: old, current: quota(9, reset: new.resetsAt), observedAt: now))
        XCTAssertFalse(UsageLogic.confirmedReset(previous: old, current: quota(90, reset: new.resetsAt, kind: .weekly), observedAt: now))
    }
    func testCelebrationDoesNotOverrideQuotaActivity() {
        XCTAssertEqual(UsageLogic.mood([snapshot(90)], services: [.codex], now: now, celebrating: true), .happy)
        XCTAssertEqual(UsageLogic.mood([snapshot(10)], services: [.codex], now: now, celebrating: true), .sleeping)
        XCTAssertEqual(UsageLogic.mood([snapshot(90)], services: [.codex, .claude], now: now, celebrating: true), .happy)
    }
    func testCodexParserUsesDurationRatherThanPrimaryOrder() throws {
        let json = #"{"result":{"rateLimits":{"primary":null},"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":31,"windowDurationMins":10080,"resetsAt":1800009999},"secondary":{"usedPercent":52,"windowDurationMins":300,"resetsAt":1800001000}},"other":{"primary":{"usedPercent":100,"windowDurationMins":300}}}}}"#
        let parsed = try UsageParser.codex(Data(json.utf8), now: now)
        XCTAssertEqual(parsed.window(.weekly, at: now)?.remaining, 69)
        XCTAssertEqual(parsed.window(.fiveHour, at: now)?.remaining, 48)
    }
    func testCodexMissingDurationDoesNotInventFiveHourQuota() throws {
        let json = #"{"rateLimits":{"primary":{"usedPercent":25,"windowDurationMins":15},"secondary":null}}"#
        XCTAssertTrue(try UsageParser.codex(Data(json.utf8), now: now).windows.isEmpty)
    }
    func testCodexRejectsUnrelatedBucketAndBadPercent() {
        let json = #"{"rateLimits":{},"rateLimitsByLimitId":{"other":{"primary":{"usedPercent":10,"windowDurationMins":300}}}}"#
        XCTAssertThrowsError(try UsageParser.codex(Data(json.utf8), now: now))
        let invalid = #"{"rateLimits":{"primary":{"usedPercent":110,"windowDurationMins":300}}}"#
        XCTAssertThrowsError(try UsageParser.codex(Data(invalid.utf8), now: now))
    }
    func testClaudeParserPreservesObservationAndMissingWeekly() throws {
        let json = #"{"observed_at":1800000000,"rate_limits":{"five_hour":{"used_percentage":35.5,"resets_at":1800001000}}}"#
        let parsed = try UsageParser.claude(Data(json.utf8))
        XCTAssertEqual(parsed.refreshedAt, now)
        XCTAssertEqual(parsed.window(.fiveHour, at: now)?.remaining, 64.5)
        XCTAssertNil(parsed.window(.weekly, at: now))
        XCTAssertThrowsError(try UsageParser.claude(Data(#"{"rate_limits":{}}"#.utf8)))
    }
    func testSettingsPersistenceAndBounds() {
        let suite = "DevPet.Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SettingsStore(defaults: defaults)
        var p = Preferences(); p.animal = .wolf; p.language = "tr"; p.clickThrough = true; p.demo = true; p.size = 9; p.opacity = 0; p.refreshMinutes = 300
        store.save(p)
        let actual = store.load()
        XCTAssertEqual(actual.animal, .wolf); XCTAssertEqual(actual.language, "tr"); XCTAssertTrue(actual.clickThrough)
        XCTAssertEqual(actual.size, 2.5); XCTAssertEqual(actual.opacity, 0.2); XCTAssertEqual(actual.refreshMinutes, 30)
    }
    func testNewPreferencesMigrateWithoutResettingExistingAppearance() throws {
        let suite = "DevPet.Migration.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var prefs = Preferences(); prefs.animal = .fox; prefs.language = "tr"; prefs.opacity = 0.7
        var old = try JSONSerialization.jsonObject(with: JSONEncoder().encode(prefs)) as! [String: Any]
        old.removeValue(forKey: "attachPet")
        old.removeValue(forKey: "claudeExpanded"); old.removeValue(forKey: "codexExpanded")
        defaults.set(try JSONSerialization.data(withJSONObject: old), forKey: "preferences")
        let loaded = SettingsStore(defaults: defaults).load()
        XCTAssertTrue(loaded.attachPet); XCTAssertEqual(loaded.animal, .fox)
        XCTAssertEqual(loaded.language, "tr"); XCTAssertEqual(loaded.opacity, 0.7)
    }
    func testProviderSelectionAndDisclosurePersist() {
        let suite = "DevPet.Disclosure.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var prefs = Preferences()
        prefs.selectProviders("claude"); prefs.setExpanded(true, for: .claude)
        SettingsStore(defaults: defaults).save(prefs)
        let saved = SettingsStore(defaults: defaults).load()
        XCTAssertEqual(saved.services, [.claude]); XCTAssertEqual(saved.providerSelection, "claude")
        XCTAssertTrue(saved.isExpanded(.claude)); XCTAssertFalse(saved.isExpanded(.codex))
        prefs.selectProviders("codex"); XCTAssertEqual(prefs.services, [.codex])
        prefs.selectProviders("both"); XCTAssertEqual(prefs.services, [.claude, .codex])
        let openHeight = prefs.dashboardHeight
        prefs.setExpanded(false, for: .claude); XCTAssertLessThan(prefs.dashboardHeight, openHeight)
    }
    func testPetQuotaLayoutStaysFixedAcrossAnimalsAndScalesTogether() {
        var prefs = Preferences(); prefs.selectProviders("both")
        let width = prefs.petWindowWidth, height = prefs.petWindowHeight
        let quotaWidth = prefs.petQuotaWidth, quotaScale = prefs.petQuotaScale
        for animal in Animal.allCases {
            prefs.animal = animal
            for factor in [0.5, 1.0, 1.5, 2.0, 2.5] {
                prefs.size = factor
                XCTAssertEqual(prefs.petWindowWidth, width * factor, accuracy: 0.001)
                XCTAssertEqual(prefs.petWindowHeight, height * factor, accuracy: 0.001)
                XCTAssertEqual(prefs.petQuotaWidth, quotaWidth)
                XCTAssertEqual(prefs.petQuotaScale, quotaScale)
            }
        }
    }
    func testQuotaStackFitsEveryStandingSpriteAtEveryDisplayScale() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("DevPet/Resources/Sprites/Companions-v6.json"))
        let metadata = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let frames = metadata["frames"] as! [[Double]]
        let p = Preferences()
        for start in stride(from: 0, to: frames.count, by: 3) {
            let commonWidth = frames[start..<start + 3].map { $0[2] }.max()!
            let commonHeight = frames[start..<start + 3].map { $0[3] }.max()!
            let artHeight = min(40, 44 * commonHeight / commonWidth)
            for state in 0...1 {
                let visibleTop = 49 - artHeight * frames[start + state][3] / commonHeight
                for backing in [1.0, 2.0] {
                    for size in [0.5, 1, 1.3959565, 1.5, 2, 2.5] {
                        let unit = max(1 / backing, floor(p.petBaseSpriteSide * size / 64 * backing) / backing)
                        let renderedScale = unit / (p.petBaseSpriteSide / 64)
                        let stackHeight = p.petQuotaStackHeight * p.petQuotaScale * renderedScale
                        let stackTop = 48.5 * unit - stackHeight
                        XCTAssertGreaterThanOrEqual(stackTop, visibleTop * unit - 0.01, "frame \(start + state), backing \(backing), size \(size)")
                        XCTAssertLessThanOrEqual(48.5 * unit, 49 * unit)
                    }
                }
            }
        }
    }
    func testPetWindowTrimsUnusedCanvasButStillContainsQuotaCards() {
        var prefs = Preferences(); prefs.selectProviders("both")
        let formerHeight = prefs.petBaseSpriteSide * 52 / 64 + 12
        XCTAssertLessThan(prefs.petBaseWindowHeight, formerHeight - 30)
        XCTAssertGreaterThanOrEqual(prefs.petBaseWindowHeight, prefs.petQuotaStackHeight * prefs.petQuotaScale + 6)
        XCTAssertEqual(prefs.petViewportTop + prefs.petViewportHeight, 49)
        for factor in [0.5, 1.0, 1.5, 2.0, 2.5] {
            prefs.size = factor
            XCTAssertGreaterThanOrEqual(prefs.petWindowHeight, (prefs.petQuotaStackHeight * prefs.petQuotaScale + 6) * factor)
        }
    }
    func testMinimalModePersistsAndFitsSelectedProviders() {
        let suite = "DevPet.Minimal.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var prefs = Preferences(); prefs.mode = "minimal"; prefs.selectProviders("both"); prefs.sanitize()
        SettingsStore(defaults: defaults).save(prefs)
        let loaded = SettingsStore(defaults: defaults).load()
        XCTAssertEqual(loaded.mode, "minimal")
        XCTAssertEqual(loaded.petWindowWidth, 120)
        XCTAssertEqual(loaded.petWindowHeight, 91.2, accuracy: 0.01)
        prefs.selectProviders("claude")
        XCTAssertEqual(prefs.petWindowHeight, 48)
        prefs.selectProviders("codex")
        XCTAssertEqual(prefs.petWindowHeight, 48)
        prefs.size = 2.5
        XCTAssertEqual(prefs.petWindowWidth, 300)
        XCTAssertEqual(prefs.petWindowHeight, 120)
    }
    func testCorruptedSettingsRecoverDefaults() {
        let defaults = UserDefaults(suiteName: "DevPet.Tests.\(UUID().uuidString)")!
        defaults.set(Data("broken".utf8), forKey: "preferences")
        XCTAssertEqual(SettingsStore(defaults: defaults).load(), Preferences())
    }
    func testRestoreWhenDisplayRemovedAndNegativeOrigins() {
        let left = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let right = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let old = CGRect(x: -1800, y: 800, width: 200, height: 200)
        XCTAssertEqual(UsageLogic.restore(frame: old, screens: [left, right]), old)
        let restored = UsageLogic.restore(frame: old, screens: [right])
        XCTAssertTrue(right.contains(restored)); XCTAssertEqual(restored.minX, 0)
        XCTAssertEqual(UsageLogic.restore(frame: CGRect(x: 1400, y: 880, width: 3000, height: 2000), screens: [right]), right)
        XCTAssertEqual(UsageLogic.restore(frame: old, screens: []), old)
    }
    func testCountdownNeverConfirmsReset() {
        XCTAssertEqual(UsageLogic.countdown(nil, now: now), "—")
        XCTAssertEqual(UsageLogic.countdown(now, now: now), "Awaiting refresh")
        XCTAssertEqual(UsageLogic.countdown(now.addingTimeInterval(61), now: now), "2m")
        XCTAssertEqual(UsageLogic.countdown(now.addingTimeInterval(9720), now: now), "2h 42m")
        XCTAssertEqual(UsageLogic.countdown(now.addingTimeInterval(90000), now: now), "1d 1h")
    }
}
