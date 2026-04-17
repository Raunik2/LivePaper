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

# ── Step 1: Xcode Command Line Tools ──────────────────────────
echo "① Checking Xcode Command Line Tools..."
if ! command -v swiftc &>/dev/null; then
    echo "   📦 Installing Xcode Command Line Tools..."
    xcode-select --install 2>/dev/null || true
    echo ""
    echo "   ⏳ Please complete the Xcode CLT installation dialog,"
    echo "      then re-run this script."
    exit 1
fi
echo "   ✓ swiftc found"

# ── Step 2: Homebrew ──────────────────────────────────────────
echo "② Checking Homebrew..."
if ! command -v brew &>/dev/null; then
    echo "   📦 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for this session
    if [ -f /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -f /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi
echo "   ✓ Homebrew ready"

# ── Step 3: Install tools via Homebrew ────────────────────────
echo "③ Checking dependencies..."

BREW_INSTALL=""
if ! command -v git-lfs &>/dev/null; then BREW_INSTALL="$BREW_INSTALL git-lfs"; fi
if ! command -v yt-dlp &>/dev/null; then BREW_INSTALL="$BREW_INSTALL yt-dlp"; fi
if ! command -v ffmpeg &>/dev/null; then BREW_INSTALL="$BREW_INSTALL ffmpeg"; fi

if [ -n "$BREW_INSTALL" ]; then
    echo "   📦 Installing:$BREW_INSTALL"
    brew install $BREW_INSTALL
fi

# Initialize git-lfs globally (idempotent)
git lfs install --skip-smudge &>/dev/null || true

echo "   ✓ git-lfs, yt-dlp, ffmpeg ready"

# ── Step 4: Download source ──────────────────────────────────
echo "④ Downloading LivePaper source..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" 2>/dev/null)" && pwd 2>/dev/null || pwd)"
if [ -d "$SCRIPT_DIR/Sources" ]; then
    SRC_DIR="$SCRIPT_DIR"
    echo "   ✓ Using local source"
else
    TMP_DIR=$(mktemp -d)
    trap "rm -rf $TMP_DIR" EXIT
    git clone --depth 1 https://github.com/Raunik2/LivePaper.git "$TMP_DIR/LivePaper" 2>/dev/null
    echo "   📥 Downloading sample videos..."
    (cd "$TMP_DIR/LivePaper" && git lfs pull 2>/dev/null) || true
    SRC_DIR="$TMP_DIR/LivePaper"
    echo "   ✓ Source downloaded"
fi

# ── Step 5: Build ─────────────────────────────────────────────
echo "⑤ Building LivePaper... (this may take 30-60 seconds)"
cd "$SRC_DIR"

APP="LivePaper.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

swiftc Sources/*.swift -o "$APP/Contents/MacOS/LivePaper" \
  -framework AppKit -framework AVFoundation -framework CoreMedia \
  -framework CoreGraphics -framework QuartzCore -framework CoreText \
  -framework IOKit \
  -target arm64-apple-macosx15.0
echo "   ✓ Build complete"

# ── Step 6: Bundle resources ──────────────────────────────────
echo "⑥ Bundling resources..."

# Font
if [ -f "Fonts/Anurati-Regular.otf" ]; then
  cp "Fonts/Anurati-Regular.otf" "$APP/Contents/Resources/"
elif [ -f "$HOME/Library/Fonts/Anurati-Regular.otf" ]; then
  cp "$HOME/Library/Fonts/Anurati-Regular.otf" "$APP/Contents/Resources/"
fi

# App icon
[ -f "AppIcon.icns" ] && cp AppIcon.icns "$APP/Contents/Resources/"

# License
[ -f "LICENSE" ] && cp LICENSE "$APP/Contents/Resources/"

# Sample videos — skip Git LFS pointers (<100KB)
VIDEOS_DIR="$HOME/Movies/LivePaper"
mkdir -p "$VIDEOS_DIR"
VIDEOS_COPIED=0
if [ -d "Videos" ]; then
  for v in Videos/*.mov Videos/*.mp4 Videos/*.m4v; do
    [ -f "$v" ] || continue
    FSIZE=$(stat -f%z "$v" 2>/dev/null || echo 0)
    [ "$FSIZE" -lt 100000 ] && continue
    BNAME=$(basename "$v")
    if [ ! -f "$VIDEOS_DIR/$BNAME" ]; then
      cp "$v" "$VIDEOS_DIR/"
      VIDEOS_COPIED=$((VIDEOS_COPIED + 1))
    fi
  done
fi
if [ "$VIDEOS_COPIED" -gt 0 ]; then
  echo "   ✓ Installed $VIDEOS_COPIED sample wallpaper(s) to ~/Movies/LivePaper/"
else
  echo "   ✓ Resources bundled"
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

# ── Step 7: Sign & Install ───────────────────────────────────
echo "⑦ Installing..."
codesign --force --deep -s - "$APP" 2>/dev/null
rm -rf /Applications/LivePaper.app
cp -R "$APP" /Applications/LivePaper.app
xattr -cr /Applications/LivePaper.app 2>/dev/null

echo ""
echo "╔══════════════════════════════════════╗"
echo "║     ✅ LivePaper installed!          ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "🚀 Launching LivePaper..."
open /Applications/LivePaper.app
echo ""
echo "Done! Check your menu bar for the LivePaper icon."
