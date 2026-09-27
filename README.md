# Stay Up

A tiny native macOS **menu bar** app. Click the icon once to open the Stay Up page in your default browser and (optionally) snap that window to the left half of the screen.

No Dock icon. No third-party dependencies. Apple Silicon (and Intel via rebuild) — requires macOS 13+.

---

## Try it out

### What it does

| Action | Result |
|--------|--------|
| **Left-click** menu bar icon | Opens the Stay Up URL in your default browser |
| **Right-click** menu bar icon | **Open URL** · **Enable Half-Width Resize…** · **Quit Stay Up** |

After install, the app also registers itself to **open at login**.

Default URL:

`https://itsurl.com/utilities/stay-up/start`

### Requirements

- macOS 13 or later
- Xcode Command Line Tools (for building), or a pre-built `Stay Up.app`
- Apple Silicon Macs work out of the box with the included build script (`arm64`)

### Build & install

```bash
git clone <this-repo-url>
cd stay-up-mac
./build.sh
cp -R "Stay Up.app" /Applications/
open "/Applications/Stay Up.app"
```

You should see a globe + **Stay** item in the menu bar (near the clock). On macOS Tahoe, if the icon is missing, open **System Settings → Menu Bar → Allow in the Menu Bar** and turn **Stay Up** on.

### Half-width browser window (optional)

Left-click opens the URL immediately. To also resize the browser to **50% width** on the left:

1. Click the icon (or right-click → **Enable Half-Width Resize…**)
2. Allow Stay Up under **System Settings → Privacy & Security → Accessibility**
3. Click the menu bar icon again

Rebuilding/reinstalling the app can reset that permission — toggle Stay Up off and on again in Accessibility if resize stops working.

### Change the URL

Edit one place, then rebuild:

```swift
// StayUp/Config.swift
static let urlString = "https://itsurl.com/utilities/stay-up/start"

// Optional: fraction of screen width (0.5 = half)
static let browserWidthFraction: Double = 0.5
```

```bash
./build.sh
cp -R "Stay Up.app" /Applications/
```

### Quit / uninstall

- **Quit:** right-click the menu bar icon → **Quit Stay Up**
- **Stop login launch:** System Settings → General → Login Items → remove Stay Up
- **Uninstall:** quit the app, then delete `/Applications/Stay Up.app`

---

## Contribute

### Project layout

```
StayUp/
  Config.swift       # URL + width fraction (user-facing knobs)
  AppDelegate.swift  # Menu bar item, click handling, resize, login item
  main.swift         # AppKit entry point (accessory / no Dock)
  Info.plist         # Bundle metadata
build.sh             # Builds Stay Up.app (ad-hoc signed)
.gitignore           # Ignores built *.app bundles
```

Native **AppKit** + **ServiceManagement** + **ApplicationServices** only. No Swift Package Manager dependencies.

### Prerequisites

- macOS 13+
- Xcode or `xcode-select --install` (needs `swiftc` and macOS SDK)
- For Apple Silicon builds as shipped: `arm64-apple-macos13.0` (see `build.sh`)

### Develop locally

```bash
./build.sh
open "Stay Up.app"
```

After code changes, rebuild and reinstall to `/Applications` if you want login-item / Accessibility paths to match the installed copy:

```bash
./build.sh
pkill -f StayUp || true
cp -R "Stay Up.app" /Applications/
open "/Applications/Stay Up.app"
```

Do **not** commit `Stay Up.app` — it is gitignored. Commit sources and `build.sh` only.

### Coding notes

- **Primary UX:** menu bar icon → single left-click → URL opens. No intermediate menu on left-click.
- **Dock:** hidden via `NSApp.setActivationPolicy(.accessory)` (avoid relying on `LSUIElement` alone on newer macOS).
- **Resize:** uses Accessibility (`AXUIElement`) after the browser activates; fails closed if permission is denied.
- Keep the app small — prefer a few Swift files over new frameworks.

### Pull requests

1. Fork and create a branch from `main`
2. Make a focused change (one concern per PR when possible)
3. Verify `./build.sh` succeeds and the menu bar click still opens the URL
4. Open a PR with a short summary of **why** and how you tested

### Ideas that fit well

- SF Symbol / icon-only menu bar item
- Clearer first-run guidance for Menu Bar + Accessibility on macOS Tahoe
- Intel (`x86_64`) or universal binary support in `build.sh`
- Tests or a simple smoke script around `Config` / launch

### License / conduct

If this repo does not yet include a license or contributor guidelines, open an issue before large changes so maintainers can set expectations.
