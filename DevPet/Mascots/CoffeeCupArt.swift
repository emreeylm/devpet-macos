import SwiftUI
#if canImport(DevPetCore)
import DevPetCore
#endif

/// Fixed pixel mugs matching the right-facing reference sheet, independent of all animation.
enum CoffeeCupArt {
    struct Style { let name: String; let pixels: [[Character]]; let palette: [Character: UInt32] }
    private struct Grid {
        var cells = Array(repeating: Array(repeating: Character("."), count: 20), count: 22)
        mutating func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: Character) {
            for row in max(0, y)..<min(22, y + h) { for col in max(0, x)..<min(20, x + w) { cells[row][col] = color } }
        }
    }
    static let styles: [Animal: Style] = Dictionary(uniqueKeysWithValues: Animal.allCases.map { animal in
        let name: String, body: UInt32, shadow: UInt32, highlight: UInt32, mark: UInt32, pattern: [String]
        switch animal {
        case .cat:
            name = "Neon cat mug"; body = 0x25223C; shadow = 0x17172C; highlight = 0x66517E; mark = 0xE978EC
            pattern = ["x.....x", "xx...xx", "xxxxxxx", "x.x.x.x", "x.....x", ".x.x.x.", "..xxx.."]
        case .dog:
            name = "Bone mug"; body = 0xF8E4BA; shadow = 0xCDA87A; highlight = 0xFFF4D9; mark = 0x86523A
            pattern = ["xx...xx", "xxx.xxx", ".xxxxx.", "xxx.xxx", "xx...xx"]
        case .fox:
            name = "Maple mug"; body = 0xFFE4E0; shadow = 0xDDA5A6; highlight = 0xFFF4EE; mark = 0xF36A3C
            pattern = ["...x...", ".x.xxx.", "xxxxxxx", ".xxxxx.", "..xxx..", "...x...", "...x..."]
        case .panda:
            name = "Bamboo mug"; body = 0xF1F1D9; shadow = 0xBEC7A7; highlight = 0xFFFFEB; mark = 0x4EA947
            pattern = ["x..x..x", ".x.x.x.", "..xxx..", "...x...", ".x.x.x.", "..xxx..", "...x..."]
        case .rabbit:
            name = "Bunny mug"; body = 0xFFE3ED; shadow = 0xD9A5BF; highlight = 0xFFF5F8; mark = 0xE875AB
            pattern = [".x...x.", ".x...x.", ".xx.xx.", "..xxx..", ".xxxxx.", ".x.x.x.", "..xxx.."]
        case .bear:
            name = "Bear mug"; body = 0xA46D43; shadow = 0x74472F; highlight = 0xD4A46D; mark = 0xFFE1A3
            pattern = ["xx...xx", "xxxxxxx", ".xxxxx.", ".x.x.x.", ".xxxxx.", "..x.x..", "..xxx.."]
        case .owl:
            name = "Moon mug"; body = 0x303775; shadow = 0x20264F; highlight = 0x636BB0; mark = 0xFFE46B
            pattern = ["..xxx..", ".xxx...", "xxx....", "xxx....", "xxx....", ".xxx..x", "..xxxx."]
        case .frog:
            name = "Frog mug"; body = 0x69C94E; shadow = 0x3B913C; highlight = 0xB8F384; mark = 0x234B38
            pattern = [".xx.xx.", "x..x..x", "x.x.x.x", ".xxxxx.", "x.....x", ".x...x.", "..xxx.."]
        case .penguin:
            name = "Fish mug"; body = 0xD9F0FA; shadow = 0x9BBBD7; highlight = 0xF6FFFF; mark = 0x3488D9
            pattern = ["..xxx..", ".xxxxx.", "xxx.xxx", ".xxxxx.", "..xxx.."]
        case .raccoon:
            name = "Nightshift bin mug"; body = 0xEEE7E8; shadow = 0xBCB0BF; highlight = 0xFFFAF7; mark = 0x39334F
            pattern = ["..xxx..", "xxxxxxx", ".xxxxx.", ".x.x.x.", ".x.x.x.", ".x.x.x.", "..xxx.."]
        case .capybara:
            name = "Orange mug"; body = 0xFFEBDA; shadow = 0xD4B09D; highlight = 0xFFFAF0; mark = 0xF6A03B
            pattern = ["..g.g..", "...g...", "..xxx..", ".xxxxx.", ".xxxxx.", ".xxxxx.", "..xxx.."]
        case .wolf:
            name = "Mountain mug"; body = 0x35375F; shadow = 0x20223D; highlight = 0x777CA5; mark = 0xEBF1FF
            pattern = ["...x...", "..xxx..", "..x.x..", ".xx.xx.", ".x...x.", "xx.x.xx", "xxxxxxx"]
        }
        var g = Grid()
        let y = animal == .owl ? 7 : 5
        g.rect(3, y, 12, 1, "o"); g.rect(2, y + 1, 14, 19 - y, "o"); g.rect(3, 20, 12, 1, "o")
        g.rect(3, y + 2, 12, 18 - y, "b"); g.rect(4, 19, 10, 1, "s")
        g.rect(4, y + 1, 10, 1, "h"); g.rect(4, y + 2, 10, 2, "c"); g.rect(4, y + 4, 10, 1, "h")
        g.rect(3, y + 5, 1, 18 - y - 5, "h"); g.rect(13, y + 5, 2, 18 - y - 5, "s")
        g.rect(16, y + 4, 2, 1, "o"); g.rect(18, y + 5, 2, 6, "o"); g.rect(16, y + 10, 2, 1, "o")
        g.rect(16, y + 5, 2, 1, "b"); g.rect(18, y + 6, 1, 4, "s"); g.rect(16, y + 9, 2, 1, "b")
        let top = 19 - pattern.count
        for (row, line) in pattern.enumerated() {
            for (col, char) in line.enumerated() where char != "." { g.rect(5 + col, top + row, 1, 1, char == "g" ? "g" : "m") }
        }
        let palette: [Character: UInt32] = ["o": 0x16182C, "b": body, "s": shadow, "h": highlight, "c": 0x745140, "m": mark, "g": 0x4EAD4F]
        return (animal, Style(name: name, pixels: g.cells, palette: palette))
    })
}
