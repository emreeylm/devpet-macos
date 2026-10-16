import AppKit
import SwiftUI
import Combine
#if canImport(DevPetCore)
import DevPetCore
#endif

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
@MainActor final class WindowCoordinator: NSObject, NSWindowDelegate {
    let model: AppModel
    let pet: FloatingPanel
    let stats: FloatingPanel
    private var settings: NSWindow?
    private var subscription: AnyCancellable?
    private var screenObserver: NSObjectProtocol?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var resizing = false
    private var lastMode = ""
    private var lastDashboardLayout = ""
    init(model: AppModel) {
        self.model = model
        pet = FloatingPanel(contentRect: CGRect(x: 100, y: 100, width: 160, height: 176), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        stats = FloatingPanel(contentRect: CGRect(x: 100, y: 100, width: 430, height: 530), styleMask: [.borderless, .nonactivatingPanel, .resizable], backing: .buffered, defer: false)
        super.init()
        for window in [pet, stats] {
            window.isOpaque = false; window.backgroundColor = .clear
            window.hasShadow = window === stats
            window.isMovableByWindowBackground = true
            window.hidesOnDeactivate = false
            window.isReleasedWhenClosed = false
            // Apply cross-application eligibility together with the always-on-top preference.
            window.collectionBehavior = Self.collectionBehavior(alwaysOnTop: model.preferences.alwaysOnTop)
            window.delegate = self
        }
        pet.contentView = NSHostingView(rootView: AnyView(PetWidget(model: model).environment(\.displayScale, pet.backingScaleFactor)))
        stats.contentView = NSHostingView(rootView: AnyView(UsageDashboard(model: model).environment(\.displayScale, stats.backingScaleFactor)))
        stats.minSize = NSSize(width: 310, height: 180); stats.maxSize = NSSize(width: 850, height: 800)
        lastMode = model.preferences.mode
        stats.minSize = NSSize(width: 390, height: model.preferences.dashboardHeight)
        restoreSaved(pet, key: "petFrame", defaultOffset: NSPoint(x: 210, y: 310))
        restoreSaved(stats, key: "statsFrame", defaultOffset: NSPoint(x: 470, y: 480))
        let disclosureLayoutMigrated = model.store.defaults.bool(forKey: "disclosureLayoutV1")
        lastDashboardLayout = disclosureLayoutMigrated ? model.preferences.dashboardLayoutID : ""
        model.store.defaults.set(true, forKey: "disclosureLayoutV1")
        model.onSettings = { [weak self] in self?.showSettings() }
        model.onRestore = { [weak self] in self?.resetPositions() }
        subscription = model.preferencesChanged.sink { [weak self] in self?.apply() }
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.recoverWindows(); self?.reassertFloatingWindows() } }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification] {
            workspaceObservers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.reassertFloatingWindows() }
            })
        }
        apply()
        updateRenderingScale(pet); updateRenderingScale(stats)
    }
    static func collectionBehavior(alwaysOnTop: Bool) -> NSWindow.CollectionBehavior {
        if alwaysOnTop {
            // Supported public AppKit behavior for overlays across other apps, Stage Manager
            // sets and eligible full-screen Spaces. Never use screen-saver/system window levels.
            return [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary, .ignoresCycle]
        }
        return [.canJoinAllSpaces, .fullScreenNone, .ignoresCycle]
    }
    func reassertFloatingWindows() {
        guard model.preferences.alwaysOnTop, NSEvent.pressedMouseButtons & 1 == 0 else { return }
        for window in [pet, stats] {
            window.level = .floating
            window.collectionBehavior = Self.collectionBehavior(alwaysOnTop: true)
            let visible = window === pet ? shouldShowStandalonePet : model.preferences.statsVisible && model.preferences.mode == "expanded"
            if visible { window.orderFrontRegardless() }
        }
    }
    func windowDidChangeScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === pet || window === stats else { return }
        // Refresh the backing scale without clamping or interrupting the drag.
        updateRenderingScale(window)
        reassertFloatingWindows()
    }
    var shouldShowStandalonePet: Bool {
        let p = model.preferences
        if p.mode == "minimal" { return p.statsVisible }
        return p.petVisible && !(p.attachPet && p.statsVisible && p.mode != "pet")
    }
    func apply() {
        let p = model.preferences
        resizing = true
        for window in [pet, stats] {
            window.level = p.alwaysOnTop ? .floating : .normal
            window.collectionBehavior = Self.collectionBehavior(alwaysOnTop: p.alwaysOnTop)
            window.alphaValue = p.opacity
        }
        pet.ignoresMouseEvents = p.mode != "minimal" && p.clickThrough
        pet.setContentSize(NSSize(width: p.petWindowWidth, height: p.petWindowHeight))
        if lastMode != p.mode {
            stats.minSize = NSSize(width: 390, height: 180)
            stats.setContentSize(NSSize(width: 430, height: 530))
            lastMode = p.mode
        }
        stats.minSize = NSSize(width: 390, height: p.dashboardHeight)
        if lastDashboardLayout != p.dashboardLayoutID || stats.frame.height < stats.minSize.height {
            let top = stats.frame.maxY
            let height = p.dashboardHeight
            let target = NSRect(x: stats.frame.minX, y: top - height, width: max(stats.frame.width, stats.minSize.width), height: height)
            let fitted = UsageLogic.restore(frame: target, screens: NSScreen.screens.map(\.visibleFrame))
            stats.setFrame(fitted, display: true, animate: stats.isVisible && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
            lastDashboardLayout = p.dashboardLayoutID
        }
        resizing = false
        recoverWindows()
        setVisible(pet, shouldShowStandalonePet)
        setVisible(stats, p.statsVisible && p.mode == "expanded")
    }
    /// Fades a panel in or out on visibility changes only; repeated calls leave it untouched.
    private func setVisible(_ window: NSWindow, _ visible: Bool) {
        let target = model.preferences.opacity
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            visible ? window.orderFrontRegardless() : window.orderOut(nil); return
        }
        if visible {
            if !window.isVisible { window.alphaValue = 0 }
            window.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { $0.duration = 0.18; window.animator().alphaValue = target }
        } else if window.isVisible {
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.15; window.animator().alphaValue = 0 }) { [weak window] in
                // Skip if it was re-shown while fading out.
                if let window, window.alphaValue == 0 { window.orderOut(nil) }
            }
        }
    }
    func showSettings() {
        if settings == nil {
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 820, height: 700), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "DevPet"; window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 790, height: 660)
            window.contentView = NSHostingView(rootView: SettingsView(model: model))
            window.center(); settings = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settings?.makeKeyAndOrderFront(nil)
    }
    func resetPositions() {
        model.preferences.clickThrough = false; model.preferences.petVisible = true; model.preferences.statsVisible = true
        for (window, x, y) in [(pet, 210.0, 310.0), (stats, 470.0, 480.0)] {
            if let screen = NSScreen.main?.visibleFrame { window.setFrameOrigin(NSPoint(x: screen.maxX - x, y: screen.maxY - y)) }
        }
        recoverWindows(); save(pet); save(stats)
    }
    private func restoreSaved(_ window: NSWindow, key: String, defaultOffset: NSPoint) {
        let defaults = model.store.defaults
        guard let saved = defaults.dictionary(forKey: key), let x = saved["x"] as? Double, let y = saved["y"] as? Double, x.isFinite, y.isFinite else {
            if let frame = NSScreen.main?.visibleFrame { window.setFrameOrigin(NSPoint(x: frame.maxX - defaultOffset.x, y: frame.maxY - defaultOffset.y)) }; return
        }
        let width = saved["width"] as? Double ?? window.frame.width
        let height = saved["height"] as? Double ?? window.frame.height
        guard width.isFinite, height.isFinite, width > 0, height > 0 else { return }
        let frame = CGRect(x: x, y: y, width: width, height: height)
        let screens = NSScreen.screens
        let preferred = screens.firstIndex { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.intValue == saved["screen"] as? Int }
        window.setFrame(UsageLogic.restore(frame: frame, screens: screens.map(\.visibleFrame), preferred: preferred), display: false)
    }
    func recoverWindows() {
        resizing = true
        for window in [pet, stats] {
            let fitted = UsageLogic.restore(frame: window.frame, screens: NSScreen.screens.map(\.visibleFrame))
            // Leave unchanged frames alone so an in-flight resize animation isn't cancelled.
            if fitted != window.frame { window.setFrame(fitted, display: true) }
        }
        resizing = false
    }
    private func updateRenderingScale(_ window: NSWindow) {
        guard let host = window.contentView as? NSHostingView<AnyView> else { return }
        let scale = window.backingScaleFactor
        if window === pet { host.rootView = AnyView(PetWidget(model: model).environment(\.displayScale, scale)) }
        else if window === stats { host.rootView = AnyView(UsageDashboard(model: model).environment(\.displayScale, scale)) }
        host.needsDisplay = true
    }
    func windowDidChangeBackingProperties(_ notification: Notification) {
        if let window = notification.object as? NSWindow { updateRenderingScale(window) }
    }
    func windowDidMove(_ notification: Notification) { if let window = notification.object as? NSWindow, !resizing { save(window) } }
    func windowDidResize(_ notification: Notification) { if let window = notification.object as? NSWindow, !resizing { save(window) } }
    private func save(_ window: NSWindow) {
        let frame = window.frame
        let screen = (window.screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.intValue ?? 0
        model.store.defaults.set(["x": frame.minX, "y": frame.minY, "width": frame.width, "height": frame.height, "screen": Double(screen)], forKey: window === pet ? "petFrame" : "statsFrame")
    }
    func verify() -> [String: Bool] {
        ["petNonActivating": !pet.canBecomeKey, "statsNonActivating": !stats.canBecomeKey,
         "petFloating": pet.level == .floating,
         "joinsOtherApplications": pet.collectionBehavior.contains(.canJoinAllApplications) && stats.collectionBehavior.contains(.canJoinAllApplications),
         "eligibleFullScreenOverlay": pet.collectionBehavior.contains(.fullScreenAuxiliary) && !pet.collectionBehavior.contains(.fullScreenNone), "statsResizable": stats.styleMask.contains(.resizable),
         "independentWindows": pet !== stats, "petVisible": pet.isVisible, "statsVisible": stats.isVisible,
         "validPetPosition": NSScreen.screens.contains { $0.visibleFrame.contains(pet.frame) },
         "validStatsPosition": NSScreen.screens.contains { $0.visibleFrame.contains(stats.frame) }]
    }
}
