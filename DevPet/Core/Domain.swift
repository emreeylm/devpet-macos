import Foundation
import CoreGraphics

public enum Animal: String, CaseIterable, Codable, Identifiable, Sendable {
    case cat, dog, fox, panda, rabbit, bear, owl, frog, penguin, raccoon, capybara, wolf
    public var id: String { rawValue }
}
public enum Mood: String, CaseIterable, Sendable { case happy, normal, alert, tired, sleeping, unknown }
public enum Service: String, CaseIterable, Codable, Identifiable, Sendable {
    case claude, codex
    public var id: String { rawValue }
    public var title: String { self == .claude ? "Claude Code" : "Codex" }
}
public enum WindowKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case fiveHour, weekly
    public var id: String { rawValue }
}
public enum Connection: String, Codable, Sendable { case connected, unavailable, failed, disabled }
public struct QuotaWindow: Codable, Equatable, Sendable {
    public var kind: WindowKind
    public var remaining: Double
    public var resetsAt: Date?
    public init(kind: WindowKind, used: Double, resetsAt: Date?) throws {
        guard used.isFinite, (0...100).contains(used) else { throw UsageError.invalidData }
        self.kind = kind; remaining = 100 - used; self.resetsAt = resetsAt
    }
    public func isValid(at now: Date) -> Bool { resetsAt.map { $0 > now } ?? true }
}
public struct UsageSnapshot: Codable, Equatable, Sendable {
    public var service: Service
    public var windows: [QuotaWindow]
    public var refreshedAt: Date?
    public var connection: Connection
    public var diagnostic: String
    public init(service: Service, windows: [QuotaWindow] = [], refreshedAt: Date? = nil, connection: Connection = .unavailable, diagnostic: String = "") {
        self.service = service; self.windows = windows; self.refreshedAt = refreshedAt; self.connection = connection; self.diagnostic = diagnostic
    }
    public func isFresh(at now: Date, maxAge: TimeInterval = 900) -> Bool {
        guard connection == .connected, let date = refreshedAt else { return false }
        return now.timeIntervalSince(date) >= -60 && now.timeIntervalSince(date) <= maxAge
    }
    public func window(_ kind: WindowKind, at now: Date, maxAge: TimeInterval = 900) -> QuotaWindow? {
        guard isFresh(at: now, maxAge: maxAge) else { return nil }
        return windows.first { $0.kind == kind && $0.isValid(at: now) }
    }
}
public enum UsageError: Error, LocalizedError, Sendable {
    case invalidData, missingCLI, timeout, authentication, missingBridge, protocolFailure
    public var errorDescription: String? {
        switch self {
        case .invalidData: return "Usage data is missing or invalid."
        case .missingCLI: return "Codex CLI was not found. Install it or choose its executable in Settings."
        case .timeout: return "Codex did not respond within 20 seconds."
        case .authentication: return "Codex could not read quotas. Sign in with ChatGPT using codex login."
        case .missingBridge: return "Claude statusline bridge has not supplied data. See the connection guide."
        case .protocolFailure: return "The installed Codex app-server protocol is incompatible."
        }
    }
}
public enum UsageLogic {
    public static func mood(_ snapshots: [UsageSnapshot], services: Set<Service>, now: Date, celebrating: Bool = false, maxAge: TimeInterval = 900) -> Mood {
        let relevant = snapshots.filter { services.contains($0.service) }
        // Displayed weekly quotas never influence companion activity.
        let values = relevant.compactMap { $0.window(.fiveHour, at: now, maxAge: maxAge)?.remaining }
        guard let minimum = values.min() else { return .unknown }
        if minimum < 15 { return .sleeping }
        if minimum <= 50 { return .tired }
        return .happy
    }
    public static func confirmedReset(previous: QuotaWindow?, current: QuotaWindow, observedAt: Date) -> Bool {
        guard let previous, previous.kind == current.kind, let old = previous.resetsAt, let new = current.resetsAt else { return false }
        return old <= observedAt && new > observedAt && new > old && current.remaining > previous.remaining
    }
    public static func countdown(_ reset: Date?, now: Date) -> String {
        guard let reset else { return "—" }
        let delta = reset.timeIntervalSince(now)
        guard delta > 0 else { return "Awaiting refresh" }
        let minutes = Int(ceil(delta / 60))
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h \(minutes % 60)m" }
        return "\(hours / 24)d \(hours % 24)h"
    }
    public static func restore(frame: CGRect, screens: [CGRect], preferred: Int? = nil) -> CGRect {
        guard !screens.isEmpty else { return frame }
        let screen = preferred.flatMap { screens.indices.contains($0) ? screens[$0] : nil } ?? screens.max { $0.intersection(frame).area < $1.intersection(frame).area }!
        let width = min(frame.width, screen.width), height = min(frame.height, screen.height)
        return CGRect(x: min(max(frame.minX, screen.minX), screen.maxX - width), y: min(max(frame.minY, screen.minY), screen.maxY - height), width: width, height: height)
    }
}
private extension CGRect { var area: CGFloat { isNull ? 0 : width * height } }

