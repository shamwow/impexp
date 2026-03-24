#!/usr/bin/env bash
# iterm.sh — Export/import iTerm2 preferences and profiles

ITERM_PLIST="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
ITERM_SUPPORT="$HOME/Library/Application Support/iTerm2"

export_iterm() {
    local dest="$1/iterm"
    mkdir -p "$dest"

    local found=0

    # Export iTerm2 preferences plist
    if [[ -f "$ITERM_PLIST" ]]; then
        # Convert binary plist to XML for portability
        plutil -convert xml1 -o "$dest/com.googlecode.iterm2.plist" "$ITERM_PLIST" 2>/dev/null \
            || cp "$ITERM_PLIST" "$dest/com.googlecode.iterm2.plist"
        log_success "Exported iTerm2 preferences"
        ((found++))
    fi

    # Export DynamicProfiles
    if [[ -d "$ITERM_SUPPORT/DynamicProfiles" ]] && [[ "$(ls -A "$ITERM_SUPPORT/DynamicProfiles" 2>/dev/null)" ]]; then
        cp -r "$ITERM_SUPPORT/DynamicProfiles" "$dest/DynamicProfiles"
        log_success "Exported iTerm2 DynamicProfiles"
        ((found++))
    fi

    # Export scripts
    if [[ -d "$ITERM_SUPPORT/Scripts" ]] && [[ "$(ls -A "$ITERM_SUPPORT/Scripts" 2>/dev/null)" ]]; then
        cp -r "$ITERM_SUPPORT/Scripts" "$dest/Scripts"
        log_success "Exported iTerm2 Scripts"
        ((found++))
    fi

    if [[ $found -eq 0 ]]; then
        log_warn "No iTerm2 configuration found"
        return 1
    fi
    return 0
}

import_iterm() {
    local src="$1/iterm"
    if [[ ! -d "$src" ]]; then
        log_warn "No iTerm2 data in snapshot"
        return 1
    fi

    # Import preferences
    if [[ -f "$src/com.googlecode.iterm2.plist" ]]; then
        backup_file "$ITERM_PLIST"
        cp "$src/com.googlecode.iterm2.plist" "$ITERM_PLIST"
        # Tell macOS to reload the plist
        defaults read com.googlecode.iterm2 &>/dev/null || true
        log_success "Imported iTerm2 preferences"
        log_info "Restart iTerm2 for changes to take effect"
    fi

    # Import DynamicProfiles
    if [[ -d "$src/DynamicProfiles" ]]; then
        mkdir -p "$ITERM_SUPPORT/DynamicProfiles"
        if [[ -d "$ITERM_SUPPORT/DynamicProfiles" ]] && [[ "$(ls -A "$ITERM_SUPPORT/DynamicProfiles" 2>/dev/null)" ]]; then
            backup_file "$ITERM_SUPPORT/DynamicProfiles"
        fi
        cp -r "$src/DynamicProfiles/"* "$ITERM_SUPPORT/DynamicProfiles/" 2>/dev/null || true
        log_success "Imported iTerm2 DynamicProfiles"
    fi

    # Import scripts
    if [[ -d "$src/Scripts" ]]; then
        mkdir -p "$ITERM_SUPPORT/Scripts"
        cp -r "$src/Scripts/"* "$ITERM_SUPPORT/Scripts/" 2>/dev/null || true
        log_success "Imported iTerm2 Scripts"
    fi

    return 0
}
