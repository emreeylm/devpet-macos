import Foundation

public enum QuotaNoticeKind: String, Codable, Sendable { case early, critical, exhausted, reset }
public struct QuotaNotice: Sendable {
    public let service: Service
    public let window: QuotaWindow
    public let kind: QuotaNoticeKind
    public let cycle: String
    public var id: String { "\(service.rawValue)-\(window.kind.rawValue)-\(cycle)-\(kind.rawValue)" }
}

/// Stores only quota observations and delivered warning levels, never session data.
public struct QuotaNotificationTracker: Codable, Sendable {
    private struct Cycle: Codable, Sendable {
        var id = UUID().uuidString
        var window: QuotaWindow
        var observedAt: Date
        var delivered: Set<QuotaNoticeKind> = []
        var resetPending = false
    }
    private var cycles: [String: Cycle] = [:]
    public init() {}
    public mutating func notices(for snapshot: UsageSnapshot, preferences p: Preferences, now: Date) -> [QuotaNotice] {
        guard !p.demo, p.services.contains(snapshot.service), snapshot.isFresh(at: now, maxAge: p.staleAge), let date = snapshot.refreshedAt else { return [] }
        var notices: [QuotaNotice] = []
        for window in snapshot.windows where window.isValid(at: now) {
            let key = "\(snapshot.service.rawValue)-\(window.kind.rawValue)"
            let previous = cycles[key]
            // A delayed sample must not roll the remembered cycle backwards.
            if let previous, date < previous.observedAt { continue }
            let reset = previous.map { date > $0.observedAt && UsageLogic.confirmedReset(previous: $0.window, current: window, observedAt: date) } ?? false
            let newCycle = previous.map { old in
                guard let oldReset = old.window.resetsAt, let nextReset = window.resetsAt else { return false }
                return date > old.observedAt && oldReset <= date && nextReset > date && nextReset > oldReset
            } ?? false
            var cycle = newCycle ? Cycle(window: window, observedAt: date) : (previous ?? Cycle(window: window, observedAt: date))
            if reset && p.notifications && p.resetNotifications { cycle.resetPending = true }
            cycle.window = window; cycle.observedAt = date
            cycles[key] = cycle
            guard p.notifications, p.windows.contains(window.kind) else { continue }
            let kind: QuotaNoticeKind?
            if cycle.resetPending && p.resetNotifications { kind = .reset }
            else if window.remaining == 0 && p.exhaustedNotifications { kind = .exhausted }
            else if window.remaining <= p.threshold && p.lowWarnings { kind = .critical }
            else if window.remaining <= max(p.earlyWarningThreshold, p.threshold) && p.lowWarnings { kind = .early }
            else { kind = nil }
            if let kind, !cycle.delivered.contains(kind) {
                notices.append(QuotaNotice(service: snapshot.service, window: window, kind: kind, cycle: cycle.id))
            }
        }
        return notices
    }
    public func needsDelivery(_ notice: QuotaNotice) -> Bool {
        let cycle = cycles["\(notice.service.rawValue)-\(notice.window.kind.rawValue)"]
        return cycle?.id == notice.cycle && cycle?.delivered.contains(notice.kind) == false
    }
    public mutating func delivered(_ notice: QuotaNotice) {
        let key = "\(notice.service.rawValue)-\(notice.window.kind.rawValue)"
        guard cycles[key]?.id == notice.cycle else { return }
        cycles[key]?.delivered.insert(notice.kind)
        if notice.kind == .reset { cycles[key]?.resetPending = false }
        // Starting below a critical level sends one warning, never a burst of older levels.
        if notice.kind == .critical || notice.kind == .exhausted { cycles[key]?.delivered.insert(.early) }
        if notice.kind == .exhausted { cycles[key]?.delivered.insert(.critical) }
    }
}
