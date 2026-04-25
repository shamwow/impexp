#!/usr/bin/env bash
# cursor.sh — Export/import Cursor (editor) User settings and extensions
# Includes settings.json, keybindings.json (custom shortcuts, e.g. cursorMove line jumps), snippets/, extensions list.

CURSOR_USER_DIR="$HOME/Library/Application Support/Cursor/User"

export_cursor() {
    local dest="$1/cursor"
    mkdir -p "$dest"

    if [[ ! -d "$CURSOR_USER_DIR" ]]; then
        log_warn "Cursor user directory not found: $CURSOR_USER_DIR"
        return 1
    fi

    # Copy config files
    for file in settings.json keybindings.json; do
        if [[ -f "$CURSOR_USER_DIR/$file" ]]; then
            cp "$CURSOR_USER_DIR/$file" "$dest/$file"
            log_success "Exported $file"
        fi
    done

    # Copy snippets directory
    if [[ -d "$CURSOR_USER_DIR/snippets" ]]; then
        cp -r "$CURSOR_USER_DIR/snippets" "$dest/snippets"
        log_success "Exported snippets/"
    fi

    # Export extensions list
    if command -v cursor &>/dev/null; then
        cursor --list-extensions > "$dest/extensions.txt"
        local count
        count="$(wc -l < "$dest/extensions.txt" | tr -d ' ')"
        log_success "Exported $count extensions to extensions.txt"
    else
        log_warn "'cursor' CLI not found — skipping extensions list"
    fi

    return 0
}

import_cursor() {
    local src="$1/cursor"
    if [[ ! -d "$src" ]]; then
        log_warn "No Cursor data in snapshot"
        return 1
    fi

    mkdir -p "$CURSOR_USER_DIR"

    # Restore config files
    for file in settings.json keybindings.json; do
        if [[ -f "$src/$file" ]]; then
            safe_copy "$src/$file" "$CURSOR_USER_DIR/$file"
            log_success "Imported $file"
        fi
    done

    # Restore snippets
    if [[ -d "$src/snippets" ]]; then
        if [[ -d "$CURSOR_USER_DIR/snippets" ]]; then
            backup_file "$CURSOR_USER_DIR/snippets"
        fi
        cp -r "$src/snippets" "$CURSOR_USER_DIR/snippets"
        log_success "Imported snippets/"
    fi

    # Install extensions
    if [[ -f "$src/extensions.txt" ]]; then
        if ! command -v cursor &>/dev/null; then
            log_warn "'cursor' CLI not found — cannot install extensions"
            log_info "Install Cursor and its shell command, then run: while read ext; do cursor --install-extension \"\$ext\"; done < $src/extensions.txt"
            return 0
        fi

        local count
        count="$(wc -l < "$src/extensions.txt" | tr -d ' ')"
        if ask_yes_no "Install $count Cursor extensions?" "y"; then
            while IFS= read -r ext; do
                [[ -z "$ext" ]] && continue
                if cursor --install-extension "$ext" --force &>/dev/null; then
                    log_success "Installed extension: $ext"
                else
                    log_warn "Failed to install: $ext"
                fi
            done < "$src/extensions.txt"
        fi
    fi

    return 0
}
