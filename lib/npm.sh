#!/usr/bin/env bash
# npm.sh — Export/import global npm packages and nvm node versions

_source_nvm() {
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    if [[ -s "$NVM_DIR/nvm.sh" ]]; then
        set +eu
        source "$NVM_DIR/nvm.sh" 2>/dev/null
        set -eu
        return 0
    fi
    return 1
}

export_npm() {
    local dest="$1/npm"
    mkdir -p "$dest"

    # Export global npm packages
    if command -v npm &>/dev/null; then
        # Parse npm list output: lines with "{" after a key are package entries
        npm list -g --depth=0 --json 2>/dev/null \
            | grep -E '^\s+"[^"]+": \{' \
            | sed 's/.*"\([^"]*\)".*/\1/' \
            | grep -vE '^(npm|corepack|dependencies)$' \
            > "$dest/global-packages.txt" || true

        local count
        count="$(wc -l < "$dest/global-packages.txt" | tr -d ' ')"
        log_success "Exported $count global npm packages"
    else
        log_warn "npm not found — skipping global packages"
    fi

    # Export nvm versions
    if _source_nvm; then
        set +eu
        nvm list --no-colors 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | sort -uV > "$dest/nvm-versions.txt"
        local default_ver
        default_ver="$(nvm alias default 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || true)"
        set -eu
        if [[ -n "$default_ver" ]]; then
            echo "$default_ver" > "$dest/nvm-default.txt"
            log_success "Exported nvm default: $default_ver"
        fi
        local ver_count
        ver_count="$(wc -l < "$dest/nvm-versions.txt" | tr -d ' ')"
        log_success "Exported $ver_count nvm-managed Node versions"
    else
        log_warn "nvm not found — skipping Node version management"
    fi

    return 0
}

import_npm() {
    local src="$1/npm"
    if [[ ! -d "$src" ]]; then
        log_warn "No npm data in snapshot"
        return 1
    fi

    # Import nvm versions first (need Node to install npm packages)
    if [[ -f "$src/nvm-versions.txt" ]]; then
        if ! _source_nvm; then
            log_warn "nvm not installed"
            if ask_yes_no "Install nvm?" "y"; then
                curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
                _source_nvm
            else
                log_info "Skipping nvm/Node version import"
            fi
        fi

        if command -v nvm &>/dev/null 2>&1 || type nvm &>/dev/null 2>&1; then
            local all_versions=()
            while IFS= read -r line; do all_versions+=("$line"); done < "$src/nvm-versions.txt"

            # Filter out Node versions < 16 on Apple Silicon (no arm64 binaries, source build fails)
            local versions=()
            local skipped=()
            local is_arm64=false
            [[ "$(uname -m)" == "arm64" ]] && is_arm64=true
            for ver in "${all_versions[@]}"; do
                [[ -z "$ver" ]] && continue
                local major
                major="$(echo "$ver" | grep -oE '[0-9]+' | head -1)"
                if [[ "$is_arm64" == true ]] && [[ "$major" -lt 16 ]]; then
                    skipped+=("$ver")
                else
                    versions+=("$ver")
                fi
            done

            if [[ ${#skipped[@]} -gt 0 ]]; then
                log_warn "Skipping ${#skipped[@]} Node versions incompatible with Apple Silicon: ${skipped[*]}"
            fi

            if [[ ${#versions[@]} -gt 0 ]] && ask_yes_no "Install ${#versions[@]} Node versions via nvm?" "y"; then
                for ver in "${versions[@]}"; do
                    [[ -z "$ver" ]] && continue
                    log_info "Installing Node $ver..."
                    set +eu
                    nvm install "$ver" || log_warn "Failed to install $ver"
                    set -eu
                done
            fi

            if [[ -f "$src/nvm-default.txt" ]]; then
                local default_ver
                default_ver="$(cat "$src/nvm-default.txt")"
                set +eu
                nvm alias default "$default_ver" 2>/dev/null
                nvm use default 2>/dev/null
                set -eu
                log_success "Set nvm default to $default_ver"
            fi
        fi
    fi

    # Import global npm packages
    if [[ -f "$src/global-packages.txt" ]]; then
        if ! command -v npm &>/dev/null; then
            log_warn "npm not available — cannot install global packages"
            return 1
        fi

        local packages=()
        while IFS= read -r line; do packages+=("$line"); done < "$src/global-packages.txt"
        local count=${#packages[@]}
        if [[ $count -gt 0 ]] && ask_yes_no "Install $count global npm packages?" "y"; then
            for pkg in "${packages[@]}"; do
                [[ -z "$pkg" ]] && continue
                log_info "Installing $pkg..."
                npm install -g "$pkg" 2>/dev/null || log_warn "Failed to install $pkg"
            done
            log_success "Global npm packages installed"
        fi
    fi

    return 0
}
