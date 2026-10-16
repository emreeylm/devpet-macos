import AppKit
import SwiftUI

/// A dedicated native surface keeps dragging separate from adjacent SwiftUI buttons.
struct WindowDragHandle: NSViewRepresentable {
    var identifier = "windowDrag"
    var menuFactory: (() -> NSMenu)? = nil
    var tooltip: String? = nil
    func makeNSView(context: Context) -> DragSurface {
        let view = DragSurface()
        view.identifier = NSUserInterfaceItemIdentifier(identifier)
        view.menuFactory = menuFactory
        view.toolTip = tooltip
        return view
    }
    func updateNSView(_ nsView: DragSurface, context: Context) { nsView.menuFactory = menuFactory; nsView.toolTip = tooltip }

}
final class DragSurface: NSView {
    var menuFactory: (() -> NSMenu)?
    private var initialMouse: NSPoint?
    private var initialOrigin: NSPoint?
    override var acceptsFirstResponder: Bool { false }
    override var mouseDownCanMoveWindow: Bool { false }
    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        initialMouse = window.convertPoint(toScreen: event.locationInWindow)
        initialOrigin = window.frame.origin
    }
    override func mouseDragged(with event: NSEvent) {
        guard let window, let initialMouse, let initialOrigin else { return }
        let current = window.convertPoint(toScreen: event.locationInWindow)
        // Screen coordinates keep the drag continuous across displays and moving window origins.
        window.setFrameOrigin(NSPoint(x: initialOrigin.x + current.x - initialMouse.x,
                                      y: initialOrigin.y + current.y - initialMouse.y))
    }
    override func mouseUp(with event: NSEvent) {
        initialMouse = nil; initialOrigin = nil
        (window?.delegate as? WindowCoordinator)?.reassertFloatingWindows()
    }
    override func rightMouseDown(with event: NSEvent) {
        if let menu = menuFactory?() { NSMenu.popUpContextMenu(menu, with: event, for: self) }
        else { super.rightMouseDown(with: event) }
    }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
}
