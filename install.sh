#!/bin/bash
# LivePaper Installer
# Run: curl -sL https://raw.githubusercontent.com/Raunik2/LivePaper/main/install.sh | bash
# Or:  ./install.sh  (from the repo directory)
set -e

echo ""
echo "╔══════════════════════════════════════╗"
echo "║        LivePaper  Installer          ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Check macOS version (require Tahoe / macOS 16+)
OS_MAJOR=$(sw_vers -productVersion | cut -d. -f1)
if [ "$OS_MAJOR" -le 15 ] 2>/dev/null; then
    echo "❌ LivePaper requires macOS Tahoe (16.0+)."
    echo "   You are running macOS $(sw_vers -productVersion)."
    exit 1
fi

# Check for Xcode Command Line Tools (needed for swiftc)
if ! command -v swiftc &>/dev/null; then
    echo "📦 Installing Xcode Command Line Tools (required to build)..."
    xcode-select --install 2>/dev/null || true
    echo ""
    echo "⏳ Please complete the Xcode CLT installation dialog,"
    echo "   then re-run this script."
    exit 1
fi

# Determine source directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" 2>/dev/null)" && pwd 2>/dev/null || pwd)"
if [ -d "$SCRIPT_DIR/Sources" ]; then
    SRC_DIR="$SCRIPT_DIR"
else
    # Running via curl — clone to tmp
    echo "📥 Downloading LivePaper source..."
    TMP_DIR=$(mktemp -d)
    trap "rm -rf $TMP_DIR" EXIT
    if command -v git &>/dev/null; then
        git clone --depth 1 https://github.com/Raunik2/LivePaper.git "$TMP_DIR/LivePaper" 2>/dev/null
    else
        curl -sL https://github.com/Raunik2/LivePaper/archive/main.tar.gz | tar xz -C "$TMP_DIR"
        mv "$TMP_DIR"/LivePaper-* "$TMP_DIR/LivePaper"
    fi
    SRC_DIR="$TMP_DIR/LivePaper"
fi

echo "🔨 Building LivePaper..."
cd "$SRC_DIR"

APP="LivePaper.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

swiftc Sources/*.swift -o "$APP/Contents/MacOS/LivePaper" \
  -framework AppKit -framework AVFoundation -framework CoreMedia \
  -framework CoreGraphics -framework QuartzCore -framework CoreText \
  -framework IOKit \
  -target arm64-apple-macosx15.0 2>/dev/null

# Bundle font
if [ -f "Fonts/Anurati-Regular.otf" ]; then
  cp "Fonts/Anurati-Regular.otf" "$APP/Contents/Resources/"
elif [ -f "$HOME/Library/Fonts/Anurati-Regular.otf" ]; then
  cp "$HOME/Library/Fonts/Anurati-Regular.otf" "$APP/Contents/Resources/"
fi

# Bundle app icon
[ -f "AppIcon.icns" ] && cp AppIcon.icns "$APP/Contents/Resources/"

# Bundle license
[ -f "LICENSE" ] && cp LICENSE "$APP/Contents/Resources/"

# Install bundled sample videos to ~/Movies/LivePaper/
VIDEOS_DIR="$HOME/Movies/LivePaper"
mkdir -p "$VIDEOS_DIR"
if [ -d "Videos" ]; then
  for v in Videos/*.mov Videos/*.mp4 Videos/*.m4v; do
    [ -f "$v" ] && [ ! -f "$VIDEOS_DIR/$(basename "$v")" ] && cp "$v" "$VIDEOS_DIR/"
  done
fi

# Info.plist
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

# Code sign
codesign --force --deep -s - "$APP" 2>/dev/null

# Install
echo "📂 Installing to /Applications..."
rm -rf /Applications/LivePaper.app
cp -R "$APP" /Applications/LivePaper.app
xattr -cr /Applications/LivePaper.app 2>/dev/null

echo ""
echo "✅ LivePaper installed successfully!"
echo ""
echo "🚀 Launching LivePaper..."
open /Applications/LivePaper.app

echo ""
echo "Done! LivePaper is running. Check your menu bar."
