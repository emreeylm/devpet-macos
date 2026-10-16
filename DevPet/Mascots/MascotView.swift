import SwiftUI
import ImageIO
#if canImport(DevPetCore)
import DevPetCore
#endif

/// Body, laptop and decorative cup stay fixed; only the original typing paw moves.
struct MascotView: View {
    var animal: Animal
    var mood: Mood
    var accent: Color
    var animate = true
    var previewTime: Double? = nil
    var viewportTop: Double = 0
    var viewportHeight: Double = 52
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale
    private let cupCell = 0.75
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 8, paused: !animate || reduceMotion)) { timeline in
            let time = previewTime ?? (animate && !reduceMotion ? timeline.date.timeIntervalSinceReferenceDate : 0)
            Canvas { context, size in
                let unit = max(1 / displayScale, floor(min(size.width / 76, size.height / viewportHeight) * displayScale) / displayScale)
                let physicalScale = unit * displayScale
                func snap(_ value: Double) -> Double { (value * physicalScale).rounded() / physicalScale }
                context.translateBy(x: ((size.width - 76 * unit) / 2 * displayScale).rounded() / displayScale,
                                    y: ((size.height - viewportHeight * unit) / 2 * displayScale).rounded() / displayScale - viewportTop * unit)
                context.scaleBy(x: unit, y: unit)
                guard let frame = CompanionAtlas.frame(animal: animal, mood: mood), let cup = CoffeeCupArt.styles[animal] else { return }
                let rect = CGRect(x: snap(54 - frame.size.width), y: snap(49 - frame.size.height), width: snap(frame.size.width), height: snap(frame.size.height))
                let action = CompanionRoutine.sample(time: time, animal: animal, mood: mood)
                drawCharacter(frame.image, in: rect, action: action, physicalScale: physicalScale, context: &context)
                drawCoffee(cup, in: rect, physicalScale: physicalScale, context: &context)
                func pixel(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ opacity: Double = 1) {
                    context.fill(Path(CGRect(x: snap(x), y: snap(y), width: max(1 / physicalScale, snap(w)), height: max(1 / physicalScale, snap(h)))), with: .color(accent.opacity(opacity)), style: FillStyle(antialiased: false))
                }
                if mood == .sleeping {
                    do {
                        for (x, y, width, phase) in [(49.0, max(17, viewportTop + 14), 3.0, 0.0), (48.0, max(9, viewportTop + 6), 4.0, 0.5)] {
                            let progress = time == 0 ? 0.5 : cycle(time / 4, phase: phase)
                            let opacity = time == 0 ? 0.85 : min(1, sin(progress * .pi) * 1.6) * 0.85
                            let top = y - (progress * 5).rounded(.down)
                            pixel(x, top, width, 1, opacity); pixel(x, top + width - 1, width, 1, opacity)
                            for i in 1..<Int(width) - 1 { pixel(x + width - 1 - Double(i), top + Double(i), 1, 1, opacity) }
                        }
                    }
                    return
                }
                if (action.typing || time == 0), mood != .unknown, time == 0 || Int(time * (mood == .happy ? 2 : 0.6)) % 2 == 0 {
                    pixel(rect.minX + rect.width * 0.80, rect.minY + rect.height * 0.75, 0.5, 1.8, mood == .happy ? 0.85 : 0.45)
                }

            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(animal.rawValue.capitalized), \(mood.rawValue), \(CoffeeCupArt.styles[animal]?.name ?? "coffee")")
    }
    private func cycle(_ value: Double, phase: Double = 0) -> Double {
        let p = (value - phase).truncatingRemainder(dividingBy: 1)
        return p < 0 ? p + 1 : p
    }
    private func drawCharacter(_ image: CGImage, in rect: CGRect, action: CompanionRoutine, physicalScale: Double, context: inout GraphicsContext) {
        let art = Image(decorative: image, scale: 1).interpolation(.none)
        func snap(_ value: Double) -> Double { (value * physicalScale).rounded() / physicalScale }
        guard action.keyDown else { context.draw(art, in: rect); return }
        let anchor: CGPoint
        switch animal {
        case .capybara: anchor = CGPoint(x: 0.67, y: 0.87)
        case .penguin, .owl: anchor = CGPoint(x: 0.62, y: 0.89)
        case .bear, .panda, .frog: anchor = CGPoint(x: 0.59, y: 0.89)
        case .raccoon, .wolf: anchor = CGPoint(x: 0.68, y: 0.89)
        default: anchor = CGPoint(x: 0.61, y: 0.91)
        }
        let center = CGPoint(x: rect.minX + rect.width * anchor.x, y: rect.minY + rect.height * anchor.y)
        let width = rect.width * 0.13, height = rect.height * 0.10
        let points: [(Double, Double)] = [(-0.3, -0.5), (0.2, -0.5), (0.45, -0.2), (0.5, 0.15), (0.2, 0.5), (-0.25, 0.5), (-0.5, 0.15), (-0.5, -0.15)]
        var paw = Path()
        for (index, point) in points.enumerated() {
            let vertex = CGPoint(x: snap(center.x + point.0 * width), y: snap(center.y + point.1 * height))
            if index == 0 { paw.move(to: vertex) } else { paw.addLine(to: vertex) }
        }
        paw.closeSubpath(); var rest = Path(rect); rest.addPath(paw)
        context.drawLayer { layer in layer.clip(to: rest, style: FillStyle(eoFill: true, antialiased: false)); layer.draw(art, in: rect) }
        context.drawLayer { layer in layer.clip(to: paw, style: FillStyle(antialiased: false)); layer.draw(art, in: rect.offsetBy(dx: 0, dy: snap(0.75))) }
    }
    private func drawCoffee(_ cup: CoffeeCupArt.Style, in rect: CGRect, physicalScale: Double, context: inout GraphicsContext) {
        func snap(_ value: Double) -> Double { (value * physicalScale).rounded() / physicalScale }
        // A fixed companion prop; no action, clock, paw, grip or lift affects its transform.
        let origin = CGPoint(x: 53.5, y: rect.maxY - 21 * cupCell)
        context.drawLayer { layer in
            layer.translateBy(x: snap(origin.x), y: snap(origin.y))
            for (row, line) in cup.pixels.enumerated() {
                for (column, key) in line.enumerated() {
                    guard let hex = cup.palette[key] else { continue }
                    let left = snap(Double(column) * cupCell), top = snap(Double(row) * cupCell)
                    let right = snap(Double(column + 1) * cupCell), bottom = snap(Double(row + 1) * cupCell)
                    layer.fill(Path(CGRect(x: left, y: top, width: right - left, height: bottom - top)), with: .color(Color(hex: hex)), style: FillStyle(antialiased: false))
                }
            }
        }
    }

}

