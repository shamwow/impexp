#!/usr/bin/env bash
# shell.sh — Export/import zsh and bash configs

SHELL_FILES=(zshrc zprofile zshenv bashrc bash_profile)

export_shell() {
    local dest="$1/shell"
    mkdir -p "$dest"

    local found=0
    for name in "${SHELL_FILES[@]}"; do
        local src="$HOME/.$name"
        if [[ -f "$src" ]]; then
            cp "$src" "$dest/$name"
            log_success "Exported $src"
            ((found++))
        fi
    done

    if [[ $found -eq 0 ]]; then
        log_warn "No shell config files found"
        return 1
    fi
    return 0
}

import_shell() {
    local src="$1/shell"
    if [[ ! -d "$src" ]]; then
        log_warn "No shell data in snapshot"
        return 1
    fi

    for name in "${SHELL_FILES[@]}"; do
        if [[ -f "$src/$name" ]]; then
            safe_copy "$src/$name" "$HOME/.$name"
            log_success "Imported ~/.$name"
        fi
    done
    return 0
}
