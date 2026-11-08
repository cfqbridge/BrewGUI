#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

APP_VERSION="${APP_VERSION:-2.1.261108}"

echo "==> 1. Compiling BrewGUI v$APP_VERSION (Release, arm64)..."
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/tmp/clang-module-cache}"
swift build --disable-sandbox -c release --arch arm64 -Xswiftc -module-cache-path -Xswiftc /tmp/swift-module-cache -Xcc -fmodules-cache-path=/tmp/clang-module-cache

BIN_PATH="$(swift build --disable-sandbox -c release --arch arm64 --show-bin-path)/BrewGUI"
APP_BUNDLE="$PROJECT_DIR/dist/BrewGUI.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> 2. Assembling $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/BrewGUI"
chmod +x "$MACOS_DIR/BrewGUI"

ICON_SOURCE="${1:-$PROJECT_DIR/ref/icon_option_c.png}"
if [[ -f "$ICON_SOURCE" ]]; then
    echo "==> Building AppIcon.icns from $ICON_SOURCE..."
    ICONSET_DIR="$PROJECT_DIR/.build/AppIcon.iconset"
    rm -rf "$ICONSET_DIR"
    mkdir -p "$ICONSET_DIR"
    /usr/bin/sips -z 16 16     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
    /usr/bin/sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
    /usr/bin/sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
    /usr/bin/sips -z 64 64     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
    /usr/bin/sips -z 128 128   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
    /usr/bin/sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
    /usr/bin/sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
    /usr/bin/sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
    /usr/bin/sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
    /usr/bin/sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
    /usr/bin/iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
fi

cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>BrewGUI</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>local.orca.BrewGUI</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>BrewGUI</string>
    <key>CFBundleDisplayName</key>
    <string>BrewGUI</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${APP_VERSION##*.}</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>zh_CN</string>
        <string>zh_TW</string>
        <string>en</string>
    </array>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>BrewGUI 需要使用系统对话框在需要管理员权限时请求您的密码授权。</string>
    <key>NSAppManagementUsageDescription</key>
    <string>BrewGUI 需要 App 管理权限以通过 Homebrew 安装、升级、接管或卸载 /Applications 目录下的应用程序。</string>
</dict>
</plist>
EOF

echo "==> 3. Signing $APP_BUNDLE with Ad-hoc signature..."
ENTITLEMENTS_PLIST="$PROJECT_DIR/.build/BrewGUI.entitlements"
cat > "$ENTITLEMENTS_PLIST" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
EOF
/usr/bin/codesign --force --deep --entitlements "$ENTITLEMENTS_PLIST" -s - "$APP_BUNDLE"
touch "$APP_BUNDLE"

echo "==> 4. Packaging styled DMG installer..."
DMG_BG_SOURCE="${2:-$PROJECT_DIR/ref/dmg_bg_option_c.png}"
DMG_VOL_NAME="BrewGUI"
DMG_STAGING="$PROJECT_DIR/.build/dmg_staging"
DMG_TEMP="$PROJECT_DIR/.build/BrewGUI_temp.dmg"
DMG_FINAL="$PROJECT_DIR/dist/BrewGUI.dmg"

# Detach any existing mounted volume with the same name
if [[ -d "/Volumes/$DMG_VOL_NAME" ]]; then
    /usr/bin/hdiutil detach "/Volumes/$DMG_VOL_NAME" -force >/dev/null 2>&1 || true
fi

rm -rf "$DMG_STAGING" "$DMG_TEMP" "$DMG_FINAL"
mkdir -p "$DMG_STAGING/.background"
cp -R "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

if [[ -f "$DMG_BG_SOURCE" ]]; then
    BG_1X="$PROJECT_DIR/.build/dmg_bg_1x.png"
    BG_2X="$PROJECT_DIR/.build/dmg_bg_2x.png"
    /usr/bin/sips -z 420 660 -s dpiWidth 72 -s dpiHeight 72 "$DMG_BG_SOURCE" --out "$BG_1X" >/dev/null
    /usr/bin/sips -z 840 1320 -s dpiWidth 144 -s dpiHeight 144 "$DMG_BG_SOURCE" --out "$BG_2X" >/dev/null
    /usr/bin/tiffutil -cathidpicheck "$BG_1X" "$BG_2X" -out "$DMG_STAGING/.background/background.tiff" >/dev/null
    rm -f "$BG_1X" "$BG_2X"
fi

if [[ -f "$RESOURCES_DIR/AppIcon.icns" ]]; then
    cp "$RESOURCES_DIR/AppIcon.icns" "$DMG_STAGING/.VolumeIcon.icns"
fi

DS_STORE_TEMPLATE="$PROJECT_DIR/ref/dmg_DS_Store"
if [[ -f "$DS_STORE_TEMPLATE" ]]; then
    cp -f "$DS_STORE_TEMPLATE" "$DMG_STAGING/.DS_Store"
fi

/usr/bin/hdiutil create -srcfolder "$DMG_STAGING" -volname "$DMG_VOL_NAME" -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" -format UDRW -ov "$DMG_TEMP" >/dev/null

ATTACH_OUTPUT="$(/usr/bin/hdiutil attach -readwrite -noverify -noautoopen "$DMG_TEMP")"
DEV_NAME="$(echo "$ATTACH_OUTPUT" | awk '/\/Volumes\// {print $1; exit}')"
MOUNT_DIR="/Volumes/$DMG_VOL_NAME"

if [[ -f "$MOUNT_DIR/.VolumeIcon.icns" && -x "/usr/bin/SetFile" ]]; then
    /usr/bin/SetFile -a C "$MOUNT_DIR" || true
fi

if [[ "${GITHUB_ACTIONS:-}" != "true" ]]; then
/usr/bin/osascript <<EOF || echo "Warning: Finder AppleScript layout skipped (sandbox or headless environment)."
tell application "Finder"
    tell disk "$DMG_VOL_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 860, 568}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        set text size of theViewOptions to 13
        set background picture of theViewOptions to file ".background:background.tiff"
        set position of item "BrewGUI.app" of container window to {170, 180}
        set position of item "Applications" of container window to {490, 180}
        close
        open
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF
    if [[ -f "$MOUNT_DIR/.DS_Store" ]]; then
        cp -f "$MOUNT_DIR/.DS_Store" "$DS_STORE_TEMPLATE"
        echo "==> Updated DMG layout template: $DS_STORE_TEMPLATE"
    fi
elif [[ -f "$DS_STORE_TEMPLATE" ]]; then
    cp -f "$DS_STORE_TEMPLATE" "$MOUNT_DIR/.DS_Store"
    echo "==> Applied pre-built DMG layout template: $DS_STORE_TEMPLATE"
fi

/bin/chmod -Rf go-w "$MOUNT_DIR" 2>/dev/null || true
/bin/sync
/usr/bin/hdiutil detach "$DEV_NAME" -quiet || /usr/bin/hdiutil detach "$DEV_NAME" -force -quiet
/usr/bin/hdiutil convert "$DMG_TEMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_FINAL" >/dev/null
rm -rf "$DMG_STAGING" "$DMG_TEMP"

DMG_SHA256="$(/usr/bin/shasum -a 256 "$DMG_FINAL" | awk '{print $1}')"
RELEASE_DATE="$(date +%Y-%m-%d)"
VERSION_JSON="$PROJECT_DIR/dist/version.json"
cat > "$VERSION_JSON" <<EOF
{
  "version": "${APP_VERSION}",
  "release_date": "${RELEASE_DATE}",
  "download_url": "https://github.com/cfqbridge/BrewGUI/releases/latest/download/BrewGUI.dmg",
  "sha256": "${DMG_SHA256}",
  "release_page": "https://github.com/cfqbridge/BrewGUI/releases/latest"
}
EOF
echo "==> Generated version.json (sha256: $DMG_SHA256): $VERSION_JSON"

if [[ -d "$PROJECT_DIR/site" ]]; then
    cp -f "$DMG_FINAL" "$PROJECT_DIR/site/BrewGUI.dmg"
    cp -f "$VERSION_JSON" "$PROJECT_DIR/site/version.json"
    echo "==> Synced DMG & version.json to: $PROJECT_DIR/site/"
fi

echo "==> Done! App bundle: $APP_BUNDLE"
echo "==> Done! DMG image:  $DMG_FINAL"
