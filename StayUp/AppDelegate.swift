import AppKit
import ApplicationServices
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var didPromptAccessibilityThisSession = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        registerLaunchAtLogin()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.warnIfMenuBarItemHidden()
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true
        statusItem.autosaveName = "StayUpMenuBarItem"

        guard let button = statusItem.button else {
            NSLog("Stay Up: status item button was nil")
            return
        }

        if let image = NSImage(
            systemSymbolName: "globe",
            accessibilityDescription: "Stay Up"
        ) {
            let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
            button.image = image.withSymbolConfiguration(config)
            button.image?.isTemplate = true
        }

        button.title = " Stay"
        button.imagePosition = .imageLeading
        button.toolTip = "Stay Up — click to open"
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        NSLog("Stay Up: menu bar item ready")
    }

    private func warnIfMenuBarItemHidden() {
        guard let button = statusItem.button else { return }

        let frame = button.window?.frame ?? .zero
        let screen = button.window?.screen
        let looksHidden = screen == nil || frame.origin.y < 0 || frame.width < 1
        guard looksHidden else { return }

        let alert = NSAlert()
        alert.messageText = "Enable Stay Up in the menu bar"
        alert.informativeText = """
        Stay Up is running, but macOS is hiding its menu bar icon.

        Open System Settings → Menu Bar, find “Stay Up”, and turn it on.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "OK")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openMenuBarSettings()
        }
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let openItem = NSMenuItem(
            title: "Open URL",
            action: #selector(openURL),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        let accessItem = NSMenuItem(
            title: "Enable Half-Width Resize…",
            action: #selector(requestAccessibilityHelp),
            keyEquivalent: ""
        )
        accessItem.target = self
        menu.addItem(accessItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit Stay Up",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            openURL()
            return
        }

        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
        } else {
            openURL()
        }
    }

    private func showMenu() {
        let menu = makeMenu()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openURL() {
        NSWorkspace.shared.open(Config.url)

        guard isAccessibilityTrusted(prompt: true) else {
            if !didPromptAccessibilityThisSession {
                didPromptAccessibilityThisSession = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                    self?.showAccessibilityAlert()
                }
            }
            return
        }

        // Browser needs a moment to bring its window forward.
        for delay in [0.45, 0.9, 1.6] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.resizeDefaultBrowserToHalfWidth()
            }
        }
    }

    @objc private func requestAccessibilityHelp() {
        _ = isAccessibilityTrusted(prompt: true)
        showAccessibilityAlert()
    }

    private func isAccessibilityTrusted(prompt: Bool) -> Bool {
        if prompt {
            let options = [
                kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
            ] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
        return AXIsProcessTrusted()
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Allow Stay Up to resize the browser"
        alert.informativeText = """
        macOS blocks window resizing until Stay Up is enabled under Accessibility.

        1. Click “Open Accessibility Settings”
        2. Turn on Stay Up
        3. Click the Stay Up menu bar icon again
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Accessibility Settings")
        alert.addButton(withTitle: "Later")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }

    private func openAccessibilitySettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.Accessibility-Settings.extension"
        ]
        for string in urls {
            if let url = URL(string: string), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    private func openMenuBarSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.ControlCenter-Settings.extension?MenuBar",
            "x-apple.systempreferences:com.apple.MenuBarSettings"
        ]
        for string in urls {
            if let url = URL(string: string), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    /// Places the default browser's front window on the left half of the screen.
    private func resizeDefaultBrowserToHalfWidth() {
        guard isAccessibilityTrusted(prompt: false) else { return }
        guard let screen = NSScreen.main else { return }
        guard let bundleID = defaultBrowserBundleIdentifier() else { return }

        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        guard let app = apps.first(where: { !$0.isTerminated }) else { return }

        app.activate(options: [.activateIgnoringOtherApps])

        let visible = screen.visibleFrame
        let full = screen.frame
        // Accessibility uses top-left origin (y grows downward).
        var origin = CGPoint(
            x: visible.origin.x,
            y: full.maxY - visible.maxY
        )
        var size = CGSize(
            width: visible.width * Config.browserWidthFraction,
            height: visible.height
        )

        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &windowsRef
        )
        guard result == .success,
              let windows = windowsRef as? [AXUIElement],
              let window = windows.first
        else {
            NSLog("Stay Up: could not get browser windows (ax=\(result.rawValue))")
            return
        }

        // Exit full-screen / zoomed states that block resizing.
        AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, kCFBooleanFalse)

        if let posValue = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }
    }

    private func defaultBrowserBundleIdentifier() -> String? {
        guard let appURL = NSWorkspace.shared.urlForApplication(toOpen: Config.url) else {
            return nil
        }
        return Bundle(url: appURL)?.bundleIdentifier
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func registerLaunchAtLogin() {
        do {
            try SMAppService.mainApp.register()
        } catch {
            NSLog("Stay Up: login item register failed: \(error.localizedDescription)")
        }
    }
}
