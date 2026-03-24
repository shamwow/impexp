#!/usr/bin/env bash
# homebrew.sh — Export/import Homebrew packages via Brewfile

export_homebrew() {
    local dest="$1/homebrew"
    mkdir -p "$dest"

    if ! command -v brew &>/dev/null; then
        log_warn "Homebrew not installed — skipping"
        return 1
    fi

    if brew bundle dump --file="$dest/Brewfile" --force 2>/dev/null; then
        local taps brews casks
        taps="$(grep -c '^tap ' "$dest/Brewfile" 2>/dev/null || echo 0)"
        brews="$(grep -c '^brew ' "$dest/Brewfile" 2>/dev/null || echo 0)"
        casks="$(grep -c '^cask ' "$dest/Brewfile" 2>/dev/null || echo 0)"
        log_success "Exported Brewfile: $taps taps, $brews formulae, $casks casks"
    else
        log_error "brew bundle dump failed"
        return 1
    fi

    return 0
}

import_homebrew() {
    local src="$1/homebrew"
    if [[ ! -f "$src/Brewfile" ]]; then
        log_warn "No Brewfile in snapshot"
        return 1
    fi

    if ! command -v brew &>/dev/null; then
        log_warn "Homebrew not installed"
        if ask_yes_no "Install Homebrew?" "y"; then
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            log_info "Skipping Homebrew import"
            return 1
        fi
    fi

    local count
    count="$(wc -l < "$src/Brewfile" | tr -d ' ')"
    log_info "Brewfile has $count entries — this may take a while"

    if ask_yes_no "Install Homebrew packages from Brewfile?" "y"; then
        # --no-upgrade: don't upgrade already-installed packages
        # HOMEBREW_CASK_OPTS: skip casks where the app already exists
        HOMEBREW_CASK_OPTS="--no-quarantine" brew bundle --file="$src/Brewfile" --no-upgrade || true
        log_success "Homebrew packages installed"
    fi

    return 0
}
