#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
./scripts/build-icon.sh
APP="$PWD/dist/BroClean.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp -R .build/release/BroClean_BrowserScopeApp.bundle "$APP/Contents/Resources/"
cp .build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp .build/release/BroCleanDesktop "$APP/Contents/MacOS/BroClean"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.browserscope.app</string>
<key>BroCleanGitHubURL</key><string>https://github.com/holynova/BroClean</string>
<key>CFBundleName</key><string>BroClean</string>
<key>CFBundleExecutable</key><string>BroClean</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.3.0</string>
<key>CFBundleVersion</key><string>3</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --strict "$APP"
printf 'Built %s\n' "$APP"
