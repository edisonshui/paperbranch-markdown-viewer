import AppKit
import XCTest

@testable import PaperbranchBridgeCore

/// The top bar covers the transparent title bar, so it must answer a double-click the way the
/// title bar would: by the System Settings choice under "Double-click a window's title bar".
@MainActor
final class TitleBarDoubleClickTests: XCTestCase {
    private func defaults(_ values: [String: Any]) -> UserDefaults {
        let suite = "TitleBarDoubleClickTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        values.forEach { defaults.set($0.value, forKey: $0.key) }
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return defaults
    }

    func testDoubleClickActionFollowsTheSystemSetting() {
        XCTAssertEqual(PBTitleBarDoubleClickAction.current(defaults([:])), .zoom)
        XCTAssertEqual(PBTitleBarDoubleClickAction.current(defaults(["AppleActionOnDoubleClick": "Maximize"])), .zoom)
        XCTAssertEqual(PBTitleBarDoubleClickAction.current(defaults(["AppleActionOnDoubleClick": "Minimize"])), .minimize)
        XCTAssertEqual(PBTitleBarDoubleClickAction.current(defaults(["AppleActionOnDoubleClick": "None"])), .none)
    }

    func testDoubleClickOnTheTopBarZoomsTheWindow() throws {
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 600, height: 400),
                              styleMask: [.titled, .resizable, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let dragView = PBWindowDragView(frame: NSRect(x: 0, y: 0, width: 600, height: 52))
        dragView.doubleClickAction = { .zoom }
        window.contentView?.addSubview(dragView)
        window.orderFront(nil)
        defer { window.close() }
        let before = window.frame

        let event = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: NSPoint(x: 10, y: 10), modifierFlags: [],
                                                     timestamp: 0, windowNumber: window.windowNumber, context: nil,
                                                     eventNumber: 0, clickCount: 2, pressure: 1))
        dragView.mouseDown(with: event)

        XCTAssertNotEqual(window.frame, before, "a double-click on the top bar zooms the window")
    }
}
