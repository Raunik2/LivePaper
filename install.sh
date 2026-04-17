#!/bin/bash
# LivePaper Installer
# Run: curl -sL https://raw.githubusercontent.com/Raunik2/LivePaper/main/install.sh | bash
# Or:  ./install.sh  (from the repo directory)
set -e

# ── Progress Bar Helper ───────────────────────────────────────
TOTAL_STEPS=7
CURRENT_STEP=0
BAR_WIDTH=30

show_progress() {
    CURRENT_STEP=$1
    local label="$2"
    local filled=$((CURRENT_STEP * BAR_WIDTH / TOTAL_STEPS))
    local empty=$((BAR_WIDTH - filled))
    local pct=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    printf "\r   [%s] %3d%%  %s\033[K" "$bar" "$pct" "$label"
}

finish_step() {
    printf "\r   [" 
    local filled=$((CURRENT_STEP * BAR_WIDTH / TOTAL_STEPS))
    local empty=$((BAR_WIDTH - filled))
    for ((i=0; i<filled; i++)); do printf "█"; done
    for ((i=0; i<empty; i++)); do printf "░"; done
    printf "] %3d%%  ✓ %s\033[K\n" "$((CURRENT_STEP * 100 / TOTAL_STEPS))" "$1"
}

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
show_progress 0 "Checking Xcode CLI Tools..."
if ! command -v swiftc &>/dev/null; then
    echo ""
    echo "   📦 Installing Xcode Command Line Tools..."
    xcode-select --install 2>/dev/null || true
    echo ""
    echo "   ⏳ Please complete the Xcode CLT installation dialog,"
    echo "      then re-run this script."
    exit 1
fi
show_progress 1 "Xcode CLI Tools"
finish_step "Xcode CLI Tools"

# ── Step 2: Homebrew ──────────────────────────────────────────
show_progress 1 "Checking Homebrew..."
if ! command -v brew &>/dev/null; then
    echo ""
    echo "   📦 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [ -f /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -f /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi
show_progress 2 "Homebrew"
finish_step "Homebrew"

# ── Step 3: Install tools via Homebrew ────────────────────────
show_progress 2 "Checking dependencies..."

BREW_INSTALL=""
if ! command -v git-lfs &>/dev/null; then BREW_INSTALL="$BREW_INSTALL git-lfs"; fi
if ! command -v yt-dlp &>/dev/null; then BREW_INSTALL="$BREW_INSTALL yt-dlp"; fi
if ! command -v ffmpeg &>/dev/null; then BREW_INSTALL="$BREW_INSTALL ffmpeg"; fi

if [ -n "$BREW_INSTALL" ]; then
    show_progress 2 "Installing:$BREW_INSTALL..."
    echo ""
    brew install $BREW_INSTALL
fi

git lfs install --skip-smudge &>/dev/null || true

show_progress 3 "Dependencies"
finish_step "git-lfs, yt-dlp, ffmpeg"

# ── Step 4: Download source ──────────────────────────────────
show_progress 3 "Downloading source..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" 2>/dev/null)" && pwd 2>/dev/null || pwd)"
if [ -d "$SCRIPT_DIR/Sources" ]; then
    SRC_DIR="$SCRIPT_DIR"
else
    TMP_DIR=$(mktemp -d)
    trap "rm -rf $TMP_DIR" EXIT
    git clone --depth 1 https://github.com/Raunik2/LivePaper.git "$TMP_DIR/LivePaper" 2>/dev/null
    show_progress 3 "Downloading sample videos..."
    (cd "$TMP_DIR/LivePaper" && git lfs pull 2>/dev/null) || true
    SRC_DIR="$TMP_DIR/LivePaper"
fi
show_progress 4 "Source ready"
finish_step "Source downloaded"

# ── Step 5: Build ─────────────────────────────────────────────
show_progress 4 "Building LivePaper... (30-60 seconds)"
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
show_progress 5 "Build complete"
finish_step "Build complete"

# ── Step 6: Bundle resources ──────────────────────────────────
show_progress 5 "Bundling resources..."

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
  show_progress 6 "Resources bundled"
  finish_step "Bundled + $VIDEOS_COPIED sample wallpaper(s)"
else
  show_progress 6 "Resources bundled"
  finish_step "Resources bundled"
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
show_progress 6 "Signing & installing..."
codesign --force --deep -s - "$APP" 2>/dev/null
rm -rf /Applications/LivePaper.app
cp -R "$APP" /Applications/LivePaper.app
xattr -cr /Applications/LivePaper.app 2>/dev/null
show_progress 7 "Installed!"
finish_step "Installed to /Applications"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║     ✅ LivePaper installed!          ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "🚀 Launching LivePaper..."
open /Applications/LivePaper.app
echo ""
echo "Done! Check your menu bar for the LivePaper icon."
