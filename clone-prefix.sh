#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
BASEPREFIX="$HOME/Games/BasePrefix"
INTERNAL_PREFIX_ROOT="$HOME/Games"

# --- Cleanup Function ---
cleanup() {
    if [[ -n "${WINEDEBUG:-}" ]]; then
        unset WINEDEBUG
    fi
}
trap cleanup EXIT

# --- Check required commands ---
required_commands=(rsync wine kdialog find df basename awk mkdir rm)
for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "WARNING: Required command '$cmd' not found. Using terminal fallback." >&2
        USE_GUI=false
    fi
done
USE_GUI=${USE_GUI:-true}

# Check for qdbus version (qdbus6 for Plasma 6)
QDBUS=""
if command -v qdbus6 >/dev/null 2>&1; then
    QDBUS="qdbus6"
elif command -v qdbus >/dev/null 2>&1; then
    QDBUS="qdbus"
else
    echo "WARNING: qdbus or qdbus6 not found. Using terminal mode." >&2
    USE_GUI=false
fi

# --- GUI Functions ---
show_error() {
    if $USE_GUI; then
        kdialog --error "$1"
    else
        echo "❌ $1" >&2
    fi
}

show_msg() {
    if $USE_GUI; then
        kdialog --msgbox "$1"
    else
        echo "ℹ️ $1"
    fi
}

show_progress_start() {
    if $USE_GUI; then
        dbusRef=$(kdialog --progressbar "$1" 0)
        $QDBUS $dbusRef showCancelButton false
        echo "$dbusRef"
    else
        echo "⏳ $1"
    fi
}

show_progress_end() {
    local dbusRef="$1"
    local message="$2"

    if $USE_GUI; then
        $QDBUS $dbusRef close
        show_msg "$message"
    else
        echo "✅ $message"
    fi
}

# --- Detect external drives ---
declare -A EXTERNAL_DRIVES
while IFS= read -r -d '' mount; do
    label=$(basename "$mount")
    size=$(df -h "$mount" | awk 'NR==2{print $2}')
    EXTERNAL_DRIVES["$mount"]="$label ($size)"
done < <(find "/run/media/$USER" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

# --- Build location menu ---
menu_items=("internal" "Internal: $INTERNAL_PREFIX_ROOT")
for mount in "${!EXTERNAL_DRIVES[@]}"; do
    menu_items+=("$mount" "External: ${EXTERNAL_DRIVES[$mount]} at $mount")
done

# --- Prompt for prefix location ---
if $USE_GUI; then
    choice=$(kdialog --title "Prefix Location" \
             --menu "Select installation location:" \
             "${menu_items[@]}" 2>/dev/null)
else
    # Terminal fallback for location selection
    echo "📦 Where do you want to clone the new prefix?"
    echo "1) Internal drive ($INTERNAL_PREFIX_ROOT)"
    i=2
    declare -A EXTERNAL_OPTIONS
    for mount in "${!EXTERNAL_DRIVES[@]}"; do
        echo "$i) External: ${EXTERNAL_DRIVES[$mount]} at $mount"
        EXTERNAL_OPTIONS["$i"]="$mount"
        ((i++))
    done
    read -rp "Choose option [1-$i]: " CHOICE
    if [[ "$CHOICE" == "1" ]]; then
        choice="internal"
    else
        choice="${EXTERNAL_OPTIONS[$CHOICE]}"
    fi
fi

[[ -z "$choice" ]] && { echo "❌ Location selection canceled"; exit 1; }

if [[ "$choice" == "internal" ]]; then
    TARGET_ROOT="$INTERNAL_PREFIX_ROOT"
else
    TARGET_ROOT="${choice}/Games"
    mkdir -p "$TARGET_ROOT" || {
        show_error "Failed to create directory: $TARGET_ROOT"
        exit 1
    }
fi

# --- Validate Base Prefix ---
[[ ! -d "$BASEPREFIX" ]] && { show_error "Base prefix not found at: $BASEPREFIX"; exit 1; }

# --- Prompt for New Prefix Name ---
while :; do
    if $USE_GUI; then
        PREFIXNAME=$(kdialog --title "New Prefix" \
                   --inputbox "Enter prefix name (alphanumeric, '.', '-', '_' allowed):" \
                   "NewPrefix" 2>/dev/null)
    else
        read -rp "Enter new prefix name: " PREFIXNAME
    fi

    [[ -z "$PREFIXNAME" ]] && { show_error "Prefix name cannot be empty!"; continue; }
    [[ "$PREFIXNAME" =~ ^[a-zA-Z0-9._-]+$ ]] && break
    show_error "Invalid characters in prefix name!"
done

DEST="$TARGET_ROOT/$PREFIXNAME"

# --- Overwrite Check ---
if [[ -e "$DEST" ]]; then
    if $USE_GUI; then
        kdialog --warningyesno "Prefix '$DEST' exists! Overwrite?" 2>/dev/null
        [[ $? -ne 0 ]] && { echo "❌ Aborted."; exit 1; }
    else
        read -rp "Prefix '$DEST' exists! Overwrite? [y/N]: " ans
        [[ ! "$ans" =~ ^[Yy]$ ]] && { echo "❌ Aborted."; exit 1; }
    fi
    rm -rf "$DEST"
fi

# --- Clone Prefix ---
progress_ref=$(show_progress_start "Cloning wine prefix...")

echo "🛠️ Cloning base prefix to $DEST"
mkdir -p "$DEST"
rsync -a --info=progress2 "$BASEPREFIX/" "$DEST/"

show_progress_end "$progress_ref" "\n \nPrefix cloned successfully to:\n$DEST"

# --- Game Installation ---
install_game() {
    local INSTALLER_PATH="$1"
    local installer_name=$(basename "$INSTALLER_PATH")

    progress_ref=$(show_progress_start "Running installer: $installer_name")

    echo "🚀 Launching installer: $installer_name"
    WINEDEBUG="-all" WINEPREFIX="$DEST" wine "$INSTALLER_PATH"

    show_progress_end "$progress_ref" "\n \nInstaller completed:\n$installer_name"
}

if $USE_GUI; then
    kdialog --yesno "\n\nInstall game/DLC now?" 2>/dev/null
    proceed=$?
else
    read -rp "Install game/DLC now? [y/N]: " ans
    [[ "$ans" =~ ^[Yy]$ ]] && proceed=0 || proceed=1
fi

if [[ $proceed -eq 0 ]]; then
    while :; do
        if $USE_GUI; then
            INSTALLER_PATH=$(kdialog --getopenfilename "$HOME" "*.exe *.msi" 2>/dev/null)
        else
            read -e -rp "Enter path to installer: " INSTALLER_PATH
        fi

        [[ -z "$INSTALLER_PATH" ]] && break

        if [[ ! -f "$INSTALLER_PATH" ]]; then
            show_error "Installer not found: ${INSTALLER_PATH##*/}"
            continue
        fi

        install_game "$INSTALLER_PATH"

        if $USE_GUI; then
            kdialog --yesno "\n\nInstall another component?" 2>/dev/null || break
        else
            read -rp "Install another component? [y/N]: " ans
            [[ ! "$ans" =~ ^[Yy]$ ]] && break
        fi
    done
fi

# --- Finalization ---
show_msg "\n \n🎉 Setup complete! Prefix location: $DEST"
exit 0
