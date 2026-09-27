#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Stay Up"
BUNDLE="$ROOT/Stay Up.app"
CONTENTS="$BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
SRC="$ROOT/StayUp"

echo "Building ${APP_NAME}..."

rm -rf "$BUNDLE"
mkdir -p "$MACOS"

swiftc \
  -O \
  -whole-module-optimization \
  -target arm64-apple-macos13.0 \
  -sdk "$(xcrun --show-sdk-path)" \
  -framework AppKit \
  -framework ServiceManagement \
  -framework ApplicationServices \
  "$SRC/Config.swift" \
  "$SRC/AppDelegate.swift" \
  "$SRC/main.swift" \
  -o "$MACOS/StayUp"

cp "$SRC/Info.plist" "$CONTENTS/Info.plist"

# Ad-hoc sign so macOS Gatekeeper / SMAppService behave better locally.
codesign --force --deep --sign - "$BUNDLE" 2>/dev/null || true

echo ""
echo "Built: $BUNDLE"
echo ""
echo "Run it:"
echo "  open \"$BUNDLE\""
echo ""
echo "Install to Applications:"
echo "  cp -R \"$BUNDLE\" /Applications/"
echo "  open \"/Applications/${APP_NAME}.app\""
