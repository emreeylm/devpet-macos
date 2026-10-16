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
    private var notificationKeys: Set<String> = []
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
        notificationKeys = Set(store.defaults.stringArray(forKey: "notificationKeys") ?? [])
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
                    notify(result, resets: confirmed.map(\.kind))
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
    func enableNotifications() {
        guard preferences.notifications else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            Task { @MainActor in if !granted { self?.systemMessage = self?.text("Notifications are disabled in System Settings.", "Bildirimler Sistem Ayarları’nda kapalı.") ?? "" } }
        }
    }
    private func notify(_ snapshot: UsageSnapshot, resets: [WindowKind]) {
        guard preferences.notifications, snapshot.isFresh(at: now, maxAge: preferences.staleAge) else { return }
        for window in snapshot.windows where preferences.windows.contains(window.kind) && window.isValid(at: now) {
            let event: String?
            if resets.contains(window.kind) && preferences.resetNotifications { event = "reset" }
            else if window.remaining == 0 { event = "exhausted" }
            else if window.remaining < preferences.threshold && preferences.lowWarnings { event = "low" }
            else { event = nil }
            guard let event else { continue }
            let key = "\(snapshot.service.rawValue)-\(window.kind.rawValue)-\(window.resetsAt?.timeIntervalSince1970 ?? 0)-\(event)"
            guard !notificationKeys.contains(key) else { continue }
            let content = UNMutableNotificationContent()
            content.title = "DevPet · \(snapshot.service.title)"
            let name = window.kind == .fiveHour ? text("5-hour", "5 saatlik") : text("Weekly", "Haftalık")
            content.body = event == "reset" ? "\(name): " + text("Quota reset confirmed.", "Kota yenilenmesi doğrulandı.") : "\(name): \(Int(window.remaining))% " + text("remaining", "kaldı")
            content.sound = .default
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: key, content: content, trigger: nil)) { [weak self] error in
                Task { @MainActor in
                    guard error == nil, let self else { return }
                    self.notificationKeys.insert(key)
                    if self.notificationKeys.count > 512 { self.notificationKeys = Set(self.notificationKeys.sorted().suffix(256)) }
                    self.store.defaults.set(Array(self.notificationKeys), forKey: "notificationKeys")
                }
            }
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
