#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="AleClip"
APP_BUNDLE="${DIR}/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

echo "🔨 Compiling release binary..."
swift build -c release

echo "📦 Packaging ${APP_NAME}.app with AppIcon..."

rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS}" "${RESOURCES}"

# Copy compiled release binary
cp "${DIR}/.build/release/aleclip" "${MACOS}/aleclip"
chmod +x "${MACOS}/aleclip"

# Copy AppIcon.icns if available
if [ -f "${DIR}/Resources/AppIcon.icns" ]; then
    cp "${DIR}/Resources/AppIcon.icns" "${RESOURCES}/AppIcon.icns"
fi

# Create Info.plist
cat <<EOF > "${CONTENTS}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>aleclip</string>
    <key>CFBundleIdentifier</key>
    <string>com.darwin.aleclip</string>
    <key>CFBundleName</key>
    <string>AleClip</string>
    <key>CFBundleDisplayName</key>
    <string>AleClip</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Strip quarantine and sign with ad-hoc signature
xattr -cr "${APP_BUNDLE}"
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "✅ Successfully signed and packaged ${APP_BUNDLE}!"

# Setup DMG staging with Applications symlink, VolumeIcon, and background
STAGING_DIR="${DIR}/.dmg_staging"
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

cp -R "${APP_BUNDLE}" "${STAGING_DIR}/${APP_NAME}.app"
ln -s /Applications "${STAGING_DIR}/Applications"

if [ -f "${DIR}/Resources/AppIcon.icns" ]; then
    cp "${DIR}/Resources/AppIcon.icns" "${STAGING_DIR}/.VolumeIcon.icns"
    SetFile -a C "${STAGING_DIR}" 2>/dev/null || true
fi

if [ -f "${DIR}/Resources/dmg_background.png" ]; then
    mkdir -p "${STAGING_DIR}/.background"
    cp "${DIR}/Resources/dmg_background.png" "${STAGING_DIR}/.background/background.png"
fi

# Create macOS DMG image
DMG_PATH="${DIR}/${APP_NAME}.dmg"
rm -f "${DMG_PATH}"
echo "💿 Creating ${APP_NAME}.dmg with custom logo, volume icon, and Applications drag link..."
hdiutil create -volname "${APP_NAME}" -srcfolder "${STAGING_DIR}" -ov -format UDZO "${DMG_PATH}" -quiet
rm -rf "${STAGING_DIR}"

# Remove quarantine from DMG
xattr -cr "${DMG_PATH}"
echo "✅ Successfully built DMG at ${DMG_PATH}!"

# Update /Applications/AleClip.app
echo "🚀 Updating /Applications/${APP_NAME}.app..."
pkill -x aleclip 2>/dev/null || true
rm -rf "/Applications/${APP_NAME}.app"
cp -R "${APP_BUNDLE}" "/Applications/${APP_NAME}.app"
xattr -cr "/Applications/${APP_NAME}.app"
touch "/Applications/${APP_NAME}.app"

# Relaunch
open "/Applications/${APP_NAME}.app"
echo "🎉 AleClip is now running with the new App Icon!"
