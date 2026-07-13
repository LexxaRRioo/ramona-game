import AppKit
import ApplicationServices

/// Tracks the frontmost application's focused window frame via the
/// Accessibility API, and reports live updates when it moves, resizes,
/// or disappears (closed/minimized) - or when the user switches app.
///
/// Reported frames are in Cocoa screen coordinates (bottom-left origin),
/// matching NSScreen/SKView, converted from AX's top-left-origin space.
/// Only the primary display is handled; windows on secondary displays will
/// report an out-of-bounds frame, which callers should treat as untrackable.
final class FrontmostWindowTracker {
    var onFrameChange: ((CGRect?) -> Void)?

    private var appObserver: AXObserver?
    private var currentAppElement: AXUIElement?
    private var currentWindowElement: AXUIElement?
    private var workspaceObserver: NSObjectProtocol?

    init() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.trackApplication(pid: app.processIdentifier)
        }

        if let frontmost = NSWorkspace.shared.frontmostApplication {
            trackApplication(pid: frontmost.processIdentifier)
        }
    }

    deinit {
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
        stopObservingCurrentApp()
    }

    private func trackApplication(pid: pid_t) {
        stopObservingCurrentApp()

        let appElement = AXUIElementCreateApplication(pid)
        currentAppElement = appElement

        var observer: AXObserver?
        guard AXObserverCreate(pid, Self.axCallback, &observer) == .success, let observer else {
            onFrameChange?(nil)
            return
        }
        appObserver = observer

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(observer, appElement, kAXFocusedWindowChangedNotification as CFString, refcon)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)

        trackFocusedWindow(of: appElement)
    }

    private func trackFocusedWindow(of appElement: AXUIElement) {
        stopObservingCurrentWindow()

        var focusedWindow: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success else {
            onFrameChange?(nil)
            return
        }
        let windowElement = focusedWindow as! AXUIElement
        currentWindowElement = windowElement

        if let observer = appObserver {
            let refcon = Unmanaged.passUnretained(self).toOpaque()
            AXObserverAddNotification(observer, windowElement, kAXMovedNotification as CFString, refcon)
            AXObserverAddNotification(observer, windowElement, kAXResizedNotification as CFString, refcon)
            AXObserverAddNotification(observer, windowElement, kAXUIElementDestroyedNotification as CFString, refcon)
        }

        reportCurrentFrame()
    }

    private func reportCurrentFrame() {
        guard let windowElement = currentWindowElement else {
            onFrameChange?(nil)
            return
        }
        onFrameChange?(Self.cocoaFrame(of: windowElement))
    }

    private func stopObservingCurrentWindow() {
        if let observer = appObserver, let windowElement = currentWindowElement {
            AXObserverRemoveNotification(observer, windowElement, kAXMovedNotification as CFString)
            AXObserverRemoveNotification(observer, windowElement, kAXResizedNotification as CFString)
            AXObserverRemoveNotification(observer, windowElement, kAXUIElementDestroyedNotification as CFString)
        }
        currentWindowElement = nil
    }

    private func stopObservingCurrentApp() {
        stopObservingCurrentWindow()
        if let observer = appObserver {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        appObserver = nil
        currentAppElement = nil
    }

    private static func cocoaFrame(of windowElement: AXUIElement) -> CGRect? {
        var positionValue: AnyObject?
        var sizeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(windowElement, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(windowElement, kAXSizeAttribute as CFString, &sizeValue) == .success else {
            return nil
        }

        var axPosition = CGPoint.zero
        var axSize = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &axPosition),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &axSize) else {
            return nil
        }

        guard let primaryScreenHeight = NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height else {
            return nil
        }

        return CGRect(
            x: axPosition.x,
            y: primaryScreenHeight - axPosition.y - axSize.height,
            width: axSize.width,
            height: axSize.height
        )
    }

    private static let axCallback: AXObserverCallback = { _, _, notification, refcon in
        guard let refcon else { return }
        let tracker = Unmanaged<FrontmostWindowTracker>.fromOpaque(refcon).takeUnretainedValue()

        switch notification as String {
        case kAXFocusedWindowChangedNotification:
            if let appElement = tracker.currentAppElement {
                tracker.trackFocusedWindow(of: appElement)
            }
        case kAXUIElementDestroyedNotification:
            tracker.stopObservingCurrentWindow()
            tracker.onFrameChange?(nil)
        case kAXMovedNotification, kAXResizedNotification:
            tracker.reportCurrentFrame()
        default:
            break
        }
    }
}
