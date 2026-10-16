#!/bin/zsh
set -eu
cd "${0:A:h}"
swift build -c release
APP="$PWD/Watch Playground.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/WatchPlayground "$APP/Contents/MacOS/WatchPlayground"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>WatchPlayground</string>
<key>CFBundleIdentifier</key><string>com.example.watchplayground.mac</string>
<key>CFBundleName</key><string>Watch Playground</string>
<key>CFBundleDisplayName</key><string>Watch Playground</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSLocalNetworkUsageDescription</key><string>Receive sensor feeds from your paired Apple Watch on your local network.</string>
<key>NSBluetoothAlwaysUsageDescription</key><string>Stream sensor feeds directly from your Apple Watch with low latency.</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
SIGNING_IDENTITY="${WATCHPLAYGROUND_SIGN_IDENTITY:--}"
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  FOUND_IDENTITY=$(security find-identity -v -p codesigning | /usr/bin/awk '/Apple Development:/ {print $2; exit}')
  if [[ -n "$FOUND_IDENTITY" ]]; then SIGNING_IDENTITY="$FOUND_IDENTITY"; fi
fi
codesign --force --sign "$SIGNING_IDENTITY" "$APP"
echo "Built: $APP"
