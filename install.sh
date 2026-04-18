#!/bin/bash
# LivePaper Installer
# Run: curl -sL https://raw.githubusercontent.com/Raunik2/LivePaper/main/install.sh | bash
# Or:  ./install.sh  (from the repo directory)
set -e

# ── Terminal Colors & Symbols ─────────────────────────────────
BOLD="\033[1m"
DIM="\033[2m"
RESET="\033[0m"
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
MAGENTA="\033[35m"
WHITE="\033[97m"
BG_DARK="\033[48;5;236m"

TICK="${GREEN}✔${RESET}"
CROSS="${RED}✘${RESET}"
ARROW="${CYAN}▸${RESET}"
SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")

TOTAL_STEPS=7
CURRENT_STEP=0

# ── Spinner ───────────────────────────────────────────────────
spin_pid=""
start_spinner() {
    local msg="$1"
    (
        i=0
        while true; do
            printf "\r   ${CYAN}${SPINNER_FRAMES[$((i % 10))]}${RESET}  %s\033[K" "$msg"
            i=$((i + 1))
            sleep 0.08
        done
    ) &
    spin_pid=$!
    disown $spin_pid 2>/dev/null
}
stop_spinner() {
    [[ -n "$spin_pid" ]] && kill "$spin_pid" 2>/dev/null
    spin_pid=""
    printf "\r\033[K"
}

# ── Progress Bar ──────────────────────────────────────────────
show_bar() {
    CURRENT_STEP=$1
    local pct=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    local bar_w=32
    local filled=$((CURRENT_STEP * bar_w / TOTAL_STEPS))
    local empty=$((bar_w - filled))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="━"; done
    local remaining=""
    for ((i=0; i<empty; i++)); do remaining+="─"; done
    printf "   ${DIM}[${RESET}${GREEN}${bar}${RESET}${DIM}${remaining}]${RESET} ${WHITE}${pct}%%${RESET}\n"
}

step_done() {
    local step_num=$1
    local label="$2"
    printf "   ${TICK}  ${WHITE}%s${RESET}\n" "$label"
}

step_skip() {
    local label="$1"
    printf "   ${DIM}⊘  %s (already installed)${RESET}\n" "$label"
}

# ── Header ────────────────────────────────────────────────────
clear 2>/dev/null || true
echo ""
printf "   ${BOLD}${MAGENTA}╭─────────────────────────────────────╮${RESET}\n"
printf "   ${BOLD}${MAGENTA}│${RESET}  ${BOLD}${WHITE}  ◆  LivePaper Installer  ◆  ${RESET}  ${BOLD}${MAGENTA}│${RESET}\n"
printf "   ${BOLD}${MAGENTA}│${RESET}  ${DIM}    Live video wallpapers for     ${RESET}  ${BOLD}${MAGENTA}│${RESET}\n"
printf "   ${BOLD}${MAGENTA}│${RESET}  ${DIM}         macOS Tahoe             ${RESET}  ${BOLD}${MAGENTA}│${RESET}\n"
printf "   ${BOLD}${MAGENTA}╰─────────────────────────────────────╯${RESET}\n"
echo ""

# Check macOS version (require Tahoe / macOS 16+)
OS_MAJOR=$(sw_vers -productVersion | cut -d. -f1)
if [ "$OS_MAJOR" -le 15 ] 2>/dev/null; then
    printf "   ${CROSS}  ${RED}Requires macOS Tahoe (16.0+)${RESET}\n"
    printf "   ${DIM}   You are running macOS $(sw_vers -productVersion).${RESET}\n"
    exit 1
fi

printf "   ${DIM}macOS $(sw_vers -productVersion) detected${RESET}\n"
echo ""

# ── Step 1: Xcode Command Line Tools ──────────────────────────
start_spinner "Checking Xcode CLI Tools..."
if ! command -v swiftc &>/dev/null; then
    stop_spinner
    printf "   ${ARROW}  Installing Xcode Command Line Tools...\n"
    xcode-select --install 2>/dev/null || true
    echo ""
    printf "   ${YELLOW}⏳ Complete the Xcode CLT dialog, then re-run this script.${RESET}\n"
    exit 1
fi
stop_spinner
step_done 1 "Xcode CLI Tools"

# ── Step 2: Dependencies (yt-dlp, ffmpeg) ─────────────────────
LOCAL_BIN="$HOME/.livepaper/bin"
mkdir -p "$LOCAL_BIN"

NEED_YTDLP=false
NEED_FFMPEG=false
command -v yt-dlp &>/dev/null || [ -f "$LOCAL_BIN/yt-dlp" ] || NEED_YTDLP=true
command -v ffmpeg &>/dev/null || [ -f "$LOCAL_BIN/ffmpeg" ] || NEED_FFMPEG=true

