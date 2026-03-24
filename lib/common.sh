#!/usr/bin/env bash
# common.sh — Shared utilities for impexp

# Colors (disabled if not a terminal)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' BOLD='' NC=''
fi

log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }

# Ask yes/no question. Usage: ask_yes_no "prompt" [y|n]
# Returns 0 for yes, 1 for no.
ask_yes_no() {
    local prompt="$1"
    local default="${2:-y}"
    local hint="[Y/n]"
    [[ "$default" == "n" ]] && hint="[y/N]"

    if [[ ! -t 0 ]]; then
        [[ "$default" == "y" ]] && return 0 || return 1
    fi

    while true; do
        echo -en "${BOLD}${prompt}${NC} ${hint} "
        read -r -n 1 answer
        echo
        answer="${answer:-$default}"
        case "$answer" in
            [yY]) return 0 ;;
            [nN]) return 1 ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}

# Present a numbered module checklist. Sets SELECTED_MODULES array.
# Usage: ask_modules module1 module2 ...
ask_modules() {
    local modules=("$@")
    local count=${#modules[@]}

    echo -e "\n${BOLD}Available modules:${NC}"
    for i in "${!modules[@]}"; do
        echo "  $((i + 1))) ${modules[$i]}"
    done
    echo "  a) All"
    echo

    if [[ ! -t 0 ]]; then
        SELECTED_MODULES=("${modules[@]}")
        return
    fi

    echo -en "${BOLD}Select modules (comma-separated numbers, or 'a' for all):${NC} "
    read -r selection

    if [[ "$selection" == "a" || "$selection" == "A" || -z "$selection" ]]; then
        SELECTED_MODULES=("${modules[@]}")
        return
    fi

    SELECTED_MODULES=()
    IFS=',' read -ra nums <<< "$selection"
    for num in "${nums[@]}"; do
        num="$(echo "$num" | tr -d ' ')"
        if [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= count )); then
            SELECTED_MODULES+=("${modules[$((num - 1))]}")
        else
            log_warn "Ignoring invalid selection: $num"
        fi
    done

    if [[ ${#SELECTED_MODULES[@]} -eq 0 ]]; then
        log_warn "No modules selected, defaulting to all"
        SELECTED_MODULES=("${modules[@]}")
    fi
}

# Backup a file before overwriting. Returns 0 if backup was made, 1 if source didn't exist.
backup_file() {
    local target="$1"
    if [[ -e "$target" ]]; then
        local backup="${target}.impexp-backup.$(date +%Y%m%d%H%M%S)"
        cp -a "$target" "$backup"
        log_info "Backed up $target → $backup"
        return 0
    fi
    return 0
}

# Safe copy: backup destination first, then copy. Creates parent dirs.
safe_copy() {
    local src="$1"
    local dest="$2"
    mkdir -p "$(dirname "$dest")"
    backup_file "$dest"
    cp -a "$src" "$dest"
}

# Create a .tar.gz archive from a snapshot directory.
create_export_archive() {
    local snapshot_dir="$1"
    local archive="${snapshot_dir}.tar.gz"
    tar -czf "$archive" -C "$(dirname "$snapshot_dir")" "$(basename "$snapshot_dir")"
    log_success "Archive created: $archive"
    echo "$archive"
}

# Extract an archive to a temp directory. Prints the extracted snapshot path.
extract_import_archive() {
    local archive="$1"
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    tar -xzf "$archive" -C "$tmp_dir"
    # Find the snapshot directory inside (should be the only entry)
    local snapshot
    snapshot="$(find "$tmp_dir" -mindepth 1 -maxdepth 1 -type d | head -1)"
    if [[ -z "$snapshot" ]]; then
        log_error "Could not find snapshot directory in archive"
        return 1
    fi
    echo "$snapshot"
}