enum CompanionAtlas {
    struct Frame { let image: CGImage; let size: CGSize }
    private struct Metadata: Decodable { let frames: [[Int]] }
    private static let images: [CGImage] = {
        var bundles = [Bundle.main]
        #if SWIFT_PACKAGE
        bundles.append(Bundle.module)
        #endif
        for bundle in bundles {
            guard let url = bundle.url(forResource: "Companions-v6", withExtension: "png", subdirectory: "Sprites"),
                  let json = bundle.url(forResource: "Companions-v6", withExtension: "json", subdirectory: "Sprites"),
                  let source = CGImageSourceCreateWithURL(url as CFURL, nil), let atlas = CGImageSourceCreateImageAtIndex(source, 0, nil),
                  let data = try? Data(contentsOf: json), let metadata = try? JSONDecoder().decode(Metadata.self, from: data) else { continue }
            let cropped = metadata.frames.compactMap { bounds -> CGImage? in
                guard bounds.count == 4 else { return nil }
                return atlas.cropping(to: CGRect(x: bounds[0], y: bounds[1], width: bounds[2], height: bounds[3]))
            }
            if cropped.count == 36 { return cropped }
        }
        return []
    }()
    // Four source pixels per logical unit retain the reference detail at native Retina density.
    private static let pixelImages: [CGImage] = images.enumerated().map { index, source in
        let common = registeredSize(index)
        let content = contentSize(index)
        let width = max(1, Int((common.width * 4).rounded()))
        let pixelsHigh = 132
        guard let context = CGContext(data: nil, width: width, height: pixelsHigh, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return source }
        context.interpolationQuality = .none
        context.draw(source, in: CGRect(x: Double(width) - content.width * 4, y: 0, width: content.width * 4, height: content.height * 4))
        return context.makeImage() ?? source
    }
    static var isLoaded: Bool { images.count == 36 }
    private static func commonSize(_ index: Int) -> CGSize {
        let start = index - index % 3
        let states = images[start..<(start + 3)]
        return CGSize(width: states.map(\.width).max() ?? 1, height: states.map(\.height).max() ?? 1)
    }
    private static func contentSize(_ index: Int) -> CGSize {
        let source = images[index]
        // Working and tired silhouettes each fill the shared 33-unit height.
        // Sleeping uses the same registration box, without stretching its resting pose.
        let height = index % 3 == 2 ? 33 * Double(source.height) / commonSize(index).height : 33
        return CGSize(width: height * Double(source.width) / Double(source.height), height: height)
    }
    private static func registeredSize(_ index: Int) -> CGSize {
        let start = index - index % 3
        return CGSize(width: (start..<start + 3).map { contentSize($0).width }.max() ?? 1, height: 33)
    }
    static func frame(animal: Animal, mood: Mood) -> Frame? {
        guard isLoaded, let animalIndex = Animal.allCases.firstIndex(of: animal) else { return nil }
        let first = (animalIndex / 2) * 6 + (animalIndex % 2) * 3
        let state = mood == .sleeping ? 2 : mood == .happy ? 0 : 1
        return Frame(image: pixelImages[first + state], size: registeredSize(first))
    }

}

extension Color {
    init(hex: UInt32) { self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255) }
    fileprivate func lighter() -> Color { blend(.white, amount: 0.2) }
    fileprivate func darker() -> Color { blend(.black, amount: 0.25) }
    private func blend(_ other: Color, amount: Double) -> Color {
        let a = NSColor(self).usingColorSpace(.deviceRGB) ?? .black, b = NSColor(other).usingColorSpace(.deviceRGB) ?? .black
        return Color(red: a.redComponent * (1 - amount) + b.redComponent * amount, green: a.greenComponent * (1 - amount) + b.greenComponent * amount, blue: a.blueComponent * (1 - amount) + b.blueComponent * amount)
    }
}
