import Foundation
import CoreGraphics

public struct DisplayArea: Sendable {
    public var id: String
    public var frame: CGRect
    public init(id: String, frame: CGRect) { self.id = id; self.frame = frame }
}
public struct SavedWindowPlacement: Codable, Sendable {
    public var displayID: String
    public var frame: CGRect
    public var visibleFrame: CGRect
    public init(frame: CGRect, display: DisplayArea) {
        self.frame = frame; displayID = display.id; visibleFrame = display.frame
    }
    public var isValid: Bool {
        [frame.minX, frame.minY, frame.width, frame.height, visibleFrame.minX, visibleFrame.minY, visibleFrame.width, visibleFrame.height].allSatisfy(\.isFinite) && frame.width > 0 && frame.height > 0 && visibleFrame.width > 0 && visibleFrame.height > 0
    }
    public func restored(on displays: [DisplayArea], size: CGSize? = nil) -> CGRect {
        guard let index = displays.firstIndex(where: { $0.id == displayID }) else {
            return UsageLogic.restore(frame: CGRect(origin: frame.origin, size: size ?? frame.size), screens: displays.map(\.frame))
        }
        let target = displays[index].frame
        let desired = size ?? frame.size
        let width = min(desired.width, target.width), height = min(desired.height, target.height)
        // Preserve relative placement and edge alignment across resolution/Dock changes.
        let horizontal = max(0, min(1, (frame.minX - visibleFrame.minX) / max(1, visibleFrame.width - frame.width)))
        let vertical = max(0, min(1, (frame.minY - visibleFrame.minY) / max(1, visibleFrame.height - frame.height)))
        let moved = CGRect(x: target.minX + horizontal * max(0, target.width - width), y: target.minY + vertical * max(0, target.height - height), width: width, height: height)
        return UsageLogic.restore(frame: moved, screens: displays.map(\.frame), preferred: index)
    }
}
