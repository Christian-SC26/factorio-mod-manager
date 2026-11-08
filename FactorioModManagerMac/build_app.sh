#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

UNIVERSAL_FLAGS=(-c release --arch arm64 --arch x86_64)

echo "==> Building Factorio Mod Manager (Release, universal: arm64 + x86_64)..."
if swift build "${UNIVERSAL_FLAGS[@]}"; then
    BIN_DIR="$(swift build "${UNIVERSAL_FLAGS[@]}" --show-bin-path)"
elif [ "${FMM_REQUIRE_UNIVERSAL:-0}" = "1" ]; then
    echo "==> Universal build failed and FMM_REQUIRE_UNIVERSAL=1, stopping." >&2
    exit 1
else
    # Multi-arch builds need the full Xcode; Command Line Tools alone build for this Mac only
    echo "==> Universal build unavailable, building for this Mac's architecture only..."
    swift build -c release
    BIN_DIR="$(swift build -c release --show-bin-path)"
fi

APP_NAME="FMM.app"
APP_DIR="$DIR/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Creating macOS App Bundle ($APP_NAME)..."
rm -rf "$APP_DIR" "$DIR/Factorio Mod Manager.app"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_DIR/FactorioModManagerMac" "$MACOS_DIR/FactorioModManagerMac"
echo "==> Architectures: $(lipo -archs "$MACOS_DIR/FactorioModManagerMac")"

if [ -f "$DIR/Resources/AppIcon.icns" ]; then
    cp "$DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

cat <<EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>FactorioModManagerMac</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.christian.FactorioModManager</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>FMM</string>
    <key>CFBundleDisplayName</key>
    <string>FMM</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.2.0</string>
    <key>CFBundleVersion</key>
    <string>3</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "==> Application bundle created at: $APP_DIR"
echo "==> You can run it with: open '$APP_DIR'"
