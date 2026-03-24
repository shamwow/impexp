#!/usr/bin/env bash
# golang.sh — Export/import Go versions (via GVM) and global binaries

_source_gvm() {
    if [[ -s "$HOME/.gvm/scripts/gvm" ]]; then
        set +eu
        source "$HOME/.gvm/scripts/gvm" 2>/dev/null
        set -eu
        return 0
    fi
    return 1
}

export_golang() {
    local dest="$1/golang"
    mkdir -p "$dest"

    if ! _source_gvm; then
        log_warn "GVM not installed — skipping Go export"
        return 1
    fi

    # Export installed Go versions
    local gvm_output
    set +eu
    gvm_output="$(gvm list 2>/dev/null || true)"
    set -eu
    echo "$gvm_output" > "$dest/gvm-versions-raw.txt"

    # Parse versions list
    echo "$gvm_output" | grep -oE 'go[0-9]+\.[0-9]+(\.[0-9]+)?' | sort -uV > "$dest/gvm-versions.txt"

    # Find default version (marked with =>)
    local default_ver
    default_ver="$(echo "$gvm_output" | grep '=>' | grep -oE 'go[0-9]+\.[0-9]+(\.[0-9]+)?' || true)"
    if [[ -n "$default_ver" ]]; then
        echo "$default_ver" > "$dest/gvm-default.txt"
        log_success "Default Go version: $default_ver"
    fi

    local ver_count
    ver_count="$(wc -l < "$dest/gvm-versions.txt" | tr -d ' ')"
    log_success "Exported $ver_count Go versions"

    # Export go version for reference
    go version 2>/dev/null > "$dest/go-version.txt" || true

    # Export $GOPATH/bin contents
    local gopath_bin="${GOPATH:-$HOME/go}/bin"
    if [[ -d "$gopath_bin" ]] && [[ "$(ls -A "$gopath_bin" 2>/dev/null)" ]]; then
        ls "$gopath_bin" > "$dest/go-binaries.txt"
        local bin_count
        bin_count="$(wc -l < "$dest/go-binaries.txt" | tr -d ' ')"
        log_success "Exported $bin_count Go binary names from \$GOPATH/bin"
    fi

    rm -f "$dest/gvm-versions-raw.txt"
    return 0
}

import_golang() {
    local src="$1/golang"
    if [[ ! -d "$src" ]]; then
        log_warn "No Go data in snapshot"
        return 1
    fi

    if ! _source_gvm; then
        log_warn "GVM not installed"
        if ask_yes_no "Install GVM?" "y"; then
            bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
            _source_gvm || { log_error "Failed to source GVM after install"; return 1; }
        else
            log_info "Skipping Go import"
            return 1
        fi
    fi

    # Install Go versions
    if [[ -f "$src/gvm-versions.txt" ]]; then
        local versions
        mapfile -t versions < "$src/gvm-versions.txt"
        if [[ ${#versions[@]} -gt 0 ]] && ask_yes_no "Install ${#versions[@]} Go versions via GVM?" "y"; then
            for ver in "${versions[@]}"; do
                [[ -z "$ver" ]] && continue
                log_info "Installing $ver..."
                set +eu
                gvm install "$ver" -B 2>/dev/null || gvm install "$ver" 2>/dev/null || log_warn "Failed to install $ver"
                set -eu
            done
        fi
    fi

    # Set default
    if [[ -f "$src/gvm-default.txt" ]]; then
        local default_ver
        default_ver="$(cat "$src/gvm-default.txt")"
        set +eu
        gvm use "$default_ver" --default 2>/dev/null || log_warn "Failed to set default: $default_ver"
        set -eu
        log_success "Set default Go version to $default_ver"
    fi

    # Print go binaries for manual install
    if [[ -f "$src/go-binaries.txt" ]]; then
        echo
        log_info "The following Go binaries were in \$GOPATH/bin:"
        cat "$src/go-binaries.txt"
        echo
        log_info "Install them manually with 'go install <package>@latest'"
    fi

    return 0
}
