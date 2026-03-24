#!/usr/bin/env bash
# vscode.sh — Export/import VSCode settings and extensions

VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"

export_vscode() {
    local dest="$1/vscode"
    mkdir -p "$dest"

    if [[ ! -d "$VSCODE_USER_DIR" ]]; then
        log_warn "VSCode user directory not found: $VSCODE_USER_DIR"
        return 1
    fi

    # Copy config files
    for file in settings.json keybindings.json; do
        if [[ -f "$VSCODE_USER_DIR/$file" ]]; then
            cp "$VSCODE_USER_DIR/$file" "$dest/$file"
            log_success "Exported $file"
        fi
    done

    # Copy snippets directory
    if [[ -d "$VSCODE_USER_DIR/snippets" ]]; then
        cp -r "$VSCODE_USER_DIR/snippets" "$dest/snippets"
        log_success "Exported snippets/"
    fi

    # Export extensions list
    if command -v code &>/dev/null; then
        code --list-extensions > "$dest/extensions.txt"
        local count
        count="$(wc -l < "$dest/extensions.txt" | tr -d ' ')"
        log_success "Exported $count extensions to extensions.txt"
    else
        log_warn "'code' CLI not found — skipping extensions list"
    fi

    return 0
}

import_vscode() {
    local src="$1/vscode"
    if [[ ! -d "$src" ]]; then
        log_warn "No VSCode data in snapshot"
        return 1
    fi

    mkdir -p "$VSCODE_USER_DIR"

    # Restore config files
    for file in settings.json keybindings.json; do
        if [[ -f "$src/$file" ]]; then
            safe_copy "$src/$file" "$VSCODE_USER_DIR/$file"
            log_success "Imported $file"
        fi
    done

    # Restore snippets
    if [[ -d "$src/snippets" ]]; then
        if [[ -d "$VSCODE_USER_DIR/snippets" ]]; then
            backup_file "$VSCODE_USER_DIR/snippets"
        fi
        cp -r "$src/snippets" "$VSCODE_USER_DIR/snippets"
        log_success "Imported snippets/"
    fi

    # Install extensions
    if [[ -f "$src/extensions.txt" ]]; then
        if ! command -v code &>/dev/null; then
            log_warn "'code' CLI not found — cannot install extensions"
            log_info "Install VSCode, then run: while read ext; do code --install-extension \"\$ext\"; done < $src/extensions.txt"
            return 0
        fi

        local count
        count="$(wc -l < "$src/extensions.txt" | tr -d ' ')"
        if ask_yes_no "Install $count VSCode extensions?" "y"; then
            while IFS= read -r ext; do
                [[ -z "$ext" ]] && continue
                if code --install-extension "$ext" --force &>/dev/null; then
                    log_success "Installed extension: $ext"
                else
                    log_warn "Failed to install: $ext"
                fi
            done < "$src/extensions.txt"
        fi
    fi

    return 0
}
