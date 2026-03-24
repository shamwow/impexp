#!/usr/bin/env bash
set -euo pipefail

IMPEXP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_BASE="$IMPEXP_DIR/exports"
IMPEXP_YES=false

# shellcheck source=lib/common.sh
source "$IMPEXP_DIR/lib/common.sh"

ALL_MODULES=(shell git ohmyzsh iterm vscode jetbrains homebrew npm golang rust python)

trap 'log_error "Unexpected error at line $LINENO"; exit 1' ERR

usage() {
    echo "Usage: impexp.sh [--yes|-y] <command> [args]"
    echo
    echo "Commands:"
    echo "  export    Export dev environment to a snapshot"
    echo "  import    Import dev environment from a snapshot"
    echo "  list      List available snapshots"
    echo "  help      Show this help"
    echo
    echo "Options:"
    echo "  -y, --yes   Auto-accept all prompts"
}

cmd_export() {
    local snapshot_dir="$EXPORT_BASE/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$snapshot_dir"

    # Write manifest
    cat > "$snapshot_dir/manifest.json" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "hostname": "$(hostname)",
  "username": "$(whoami)"
}
EOF

    log_info "Exporting to: $snapshot_dir"
    echo

    ask_modules "${ALL_MODULES[@]}"

    local warnings=()
    for module in "${SELECTED_MODULES[@]}"; do
        echo
        log_info "=== Exporting: $module ==="
        source "$IMPEXP_DIR/lib/${module}.sh"
        if ! "export_${module}" "$snapshot_dir"; then
            log_warn "Module '$module' completed with warnings"
            warnings+=("$module")
        fi
    done

    echo
    log_success "Export complete: $snapshot_dir"
    if [[ ${#warnings[@]} -gt 0 ]]; then
        log_warn "Warnings in: ${warnings[*]}"
    fi

    echo
    if ask_yes_no "Create .tar.gz archive?" "y"; then
        create_export_archive "$snapshot_dir"
    fi
}

cmd_import() {
    local input="${1:-}"
    if [[ -z "$input" ]]; then
        log_error "Usage: impexp.sh import <snapshot-dir-or-archive>"
        exit 1
    fi

    local snapshot_dir
    if [[ "$input" == *.tar.gz ]]; then
        snapshot_dir="$(extract_import_archive "$input")"
        log_info "Extracted archive to: $snapshot_dir"
    else
        snapshot_dir="$input"
    fi

    if [[ ! -f "$snapshot_dir/manifest.json" ]]; then
        log_error "Not a valid snapshot: missing manifest.json"
        exit 1
    fi

    echo -e "\n${BOLD}Snapshot info:${NC}"
    cat "$snapshot_dir/manifest.json"
    echo

    # Detect which modules have data
    local available=()
    for module in "${ALL_MODULES[@]}"; do
        local module_dir="$snapshot_dir/$module"
        if [[ -d "$module_dir" ]] && [[ "$(ls -A "$module_dir" 2>/dev/null)" ]]; then
            available+=("$module")
        fi
    done

    if [[ ${#available[@]} -eq 0 ]]; then
        log_warn "No module data found in snapshot"
        return
    fi

    ask_modules "${available[@]}"

    local warnings=()
    for module in "${SELECTED_MODULES[@]}"; do
        echo
        log_info "=== Importing: $module ==="
        source "$IMPEXP_DIR/lib/${module}.sh"
        if ! "import_${module}" "$snapshot_dir"; then
            log_warn "Module '$module' completed with warnings"
            warnings+=("$module")
        fi
    done

    echo
    log_success "Import complete"
    if [[ ${#warnings[@]} -gt 0 ]]; then
        log_warn "Warnings in: ${warnings[*]}"
    fi
}

cmd_list() {
    if [[ ! -d "$EXPORT_BASE" ]]; then
        log_info "No exports found"
        return
    fi

    local snapshots=()
    while IFS= read -r dir; do
        snapshots+=("$dir")
    done < <(find "$EXPORT_BASE" -mindepth 1 -maxdepth 1 -type d | sort)

    if [[ ${#snapshots[@]} -eq 0 ]]; then
        log_info "No exports found"
        return
    fi

    echo -e "${BOLD}Available snapshots:${NC}\n"
    for dir in "${snapshots[@]}"; do
        local name
        name="$(basename "$dir")"
        echo -e "${BOLD}$name${NC}"

        if [[ -f "$dir/manifest.json" ]]; then
            # Parse without jq
            local hostname timestamp
            hostname="$(grep '"hostname"' "$dir/manifest.json" | sed 's/.*: *"\(.*\)".*/\1/')"
            timestamp="$(grep '"timestamp"' "$dir/manifest.json" | sed 's/.*: *"\(.*\)".*/\1/')"
            echo "  Host: $hostname | Time: $timestamp"
        fi

        # List modules present
        local modules=()
        for m in "${ALL_MODULES[@]}"; do
            if [[ -d "$dir/$m" ]] && [[ "$(ls -A "$dir/$m" 2>/dev/null)" ]]; then
                modules+=("$m")
            fi
        done
        if [[ ${#modules[@]} -gt 0 ]]; then
            echo "  Modules: ${modules[*]}"
        fi
        echo
    done
}

# Parse all args: extract flags from any position, preserve positional order
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes)  IMPEXP_YES=true ;;
        -h|--help) POSITIONAL+=("help") ;;
        *)         POSITIONAL+=("$1") ;;
    esac
    shift
done

# Main
case "${POSITIONAL[0]:-help}" in
    export)  cmd_export ;;
    import)  cmd_import "${POSITIONAL[1]:-}" ;;
    list)    cmd_list ;;
    help)    usage ;;
    *)
        log_error "Unknown command: ${POSITIONAL[0]}"
        usage
        exit 1
        ;;
esac
