#!/bin/bash
# Build CodeEditorSample, wrap the SwiftPM-built executable in a minimal
# .app bundle, and `open` it. `open` launches the app via LaunchServices,
# detached from this terminal — closing the terminal no longer kills the
# app, the Dock entry is the standard one, and cmd-Q / Force Quit work
# normally.
#
# Usage: ./Scripts/run-sample.sh [debug|release]   (default: debug)

set -euo pipefail

CONFIG="${1:-debug}"
case "$CONFIG" in
    debug)   SWIFT_BUILD_FLAGS=()                 ;;
    release) SWIFT_BUILD_FLAGS=(-c release)       ;;
    *) echo "config must be 'debug' or 'release'" >&2; exit 2 ;;
esac

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "Building CodeEditorSample ($CONFIG)…"
swift build "${SWIFT_BUILD_FLAGS[@]+"${SWIFT_BUILD_FLAGS[@]}"}" --product CodeEditorSample

BIN_DIR="$(swift build "${SWIFT_BUILD_FLAGS[@]+"${SWIFT_BUILD_FLAGS[@]}"}" --show-bin-path)"
BINARY="$BIN_DIR/CodeEditorSample"
if [[ ! -x "$BINARY" ]]; then
    echo "Built binary not found at $BINARY" >&2
    exit 1
fi

APP_DIR="$BIN_DIR/CodeEditorSample.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RES="$CONTENTS/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RES"

# Copy (not symlink) so `open` is happy and code-signing-on-first-run works.
cp "$BINARY" "$MACOS/CodeEditorSample"

# Carry SwiftPM resource bundles next to the executable so the runtime
# `Bundle.module` lookup keeps resolving (Themes JSON, etc.).
find "$BIN_DIR" -maxdepth 1 -name '*.bundle' -print0 | while IFS= read -r -d '' bundle; do
    cp -R "$bundle" "$MACOS/"
done

cat >"$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>          <string>CodeEditorSample</string>
    <key>CFBundleIdentifier</key>          <string>dev.ajmcclary.CodeEditorSample</string>
    <key>CFBundleName</key>                <string>CodeEditorSample</string>
    <key>CFBundleDisplayName</key>         <string>CodeEditorSample</string>
    <key>CFBundlePackageType</key>         <string>APPL</string>
    <key>CFBundleShortVersionString</key>  <string>0.1</string>
    <key>CFBundleVersion</key>             <string>1</string>
    <key>LSMinimumSystemVersion</key>      <string>13.0</string>
    <key>NSPrincipalClass</key>            <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>     <true/>
    <key>LSApplicationCategoryType</key>   <string>public.app-category.developer-tools</string>
</dict>
</plist>
PLIST

echo "Wrote $APP_DIR"

# `-n` opens a fresh instance every run; `-W` would block — we don't.
open -n "$APP_DIR"
echo "Launched (detached). Use the Dock or cmd-Q to quit."
