#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

# One architecture per build: arm64 (Apple Silicon) or x86_64 (Intel), this Mac's own by default.
# The Xcode-style build systems (`--arch`, and the default since Swift 6.4) stamp the deployment target (13.0)
# into the binary as its SDK version, and macOS then shows the pre-Liquid Glass design.
ARCH="${FMM_ARCH:-$(uname -m)}"
case "$ARCH" in
    arm64|x86_64) ;;
    *) echo "==> Unknown FMM_ARCH \"$ARCH\", use arm64 or x86_64." >&2; exit 1 ;;
esac
BUILD_FLAGS=(-c release --build-system native --triple "$ARCH-apple-macosx13.0")

echo "==> Building Factorio Mod Manager (Release, $ARCH)..."
swift build "${BUILD_FLAGS[@]}"
BIN_DIR="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)"

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

# macOS turns on Liquid Glass only for binaries linked against SDK 26 or later
SDK_VERSION="$(vtool -show-build "$MACOS_DIR/FactorioModManagerMac" | awk '$1 == "sdk" { print $2; exit }')"
echo "==> Linked SDK: $SDK_VERSION"
if [ -n "${FMM_MIN_SDK:-}" ] && [ "${SDK_VERSION%%.*}" -lt "$FMM_MIN_SDK" ]; then
    echo "==> Linked SDK $SDK_VERSION is older than FMM_MIN_SDK=$FMM_MIN_SDK, stopping." >&2
    exit 1
fi

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

if [ -n "${FMM_SIGN_IDENTITY:-}" ]; then
    echo "==> Signing with \"$FMM_SIGN_IDENTITY\" (hardened runtime)..."
    codesign --force --options runtime --timestamp --sign "$FMM_SIGN_IDENTITY" "$APP_DIR"
else
    echo "==> FMM_SIGN_IDENTITY not set, signing ad-hoc..."
    codesign --force --sign - "$APP_DIR"
fi
codesign --verify --strict "$APP_DIR"

if [ -n "${FMM_NOTARY_PROFILE:-}" ]; then
    echo "==> Notarizing with keychain profile \"$FMM_NOTARY_PROFILE\"..."
    ZIP="$DIR/FMM-notarize.zip"
    ditto -c -k --keepParent "$APP_DIR" "$ZIP"
    xcrun notarytool submit "$ZIP" --keychain-profile "$FMM_NOTARY_PROFILE" --wait
    rm -f "$ZIP"
    xcrun stapler staple "$APP_DIR"
    spctl -a -vv -t exec "$APP_DIR"
fi

echo "==> Application bundle created at: $APP_DIR"
echo "==> You can run it with: open '$APP_DIR'"
