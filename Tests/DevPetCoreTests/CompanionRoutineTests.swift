import XCTest
@testable import DevPetCore

final class CompanionRoutineTests: XCTestCase {
    func testWorkingStatesKeepTypingWithoutCoffeeBreaks() {
        for animal in Animal.allCases {
            for mood in [Mood.happy, .tired] {
                for time in stride(from: 0.125, through: 90, by: 0.125) {
                    XCTAssertTrue(CompanionRoutine.sample(time: time, animal: animal, mood: mood).typing)
                }
            }
        }
    }
    func testTiredTypingIsSlowerThanHappyTyping() {
        for animal in Animal.allCases {
            func taps(_ mood: Mood) -> Int {
                var wasDown = false, count = 0
                for time in stride(from: 0.125, through: 60, by: 0.125) {
                    let down = CompanionRoutine.sample(time: time, animal: animal, mood: mood).keyDown
                    if down && !wasDown { count += 1 }
                    wasDown = down
                }
                return count
            }
            XCTAssertGreaterThan(taps(.happy), taps(.tired) * 3)
        }
    }
    func testSleepUnknownAndPausedNeverType() {
        for animal in Animal.allCases {
            for mood in Mood.allCases { XCTAssertEqual(CompanionRoutine.sample(time: 0, animal: animal, mood: mood), CompanionRoutine()) }
            for mood in [Mood.sleeping, .unknown, .normal, .alert] {
                for time in stride(from: 0.125, through: 60, by: 0.125) {
                    XCTAssertEqual(CompanionRoutine.sample(time: time, animal: animal, mood: mood), CompanionRoutine())
                }
            }
        }
    }
}
