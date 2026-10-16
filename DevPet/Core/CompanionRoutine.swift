import Foundation

/// Only the existing typing paw moves. Cups and the body are stationary.
public struct CompanionRoutine: Equatable, Sendable {
    public var typing = false
    public var keyDown = false
    public init() {}
    public static func sample(time: Double, animal: Animal, mood: Mood) -> CompanionRoutine {
        var state = CompanionRoutine()
        guard time.isFinite, time > 0, mood == .happy || mood == .tired else { return state }
        let index = Double(Animal.allCases.firstIndex(of: animal) ?? 0)
        state.typing = true
        let beat = Int((time + index * 0.17) * (mood == .happy ? 6 : 1.2))
        state.keyDown = mood == .happy ? beat % 3 != 2 : beat % 6 == 0
        return state
    }
}