if [ "$NEED_YTDLP" = true ] || [ "$NEED_FFMPEG" = true ]; then
    if command -v brew &>/dev/null; then
        # Homebrew available — use it (fast)
        BREW_PKGS=""
        [ "$NEED_YTDLP" = true ] && BREW_PKGS="$BREW_PKGS yt-dlp"
        [ "$NEED_FFMPEG" = true ] && BREW_PKGS="$BREW_PKGS ffmpeg"
        start_spinner "Installing$BREW_PKGS via Homebrew..."
        brew install $BREW_PKGS &>/dev/null
        stop_spinner
        step_done 2 "Dependencies installed via Homebrew"
    else
        # No Homebrew — download standalone binaries (much faster)
        if [ "$NEED_YTDLP" = true ]; then
            start_spinner "Downloading yt-dlp..."
            curl -sL "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos" -o "$LOCAL_BIN/yt-dlp"
            chmod +x "$LOCAL_BIN/yt-dlp"
            stop_spinner
        fi
        if [ "$NEED_FFMPEG" = true ]; then
            start_spinner "Downloading ffmpeg..."
            curl -sL "https://evermeet.cx/ffmpeg/getrelease/zip" -o /tmp/lp_ffmpeg.zip
            unzip -qo /tmp/lp_ffmpeg.zip -d "$LOCAL_BIN/" 2>/dev/null
            rm -f /tmp/lp_ffmpeg.zip
            stop_spinner
            start_spinner "Downloading ffprobe..."
            curl -sL "https://evermeet.cx/ffmpeg/getrelease/ffprobe/zip" -o /tmp/lp_ffprobe.zip
            unzip -qo /tmp/lp_ffprobe.zip -d "$LOCAL_BIN/" 2>/dev/null
            rm -f /tmp/lp_ffprobe.zip
            stop_spinner
        fi
        step_done 2 "Dependencies installed to ~/.livepaper/bin"
    fi
else
    step_skip "Dependencies"
fi

echo ""
show_bar 2
echo ""

# ── Step 3: Download source ──────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" 2>/dev/null)" && pwd 2>/dev/null || pwd)"
if [ -d "$SCRIPT_DIR/Sources" ]; then
    SRC_DIR="$SCRIPT_DIR"
    step_skip "Source (using local)"
else
    start_spinner "Downloading source code..."
    TMP_DIR=$(mktemp -d)
    trap "rm -rf $TMP_DIR" EXIT
    git clone --depth 1 --filter=blob:none --no-checkout https://github.com/Raunik2/LivePaper.git "$TMP_DIR/LivePaper" 2>/dev/null
    (cd "$TMP_DIR/LivePaper" && git checkout HEAD -- Sources/ LICENSE Fonts/ AppIcon.icns 2>/dev/null) || true
    stop_spinner
    step_done 3 "Source downloaded"
    SRC_DIR="$TMP_DIR/LivePaper"
fi

# ── Step 4: Build ─────────────────────────────────────────────
cd "$SRC_DIR"

APP="LivePaper.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