public struct Preferences: Codable, Equatable, Sendable {
    public var animal: Animal = .capybara
    public var palette = "Terminal Green"
    public var customHex = "5B8CFF"
    public var size = 1.0
    public var opacity = 1.0
    public var animations = true
    public var dark = true
    public var alwaysOnTop = true
    public var clickThrough = false
    public var transparent = true
    public var attachPet = true
    public var petVisible = true
    public var statsVisible = true
    public var mode = "expanded"
    public var demo = false
    public var claudeExpanded = false
    public var codexExpanded = false
    public var claudeEnabled = true
    public var codexEnabled = true
    public var fiveHourEnabled = true
    public var weeklyEnabled = true
    public var refreshMinutes = 5.0
    public var notifications = false
    public var lowWarnings = true
    public var resetNotifications = true
    public var exhaustedNotifications = true
    public var earlyWarningThreshold = 25.0
    public var threshold = 15.0
    public var language = "en"
    public var codexPath = ""
    public var repositoryURL = ""
    public init() {}
    public var services: Set<Service> { Set(Service.allCases.filter { $0 == .claude ? claudeEnabled : codexEnabled }) }
    public var windows: Set<WindowKind> { Set(WindowKind.allCases.filter { $0 == .fiveHour ? fiveHourEnabled : weeklyEnabled }) }
    public var staleAge: TimeInterval { max(900, refreshMinutes * 120) }
    public func isExpanded(_ service: Service) -> Bool { service == .claude ? claudeExpanded : codexExpanded }
    public mutating func setExpanded(_ expanded: Bool, for service: Service) {
        if service == .claude { claudeExpanded = expanded } else { codexExpanded = expanded }
    }
    public var providerSelection: String {
        if claudeEnabled && codexEnabled { return "both" }
        if claudeEnabled { return "claude" }
        if codexEnabled { return "codex" }
        return "none"
    }
    public mutating func selectProviders(_ selection: String) {
        claudeEnabled = selection == "both" || selection == "claude"
        codexEnabled = selection == "both" || selection == "codex"
    }
    public var dashboardHeight: Double {
        let count = Double(services.count)
        let expanded = Double(services.filter { isExpanded($0) }.count)
        let extra = attachPet && petVisible ? max(0, min(112, 112 * size) - 72) : 0
        return 160 + count * 60 + expanded * 90 + extra
    }
    public var petBaseSpriteSide: Double { 132 }
    public var petSpriteSide: Double { petBaseSpriteSide * size }
    public var petQuotaStackHeight: Double { Double(services.count) * 54 - 4 }
    // Standing artwork and quota cards share the same registered height.
    public var petCanvasWidthUnits: Double { 76 }
    public var petQuotaHeightUnits: Double { 33 }
    public var petQuotaScale: Double { min(1, (petBaseSpriteSide * petQuotaHeightUnits / 64) / max(1, petQuotaStackHeight)) }
    // Keep the established card width independently of the tighter vertical footprint.
    public var petQuotaWidth: Double { 140 * min(1, (petBaseSpriteSide * 33 / 64) / max(1, petQuotaStackHeight)) }
    public var petBaseWindowWidth: Double {
        petBaseSpriteSide * petCanvasWidthUnits / 64 + 12 + (services.isEmpty || windows.isEmpty ? 0 : petQuotaWidth - petBaseSpriteSide * 8 / 64 + 2)
    }
    // Crop the unused top of the shared 64×52 art canvas without rescaling its contents.
    public var petViewportTop: Double { 15 }
    public var petViewportHeight: Double { 34 }
    public var petBaseWindowHeight: Double { petBaseSpriteSide * petViewportHeight / 64 + 6 }
    public var minimalCardScale: Double { 0.8 * size }
    public var petWindowWidth: Double { mode == "minimal" ? 120 * size : petBaseWindowWidth * size }
    public var petWindowHeight: Double { mode == "minimal" ? (max(50, petQuotaStackHeight) * 0.8 + 8) * size : petBaseWindowHeight * size }
    public var dashboardLayoutID: String {
        "\(mode)-\(providerSelection)-\(claudeExpanded)-\(codexExpanded)-\(attachPet)-\(petVisible)-\(size)"
    }

