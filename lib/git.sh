#!/usr/bin/env bash
# git.sh — Export/import git config

export_git() {
    local dest="$1/git"
    mkdir -p "$dest"

    local found=0
    for name in gitconfig gitignore_global; do
        local src="$HOME/.$name"
        if [[ -f "$src" ]]; then
            cp "$src" "$dest/$name"
            log_success "Exported $src"
            ((found++))
        fi
    done

    if [[ $found -eq 0 ]]; then
        log_warn "No git config files found"
        return 1
    fi
    return 0
}

import_git() {
    local src="$1/git"
    if [[ ! -d "$src" ]]; then
        log_warn "No git data in snapshot"
        return 1
    fi

    for name in gitconfig gitignore_global; do
        if [[ -f "$src/$name" ]]; then
            safe_copy "$src/$name" "$HOME/.$name"
            log_success "Imported ~/.$name"
        fi
    done

    log_warn "Review ~/.gitconfig — email and signing key may need updating for this machine"
    return 0
}
