#!/usr/bin/env bash
# rust.sh — Export/import Rust version (via rsvm) and cargo-installed crates

_source_rsvm() {
    set +eu
    if [[ -s "$HOME/.rsvm/current/cargo/env" ]]; then
        source "$HOME/.rsvm/current/cargo/env" 2>/dev/null
    fi
    # Check if rsvm command is available
    if [[ -s "$HOME/.rsvm/rsvm.sh" ]]; then
        source "$HOME/.rsvm/rsvm.sh" 2>/dev/null
        set -eu
        return 0
    fi
    set -eu
    # Fallback: check if rsvm is on PATH
    command -v rsvm &>/dev/null && return 0
    return 1
}

export_rust() {
    local dest="$1/rust"
    mkdir -p "$dest"

    # Export Rust version info
    local found_rust=false
    if command -v rustc &>/dev/null; then
        rustc --version > "$dest/rust-version.txt"
        log_success "Exported Rust version: $(cat "$dest/rust-version.txt")"
        found_rust=true
    fi

    # Export rsvm metadata
    if [[ -f "$HOME/.rsvm/.rsvm_version" ]]; then
        cp "$HOME/.rsvm/.rsvm_version" "$dest/rsvm-meta-version.txt"
    fi

    if [[ "$found_rust" == false ]]; then
        log_warn "No Rust installation found"
        return 1
    fi

    # List installed rsvm versions
    if [[ -d "$HOME/.rsvm/versions" ]]; then
        ls "$HOME/.rsvm/versions" 2>/dev/null | grep -E '^[0-9]' > "$dest/rsvm-installed-versions.txt" || true
        local count
        count="$(wc -l < "$dest/rsvm-installed-versions.txt" | tr -d ' ')"
        if [[ $count -gt 0 ]]; then
            log_success "Exported $count installed Rust versions"
        fi
    fi

    # Also list rustup toolchains (rsvm may use rustup internally)
    if [[ -d "$HOME/.rsvm/current/rustup/toolchains" ]]; then
        ls "$HOME/.rsvm/current/rustup/toolchains" 2>/dev/null > "$dest/rustup-toolchains.txt" || true
        local tc_count
        tc_count="$(wc -l < "$dest/rustup-toolchains.txt" | tr -d ' ')"
        if [[ $tc_count -gt 0 ]]; then
            log_success "Exported $tc_count rustup toolchains"
        fi
    fi

    # Export cargo installed crates
    if command -v cargo &>/dev/null; then
        cargo install --list > "$dest/cargo-install-list.txt" 2>/dev/null || true
        # Parse crate names (lines without leading whitespace that end with ':')
        grep -E '^[a-zA-Z]' "$dest/cargo-install-list.txt" | sed 's/ .*//' > "$dest/cargo-crates.txt" || true
        local crate_count
        crate_count="$(wc -l < "$dest/cargo-crates.txt" | tr -d ' ')"
        log_success "Exported $crate_count cargo-installed crates"
    else
        log_warn "cargo not found — skipping crate list"
    fi

    return 0
}

import_rust() {
    local src="$1/rust"
    if [[ ! -d "$src" ]]; then
        log_warn "No Rust data in snapshot"
        return 1
    fi

    # Install rsvm if needed
    if ! _source_rsvm && ! command -v rsvm &>/dev/null; then
        log_warn "rsvm not installed"
        if ask_yes_no "Install rsvm?" "y"; then
            curl -L https://raw.githubusercontent.com/aspect-build/rsvm/master/install.sh | bash
            _source_rsvm || log_warn "Could not source rsvm after install"
        else
            log_info "Skipping Rust import"
            return 1
        fi
    fi

    # Install Rust versions via rsvm
    if [[ -f "$src/rsvm-installed-versions.txt" ]]; then
        local versions=()
        while IFS= read -r line; do versions+=("$line"); done < "$src/rsvm-installed-versions.txt"
        if [[ ${#versions[@]} -gt 0 ]] && ask_yes_no "Install ${#versions[@]} Rust versions via rsvm?" "y"; then
            for ver in "${versions[@]}"; do
                [[ -z "$ver" ]] && continue
                log_info "Installing Rust $ver..."
                rsvm install "$ver" 2>/dev/null || log_warn "Failed to install $ver"
            done
        fi
    fi

    # Set default version
    if [[ -f "$src/rsvm-version.txt" ]]; then
        local default_ver
        default_ver="$(cat "$src/rsvm-version.txt")"
        rsvm use "$default_ver" 2>/dev/null || log_warn "Failed to set Rust version: $default_ver"
        log_success "Set Rust version to $default_ver"
    fi

    # Install cargo crates
    if [[ -f "$src/cargo-crates.txt" ]]; then
        if ! command -v cargo &>/dev/null; then
            log_warn "cargo not available — cannot install crates"
            return 0
        fi

        # Filter out local-path installs (lines containing '/')
        local crates=()
        while IFS= read -r crate; do
            [[ -z "$crate" ]] && continue
            # Skip entries that look like local paths
            grep -q "$crate.*path:" "$src/cargo-install-list.txt" 2>/dev/null && continue
            crates+=("$crate")
        done < "$src/cargo-crates.txt"

        if [[ ${#crates[@]} -gt 0 ]]; then
            echo
            log_info "Cargo crates to install:"
            printf '  %s\n' "${crates[@]}"
            echo
            if ask_yes_no "Install ${#crates[@]} cargo crates? (this can be slow)" "y"; then
                for crate in "${crates[@]}"; do
                    log_info "Installing $crate..."
                    cargo install "$crate" 2>/dev/null || log_warn "Failed to install $crate"
                done
                log_success "Cargo crates installed"
            fi
        fi
    fi

    return 0
}