start_spinner "Compiling LivePaper (this takes ~30s)..."
swiftc Sources/*.swift -o "$APP/Contents/MacOS/LivePaper" \
  -framework AppKit -framework AVFoundation -framework CoreMedia \
  -framework CoreGraphics -framework QuartzCore -framework CoreText \
  -framework IOKit \
  -Osize \
  -target arm64-apple-macosx15.0
stop_spinner
step_done 4 "Compiled successfully"

echo ""
show_bar 4
echo ""

# ── Step 5: Sample Wallpapers ─────────────────────────────────
VIDEOS_DIR="$HOME/Movies/LivePaper"
mkdir -p "$VIDEOS_DIR"
SAMPLE_VIDS=("anime-red-eye.mov" "doge-samurai.mov" "samurai-warrior.mov")
VIDEOS_DOWNLOADED=0
for vid in "${SAMPLE_VIDS[@]}"; do
    if [ ! -f "$VIDEOS_DIR/$vid" ]; then
        start_spinner "Downloading $vid..."
        curl -sL "https://media.githubusercontent.com/media/Raunik2/LivePaper/main/Videos/$vid" -o "$VIDEOS_DIR/$vid" 2>/dev/null
        FSIZE=$(stat -f%z "$VIDEOS_DIR/$vid" 2>/dev/null || echo 0)
        if [ "$FSIZE" -lt 100000 ]; then rm -f "$VIDEOS_DIR/$vid"; else VIDEOS_DOWNLOADED=$((VIDEOS_DOWNLOADED + 1)); fi
        stop_spinner
    fi
done
if [ "$VIDEOS_DOWNLOADED" -gt 0 ]; then
    step_done 5 "Downloaded $VIDEOS_DOWNLOADED sample wallpaper(s)"
else
    step_skip "Sample wallpapers"
fi

# ── Step 6: Bundle resources ──────────────────────────────────
start_spinner "Bundling resources..."

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


# Info.plist
PB=/usr/libexec/PlistBuddy
PLIST="$APP/Contents/Info.plist"
if [ ! -f "$PLIST" ]; then
    cat > "$PLIST" << 'PLISTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict></dict></plist>
PLISTEOF
fi
$PB -c "Add :CFBundleName string LivePaper" "$PLIST" 2>/dev/null
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

stop_spinner
step_done 6 "Resources bundled"

# ── Step 7: Sign & Install ───────────────────────────────────
start_spinner "Code signing & installing..."
codesign --force --deep -s - "$APP" 2>/dev/null
rm -rf /Applications/LivePaper.app
cp -R "$APP" /Applications/LivePaper.app
xattr -cr /Applications/LivePaper.app 2>/dev/null
stop_spinner
step_done 7 "Installed to /Applications"

echo ""
show_bar 7
echo ""

# ── Done ──────────────────────────────────────────────────────
printf "   ${BOLD}${GREEN}╭─────────────────────────────────────╮${RESET}\n"
printf "   ${BOLD}${GREEN}│${RESET}                                     ${BOLD}${GREEN}│${RESET}\n"
printf "   ${BOLD}${GREEN}│${RESET}   ${BOLD}${WHITE}✨ LivePaper installed!${RESET}            ${BOLD}${GREEN}│${RESET}\n"
printf "   ${BOLD}${GREEN}│${RESET}                                     ${BOLD}${GREEN}│${RESET}\n"
printf "   ${BOLD}${GREEN}│${RESET}   ${DIM}Launching now...${RESET}                  ${BOLD}${GREEN}│${RESET}\n"
printf "   ${BOLD}${GREEN}│${RESET}                                     ${BOLD}${GREEN}│${RESET}\n"
printf "   ${BOLD}${GREEN}╰─────────────────────────────────────╯${RESET}\n"
echo ""

open /Applications/LivePaper.app

echo ""
printf "   ${DIM}⣤⡶⢶⣦⡀${RESET}\n"
printf "   ${DIM}⠀⠀⠀⣴⡿⠟⠷⠆⣠⠋⠀⠀⠀⢸⣿${RESET}\n"
printf "   ${DIM}⠀⠀⠀⣿⡄⠀⠀⠀⠈⠀⠀⠀⠀⣾⡿${RESET}\n"
printf "   ${DIM}⠀⠀⠀⠹⣿⣦⡀⠀⠀⠀⠀⢀⣾⣿${RESET}\n"
printf "   ${DIM}⠀⠀⠀⠀⠈⠻⣿⣷⣦⣀⣠⣾⡿${RESET}\n"
printf "   ${DIM}⠀⠀⠀⠀⠀⠀⠀⠉⠻⢿⡿⠟${RESET}\n"
printf "   ${DIM}⠀⠀⠀⠀⠀⠀⠀⠀⠀⡟⠀⠀⠀⢠⠏⡆⠀⠀⠀⠀⠀⢀⣀⣤⣤⣤⣀⡀${RESET}\n"
printf "   ${DIM}⠀⠀⠀⠀⠀⡟⢦⡀⠇⠀⠀⣀⠞⠀⠀⠘⡀⢀⡠⠚⣉⠤⠂⠀⠀⠀⠈⠙⢦⡀${RESET}\n"
printf "   ${DIM}⠀⠀⠀⠀⠀⡇⠀⠉⠒⠊⠁⠀⠀⠀⠀⠀⠘⢧⠔⣉⠤⠒⠒⠉⠉⠀⠀⠀⠀⠹⣆${RESET}\n"
printf "   ${DIM}⠀⠀⠀⠀⠀⢰⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢻⠀⠀⣤⠶⠶⢶⡄⠀⠀⠀⠀⢹⡆${RESET}\n"
printf "   ${DIM}⠀⣀⠤⠒⠒⢺⠒⠀⠀⠀⠀⠀⠀⠀⠀⠤⠊⠀⢸⠀⡿⠀⡀⠀⣀⡟⠀⠀⠀⠀⢸⡇${RESET}\n"
printf "   ${DIM}⠈⠀⠀⣠⠴⠚⢯⡀⠐⠒⠚⠉⠀⢶⠂⠀⣀⠜⠀⢿⡀⠉⠚⠉⠀⠀⠀⠀⣠⠟${RESET}\n"
printf "   ${DIM}⠀⠠⠊⠀⠀⠀⠀⠙⠂⣴⠒⠒⣲⢔⠉⠉⣹⣞⣉⣈⠿⢦⣀⣀⣀⣠⡴⠟${RESET}\n"
echo ""
printf "   ${BOLD}${MAGENTA}Made with ♥ by \033]8;;https://linkedin.com/in/raunak5525/\033\\\\${BOLD}${CYAN}Raunak Gupta\033]8;;\033\\\\${RESET}\n"
echo ""
