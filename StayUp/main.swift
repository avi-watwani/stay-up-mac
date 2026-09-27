import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Hide Dock icon at runtime (avoid LSUIElement — it can make Tahoe hide the menu bar item).
app.setActivationPolicy(.accessory)
app.run()
