import SwiftUI
#if canImport(DevPetCore)
import DevPetCore
#endif

struct Glass: ViewModifier {
    var dark = true
    var accent = Color(hex: 0x779AFF)
    func body(content: Content) -> some View {
        content
            .background(LinearGradient(colors: dark ? [Color(hex: 0x19243A).opacity(0.98), Color(hex: 0x080F1D).opacity(0.97)] : [Color(hex: 0xF5F7FF), Color(hex: 0xE5EDFA)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LinearGradient(colors: [accent.opacity(0.7), Color(hex: 0xAC82E8).opacity(0.25), accent.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            .shadow(color: accent.opacity(dark ? 0.14 : 0.06), radius: 10)
            .overlay(alignment: .topLeading) {
                HStack(spacing: 5) {
                    ForEach(0..<3) { index in Circle().fill([Color(hex: 0xFB6572), Color(hex: 0xF9C65E), Color(hex: 0x46DA92)][index]).frame(width: 6, height: 6) }
                }.padding(10).allowsHitTesting(false)
            }
    }
}
struct UsageDashboard: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                HStack(spacing: 10) {
                    if model.preferences.attachPet && model.preferences.petVisible {
                        MascotView(animal: model.preferences.animal, mood: model.mood, accent: model.accent, animate: model.preferences.animations && !model.suspended)
                            .frame(width: min(144, 144 * model.preferences.size), height: min(112, 112 * model.preferences.size))
                    } else {
                        Image(systemName: "line.3.horizontal").foregroundStyle(model.accent)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("DEVPET").font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundStyle(model.accent)
                        Text("> " + model.moodName(model.mood)).font(.system(size: 9, design: .monospaced)).foregroundStyle(model.accent).lineLimit(2).padding(.horizontal, 7).padding(.vertical, 5).background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 5)).overlay(RoundedRectangle(cornerRadius: 5).stroke(model.accent.opacity(0.45)))
                    }
                    if model.preferences.demo { Text("DEMO").font(.system(size: 9, weight: .bold, design: .monospaced)).padding(.horizontal, 6).padding(.vertical, 3).background(Color.orange.opacity(0.17), in: Capsule()).foregroundStyle(.orange) }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 72)
                .overlay(WindowDragHandle(identifier: "dashboardHeaderDrag").frame(maxWidth: .infinity, maxHeight: .infinity))
                Button { Task { await model.refresh() } } label: { Image(systemName: "arrow.clockwise").rotationEffect(.degrees(model.refreshing ? 180 : 0)).animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: model.refreshing) }.disabled(model.refreshing).help(model.text("Refresh usage", "Kota verisini yenile"))
                Button { model.onSettings?() } label: { Image(systemName: "slider.horizontal.3") }.help(model.text("Settings", "Ayarlar"))
                Button { model.preferences.statsVisible = false } label: { Image(systemName: "xmark") }.help(model.text("Hide stats", "İstatistikleri gizle"))
            }.foregroundStyle(.secondary).buttonStyle(.plain)
            if model.preferences.services.isEmpty {
                Text(model.text("Enable a provider in Settings.", "Ayarlardan bir sağlayıcı etkinleştirin.")).foregroundStyle(.secondary).padding()
            }
            ForEach(model.snapshots.filter { model.preferences.services.contains($0.service) }, id: \.service) { snapshot in
                providerCard(snapshot)
            }
            Group {
                HStack {
                    Text("> " + model.moodName(model.mood)).foregroundStyle(model.accent)
                    Spacer()
                    Text(model.text("remaining quota", "kalan kota")).foregroundStyle(.secondary)
                    Image(systemName: "arrow.up.left.and.arrow.down.right").foregroundStyle(.tertiary)
                }.font(.system(size: 11, design: .monospaced)).padding(.horizontal, 3)
            }
        }
        .padding(20)
        .frame(minWidth: 390, maxWidth: .infinity, minHeight: model.preferences.dashboardHeight, maxHeight: .infinity, alignment: .top)
        .modifier(Glass(dark: model.preferences.dark, accent: model.accent))
        .overlay(alignment: .top) {
            WindowDragHandle(identifier: "dashboardTitleBarDrag").frame(height: 24)
        }
        .environment(\.colorScheme, model.preferences.dark ? .dark : .light)
    }
    func providerCard(_ snapshot: UsageSnapshot) -> some View {
        let expanded = model.preferences.isExpanded(snapshot.service)
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                    model.preferences.setExpanded(!expanded, for: snapshot.service)
                }
            } label: {
                HStack(spacing: 9) {
                        serviceMark(snapshot.service)
                        Text(snapshot.service.title).font(.system(size: 14, weight: .semibold, design: .monospaced))
                        Spacer()
                        Circle().fill(snapshot.isFresh(at: model.now, maxAge: model.preferences.staleAge) ? Color.mint : Color.orange).frame(width: 6, height: 6)
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: snapshot.isFresh(at: model.now, maxAge: model.preferences.staleAge))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .rotationEffect(.degrees(expanded ? 90 : 0)).animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: expanded)
                        .foregroundStyle(.secondary).frame(width: 18, height: 24)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
             .accessibilityLabel(snapshot.service.title + " · " + model.text(expanded ? "Collapse details" : "Expand details", expanded ? "Ayrıntıları kapat" : "Ayrıntıları aç"))
             .accessibilityValue(model.text(expanded ? "Expanded" : "Collapsed", expanded ? "Açık" : "Kapalı"))
            if expanded {
                VStack(spacing: 12) {
                    ForEach(WindowKind.allCases.filter { model.preferences.windows.contains($0) }) { kind in
                        let quota = snapshot.window(kind, at: model.now, maxAge: model.preferences.staleAge)
                        VStack(spacing: 5) {
                            HStack(spacing: 12) {
                                Text(kind == .fiveHour ? "5h" : model.text("Weekly", "Haftalık"))
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced)).frame(width: 64, alignment: .leading)
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.primary.opacity(0.08))
                                        if let quota {
                                            Capsule().fill(LinearGradient(colors: [barColor(snapshot.service, kind: kind, remaining: quota.remaining), barColor(snapshot.service, kind: kind, remaining: quota.remaining).opacity(0.75)], startPoint: .leading, endPoint: .trailing))
                                                .frame(width: max(0, geometry.size.width * quota.remaining / 100))
                                                .animation(reduceMotion ? nil : .easeOut(duration: 0.5), value: quota.remaining)
                                        }
                                    }.overlay(Capsule().stroke(Color(hex: 0x7D98CF).opacity(0.25)))
                                }.frame(height: 12)
                                Text(quota.map { "\(Int($0.remaining.rounded()))%" } ?? "—")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(quota.map { quotaColor($0.remaining) } ?? .secondary)
                                    .frame(width: 44, alignment: .trailing)
                            }
                            HStack {
                                Spacer()
                                Text(quota.map { "reset ~ " + UsageLogic.countdown($0.resetsAt, now: model.now) } ?? model.text("unavailable", "veri yok"))
                                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                            }
                        }.accessibilityElement(children: .combine)
                    }
                }.padding(.top, 3).transition(.opacity)
            if snapshot.connection != .connected || !snapshot.isFresh(at: model.now, maxAge: model.preferences.staleAge) {
                Text(snapshot.connection == .connected ? model.text("Stale data · Waiting for a new observation", "Veri eski · Yeni ölçüm bekleniyor") : model.text("Connection needed · Open Settings", "Bağlantı gerekli · Ayarları açın")).font(.system(size: 10, design: .monospaced)).foregroundStyle(.orange).transition(.opacity)
            }
            }
        }.padding(12).background(model.preferences.dark ? Color(hex: 0x080F1D).opacity(0.6) : Color.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: 0x7796D4).opacity(0.25))).help(snapshot.diagnostic)
    }
    func barColor(_ service: Service, kind: WindowKind, remaining: Double) -> Color {
        if remaining < 15 { return Color(hex: 0xFF7198) }
        if remaining <= 50 { return Color(hex: 0xF4C263) }
        return kind == .weekly ? Color(hex: 0xA482FF) : service == .claude ? Color(hex: 0x25E990) : Color(hex: 0x36ACFF)
    }
    func quotaColor(_ value: Double) -> Color { value < 15 ? Color(hex: 0xFF7198) : value <= 40 ? Color(hex: 0xF4C263) : model.accent }
    func serviceMark(_ service: Service) -> some View {
        Text(service == .claude ? "✳" : "◎").font(.system(size: 26, weight: .medium, design: .monospaced)).foregroundStyle(service == .claude ? Color.orange : Color(hex: 0x36CFE5)).accessibilityHidden(true)
    }
}
struct PetWidget: View {
    @ObservedObject var model: AppModel
    var interactive = true
    @Environment(\.displayScale) private var displayScale
    private var spriteUnit: Double { max(1 / displayScale, floor(model.preferences.petSpriteSide / 64 * displayScale) / displayScale) }
    private var quotaScale: Double { model.preferences.petQuotaScale * model.preferences.size }
    var body: some View {
        if model.preferences.mode == "minimal" {
            MinimalUsageWidget(model: model, interactive: interactive)
        } else {
            companion
        }
    }
    private var companion: some View {
        HStack(spacing: 0) {
            MascotView(animal: model.preferences.animal, mood: model.mood, accent: model.accent, animate: model.preferences.animations && model.preferences.petVisible && !model.suspended, viewportTop: model.preferences.petViewportTop, viewportHeight: model.preferences.petViewportHeight)
                .frame(width: model.preferences.petSpriteSide, height: model.preferences.petSpriteSide * model.preferences.petViewportHeight / 64)
                .padding(.trailing, model.preferences.services.isEmpty || model.preferences.windows.isEmpty ? 0 : -(model.preferences.petSpriteSide / 2 - 26 * spriteUnit) + 2 * model.preferences.size)
            if !model.preferences.services.isEmpty && !model.preferences.windows.isEmpty {
                VStack(spacing: 4 * quotaScale) {
                    ForEach(model.snapshots.filter { model.preferences.services.contains($0.service) }, id: \.service) { snapshot in
                        PetQuotaBadge(model: model, snapshot: snapshot, scale: quotaScale)
                    }
                }
                .frame(width: 140 * quotaScale, height: model.preferences.petQuotaStackHeight * quotaScale)
                .offset(y: spriteUnit * (48.5 - model.preferences.petViewportTop - model.preferences.petViewportHeight / 2) - model.preferences.petQuotaStackHeight * quotaScale / 2)
            }
        }
        .padding(.horizontal, 6 * model.preferences.size)
        .padding(.vertical, 3 * model.preferences.size)
        .frame(width: model.preferences.petWindowWidth, height: model.preferences.petWindowHeight)
        .background(model.preferences.transparent ? Color.clear : (model.preferences.dark ? Color(hex: 0x101620).opacity(0.9) : Color.white.opacity(0.9)), in: RoundedRectangle(cornerRadius: 4))
        .overlay {
            if interactive {
                WindowDragHandle(identifier: "petDragSurface", menuFactory: { petContextMenu(model) }, tooltip: model.preferences.fiveHourEnabled ? model.snapshots.filter { model.preferences.services.contains($0.service) }.map { petResetHelp($0, model: model) }.joined(separator: "\n") : nil).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .environment(\.colorScheme, model.preferences.dark ? .dark : .light)
        .help(model.moodName(model.mood))
    }
}
struct MinimalUsageWidget: View {
    @ObservedObject var model: AppModel
    var interactive = true
    var body: some View {
        VStack(spacing: 4 * model.preferences.minimalCardScale) {
            if model.preferences.services.isEmpty {
                Text(model.text("Choose a provider in Settings", "Ayarlardan sağlayıcı seçin"))
                    .font(.system(size: 9 * model.preferences.size, design: .monospaced))
                    .multilineTextAlignment(.center)
            } else {
                ForEach(model.snapshots.filter { model.preferences.services.contains($0.service) }, id: \.service) { snapshot in
                    PetQuotaBadge(model: model, snapshot: snapshot, scale: model.preferences.minimalCardScale)
                }
            }
        }
        .padding(4 * model.preferences.size)
        .frame(width: model.preferences.petWindowWidth, height: model.preferences.petWindowHeight)
        .background(model.preferences.transparent ? Color.clear : (model.preferences.dark ? Color(hex: 0x101620).opacity(0.9) : Color.white.opacity(0.9)), in: RoundedRectangle(cornerRadius: 4))
        .overlay {
            if interactive {
                WindowDragHandle(identifier: "minimalDragSurface", menuFactory: { petContextMenu(model) }, tooltip: model.snapshots.filter { model.preferences.services.contains($0.service) }.map { petResetHelp($0, model: model) }.joined(separator: "\n"))
            }
        }
        .environment(\.colorScheme, model.preferences.dark ? .dark : .light)
        .accessibilityIdentifier("minimalUsageWidget")
    }
}
struct PetQuotaBadge: View {
    @ObservedObject var model: AppModel
    var snapshot: UsageSnapshot
    var scale = 1.0
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: 2 * scale) {
            HStack(spacing: 3 * scale) {
                Rectangle().fill(snapshot.service == .claude ? Color(hex: 0xF3A36E) : model.accent).frame(width: 3 * scale, height: 3 * scale)
                Text(snapshot.service == .claude ? "CLAUDE" : "CODEX")
                    .font(.system(size: 9 * scale, weight: .bold, design: .monospaced)).tracking(0.2 * scale)
                if model.preferences.demo { Text("DEMO").font(.system(size: 6 * scale, weight: .bold, design: .monospaced)).foregroundStyle(.orange) }
                Spacer(minLength: scale)
                if model.preferences.fiveHourEnabled {
                    Text(petResetCountdown(snapshot, model: model))
                        .font(.system(size: 8.5 * scale, weight: .medium, design: .monospaced)).monospacedDigit()
                        .foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
                        .help(petResetHelp(snapshot, model: model))
                        .accessibilityLabel(petResetHelp(snapshot, model: model))
                }
            }.lineLimit(1)
            HStack(spacing: 6 * scale) {
                ForEach(WindowKind.allCases.filter { model.preferences.windows.contains($0) }) { kind in
                    let quota = snapshot.window(kind, at: model.now, maxAge: model.preferences.staleAge)
                    VStack(spacing: scale) {
                        Text(kind == .fiveHour ? "5h" : model.text("Week", "Hafta"))
                            .font(.system(size: 8.5 * scale, design: .monospaced)).foregroundStyle(.secondary)
                        Text(quota.map { "\(Int($0.remaining.rounded()))%" } ?? "—")
                            .font(.system(size: 18 * scale, weight: .bold, design: .monospaced)).monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: quota?.remaining)
                            .foregroundStyle(quota.map { $0.remaining < 15 ? Color(hex: 0xFF7198) : $0.remaining <= 40 ? Color(hex: 0xF4C263) : model.accent } ?? .secondary)
                    }.frame(maxWidth: .infinity)
                    .accessibilityLabel(snapshot.service.title + " " + (kind == .fiveHour ? "5h" : model.text("Weekly", "Haftalık")))
                    .accessibilityValue(quota.map { "\(Int($0.remaining.rounded()))% " + model.text("remaining", "kaldı") } ?? model.text("Unavailable", "Veri yok"))
                }
            }
        }
        .padding(.horizontal, 6 * scale).padding(.vertical, 2 * scale).frame(width: 140 * scale, height: 50 * scale)
        .background(model.preferences.dark ? Color(hex: 0x101620).opacity(0.96) : Color(hex: 0xE8ECE5).opacity(0.96), in: RoundedRectangle(cornerRadius: 6 * scale))
        .overlay(RoundedRectangle(cornerRadius: 6 * scale).stroke(LinearGradient(colors: [model.accent.opacity(0.65), Color(hex: 0xAC82E8).opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: max(1, (scale * displayScale).rounded()) / displayScale))
    }
}
@MainActor private func petResetCountdown(_ snapshot: UsageSnapshot, model: AppModel) -> String {
    guard let reset = snapshot.window(.fiveHour, at: model.now, maxAge: model.preferences.staleAge)?.resetsAt else { return "↻ —" }
    var countdown = UsageLogic.countdown(reset, now: model.now)
    if model.preferences.language == "tr" {
        countdown = countdown.replacingOccurrences(of: "h", with: "s").replacingOccurrences(of: "m", with: "dk")
    }
    return "↻ " + countdown.replacingOccurrences(of: " ", with: "")
}
@MainActor private func petResetHelp(_ snapshot: UsageSnapshot, model: AppModel) -> String {
    let prefix = (model.preferences.demo ? model.text("Demo · ", "Örnek · ") : "") + snapshot.service.title + " · "
    guard let reset = snapshot.window(.fiveHour, at: model.now, maxAge: model.preferences.staleAge)?.resetsAt else {
        return prefix + model.text("5-hour quota reset time unavailable", "5 saatlik kotanın yenilenme zamanı bilinmiyor")
    }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: model.preferences.language == "tr" ? "tr_TR" : "en_US")
    formatter.dateStyle = .short; formatter.timeStyle = .short
    return prefix + model.text("5-hour quota resets at ", "5 saatlik kota yenilenmesi: ") + formatter.string(from: reset)
}
@MainActor private func petContextMenu(_ model: AppModel) -> NSMenu {
    let menu = NSMenu()
    func add(_ title: String, to target: NSMenu, action: @escaping () -> Void) {
        let command = PetMenuCommand(action)
        let item = NSMenuItem(title: title, action: #selector(PetMenuCommand.invokeMenuAction(_:)), keyEquivalent: "")
        item.target = command; item.representedObject = command
        target.addItem(item)
    }
    add("Minimal", to: menu) { [weak model] in model?.preferences.mode = "minimal"; model?.preferences.statsVisible = true }
    add(model.text("Pet only", "Yalnız maskot"), to: menu) { [weak model] in model?.preferences.mode = "pet"; model?.preferences.petVisible = true }
    add(model.text("Usage details", "Kota ayrıntıları"), to: menu) { [weak model] in model?.preferences.mode = "expanded"; model?.preferences.statsVisible = true }
    if model.preferences.mode != "minimal" {
        let animals = NSMenu()
        for animal in Animal.allCases { add(model.animalName(animal), to: animals) { [weak model] in model?.preferences.animal = animal } }
        let animalItem = NSMenuItem(title: model.text("Choose animal", "Hayvan seç"), action: nil, keyEquivalent: "")
        animalItem.submenu = animals; menu.addItem(animalItem)
    }
    add(model.text("Refresh Usage", "Kota verilerini yenile"), to: menu) { [weak model] in Task { await model?.refresh() } }
    add(model.text("Settings…", "Ayarlar…"), to: menu) { [weak model] in model?.onSettings?() }
    if model.preferences.mode == "minimal" {
        add(model.text("Hide statistics", "İstatistikleri gizle"), to: menu) { [weak model] in model?.preferences.statsVisible = false }
    } else {
        add(model.text("Hide pet", "Maskotu gizle"), to: menu) { [weak model] in model?.preferences.petVisible = false }
    }
    menu.addItem(.separator())
    add(model.text("Quit DevPet", "DevPet’ten çık"), to: menu) { NSApp.terminate(nil) }
    return menu
}
@MainActor private final class PetMenuCommand: NSObject {
    let action: () -> Void
    init(_ action: @escaping () -> Void) { self.action = action }
    @objc func invokeMenuAction(_ sender: NSMenuItem) { action() }
}
