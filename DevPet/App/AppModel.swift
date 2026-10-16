import SwiftUI
import Combine
#if canImport(DevPetCore)
import DevPetCore
#endif
import UserNotifications
import ServiceManagement
import OSLog

@MainActor final class AppModel: ObservableObject {
    @Published var preferences: Preferences { didSet { store.save(preferences); preferencesChanged.send() } }
    @Published var snapshots: [UsageSnapshot] = Service.allCases.map { UsageSnapshot(service: $0) }
    @Published var refreshing = false
    @Published var suspended = false
    @Published var now = Date()
    @Published var celebrationUntil = Date.distantPast
    @Published var systemMessage = ""
    @Published var demoMood: Mood? = nil
    let preferencesChanged = PassthroughSubject<Void, Never>()
    let store: SettingsStore
    private var loop: Task<Void, Never>?
    private var generation = 0
    private var failures: [Service: Int] = [:]
    private var nextAttempt: [Service: Date] = [:]
    private var notificationTracker = QuotaNotificationTracker()
    private var pendingNotifications: Set<String> = []
    @Published var notificationAuthorization: UNAuthorizationStatus = .notDetermined
    private var isSleeping = false
    private var clock: AnyCancellable?
    private var observers: [NSObjectProtocol] = []
    private let log = Logger(subsystem: "app.devpet.mac", category: "refresh")
    var onSettings: (() -> Void)?
    var onRestore: (() -> Void)?
    var mood: Mood {
        if preferences.demo, let demoMood { return demoMood }
        return UsageLogic.mood(snapshots, services: preferences.services, now: now, celebrating: celebrationUntil > now, maxAge: preferences.staleAge)
    }
    var accent: Color { Palette.color(preferences.palette, hex: preferences.customHex) }
    init(store: SettingsStore = SettingsStore()) {
        self.store = store; preferences = store.load()
        if let data = store.defaults.data(forKey: "quotaNotificationsV2"), let tracker = try? JSONDecoder().decode(QuotaNotificationTracker.self, from: data) { notificationTracker = tracker }
        if CommandLine.arguments.contains("--demo") { preferences.demo = true }
        clock = Timer.publish(every: 30, on: .main, in: .common).autoconnect().sink { [weak self] date in self?.now = date }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.isSleeping = true; self?.suspended = true; self?.loop?.cancel() } })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.isSleeping = false; self?.suspended = false; self?.restartPolling() } })
    }
    func start() { restartPolling() }
    func restartPolling() {
        generation += 1; loop?.cancel(); guard !isSleeping else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                while self.refreshing && !Task.isCancelled {
                    do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
                }
                guard !Task.isCancelled else { return }
                await self.refresh(force: false)
                let seconds = max(60, min(1800, self.preferences.refreshMinutes * 60))
                do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
            }
        }
    }
    func refresh(force: Bool = true) async {
        guard !refreshing, !isSleeping else { return }
        refreshing = true; defer { refreshing = false }
        let currentGeneration = generation, prefs = preferences
        var providers: [(Service, any UsageProvider)] = []
        for service in Service.allCases where prefs.services.contains(service) {
            if !force, let date = nextAttempt[service], date > Date() { continue }
            let provider: any UsageProvider = prefs.demo ? DemoProvider(service: service, remaining: service == .claude ? 47 : 43) : (service == .claude ? ClaudeProvider() as any UsageProvider : CodexProvider(executable: prefs.codexPath))
            providers.append((service, provider))
        }
        let results = await withTaskGroup(of: UsageSnapshot.self) { group in
            for (_, provider) in providers { group.addTask { await provider.fetch() } }
            var collected: [UsageSnapshot] = []
            for await snapshot in group { collected.append(snapshot) }
            return collected
        }
        guard currentGeneration == generation, !Task.isCancelled else { return }
        now = Date()
        for result in results {
            let old = snapshots.first { $0.service == result.service }
            if result.connection == .connected {
                failures[result.service] = 0; nextAttempt[result.service] = nil
                let confirmed = result.windows.filter { window in
                    guard let old, old.connection == .connected, let oldDate = old.refreshedAt, let newDate = result.refreshedAt, newDate > oldDate else { return false }
                    return UsageLogic.confirmedReset(previous: old.windows.first { $0.kind == window.kind }, current: window, observedAt: newDate)
                }
                if !prefs.demo {
                    if !confirmed.isEmpty {
                        celebrationUntil = now.addingTimeInterval(8)
                        Task { [weak self] in
                            try? await Task.sleep(for: .seconds(8))
                            self?.now = Date()
                        }
                    }
                    await notify(result)
                    guard currentGeneration == generation, !Task.isCancelled else { return }
                }
            } else {
                let count = min((failures[result.service] ?? 0) + 1, 6)
                failures[result.service] = count
                nextAttempt[result.service] = now.addingTimeInterval(min(1800, prefs.refreshMinutes * 60 * pow(2, Double(count))))
                log.info("Provider unavailable: \(result.service.rawValue, privacy: .public)")
            }
            if let index = snapshots.firstIndex(where: { $0.service == result.service }) { snapshots[index] = result }
        }
        for service in Service.allCases where !prefs.services.contains(service) {
            if let index = snapshots.firstIndex(where: { $0.service == service }) { snapshots[index] = UsageSnapshot(service: service, connection: .disabled) }
        }
    }
    func connectionSettingsChanged() {
        snapshots = Service.allCases.map { UsageSnapshot(service: $0) }
        celebrationUntil = .distantPast; demoMood = nil; failures = [:]; nextAttempt = [:]
        restartPolling()
    }
    func refreshNotificationAuthorization() async {
        notificationAuthorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
    func enableNotifications() {
        guard preferences.notifications else { return }
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                systemMessage = granted ? "" : text("Notifications are disabled in System Settings.", "Bildirimler Sistem Ayarları’nda kapalı.")
            } catch { systemMessage = error.localizedDescription }
            await refreshNotificationAuthorization()
            if canSendNotifications {
                for snapshot in snapshots { await notify(snapshot) }
            }
        }
    }
    var canSendNotifications: Bool { notificationAuthorization == .authorized || notificationAuthorization == .provisional }
    func sendTestNotification() async {
        await refreshNotificationAuthorization()
        guard canSendNotifications else {
            systemMessage = text("Allow DevPet notifications in System Settings → Notifications.", "Sistem Ayarları → Bildirimler’den DevPet bildirimlerine izin verin."); return
        }
        let content = UNMutableNotificationContent()
        content.title = "DevPet"
        content.body = text("Limit notifications are ready. Keep building!", "Limit bildirimleri hazır. Çalışmaya devam!")
        content.sound = .default
        do {
            try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "devpet-notification-test", content: content, trigger: nil))
            systemMessage = text("Test notification sent.", "Test bildirimi gönderildi.")
        } catch { systemMessage = error.localizedDescription }
    }
    private func saveNotificationTracker() {
        store.defaults.set(try? JSONEncoder().encode(notificationTracker), forKey: "quotaNotificationsV2")
    }
    private func notify(_ snapshot: UsageSnapshot) async {
        let notices = notificationTracker.notices(for: snapshot, preferences: preferences, now: now)
        saveNotificationTracker()
        guard !notices.isEmpty else { return }
        await refreshNotificationAuthorization()
        guard preferences.notifications, !preferences.demo, canSendNotifications else { return }
        for notice in notices {
            guard preferences.notifications, !preferences.demo, snapshot.isFresh(at: Date(), maxAge: preferences.staleAge), preferences.services.contains(notice.service), preferences.windows.contains(notice.window.kind) else { continue }
            switch notice.kind {
            case .reset: guard preferences.resetNotifications else { continue }
            case .exhausted: guard preferences.exhaustedNotifications else { continue }
            case .early, .critical: guard preferences.lowWarnings else { continue }
            }
            guard notificationTracker.needsDelivery(notice), pendingNotifications.insert(notice.id).inserted else { continue }
            defer { pendingNotifications.remove(notice.id) }
            let content = UNMutableNotificationContent()
            content.title = "DevPet · \(notice.service.title)"
            let name = notice.window.kind == .fiveHour ? text("5-hour", "5 saatlik") : text("Weekly", "Haftalık")
            switch notice.kind {
            case .reset: content.body = name + ": " + text("Quota renewed. You can continue working.", "Kota yenilendi. Çalışmaya devam edebilirsin.")
            case .exhausted: content.body = name + ": " + text("Quota exhausted.", "Kullanım hakkın bitti.")
            case .early, .critical:
                content.body = name + ": " + String(Int(notice.window.remaining.rounded(.down))) + text("% remaining.", "% kullanım hakkın kaldı.")
            }
            if let reset = notice.window.resetsAt, notice.kind != .reset {
                content.body += " " + text("Renews in ", "Yenilenmesine kalan: ") + UsageLogic.countdown(reset, now: now) + "."
            }
            content.sound = .default
            do {
                try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: notice.id, content: content, trigger: nil))
                notificationTracker.delivered(notice)
                saveNotificationTracker()
            } catch { log.error("Could not schedule quota notification.") }
        }
    }
    var loginEnabled: Bool { SMAppService.mainApp.status == .enabled }
    func setLogin(_ enabled: Bool) {
        do { if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; objectWillChange.send() }
        catch { systemMessage = error.localizedDescription }
    }
    func text(_ english: String, _ turkish: String) -> String { preferences.language == "tr" ? turkish : english }
    func animalName(_ animal: Animal) -> String {
        let tr = ["Kedi", "Köpek", "Tilki", "Panda", "Tavşan", "Ayı", "Baykuş", "Kurbağa", "Penguen", "Rakun", "Kapibara", "Kurt"]
        return preferences.language == "tr" ? tr[Animal.allCases.firstIndex(of: animal)!] : animal.rawValue.capitalized
    }
    func moodName(_ mood: Mood) -> String {
        switch mood {
        case .happy: return text("Happily working", "Keyifle çalışıyor")
        case .normal: return text("Ready to build", "Üretmeye hazır")
        case .alert: return text("Take it steady", "Dengeli ilerle")
        case .tired: return text("Working, but tired", "Yorgun ama çalışıyor")
        case .sleeping: return text("Very tired · Resting", "Çok yorgun · Dinleniyor")
        case .unknown: return text("Waiting for usage", "Kota verisi bekleniyor")
        }
    }
}
struct Palette {
    static let names = ["Terminal Green", "Cyber Blue", "Amber", "Neon Purple", "Rose Pink", "Ocean Cyan", "Monochrome", "Sunset Orange", "Custom"]
    static func color(_ name: String, hex: String = "5B8CFF") -> Color {
        let values = ["Cyber Blue": "69B9FF", "Terminal Green": "4AE68C", "Neon Purple": "AF75F8", "Sunset Orange": "FF9259", "Rose Pink": "F87FAC", "Ocean Cyan": "4CE2EB", "Monochrome": "C8CEDF", "Amber": "F6C267", "Slate": "A8ADBD"]
        let number = UInt32(values[name] ?? hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x5B8CFF
        return Color(red: Double((number >> 16) & 255) / 255, green: Double((number >> 8) & 255) / 255, blue: Double(number & 255) / 255)
    }
}