    public mutating func sanitize() {
        size = size.isFinite ? min(max(size, 0.5), 2.5) : 1
        opacity = opacity.isFinite ? min(max(opacity, 0.2), 1) : 1
        refreshMinutes = refreshMinutes.isFinite ? min(max(refreshMinutes, 1), 30) : 5
        threshold = threshold.isFinite ? min(max(threshold, 1), 40) : 15
        earlyWarningThreshold = earlyWarningThreshold.isFinite ? min(max(earlyWarningThreshold, threshold), 50) : max(25, threshold)
        if !["pet", "expanded", "minimal"].contains(mode) { mode = "expanded" }
        if !["en", "tr"].contains(language) { language = "en" }
    }
}
public struct SettingsStore {
    public let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public func load() -> Preferences {
        guard let data = defaults.data(forKey: "preferences"),
              let saved = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let baselineData = try? JSONEncoder().encode(Preferences()),
              var merged = try? JSONSerialization.jsonObject(with: baselineData) as? [String: Any] else { return Preferences() }
        // New settings inherit defaults without resetting a user's existing preferences.
        merged.merge(saved) { _, savedValue in savedValue }
        guard let migrated = try? JSONSerialization.data(withJSONObject: merged),
              var value = try? JSONDecoder().decode(Preferences.self, from: migrated) else { return Preferences() }
        value.sanitize(); return value
    }
    public func save(_ value: Preferences) { var safe = value; safe.sanitize(); defaults.set(try? JSONEncoder().encode(safe), forKey: "preferences") }
}

public enum UsageParser {
    public static func codex(_ data: Data, now: Date) throws -> UsageSnapshot {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw UsageError.invalidData }
        let result = root["result"] as? [String: Any] ?? root
        // Never use an unrelated model bucket as the Codex quota.
        let bucket: [String: Any]?
        if let buckets = result["rateLimitsByLimitId"] as? [String: Any], !buckets.isEmpty { bucket = buckets["codex"] as? [String: Any] }
        else { bucket = result["rateLimits"] as? [String: Any] }
        guard let bucket else { throw UsageError.invalidData }
        var windows: [QuotaWindow] = []
        for key in ["primary", "secondary"] {
            guard let value = bucket[key] as? [String: Any], let duration = value["windowDurationMins"] as? Int, let used = value["usedPercent"] as? Double else { continue }
            guard let kind: WindowKind = duration == 300 ? .fiveHour : (duration == 10080 ? .weekly : nil) else { continue }
            let reset = (value["resetsAt"] as? Double).map(Date.init(timeIntervalSince1970:))
            windows.append(try QuotaWindow(kind: kind, used: used, resetsAt: reset))
        }
        return UsageSnapshot(service: .codex, windows: windows, refreshedAt: now, connection: .connected, diagnostic: windows.isEmpty ? "This account supplied no five-hour or weekly quota." : "Local Codex app-server · ChatGPT account")
    }
    public static func claude(_ data: Data) throws -> UsageSnapshot {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any], let timestamp = root["observed_at"] as? Double, let rates = root["rate_limits"] as? [String: Any] else { throw UsageError.invalidData }
        var windows: [QuotaWindow] = []
        for (key, kind) in [("five_hour", WindowKind.fiveHour), ("seven_day", .weekly)] {
            guard let value = rates[key] as? [String: Any], let used = value["used_percentage"] as? Double else { continue }
            windows.append(try QuotaWindow(kind: kind, used: used, resetsAt: (value["resets_at"] as? Double).map(Date.init(timeIntervalSince1970:))))
        }
        return UsageSnapshot(service: .claude, windows: windows, refreshedAt: Date(timeIntervalSince1970: timestamp), connection: .connected, diagnostic: "Official Claude Code statusline · Updated by active sessions")
    }
}
