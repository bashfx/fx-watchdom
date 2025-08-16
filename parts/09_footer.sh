################################################################################
# installation commands (do_install, do_uninstall, do_status)
################################################################################

################################################################################
# do_install - Install to XDG+ compliant paths
################################################################################
do_install() {
    local ret=0
    
    # Create directories
    if ! mkdir -p "$FX_LIB_DIR" "$FX_BIN_DIR"; then
        error "Failed to create installation directories"
        return 1
    fi
    
    # Copy script to lib location
    if ! cp "$SELF_PATH" "$FX_INSTALL_PATH"; then
        error "Failed to copy script to %s" "$FX_INSTALL_PATH"
        return 1
    fi
    
    # Create symlink in bin
    if ! ln -sf "$FX_INSTALL_PATH" "$FX_BIN_LINK"; then
        error "Failed to create symlink at %s" "$FX_BIN_LINK"
        return 1
    fi
    
    okay "Installed %s to %s" "$SELF_NAME" "$FX_INSTALL_PATH"
    okay "Created symlink at %s" "$FX_BIN_LINK"
    
    # Check if bin directory is in PATH
    if [[ ":$PATH:" != *":$FX_BIN_DIR:"* ]]; then
        printf "\n%sIMPORTANT:%s Add to your shell profile:\n" "$yellow" "$x"
        printf "export PATH=\"%s:\$PATH\"\n\n" "$FX_BIN_DIR"
    fi
    
    return $ret
}

################################################################################
# do_uninstall - Remove installation
################################################################################
do_uninstall() {
    local ret=0
    local removed_items=0
    
    # Remove symlink
    if [[ -L "$FX_BIN_LINK" ]]; then
        if rm -f "$FX_BIN_LINK"; then
            okay "Removed symlink: %s" "$FX_BIN_LINK"
            removed_items=$((removed_items + 1))
        else
            error "Failed to remove symlink: %s" "$FX_BIN_LINK"
            ret=1
        fi
    fi
    
    # Remove script
    if [[ -f "$FX_INSTALL_PATH" ]]; then
        if rm -f "$FX_INSTALL_PATH"; then
            okay "Removed script: %s" "$FX_INSTALL_PATH"
            removed_items=$((removed_items + 1))
        else
            error "Failed to remove script: %s" "$FX_INSTALL_PATH"
            ret=1
        fi
    fi
    
    # Remove empty directories
    if [[ -d "$FX_LIB_DIR" ]] && [[ -z "$(ls -A "$FX_LIB_DIR" 2>/dev/null)" ]]; then
        if rmdir "$FX_LIB_DIR"; then
            trace "Removed empty directory: %s" "$FX_LIB_DIR"
        fi
    fi
    
    if [[ "$removed_items" -eq 0 ]]; then
        warn "%s was not installed or already removed" "$SELF_NAME"
        ret=1
    else
        okay "Successfully uninstalled %s (%d items removed)" "$SELF_NAME" "$removed_items"
        info "User configuration preserved at %s" "$WATCHDOM_RC"
    fi
    
    return $ret
}

################################################################################
# do_status - Show installation status
################################################################################
do_status() {
    local ret=0
    
    printf "%swatchdom v%s - Installation Status%s\n\n" "$blue" "$SELF_VERSION" "$x"
    
    printf "Current script: %s\n" "$SELF_PATH"
    
    if [[ -f "$FX_INSTALL_PATH" ]]; then
        printf "Installed at  : %s %s✓%s\n" "$FX_INSTALL_PATH" "$green" "$x"
    else
        printf "Installed at  : %s %s✗%s\n" "$FX_INSTALL_PATH" "$red" "$x"
        ret=1
    fi
    
    if [[ -L "$FX_BIN_LINK" ]]; then
        local link_target
        link_target="$(readlink "$FX_BIN_LINK")"
        printf "Symlink       : %s -> %s %s✓%s\n" "$FX_BIN_LINK" "$link_target" "$green" "$x"
    else
        printf "Symlink       : %s %s✗%s\n" "$FX_BIN_LINK" "$red" "$x"
        ret=1
    fi
    
    if [[ ":$PATH:" == *":$FX_BIN_DIR:"* ]]; then
        printf "PATH includes : %s %s✓%s\n" "$FX_BIN_DIR" "$green" "$x"
    else
        printf "PATH includes : %s %s✗%s\n" "$FX_BIN_DIR" "$red" "$x"
    fi
    
    if [[ -f "$WATCHDOM_RC" ]]; then
        local tld_count
        tld_count="$(grep -c '^[^#]' "$WATCHDOM_RC" 2>/dev/null || echo 0)"
        printf "User config   : %s (%s custom TLDs) %s✓%s\n" "$WATCHDOM_RC" "$tld_count" "$green" "$x"
    else
        printf "User config   : %s %s✗%s\n" "$WATCHDOM_RC" "$yellow" "$x"
    fi
    
    printf "\n"
    
    if [[ "$ret" -eq 0 ]]; then
        okay "watchdom is properly installed and ready to use"
    else
        warn "watchdom installation is incomplete - run 'watchdom install'"
    fi
    
    return $ret
}

################################################################################
# invocation and cleanup
################################################################################

# Signal handlers and cleanup
set -euo pipefail

# Global variables for cleanup
declare -a remaining_args=()

# Invoke main function only when executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@";
fi;