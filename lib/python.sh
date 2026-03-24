#!/usr/bin/env bash
# python.sh — Export/import Python versions and tools via uv

export_python() {
    local dest="$1/python"
    mkdir -p "$dest"

    if ! command -v uv &>/dev/null; then
        log_warn "uv not installed — skipping Python export"
        return 1
    fi

    # Export installed Python versions
    local versions
    versions="$(uv python list --only-installed 2>/dev/null || true)"
    if [[ -n "$versions" ]]; then
        echo "$versions" > "$dest/uv-python-versions.txt"
        local count
        count="$(echo "$versions" | wc -l | tr -d ' ')"
        log_success "Exported $count Python installations"
    fi

    # Export globally installed tools
    local tools
    tools="$(uv tool list 2>/dev/null || true)"
    if [[ -n "$tools" ]]; then
        echo "$tools" > "$dest/uv-tools.txt"
        # Count tool names (lines that don't start with whitespace and aren't empty)
        local tool_count
        tool_count="$(echo "$tools" | grep -cE '^[a-zA-Z]' || echo 0)"
        log_success "Exported $tool_count uv-managed tools"
    fi

    return 0
}

import_python() {
    local src="$1/python"
    if [[ ! -d "$src" ]]; then
        log_warn "No Python data in snapshot"
        return 1
    fi

    # Install uv if needed
    if ! command -v uv &>/dev/null; then
        log_warn "uv not installed"
        if ask_yes_no "Install uv?" "y"; then
            curl -LsSf https://astral.sh/uv/install.sh | sh
            export PATH="$HOME/.local/bin:$PATH"
            if ! command -v uv &>/dev/null; then
                log_error "uv installation failed"
                return 1
            fi
            log_success "uv installed"
        else
            log_info "Skipping Python import"
            return 1
        fi
    fi

    # Install Python versions
    if [[ -f "$src/uv-python-versions.txt" ]]; then
        # Extract version numbers (e.g., "cpython-3.13.1" -> "3.13.1")
        local versions=()
        while IFS= read -r line; do
            local ver
            ver="$(echo "$line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
            [[ -n "$ver" ]] && versions+=("$ver")
        done < "$src/uv-python-versions.txt"

        # Deduplicate
        local unique_versions=()
        local seen=""
        for v in "${versions[@]}"; do
            if [[ "$seen" != *"|$v|"* ]]; then
                unique_versions+=("$v")
                seen="${seen}|$v|"
            fi
        done

        if [[ ${#unique_versions[@]} -gt 0 ]] && ask_yes_no "Install ${#unique_versions[@]} Python versions via uv?" "y"; then
            for ver in "${unique_versions[@]}"; do
                log_info "Installing Python $ver..."
                uv python install "$ver" 2>/dev/null || log_warn "Failed to install Python $ver"
            done
            log_success "Python versions installed"
        fi
    fi

    # Install tools
    if [[ -f "$src/uv-tools.txt" ]]; then
        # Parse tool names (lines that don't start with whitespace)
        local tools=()
        while IFS= read -r line; do
            if [[ "$line" =~ ^[a-zA-Z] ]]; then
                # Tool name is the first word, version info follows
                local tool_name
                tool_name="$(echo "$line" | awk '{print $1}')"
                [[ -n "$tool_name" ]] && tools+=("$tool_name")
            fi
        done < "$src/uv-tools.txt"

        if [[ ${#tools[@]} -gt 0 ]]; then
            echo
            log_info "Tools to install:"
            printf '  %s\n' "${tools[@]}"
            echo
            if ask_yes_no "Install ${#tools[@]} Python tools via uv?" "y"; then
                for tool in "${tools[@]}"; do
                    log_info "Installing $tool..."
                    uv tool install "$tool" 2>/dev/null || log_warn "Failed to install $tool"
                done
                log_success "Python tools installed"
            fi
        fi
    fi

    return 0
}
