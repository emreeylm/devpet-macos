import SwiftUI
#if canImport(DevPetCore)
import DevPetCore
#endif

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var section = "appearance"
    @State private var customColor = Color.blue
    let sections = [("appearance", "paintpalette", "Appearance", "Görünüm"), ("widget", "macwindow", "Widget", "Pencere"), ("providers", "network", "Providers", "Sağlayıcılar"), ("behavior", "switch.2", "Behavior", "Davranış"), ("about", "info.circle", "About", "Hakkında")]
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack { Image(systemName: "pawprint.fill").foregroundStyle(model.accent); Text("DevPet").font(.system(size: 22, weight: .bold, design: .monospaced)) }.padding(.bottom, 2)
                Text(model.text("Your terminal companion.", "Terminaldeki küçük dostun.")).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).padding(.bottom, 25)
                ForEach(sections, id: \.0) { item in
                    Button { section = item.0 } label: {
                        Label(model.text(item.2, item.3), systemImage: item.1).font(.system(size: 13, weight: .medium, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading).padding(11)
                            .background(section == item.0 ? model.accent.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(section == item.0 ? model.accent : .primary)
                    }.buttonStyle(.plain)
                }
                Spacer()
                Picker("Language / Dil", selection: $model.preferences.language) { Text("English").tag("en"); Text("Türkçe").tag("tr") }.labelsHidden()
                Text("v1.7.2 · macOS").font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary).padding(.top, 8)
            }.padding(22).frame(width: 205).background(model.preferences.dark ? Color(hex: 0x081220) : Color(hex: 0xEEF1E9))
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("> " + model.text(sections.first { $0.0 == section }!.2, sections.first { $0.0 == section }!.3)).font(.system(size: 28, weight: .bold, design: .monospaced))
                    switch section {
                    case "appearance": appearance
                    case "widget": widget
                    case "providers": providers
                    case "behavior": behavior
                    default: about
                    }
                    if !model.systemMessage.isEmpty { Text(model.systemMessage).font(.caption).foregroundStyle(.orange) }
                }.padding(28).frame(maxWidth: .infinity, alignment: .leading)
            }.background(model.preferences.dark ? Color(hex: 0x0B1424) : Color.white)
        }
        .frame(minWidth: 790, minHeight: 660)
        .environment(\.colorScheme, model.preferences.dark ? .dark : .light)
        .task { await model.refreshNotificationAuthorization() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in Task { await model.refreshNotificationAuthorization() } }
        .onChange(of: model.preferences.demo) { _, _ in model.connectionSettingsChanged() }
        .onChange(of: model.preferences.claudeEnabled) { _, _ in model.connectionSettingsChanged() }
        .onChange(of: model.preferences.codexEnabled) { _, _ in model.connectionSettingsChanged() }
        .onChange(of: model.preferences.refreshMinutes) { _, _ in model.restartPolling() }
        .onChange(of: model.preferences.notifications) { _, _ in model.enableNotifications() }
    }
    func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) { Text(title).font(.system(size: 13, weight: .semibold, design: .monospaced)); content() }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: 0x7899DC).opacity(0.22)))
    }
    var appearance: some View {
        VStack(spacing: 18) {
            HStack {
                MascotView(animal: model.preferences.animal, mood: model.mood, accent: model.accent, animate: model.preferences.animations).frame(width: 126, height: 138)
                VStack(alignment: .leading, spacing: 7) {
                    Text(model.animalName(model.preferences.animal)).font(.system(size: 21, weight: .bold, design: .monospaced))
                    Text(model.moodName(model.mood)).foregroundStyle(model.accent)
                    Text(model.text("Your quiet companion while you build.", "Üretirken yanında duran sessiz dostun.")).font(.caption).foregroundStyle(.secondary)
                }; Spacer()
            }
            card(model.text("Choose your companion", "Dostunu seç")) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                    ForEach(Animal.allCases) { animal in
                        Button { model.preferences.animal = animal } label: {
                            VStack(spacing: 0) { MascotView(animal: animal, mood: .normal, accent: model.accent, animate: false).frame(height: 65); Text(model.animalName(animal)).font(.system(size: 10, design: .monospaced)) }.padding(4).frame(maxWidth: .infinity).background(model.preferences.animal == animal ? model.accent.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 4)).overlay(RoundedRectangle(cornerRadius: 4).stroke(model.preferences.animal == animal ? model.accent : Color.clear, lineWidth: 1.5))
                        }.buttonStyle(.plain).accessibilityLabel(model.animalName(animal))
                    }
                }
            }
            card(model.text("Color & appearance", "Renk ve görünüm")) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(Palette.names.filter { $0 != "Custom" }, id: \.self) { name in
                        Button { model.preferences.palette = name } label: {
                            VStack(spacing: 5) {
                                HStack(spacing: 4) { Circle().fill(Palette.color(name)).frame(width: 7, height: 7); Text(name.replacingOccurrences(of: "Sunset Orange", with: "Sunset").replacingOccurrences(of: "Monochrome", with: "Mono")).font(.system(size: 8, weight: .semibold, design: .monospaced)).lineLimit(1).minimumScaleFactor(0.8) }
                                MascotView(animal: model.preferences.animal, mood: .happy, accent: Palette.color(name), animate: false).frame(height: 42)
                            }.padding(7).frame(maxWidth: .infinity)
                                .background(Palette.color(name).opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(model.preferences.palette == name ? Palette.color(name) : Color(hex: 0x7899DC).opacity(0.18), lineWidth: model.preferences.palette == name ? 1.5 : 1))
                        }.buttonStyle(.plain).help(name).accessibilityLabel(name)
                    }
                }
                ColorPicker(model.text("Custom accent", "Özel vurgu rengi"), selection: Binding(get: { Palette.color("Custom", hex: model.preferences.customHex) }, set: { color in
                    let rgb = NSColor(color).usingColorSpace(.deviceRGB) ?? .systemBlue
                    model.preferences.customHex = String(format: "%02X%02X%02X", Int(rgb.redComponent * 255), Int(rgb.greenComponent * 255), Int(rgb.blueComponent * 255)); model.preferences.palette = "Custom"
                }), supportsOpacity: false)
                slider(model.text("Size", "Boyut"), value: $model.preferences.size, range: 0.5...2.5, suffix: "%", multiplier: 100)
                slider(model.text("Opacity", "Opaklık"), value: $model.preferences.opacity, range: 0.2...1, suffix: "%", multiplier: 100)
                Toggle(model.text("Dark appearance", "Koyu görünüm"), isOn: $model.preferences.dark)
                Toggle(model.text("Animate companion", "Dostu canlandır"), isOn: $model.preferences.animations)
            }
            Button(model.text("Restore default appearance", "Varsayılan görünümü geri yükle")) {
                model.preferences.animal = .capybara; model.preferences.palette = "Terminal Green"; model.preferences.size = 1; model.preferences.opacity = 1; model.preferences.animations = true; model.preferences.dark = true
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    var widget: some View {
        VStack(spacing: 18) {
            card(model.text("Floating windows", "Yüzen pencereler")) {
                Picker(model.text("Display mode", "Görünüm modu"), selection: $model.preferences.mode) { Text("Minimal").tag("minimal"); Text(model.text("Pet only", "Yalnız maskot")).tag("pet"); Text(model.text("Expanded", "Geniş")).tag("expanded") }.pickerStyle(.segmented).onChange(of: model.preferences.mode) { _, mode in if mode == "minimal" { model.preferences.statsVisible = true } }
                Toggle(model.text("Attach companion to statistics", "Maskotu istatistik paneline bağla"), isOn: $model.preferences.attachPet).disabled(model.preferences.mode == "minimal")
                Toggle(model.text("Show pet", "Maskotu göster"), isOn: $model.preferences.petVisible).disabled(model.preferences.mode == "minimal")
                Toggle(model.text("Show statistics", "İstatistikleri göster"), isOn: $model.preferences.statsVisible).disabled(model.preferences.mode == "pet")
                Toggle(model.text("Always on top", "Her zaman üstte"), isOn: $model.preferences.alwaysOnTop)
                Toggle(model.text("Transparent window background", "Şeffaf pencere arka planı"), isOn: $model.preferences.transparent)
                Toggle(model.text("Click through pet", "Tıklamaları maskottan geçir"), isOn: $model.preferences.clickThrough).disabled(model.preferences.mode == "minimal")
                Text(model.preferences.mode == "minimal" ? model.text("Drag anywhere to move. Right-click for refresh, settings and display modes.", "Taşımak için pencerenin herhangi bir yerinden tutun. Yenileme, ayarlar ve görünüm seçimi için sağ tıklayın.") : model.text("Use the menu bar to disable click-through or recover hidden windows. Drag the header to move the widget. Disable attachment for independent pet movement.", "Tıklama geçirgenliğini kapatmak veya pencereleri geri getirmek için menü çubuğunu kullanın. Başlığı sürükleyerek pencereyi taşıyın. Ayrı maskot kullanımı için panel bağlantısını kapatın.")).font(.caption).foregroundStyle(.secondary)
                Text(model.text("Positions are remembered separately for Minimal, Pet Only and Expanded, including the display. If a monitor is disconnected, the widget returns to a visible screen.", "Minimal, Yalnız maskot ve Geniş konumları ekran bilgisiyle ayrı saklanır. Monitör çıkarılırsa pencere görünür ekrana döner.")).font(.caption).foregroundStyle(.secondary)
                Button(model.text("Restore window positions", "Pencere konumlarını geri yükle")) { model.onRestore?() }
            }
        }
    }
    var providers: some View {
        VStack(spacing: 18) {
            card(model.text("Data source", "Veri kaynağı")) {
                Toggle(model.text("Demo mode · Simulated usage", "Demo modu · Örnek kota verileri"), isOn: $model.preferences.demo)
                if model.preferences.demo {
                    Picker(model.text("Preview mood", "İfade önizlemesi"), selection: Binding(get: { model.demoMood?.rawValue ?? "auto" }, set: { model.demoMood = Mood(rawValue: $0) })) { Text(model.text("Automatic", "Otomatik")).tag("auto"); ForEach(Mood.allCases, id: \.rawValue) { Text(model.moodName($0)).tag($0.rawValue) } }
                }
                Picker(model.text("Show in panel", "Panelde göster"), selection: Binding(get: { model.preferences.providerSelection }, set: { choice in
                    var preferences = model.preferences
                    preferences.selectProviders(choice)
                    model.preferences = preferences
                })) {
                    Text(model.text("Both", "İkisi")).tag("both")
                    Text(model.text("Claude only", "Yalnız Claude")).tag("claude")
                    Text(model.text("Codex only", "Yalnız Codex")).tag("codex")
                    Text(model.text("Off", "Kapalı")).tag("none")
                }.pickerStyle(.segmented)
                Text(model.text("Use the arrow on each card to expand its quota details.", "Kota ayrıntılarını açmak için kartların sağındaki oka basın.")).font(.caption).foregroundStyle(.secondary)
                Toggle(model.text("5-hour window", "5 saatlik pencere"), isOn: $model.preferences.fiveHourEnabled)
                Toggle(model.text("Weekly window", "Haftalık pencere"), isOn: $model.preferences.weeklyEnabled)
            }
            ForEach(model.snapshots, id: \.service) { snapshot in
                card(snapshot.service.title) {
                    Label(model.text(snapshot.connection.rawValue.capitalized, connectionTR(snapshot.connection)), systemImage: snapshot.connection == .connected ? "checkmark.circle" : "exclamationmark.circle").foregroundStyle(snapshot.connection == .connected ? .mint : .orange)
                    Text(snapshot.diagnostic).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    if let date = snapshot.refreshedAt { Text(model.text("Last observation: ", "Son ölçüm: ") + date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary) }
                }
            }
            card(model.text("Connect Claude Code", "Claude Code bağlantısı")) {
                Text(model.text("Add this statusline command manually to Claude Code settings. DevPet never changes your configuration. If you already use a statusline, see the guide to preserve it.", "Bu statusline komutunu Claude Code ayarlarına elle ekleyin. DevPet yapılandırmanızı değiştirmez. Mevcut statusline komutunuzu korumak için kılavuza bakın.")).font(.caption).foregroundStyle(.secondary)
                Text(bridgeConfiguration).font(.system(size: 10, design: .monospaced)).textSelection(.enabled)
                Button(model.text("Copy configuration", "Yapılandırmayı kopyala")) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(bridgeConfiguration, forType: .string) }
                Button(model.text("Open connection guide", "Bağlantı kılavuzunu aç")) { if let url = Bundle.main.url(forResource: "INTEGRATIONS", withExtension: "md") { NSWorkspace.shared.open(url) } }
            }
            card(model.text("Codex executable", "Codex çalıştırılabilir dosyası")) {
                TextField(model.text("Auto-detect (Homebrew / ~/.local/bin)", "Otomatik bul (Homebrew / ~/.local/bin)"), text: $model.preferences.codexPath).textFieldStyle(.roundedBorder)
                Text(model.text("Uses your existing Codex ChatGPT login. No credentials are copied. API-key accounts may not supply subscription quotas.", "Mevcut Codex ChatGPT oturumunuzu kullanır. Kimlik bilgileri kopyalanmaz. API anahtarı hesaplarında abonelik kotası bulunmayabilir.")).font(.caption).foregroundStyle(.secondary)
            }
            Button(model.text("Refresh usage now", "Kota verilerini şimdi yenile")) { Task { await model.refresh() } }.disabled(model.refreshing)
        }
    }
    var behavior: some View {
        VStack(spacing: 18) {
            card(model.text("Background behavior", "Arka plan davranışı")) {
                Toggle(model.text("Launch at login", "Oturum açıldığında başlat"), isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) }))
                slider(model.text("Refresh interval", "Yenileme aralığı"), value: $model.preferences.refreshMinutes, range: 1...30, suffix: model.text(" min", " dk"))
                Text(model.text("Polling pauses during sleep. Failed providers retry with exponential backoff. Claude refreshes only when its active session supplies new data.", "Uyku sırasında yenileme durur. Hatalı sağlayıcılar artan aralıklarla yeniden denenir. Claude yalnızca etkin oturumu yeni veri sağladığında güncellenir.")).font(.caption).foregroundStyle(.secondary)
            }
            card(model.text("Notifications", "Bildirimler")) {
                Toggle(model.text("Enable notifications", "Bildirimleri etkinleştir"), isOn: $model.preferences.notifications)
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(model.text("Low quota warnings", "Düşük kota uyarıları"), isOn: $model.preferences.lowWarnings)
                    slider(model.text("Early warning", "İlk uyarı"), value: $model.preferences.earlyWarningThreshold, range: max(1, model.preferences.threshold)...50, suffix: "%")
                    slider(model.text("Critical warning", "Kritik uyarı"), value: $model.preferences.threshold, range: 1...min(40, model.preferences.earlyWarningThreshold), suffix: "%")
                    Toggle(model.text("Quota exhausted", "Kullanım hakkı bittiğinde"), isOn: $model.preferences.exhaustedNotifications)
                    Toggle(model.text("Confirmed quota renewal", "Kota yenilendiğinde"), isOn: $model.preferences.resetNotifications)
                    Text(model.text("Each warning is sent once per provider and quota cycle, even after restarting DevPet. Only selected providers and quota windows are included. Demo and stale data never trigger alerts.", "Her uyarı, DevPet yeniden açılsa da sağlayıcı ve kota dönemi başına bir kez gönderilir. Seçili sağlayıcılar ve kota pencereleri izlenir. Demo veya eski veriler bildirim üretmez.")).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Text(model.canSendNotifications ? model.text("macOS permission: Allowed", "macOS izni: Açık") : model.text("macOS permission: Not allowed yet", "macOS izni: Henüz açık değil")).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button(model.text("Send test", "Test gönder")) { Task { await model.sendTestNotification() } }
                    }
                }.disabled(!model.preferences.notifications)

            }
        }
    }
    var about: some View {
        VStack(spacing: 18) {
            card("DevPet 1.7.2") {
                Text(model.text("A native desktop companion for developers.", "Geliştiriciler için yerel masaüstü dostu."))
                Text(model.text("Original pixel characters · SwiftUI + AppKit · MIT License", "Özgün piksel karakterler · SwiftUI + AppKit · MIT Lisansı")).font(.caption).foregroundStyle(.secondary)
            }
            card(model.text("Privacy", "Gizlilik")) {
                Text(model.text("Preferences and quota snapshots stay on your Mac. No analytics, code, prompts or conversations are collected. Codex talks to its own service through the installed CLI; Claude supplies quota fields through a local statusline bridge.", "Tercihler ve kota verileri Mac’inizde kalır. Analitik, kod, istem veya konuşma toplanmaz. Codex kurulu CLI aracılığıyla kendi servisine bağlanır; Claude yerel statusline köprüsüyle kota alanlarını iletir.")).font(.callout)
            }
            card(model.text("Repository & updates", "Depo ve güncellemeler")) {
                TextField(model.text("GitHub repository URL (after publishing)", "GitHub depo adresi (yayınlandıktan sonra)"), text: $model.preferences.repositoryURL).textFieldStyle(.roundedBorder)
                Button(model.text("Open GitHub Releases", "GitHub Releases’ı aç")) {
                    if let url = URL(string: model.preferences.repositoryURL), url.scheme == "https", url.host == "github.com" { NSWorkspace.shared.open(url.appendingPathComponent("releases")) }
                }.disabled(model.preferences.repositoryURL.isEmpty)
                Text(model.text("Updates are installed manually from GitHub Releases. This build has not been published or notarized.", "Güncellemeler GitHub Releases üzerinden elle kurulur. Bu derleme henüz yayınlanmadı veya noter onayı almadı.")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    func slider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String, multiplier: Double = 1) -> some View {
        HStack { Text(label).frame(width: 140, alignment: .leading); Slider(value: value, in: range).accessibilityLabel(label); Text("\(Int((value.wrappedValue * multiplier).rounded()))\(suffix)").monospacedDigit().frame(width: 50, alignment: .trailing).foregroundStyle(.secondary) }.font(.system(size: 12, design: .monospaced))
    }
    var bridgeConfiguration: String {
        let executable = Bundle.main.executableURL?.path ?? "/Applications/DevPet.app/Contents/MacOS/DevPet"
        let command = "'" + executable.replacingOccurrences(of: "'", with: "'\\''") + "' --claude-statusline"
        let data = try! JSONSerialization.data(withJSONObject: ["statusLine": ["type": "command", "command": command]], options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        return String(decoding: data, as: UTF8.self)
    }
    func connectionTR(_ connection: Connection) -> String {
        switch connection { case .connected: return "Bağlı"; case .unavailable: return "Veri yok"; case .failed: return "Bağlantı hatası"; case .disabled: return "Devre dışı" }
    }
}
