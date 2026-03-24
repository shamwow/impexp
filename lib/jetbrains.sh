#!/usr/bin/env bash
# jetbrains.sh — Export/import JetBrains IDE settings

JB_BASE="$HOME/Library/Application Support/JetBrains"
JB_CONFIG_DIRS=(options keymaps codestyles colors)

# Find installed JetBrains products (directories with version numbers)
detect_jetbrains_products() {
    local products=()
    if [[ ! -d "$JB_BASE" ]]; then
        echo ""
        return
    fi
    for dir in "$JB_BASE"/*/; do
        local name
        name="$(basename "$dir")"
        # Must contain a version number and have an options/ dir
        if [[ "$name" =~ [0-9] ]] && [[ -d "$dir/options" ]]; then
            products+=("$name")
        fi
    done
    echo "${products[*]}"
}

export_jetbrains() {
    local dest="$1/jetbrains"
    mkdir -p "$dest"

    local products_str
    products_str="$(detect_jetbrains_products)"
    if [[ -z "$products_str" ]]; then
        log_warn "No JetBrains products found"
        return 1
    fi

    read -ra products <<< "$products_str"
    echo "Found JetBrains products:"
    for i in "${!products[@]}"; do
        echo "  $((i + 1))) ${products[$i]}"
    done
    echo "  a) All"
    echo

    local selected=()
    if [[ -t 0 ]]; then
        echo -en "${BOLD}Select products to export (comma-separated, or 'a'):${NC} "
        read -r selection
        if [[ "$selection" == "a" || "$selection" == "A" || -z "$selection" ]]; then
            selected=("${products[@]}")
        else
            IFS=',' read -ra nums <<< "$selection"
            for num in "${nums[@]}"; do
                num="$(echo "$num" | tr -d ' ')"
                if [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#products[@]} )); then
                    selected+=("${products[$((num - 1))]}")
                fi
            done
        fi
    else
        selected=("${products[@]}")
    fi

    if [[ ${#selected[@]} -eq 0 ]]; then
        selected=("${products[@]}")
    fi

    for product in "${selected[@]}"; do
        local product_src="$JB_BASE/$product"
        local product_dest="$dest/$product"
        mkdir -p "$product_dest"

        for config_dir in "${JB_CONFIG_DIRS[@]}"; do
            if [[ -d "$product_src/$config_dir" ]] && [[ "$(ls -A "$product_src/$config_dir" 2>/dev/null)" ]]; then
                cp -r "$product_src/$config_dir" "$product_dest/$config_dir"
                log_success "Exported $product/$config_dir"
            fi
        done

        # Record installed plugins (informational)
        if [[ -d "$product_src/plugins" ]]; then
            ls "$product_src/plugins" 2>/dev/null > "$product_dest/plugins.txt" || true
        fi
    done

    return 0
}

import_jetbrains() {
    local src="$1/jetbrains"
    if [[ ! -d "$src" ]]; then
        log_warn "No JetBrains data in snapshot"
        return 1
    fi

    for product_dir in "$src"/*/; do
        local product
        product="$(basename "$product_dir")"
        local target="$JB_BASE/$product"

        if [[ ! -d "$target" ]]; then
            # Try to find same product family with different version
            local family="${product%%[0-9]*}"
            local match=""
            for dir in "$JB_BASE"/"$family"*/; do
                [[ -d "$dir" ]] && match="$(basename "$dir")"
            done

            if [[ -n "$match" && "$match" != "$product" ]]; then
                log_warn "$product not found, but $match exists"
                if ask_yes_no "Import into $match instead?" "y"; then
                    target="$JB_BASE/$match"
                else
                    log_info "Skipping $product"
                    continue
                fi
            else
                log_warn "$product not found — install the IDE first, then re-import"
                continue
            fi
        fi

        for config_dir in "${JB_CONFIG_DIRS[@]}"; do
            if [[ -d "$product_dir/$config_dir" ]]; then
                if [[ -d "$target/$config_dir" ]]; then
                    backup_file "$target/$config_dir"
                fi
                cp -r "$product_dir/$config_dir" "$target/$config_dir"
                log_success "Imported $product/$config_dir"
            fi
        done

        # Print plugins list
        if [[ -f "$product_dir/plugins.txt" ]]; then
            echo
            log_info "Plugins that were installed in $product:"
            cat "$product_dir/plugins.txt"
            echo
            log_info "Install these manually from the JetBrains Marketplace"
        fi
    done

    return 0
}
