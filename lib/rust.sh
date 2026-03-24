#!/usr/bin/env bash
# rust.sh — Export/import Rust toolchain and cargo-installed crates
# Uses rustup for installation (rsvm on the source machine wraps rustup internally)

_ensure_cargo_on_path() {
    # Try multiple known cargo/env locations
    local env_files=(
        "$HOME/.rsvm/current/cargo/env"
        "$HOME/.cargo/env"
    )
    for env_file in "${env_files[@]}"; do
        if [[ -s "$env_file" ]]; then
            set +eu
            source "$env_file" 2>/dev/null
            set -eu
        fi
    done
    command -v cargo &>/dev/null
}

export_rust() {
    local dest="$1/rust"
    mkdir -p "$dest"

    _ensure_cargo_on_path || true

    # Export Rust version info
    if ! command -v rustc &>/dev/null; then
        log_warn "No Rust installation found"
        return 1
    fi

    rustc --version > "$dest/rust-version.txt"
    log_success "Exported Rust version: $(cat "$dest/rust-version.txt")"

    # Export rustup toolchains
    if command -v rustup &>/dev/null; then
        rustup toolchain list > "$dest/rustup-toolchains.txt" 2>/dev/null || true
        local tc_count
        tc_count="$(wc -l < "$dest/rustup-toolchains.txt" | tr -d ' ')"
        if [[ $tc_count -gt 0 ]]; then
            log_success "Exported $tc_count rustup toolchains"
        fi
    fi

    # Export cargo installed crates
    if command -v cargo &>/dev/null; then
        cargo install --list > "$dest/cargo-install-list.txt" 2>/dev/null || true
        # Parse crate names (lines without leading whitespace, before the version)
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

    # Try to get cargo on PATH from existing install
    _ensure_cargo_on_path || true

    # Install Rust via rustup if needed
    if ! command -v rustc &>/dev/null && ! command -v cargo &>/dev/null; then
        log_warn "Rust not installed"
        if ask_yes_no "Install Rust via rustup?" "y"; then
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
            # Source the newly installed cargo env
            if [[ -s "$HOME/.cargo/env" ]]; then
                set +eu
                source "$HOME/.cargo/env" 2>/dev/null
                set -eu
            fi
            if command -v rustc &>/dev/null; then
                log_success "Rust installed: $(rustc --version)"
            else
                log_error "Rust installation failed"
                return 1
            fi
        else
            log_info "Skipping Rust import"
            return 1
        fi
    fi

    # Install additional toolchains
    if [[ -f "$src/rustup-toolchains.txt" ]] && command -v rustup &>/dev/null; then
        local toolchains=()
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            # Strip " (default)" suffix and whitespace
            local tc
            tc="$(echo "$line" | sed 's/ (default)//' | tr -d ' ')"
            toolchains+=("$tc")
        done < "$src/rustup-toolchains.txt"

        if [[ ${#toolchains[@]} -gt 0 ]] && ask_yes_no "Install ${#toolchains[@]} rustup toolchains?" "y"; then
            for tc in "${toolchains[@]}"; do
                log_info "Installing toolchain $tc..."
                rustup toolchain install "$tc" 2>/dev/null || log_warn "Failed to install $tc"
            done
        fi
    fi

    # Install cargo crates
    if [[ -f "$src/cargo-crates.txt" ]]; then
        if ! command -v cargo &>/dev/null; then
            log_warn "cargo not available — cannot install crates"
            return 0
        fi

        # Filter out local-path installs
        local crates=()
        while IFS= read -r crate; do
            [[ -z "$crate" ]] && continue
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
