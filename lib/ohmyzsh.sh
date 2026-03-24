#!/usr/bin/env bash
# ohmyzsh.sh — Export/import oh-my-zsh custom plugins, themes, and config

OMZ_DIR="${ZSH:-$HOME/.oh-my-zsh}"
OMZ_CUSTOM="${ZSH_CUSTOM:-$OMZ_DIR/custom}"

export_ohmyzsh() {
    local dest="$1/ohmyzsh"
    mkdir -p "$dest"

    if [[ ! -d "$OMZ_DIR" ]]; then
        log_warn "oh-my-zsh not found at $OMZ_DIR — skipping"
        return 1
    fi

    # Export custom plugins (skip the example plugin)
    if [[ -d "$OMZ_CUSTOM/plugins" ]]; then
        local plugin_count=0
        for plugin_dir in "$OMZ_CUSTOM/plugins"/*/; do
            [[ ! -d "$plugin_dir" ]] && continue
            local name
            name="$(basename "$plugin_dir")"
            [[ "$name" == "example" ]] && continue
            mkdir -p "$dest/plugins"
            cp -r "$plugin_dir" "$dest/plugins/$name"
            ((plugin_count++))
        done
        if [[ $plugin_count -gt 0 ]]; then
            log_success "Exported $plugin_count custom plugins"
        fi
    fi

    # Export custom themes (skip the example theme)
    if [[ -d "$OMZ_CUSTOM/themes" ]]; then
        local theme_count=0
        for theme_file in "$OMZ_CUSTOM/themes"/*; do
            [[ ! -f "$theme_file" ]] && continue
            local name
            name="$(basename "$theme_file")"
            [[ "$name" == "example.zsh-theme" ]] && continue
            mkdir -p "$dest/themes"
            cp "$theme_file" "$dest/themes/$name"
            ((theme_count++))
        done
        if [[ $theme_count -gt 0 ]]; then
            log_success "Exported $theme_count custom themes"
        fi
    fi

    # Export custom .zsh files in the custom root (auto-loaded by omz)
    local custom_count=0
    for zsh_file in "$OMZ_CUSTOM"/*.zsh; do
        [[ ! -f "$zsh_file" ]] && continue
        local name
        name="$(basename "$zsh_file")"
        [[ "$name" == "example.zsh" ]] && continue
        cp "$zsh_file" "$dest/$name"
        ((custom_count++))
    done
    if [[ $custom_count -gt 0 ]]; then
        log_success "Exported $custom_count custom .zsh files"
    fi

    # Record which plugins/theme are enabled in .zshrc for reference
    if [[ -f "$HOME/.zshrc" ]]; then
        grep -E '^plugins=|^ZSH_THEME=' "$HOME/.zshrc" > "$dest/zshrc-omz-settings.txt" 2>/dev/null || true
        log_success "Exported oh-my-zsh settings from .zshrc"
    fi

    return 0
}

import_ohmyzsh() {
    local src="$1/ohmyzsh"
    if [[ ! -d "$src" ]]; then
        log_warn "No oh-my-zsh data in snapshot"
        return 1
    fi

    # Install oh-my-zsh if missing
    if [[ ! -d "$OMZ_DIR" ]]; then
        log_warn "oh-my-zsh not installed"
        if ask_yes_no "Install oh-my-zsh?" "y"; then
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        else
            log_info "Skipping oh-my-zsh import"
            return 1
        fi
    fi

    # Import custom plugins
    if [[ -d "$src/plugins" ]]; then
        for plugin_dir in "$src/plugins"/*/; do
            [[ ! -d "$plugin_dir" ]] && continue
            local name
            name="$(basename "$plugin_dir")"
            local target="$OMZ_CUSTOM/plugins/$name"
            if [[ -d "$target" ]]; then
                backup_file "$target"
            fi
            mkdir -p "$OMZ_CUSTOM/plugins"
            cp -r "$plugin_dir" "$target"
            log_success "Imported plugin: $name"
        done
    fi

    # Import custom themes
    if [[ -d "$src/themes" ]]; then
        mkdir -p "$OMZ_CUSTOM/themes"
        for theme_file in "$src/themes"/*; do
            [[ ! -f "$theme_file" ]] && continue
            local name
            name="$(basename "$theme_file")"
            safe_copy "$theme_file" "$OMZ_CUSTOM/themes/$name"
            log_success "Imported theme: $name"
        done
    fi

    # Import custom .zsh files
    for zsh_file in "$src"/*.zsh; do
        [[ ! -f "$zsh_file" ]] && continue
        local name
        name="$(basename "$zsh_file")"
        safe_copy "$zsh_file" "$OMZ_CUSTOM/$name"
        log_success "Imported custom file: $name"
    done

    # Print omz settings for reference
    if [[ -f "$src/zshrc-omz-settings.txt" ]]; then
        echo
        log_info "oh-my-zsh settings from source machine:"
        cat "$src/zshrc-omz-settings.txt"
        echo
        log_info "Update your ~/.zshrc to match if needed"
    fi

    return 0
}
