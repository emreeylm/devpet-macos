import AppKit
import SwiftUI
#if canImport(DevPetCore)
import DevPetCore
#endif

// A deliberately narrow Claude Code statusline bridge: no session, prompt or token data is retained.
func runClaudeBridge(outputURL: URL = ClaudeProvider.bridgeURL) -> Int32 {
    do {
        let input = FileHandle.standardInput.readDataToEndOfFile()
        guard input.count < 2_000_000, let payload = try JSONSerialization.jsonObject(with: input) as? [String: Any] else { return 1 }
        var normalized: [String: Any] = [:]
        if let rates = payload["rate_limits"] as? [String: Any] {
            for key in ["five_hour", "seven_day"] {
                if let source = rates[key] as? [String: Any], let used = source["used_percentage"] as? Double, used.isFinite, (0...100).contains(used) {
                    var window: [String: Any] = ["used_percentage": used]
                    if let reset = source["resets_at"] as? Double, reset.isFinite { window["resets_at"] = reset }
                    normalized[key] = window
                }
            }
        }
        let result: [String: Any] = ["observed_at": Date().timeIntervalSince1970, "rate_limits": normalized]
        let url = outputURL
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.deletingLastPathComponent().path)
        let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
        try data.write(to: url, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        let values = normalized["five_hour"] as? [String: Any]
        if let used = values?["used_percentage"] as? Double { print("DevPet · 5h \(Int((100 - used).rounded()))% left") } else { print("DevPet · usage unavailable") }
        return 0
    } catch { return 1 }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel!
    var windows: WindowCoordinator!
    var menu: MenuBarController!
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let special = CommandLine.arguments.contains("--render-gallery") || CommandLine.arguments.contains("--smoke-test")
        let defaults = special ? UserDefaults(suiteName: CommandLine.arguments.contains("--smoke-test") ? "app.devpet.verification" : "app.devpet.artwork")! : .standard
        model = AppModel(store: SettingsStore(defaults: defaults))
        if special { model.preferences = Preferences(); model.preferences.demo = true }
        if CommandLine.arguments.contains("--smoke-test") { model.preferences.attachPet = false }
        windows = WindowCoordinator(model: model); menu = MenuBarController(model: model)
        model.start()
        if CommandLine.arguments.contains("--settings") || (!special && !defaults.bool(forKey: "onboardingComplete")) {
            windows.showSettings(); defaults.set(true, forKey: "onboardingComplete")
        }
        if special {
            Task { @MainActor in
                await model.refresh()
                try? await Task.sleep(for: .seconds(1))
                if CommandLine.arguments.contains("--render-gallery") { renderGallery() }
                else { await smokeTest() }
                NSApp.terminate(nil)
            }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func renderGallery() {
        let output = CommandLine.arguments.drop { $0 != "--render-gallery" }.dropFirst().first ?? FileManager.default.currentDirectoryPath + "/Screenshots"
        try? FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
        render(DMGArtwork(), size: NSSize(width: 640, height: 420), path: output + "/DMGBackground.png")
        render(MascotGallery(), size: NSSize(width: 1380, height: 920), path: output + "/mascots.png")
        model.preferences.claudeExpanded = true; model.preferences.codexExpanded = true
        render(UsageDashboard(model: model), size: NSSize(width: 430, height: CGFloat(model.preferences.dashboardHeight)), path: output + "/dashboard.png")
        render(PetWidget(model: model), size: NSSize(width: model.preferences.petWindowWidth, height: model.preferences.petWindowHeight), path: output + "/pet-only.png")
        let previewSnapshots = model.snapshots
        for (name, remaining) in [("happy", 80.0), ("tired", 35.0), ("sleeping", 8.0)] {
            model.snapshots = Service.allCases.map { service in
                UsageSnapshot(service: service, windows: WindowKind.allCases.map { try! QuotaWindow(kind: $0, used: 100 - remaining, resetsAt: model.now.addingTimeInterval(3600)) }, refreshedAt: model.now, connection: .connected)
            }
            render(PetWidget(model: model), size: NSSize(width: model.preferences.petWindowWidth, height: model.preferences.petWindowHeight), path: output + "/pet-" + name + ".png")
        }
        model.snapshots = previewSnapshots
        model.preferences.size = 0.5
        render(PetWidget(model: model), size: NSSize(width: model.preferences.petWindowWidth, height: model.preferences.petWindowHeight), path: output + "/pet-only-small.png")
        model.preferences.size = 2
        render(PetWidget(model: model), size: NSSize(width: model.preferences.petWindowWidth, height: model.preferences.petWindowHeight), path: output + "/pet-only-large.png")
        model.preferences.size = 1
        let layoutAnimal = model.preferences.animal
        let layoutMode = model.preferences.mode
        let layoutProviders = model.preferences.providerSelection
        model.preferences.mode = "minimal"
        for selection in ["both", "claude", "codex"] {
            model.preferences.selectProviders(selection)
            renderClarity(PetWidget(model: model, interactive: false), size: NSSize(width: model.preferences.petWindowWidth, height: model.preferences.petWindowHeight), path: output + "/minimal-" + selection + ".png", scale: 2)
        }
        model.preferences.selectProviders("both")
        model.preferences.size = 2.5
        renderClarity(PetWidget(model: model, interactive: false), size: NSSize(width: model.preferences.petWindowWidth, height: model.preferences.petWindowHeight), path: output + "/minimal-250.png", scale: 2)
        model.preferences.size = 1
        model.preferences.selectProviders(layoutProviders)
        model.preferences.mode = layoutMode
        for animal in Animal.allCases {
            model.preferences.animal = animal
            renderClarity(PetWidget(model: model, interactive: false), size: NSSize(width: model.preferences.petWindowWidth, height: model.preferences.petWindowHeight), path: output + "/quota-layout-" + animal.rawValue + ".png", scale: 2)
        }
        model.preferences.animal = layoutAnimal
        let layoutTransparency = model.preferences.transparent
        model.preferences.transparent = false
        for animal in [Animal.fox, .rabbit, .capybara] {
            model.preferences.animal = animal
            renderClarity(PetWidget(model: model, interactive: false), size: NSSize(width: model.preferences.petWindowWidth, height: model.preferences.petWindowHeight), path: output + "/backplate-" + animal.rawValue + ".png", scale: 2)
        }
        model.preferences.animal = layoutAnimal
        model.preferences.transparent = layoutTransparency
        renderClarity(VStack(spacing: 8) {
            ForEach(Animal.allCases, id: \.rawValue) { animal in
                HStack(spacing: 8) {
                    Text(animal.rawValue).font(.system(size: 12, design: .monospaced)).foregroundStyle(.white).frame(width: 85)
                    ForEach([0.0, 0.125, 0.4].indices, id: \.self) { index in
                        MascotView(animal: animal, mood: .happy, accent: .green, animate: false, previewTime: [0.0, 0.125, 0.4][index]).frame(width: 160, height: 130)
                    }
                    MascotView(animal: animal, mood: .sleeping, accent: .purple, animate: false, previewTime: 0).frame(width: 160, height: 130)
                }
            }
        }.padding(12).background(Color(hex: 0x0B1424)), size: NSSize(width: 785, height: 1672), path: output + "/typing-companions.png", scale: 1)
        render(HStack(spacing: 4) {
            ForEach([Animal.cat, .dog], id: \.rawValue) { animal in
                VStack(spacing: 8) {
                    ForEach([Mood.happy, .tired, .sleeping], id: \.rawValue) { mood in
                        HStack(spacing: 2) {
                            ForEach([0.25, 1.0, 2.25], id: \.self) { phase in
                                MascotView(animal: animal, mood: mood, accent: Palette.color("Terminal Green"), animate: false, previewTime: phase).frame(width: 144, height: 117)
                            }
                        }
                    }
                }
            }
        }.padding(14).background(Color(hex: 0x0B1424)), size: NSSize(width: 908, height: 395), path: output + "/activity-frames.png")
        for backing in [1.0, 2.0] {
            for factor in [0.5, 1.0, 1.5, 2.0, 2.5] {
                model.preferences.size = factor
                renderClarity(PetWidget(model: model, interactive: false), size: NSSize(width: model.preferences.petWindowWidth, height: model.preferences.petWindowHeight), path: output + "/clarity-" + String(Int(backing)) + "x-" + String(Int(factor * 100)) + ".png", scale: backing)
            }
        }
        model.preferences.size = 1
        renderClarity(HStack(spacing: 4) {
            ForEach([0.1, 0.25, 0.5, 0.75], id: \.self) { phase in
                MascotView(animal: .capybara, mood: .happy, accent: Palette.color("Terminal Green"), animate: false, previewTime: phase).frame(width: 198, height: 161)
            }
        }.padding(12).background(Color(hex: 0x0B1424)), size: NSSize(width: 828, height: 185), path: output + "/typing-stability.png", scale: 2)
        for (index, phase) in [0.1, 0.5].enumerated() {
            renderClarity(MascotView(animal: .capybara, mood: .tired, accent: Palette.color("Terminal Green"), animate: false, previewTime: phase).frame(width: 198, height: 161), size: NSSize(width: 198, height: 161), path: output + "/typing-phase-" + String(index) + ".png", scale: 2)
        }
        render(SettingsView(model: model), size: NSSize(width: 820, height: 760), path: output + "/settings.png")
        render(MascotView(animal: .capybara, mood: .normal, accent: Palette.color("Terminal Green"), animate: false).padding(60).background(Color(red: 0.065, green: 0.08, blue: 0.15), in: RoundedRectangle(cornerRadius: 64)), size: NSSize(width: 1024, height: 1024), path: output + "/AppIcon.png")
        print("Rendered artwork and UI to \(output)")
    }
    func smokeTest() async {
        var checks = windows.verify()
        checks["companionAtlasHasAll36States"] = CompanionAtlas.isLoaded
        checks["all36PetStatesUseStableCanvas"] = Animal.allCases.allSatisfy { animal in
            let states = [Mood.happy, .tired, .sleeping].compactMap { CompanionAtlas.frame(animal: animal, mood: $0) }
            guard states.count == 3, let first = states.first else { return false }
            return states.allSatisfy { $0.size == first.size && $0.image.width == first.image.width && $0.image.height == first.image.height }
        }
        let initialSnapshots = model.snapshots
        model.snapshots = Service.allCases.map { service in
            UsageSnapshot(service: service, windows: [try! QuotaWindow(kind: .fiveHour, used: 20, resetsAt: model.now.addingTimeInterval(3600)), try! QuotaWindow(kind: .weekly, used: 100, resetsAt: model.now.addingTimeInterval(86400))], refreshedAt: model.now, connection: .connected)
        }
        checks["weeklyExhaustionDoesNotChangeAnimation"] = model.mood == .happy
        let fiveHourVisible = model.preferences.fiveHourEnabled
        model.preferences.fiveHourEnabled = false
        checks["hiddenFiveHourStillControlsAnimation"] = model.mood == .happy
        model.preferences.fiveHourEnabled = fiveHourVisible
        model.snapshots = initialSnapshots
        model.preferences.clickThrough = true
        checks["clickThrough"] = windows.pet.ignoresMouseEvents
        model.preferences.clickThrough = false
        checks["clickThroughRecovery"] = !windows.pet.ignoresMouseEvents
        var legacyPreferences = model.preferences
        legacyPreferences.mode = "compact"
        legacyPreferences.sanitize()
        checks["legacyCompactMigratesToExpanded"] = legacyPreferences.mode == "expanded"
        model.preferences.petVisible = false
        try? await Task.sleep(for: .milliseconds(250))
        checks["hidePet"] = !windows.pet.isVisible
        windows.resetPositions()
        checks["recoverPet"] = windows.pet.isVisible && !windows.pet.ignoresMouseEvents
        model.preferences.mode = "expanded"
        let originalStatsFrame = windows.stats.frame
        windows.pet.setFrameOrigin(NSPoint(x: windows.pet.frame.minX - 30, y: windows.pet.frame.minY))
        checks["independentPosition"] = windows.stats.frame == originalStatsFrame
        windows.stats.setContentSize(NSSize(width: 510, height: 530))
        checks["resizedStats"] = windows.stats.frame.size == NSSize(width: 510, height: 530)
        let restored = WindowCoordinator(model: model)
        checks["restoredStatsSize"] = restored.stats.frame.size == windows.stats.frame.size
        restored.pet.orderOut(nil); restored.stats.orderOut(nil)
        model.preferences.alwaysOnTop = false
        checks["unpinUsesNormalLevel"] = windows.pet.level == .normal && windows.stats.level == .normal
        checks["unpinOptsOutOfOtherApplications"] = !windows.pet.collectionBehavior.contains(.canJoinAllApplications)
        windows.reassertFloatingWindows()
        checks["reassertRespectsUnpin"] = windows.pet.level == .normal
        model.preferences.alwaysOnTop = true
        windows.pet.level = .normal
        windows.windowDidChangeScreen(Notification(name: NSWindow.didChangeScreenNotification, object: windows.pet))
        checks["screenChangeRestoresFloatingLevel"] = windows.pet.level == .floating
        model.preferences.petVisible = false
        windows.reassertFloatingWindows()
        try? await Task.sleep(for: .milliseconds(250))
        checks["reassertKeepsHiddenPetHidden"] = !windows.pet.isVisible
        model.preferences.petVisible = true
        model.preferences.attachPet = true
        try? await Task.sleep(for: .milliseconds(250))
        checks["attachedPetHasNoSeparateWindow"] = !windows.pet.isVisible && windows.stats.isVisible
        model.preferences.statsVisible = false
        checks["hiddenStatsRestoresStandalonePet"] = windows.pet.isVisible
        model.preferences.statsVisible = true
        model.preferences.mode = "pet"
        try? await Task.sleep(for: .milliseconds(250))
        checks["petOnlyRestoresStandalonePet"] = windows.pet.isVisible && !windows.stats.isVisible
        model.preferences.mode = "expanded"
        model.preferences.attachPet = false
        checks["detachingRestoresSeparatePet"] = windows.pet.isVisible && windows.stats.isVisible
        model.preferences.attachPet = true
        try? await Task.sleep(for: .milliseconds(100))
        windows.stats.contentView?.layoutSubtreeIfNeeded()
        let dragSurface = windows.stats.contentView?.subviewsRecursive.first { $0 is DragSurface && $0.identifier?.rawValue == "dashboardHeaderDrag" }
        checks["nativeDragSurfaceInstalled"] = dragSurface != nil
        checks["nativeDragSurfaceHasHitArea"] = (dragSurface?.bounds.width ?? 0) > 100 && (dragSurface?.bounds.height ?? 0) >= 40
        if let dragSurface = dragSurface as? DragSurface {
            let before = windows.stats.frame.origin
            func event(_ type: NSEvent.EventType, _ point: NSPoint) -> NSEvent {
                NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: windows.stats.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
            }
            dragSurface.mouseDown(with: event(.leftMouseDown, NSPoint(x: 100, y: 100)))
            dragSurface.mouseDragged(with: event(.leftMouseDragged, NSPoint(x: 135, y: 75)))
            dragSurface.mouseUp(with: event(.leftMouseUp, NSPoint(x: 100, y: 100)))
            let delta = NSPoint(x: windows.stats.frame.minX - before.x, y: windows.stats.frame.minY - before.y)
            checks["nativeMouseDragMovesPanel"] = abs(delta.x - 35) < 1 && abs(delta.y + 25) < 1
            if checks["nativeMouseDragMovesPanel"] == false { print("Unexpected simulated mouse drag delta: \(delta)") }
        }
        model.preferences.selectProviders("both")
        model.preferences.setExpanded(false, for: .claude)
        model.preferences.setExpanded(false, for: .codex)
        let collapsedHeight = windows.stats.frame.height
        let collapsedTop = windows.stats.frame.maxY
        model.preferences.setExpanded(true, for: .claude)
        checks["disclosureExpandsWindowDownward"] = windows.stats.frame.height > collapsedHeight && abs(windows.stats.frame.maxY - collapsedTop) < 1
        checks["disclosuresAreIndependent"] = model.preferences.isExpanded(.claude) && !model.preferences.isExpanded(.codex)
        model.preferences.setExpanded(false, for: .claude)
        checks["disclosureCollapseShrinksWindow"] = windows.stats.frame.height == collapsedHeight
        model.preferences.selectProviders("claude")
        checks["claudeOnlySelection"] = model.preferences.services == [.claude] && windows.stats.frame.height < collapsedHeight
        model.preferences.selectProviders("codex")
        checks["codexOnlySelection"] = model.preferences.services == [.codex]
        model.preferences.selectProviders("both")
        checks["bothProvidersSelection"] = model.preferences.services == [.claude, .codex]
        model.preferences.mode = "pet"
        try? await Task.sleep(for: .milliseconds(100))
        windows.pet.contentView?.layoutSubtreeIfNeeded()
        let petSurface = windows.pet.contentView?.subviewsRecursive.first { $0.identifier?.rawValue == "petDragSurface" } as? DragSurface
        checks["standalonePetDragSurface"] = petSurface != nil && (petSurface?.bounds.width ?? 0) >= windows.pet.frame.width - 1
        checks["standalonePetContextMenu"] = petSurface?.menuFactory != nil
        if let petSurface {
            let before = windows.pet.frame.origin
            func petEvent(_ type: NSEvent.EventType, _ point: NSPoint) -> NSEvent {
                NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: windows.pet.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
            }
            petSurface.mouseDown(with: petEvent(.leftMouseDown, NSPoint(x: 50, y: 50)))
            petSurface.mouseDragged(with: petEvent(.leftMouseDragged, NSPoint(x: 25, y: 25)))
            petSurface.mouseUp(with: petEvent(.leftMouseUp, NSPoint(x: 50, y: 50)))
            checks["standalonePetMouseDragMovesWindow"] = abs(windows.pet.frame.minX - before.x + 25) < 1 && abs(windows.pet.frame.minY - before.y + 25) < 1
        }
        checks["petQuotaBadgesHaveRoom"] = windows.pet.frame.width > model.preferences.petSpriteSide && abs(windows.pet.frame.height - model.preferences.petWindowHeight) <= 1
        model.preferences.mode = "minimal"
        model.preferences.statsVisible = true
        model.preferences.petVisible = false
        model.preferences.clickThrough = true
        try? await Task.sleep(for: .milliseconds(250))
        windows.pet.contentView?.layoutSubtreeIfNeeded()
        checks["minimalOnlyShowsSmallPanel"] = windows.pet.isVisible && !windows.stats.isVisible && abs(windows.pet.frame.width - 120 * model.preferences.size) < 1
        checks["minimalDragIgnoresPetClickThrough"] = !windows.pet.ignoresMouseEvents
        let minimalSurface = windows.pet.contentView?.subviewsRecursive.first { $0.identifier?.rawValue == "minimalDragSurface" } as? DragSurface
        checks["minimalHasDragAndMenu"] = minimalSurface?.menuFactory != nil && (minimalSurface?.bounds.width ?? 0) >= windows.pet.frame.width - 1
        if let minimalSurface {
            let before = windows.pet.frame.origin
            func event(_ type: NSEvent.EventType, _ point: NSPoint) -> NSEvent {
                NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: windows.pet.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
            }
            minimalSurface.mouseDown(with: event(.leftMouseDown, NSPoint(x: 50, y: 30)))
            minimalSurface.mouseDragged(with: event(.leftMouseDragged, NSPoint(x: 25, y: 20)))
            minimalSurface.mouseUp(with: event(.leftMouseUp, NSPoint(x: 50, y: 30)))
            checks["minimalNativeDragMovesPanel"] = abs(windows.pet.frame.minX - before.x + 25) < 1 && abs(windows.pet.frame.minY - before.y + 10) < 1
        }
        model.preferences.selectProviders("claude")
        checks["minimalSingleProviderShrinks"] = abs(windows.pet.frame.height - 48 * model.preferences.size) < 1
        model.preferences.selectProviders("both")
        model.preferences.statsVisible = false
        try? await Task.sleep(for: .milliseconds(250))
        windows.reassertFloatingWindows()
        checks["minimalHideRespected"] = !windows.pet.isVisible && !windows.stats.isVisible
        model.preferences.statsVisible = true
        model.preferences.petVisible = true
        model.preferences.clickThrough = false
        model.preferences.mode = "pet"
        if let screen = windows.pet.screen ?? NSScreen.main {
            let before = windows.pet.frame
            let visible = screen.visibleFrame
            for (name, x) in [("topLeftCorner", visible.minX), ("topRightCorner", visible.maxX - before.width)] {
                windows.pet.setFrameOrigin(NSPoint(x: x, y: visible.maxY - before.height))
                windows.recoverWindows()
                checks[name] = abs(windows.pet.frame.minX - x) < 1 && abs(windows.pet.frame.maxY - visible.maxY) < 1
            }
            windows.pet.setFrame(before, display: false)
        }
        model.preferences.mode = "expanded"
        try? await Task.sleep(for: .milliseconds(100))
        let topBar = windows.stats.contentView?.subviewsRecursive.first { $0.identifier?.rawValue == "dashboardTitleBarDrag" } as? DragSurface
        checks["fullWidthTitleBarDragSurface"] = topBar != nil && (topBar?.bounds.width ?? 0) >= windows.stats.frame.width - 1 && (topBar?.bounds.height ?? 0) == 24
        if let topBar {
            let before = windows.stats.frame.origin
            let y = windows.stats.frame.height - 10
            func titleEvent(_ type: NSEvent.EventType, _ point: NSPoint) -> NSEvent {
                NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: windows.stats.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
            }
            topBar.mouseDown(with: titleEvent(.leftMouseDown, NSPoint(x: 100, y: y)))
            topBar.mouseDragged(with: titleEvent(.leftMouseDragged, NSPoint(x: 75, y: y - 25)))
            topBar.mouseUp(with: titleEvent(.leftMouseUp, NSPoint(x: 100, y: y)))
            checks["titleBarMouseDragMovesWindow"] = abs(windows.stats.frame.minX - before.x + 25) < 1 && abs(windows.stats.frame.minY - before.y + 25) < 1
        }
        checks["demoConnected"] = model.snapshots.allSatisfy { $0.connection == .connected }
        let data = try! JSONSerialization.data(withJSONObject: checks, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))
        let path = CommandLine.arguments.drop { $0 != "--smoke-test" }.dropFirst().first
        if let path { try? data.write(to: URL(fileURLWithPath: path)) }
    }
    func render<V: View>(_ view: V, size: NSSize, path: String) {
        let host = NSHostingView(rootView: view.environment(\.colorScheme, .dark).environment(\.displayScale, 2))
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        try? bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }
    func renderClarity<V: View>(_ view: V, size: NSSize, path: String, scale: Double) {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .dark).environment(\.displayScale, scale))
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
        renderer.scale = scale
        guard let image = renderer.cgImage else { return }
        let bitmap = NSBitmapImageRep(cgImage: image)
        bitmap.size = size
        try? bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }

}
struct DMGArtwork: View {
    var body: some View {
        VStack(spacing: 5) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("DevPet").font(.system(size: 34, weight: .bold, design: .monospaced))
                    Text("> keep building.").foregroundStyle(.secondary)
                }
                Spacer()
                MascotView(animal: .capybara, mood: .normal, accent: Palette.color("Terminal Green"), animate: false).frame(width: 140, height: 110)
            }.padding(.horizontal, 36)
            Spacer()
            Text("→").font(.system(size: 42, weight: .ultraLight)).foregroundStyle(.cyan.opacity(0.7))
            Spacer()
            Text("Drag DevPet to Applications").font(.system(size: 16, weight: .medium, design: .monospaced))
            Text("Native macOS · Your quiet coding companion").font(.system(size: 11)).foregroundStyle(.secondary)
        }.padding(.vertical, 25).frame(width: 640, height: 420).foregroundStyle(.white).background(LinearGradient(colors: [Color(red: 0.09, green: 0.12, blue: 0.23), Color(red: 0.035, green: 0.04, blue: 0.075)], startPoint: .topLeading, endPoint: .bottomTrailing))
    }
}
struct MascotGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DEVPET / PIXEL TERMINAL COMPANIONS").font(.system(size: 13, weight: .bold, design: .monospaced)).tracking(3).foregroundStyle(.cyan)
            Text("> keep building.").font(.system(size: 34, weight: .bold, design: .monospaced))
            Text("12 pixel companions · 6 moods · Native macOS").foregroundStyle(.secondary)
            ForEach(0..<3) { row in
                HStack(spacing: 10) {
                    ForEach(Array(Animal.allCases[row * 4 ..< row * 4 + 4])) { animal in
                        VStack(spacing: 5) {
                            Text(animal.rawValue.capitalized).font(.system(size: 17, weight: .semibold, design: .monospaced))
                            HStack(spacing: 0) { ForEach([Mood.happy, .tired, .sleeping], id: \.rawValue) { mood in
                                VStack { MascotView(animal: animal, mood: mood, accent: Palette.color("Terminal Green"), animate: false).frame(width: 98, height: 125); Text(mood.rawValue.capitalized).font(.system(size: 10)).foregroundStyle(.secondary) }
                            } }
                        }.padding(13).background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 4)).overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.08)))
                    }
                }.frame(maxHeight: .infinity)
            }
        }.padding(30).frame(width: 1380, height: 920).background(Color(red: 0.035, green: 0.045, blue: 0.075)).foregroundStyle(.white)
    }
}
if CommandLine.arguments.contains("--claude-statusline") {
    let custom = CommandLine.arguments.drop { $0 != "--bridge-output" }.dropFirst().first
    exit(runClaudeBridge(outputURL: custom.map { URL(fileURLWithPath: $0) } ?? ClaudeProvider.bridgeURL))
}
if CommandLine.arguments.contains("--check-codex") {
    let path = CommandLine.arguments.drop { $0 != "--check-codex" }.dropFirst().first ?? ""
    Task {
        let result = await CodexProvider(executable: path).fetch()
        let summary: [String: Any] = ["connection": result.connection.rawValue, "diagnostic": result.diagnostic, "windows": result.windows.map { ["kind": $0.kind.rawValue, "remaining": $0.remaining] as [String: Any] }]
        print(String(decoding: try! JSONSerialization.data(withJSONObject: summary, options: [.sortedKeys]), as: UTF8.self))
        exit(result.connection == .connected ? 0 : 1)
    }
    dispatchMain()
}
MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.run()
}

private extension NSView {
    var subviewsRecursive: [NSView] { subviews.flatMap { [$0] + $0.subviewsRecursive } }
}
