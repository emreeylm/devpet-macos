import AppKit
import Combine
#if canImport(DevPetCore)
import DevPetCore
#endif

@MainActor final class MenuBarController: NSObject {
    private let item: NSStatusItem
    private let model: AppModel
    private var subscription: AnyCancellable?
    init(model: AppModel) {
        self.model = model; item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        item.button?.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "DevPet")
        item.button?.toolTip = "DevPet"
        subscription = model.preferencesChanged.sink { [weak self] in self?.rebuild() }
        rebuild()
    }
    func add(_ menu: NSMenu, _ title: String, _ action: Selector, checked: Bool = false, key: String = "") {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: key); entry.target = self; entry.state = checked ? .on : .off; menu.addItem(entry)
    }
    func rebuild() {
        let menu = NSMenu(), p = model.preferences
        let heading = NSMenuItem(title: p.demo ? "DevPet · DEMO" : "DevPet", action: nil, keyEquivalent: ""); menu.addItem(heading); menu.addItem(.separator())
        add(menu, model.text("Show Pet", "Maskotu göster"), #selector(togglePet), checked: p.petVisible && p.mode != "minimal")
        menu.items.last?.isEnabled = p.mode != "minimal"
        add(menu, model.text("Show Stats", "İstatistikleri göster"), #selector(toggleStats), checked: p.statsVisible && p.mode != "pet")
        let modeMenu = NSMenu()
        for (index, title) in ["Minimal", model.text("Pet only", "Yalnız maskot"), model.text("Expanded", "Geniş")].enumerated() {
            let entry = NSMenuItem(title: title, action: #selector(selectMode(_:)), keyEquivalent: "")
            entry.target = self; entry.tag = index; entry.state = p.mode == ["minimal", "pet", "expanded"][index] ? .on : .off; modeMenu.addItem(entry)
        }
        let modes = NSMenuItem(title: model.text("Display mode", "Görünüm modu"), action: nil, keyEquivalent: ""); modes.submenu = modeMenu; menu.addItem(modes)
        add(menu, model.text("Refresh Usage", "Kota verilerini yenile"), #selector(refresh), key: "r")
        let animalMenu = NSMenu()
        for (index, animal) in Animal.allCases.enumerated() {
            let entry = NSMenuItem(title: model.animalName(animal), action: #selector(selectAnimal(_:)), keyEquivalent: ""); entry.tag = index; entry.target = self; entry.state = p.animal == animal ? .on : .off; animalMenu.addItem(entry)
        }
        let animals = NSMenuItem(title: model.text("Choose Animal", "Hayvan seç"), action: nil, keyEquivalent: ""); animals.submenu = animalMenu; menu.addItem(animals)
        menu.addItem(.separator())
        add(menu, model.text("Click Through Pet", "Maskotta tıklama geçirgenliği"), #selector(toggleClickThrough), checked: p.clickThrough)
        menu.items.last?.isEnabled = p.mode != "minimal"
        add(menu, model.text("Recover Windows", "Pencereleri geri getir"), #selector(recover))
        add(menu, model.text("Settings…", "Ayarlar…"), #selector(settings), key: ",")
        add(menu, model.text("Launch at Login", "Oturum açıldığında başlat"), #selector(login), checked: model.loginEnabled)
        menu.addItem(.separator())
        add(menu, model.text("Quit DevPet", "DevPet’ten çık"), #selector(quit), key: "q")
        item.menu = menu
    }
    @objc func selectMode(_ sender: NSMenuItem) {
        model.preferences.mode = ["minimal", "pet", "expanded"][sender.tag]
        if model.preferences.mode == "pet" { model.preferences.petVisible = true } else { model.preferences.statsVisible = true }
    }
    @objc func togglePet() { model.preferences.petVisible.toggle() }
    @objc func toggleStats() { if model.preferences.mode == "pet" { model.preferences.mode = "expanded" }; model.preferences.statsVisible.toggle() }
    @objc func refresh() { Task { await model.refresh() } }
    @objc func selectAnimal(_ sender: NSMenuItem) { model.preferences.animal = Animal.allCases[sender.tag] }
    @objc func toggleClickThrough() { model.preferences.clickThrough.toggle() }
    @objc func recover() { model.onRestore?() }
    @objc func settings() { model.onSettings?() }
    @objc func login() { model.setLogin(!model.loginEnabled); rebuild() }
    @objc func quit() { NSApp.terminate(nil) }
}
