#!/bin/bash
set -e
cd "$(dirname "$0")"

APP="LivePaper.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

# Build arm64 only (macOS Tahoe is Apple Silicon only)
echo "Building..."
swiftc Sources/*.swift -o "$APP/Contents/MacOS/LivePaper" \
  -framework AppKit -framework AVFoundation -framework CoreMedia \
  -framework CoreGraphics -framework QuartzCore -framework CoreText \
  -framework IOKit \
  -Osize \
  -target arm64-apple-macosx15.0

# Bundle font
if [ -f "Fonts/Anurati-Regular.otf" ]; then
  cp "Fonts/Anurati-Regular.otf" "$APP/Contents/Resources/"
elif [ -f "$HOME/Library/Fonts/Anurati-Regular.otf" ]; then
  cp "$HOME/Library/Fonts/Anurati-Regular.otf" "$APP/Contents/Resources/"
fi

# Bundle app icon
if [ -f "AppIcon.icns" ]; then
  cp AppIcon.icns "$APP/Contents/Resources/"
fi

# Bundle license
if [ -f "LICENSE" ]; then
  cp LICENSE "$APP/Contents/Resources/"
fi

# Install bundled sample videos to ~/Movies/LivePaper/
# Skip files smaller than 100KB — they're likely Git LFS pointers
VIDEOS_DIR="$HOME/Movies/LivePaper"
mkdir -p "$VIDEOS_DIR"
if [ -d "Videos" ]; then
  for v in Videos/*.mov Videos/*.mp4 Videos/*.m4v; do
    [ -f "$v" ] || continue
    FSIZE=$(stat -f%z "$v" 2>/dev/null || echo 0)
    [ "$FSIZE" -lt 100000 ] && continue
    BNAME=$(basename "$v")
    [ ! -f "$VIDEOS_DIR/$BNAME" ] && cp "$v" "$VIDEOS_DIR/"
  done
fi

# Info.plist via PlistBuddy
PB=/usr/libexec/PlistBuddy
PLIST="$APP/Contents/Info.plist"
$PB -c "Add :CFBundleName string LivePaper" "$PLIST"
$PB -c "Add :CFBundleDisplayName string LivePaper" "$PLIST"
$PB -c "Add :CFBundleIdentifier string com.livepaper.app" "$PLIST"
$PB -c "Add :CFBundleVersion string 3.0" "$PLIST"
$PB -c "Add :CFBundleShortVersionString string 3.0" "$PLIST"
$PB -c "Add :CFBundlePackageType string APPL" "$PLIST"
$PB -c "Add :CFBundleExecutable string LivePaper" "$PLIST"
$PB -c "Add :CFBundleInfoDictionaryVersion string 6.0" "$PLIST"
$PB -c "Add :LSMinimumSystemVersion string 16.0" "$PLIST"
$PB -c "Add :NSHighResolutionCapable bool true" "$PLIST"
$PB -c "Add :LSApplicationCategoryType string public.app-category.utilities" "$PLIST"
$PB -c "Add :CFBundleIconFile string AppIcon" "$PLIST"
$PB -c "Add :NSHumanReadableCopyright string 'Copyright © 2026 Raunak Gupta. All rights reserved.'" "$PLIST"
$PB -c "Add :CFBundleGetInfoString string 'LivePaper 3.0, Copyright © 2026 Raunak Gupta'" "$PLIST"

# Ad-hoc code sign the app (prevents "damaged" error on other Macs)
echo "Code signing..."
codesign --force --deep -s - "$APP"

echo "Installing to /Applications..."
rm -rf /Applications/LivePaper.app
cp -R "$APP" /Applications/LivePaper.app

# Remove quarantine attribute to prevent Gatekeeper "Move to Bin" dialog
xattr -cr /Applications/LivePaper.app

echo ""
echo "✅ LivePaper.app installed to /Applications"
echo "🚀 Double-click it or run: open /Applications/LivePaper.app"
