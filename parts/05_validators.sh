################################################################################
# validators (_*) - input validation and state checking
################################################################################

################################################################################
# _validate_domain - Domain format validation
################################################################################
_validate_domain() {
    local domain="$1";
    
    # Check basic format
    if [[ ! "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
        error "Invalid domain format: %s" "$domain";
        return 1;
    fi;
    
    # Check length limits
    if [[ ${#domain} -gt 253 ]]; then
        error "Domain name too long: %s" "$domain";
        return 1;
    fi;
    
    # Check for double dots or invalid characters
    if [[ "$domain" =~ \.\. ]] || [[ "$domain" =~ ^[.-] ]] || [[ "$domain" =~ [.-]$ ]]; then
        error "Invalid domain format: %s" "$domain";
        return 1;
    fi;
    
    trace "Domain validation passed: %s" "$domain";
    return 0;
}

################################################################################
# _validate_datetime - Date string validation
################################################################################
_validate_datetime() {
    local when="$1";
    local epoch="";
    
    # Try to parse - if it works, it's valid
    if epoch=$(__parse_epoch "$when"); then
        trace "Datetime validation passed: %s -> %s" "$when" "$epoch";
        return 0;
    else
        error "Invalid datetime format: %s" "$when";
        return 1;
    fi;
}

################################################################################
# _validate_interval - Polling interval validation
################################################################################
_validate_interval() {
    local interval="$1";
    
    # Check if numeric
    if [[ ! "$interval" =~ ^[0-9]+$ ]]; then
        error "Interval must be numeric: %s" "$interval";
        return 1;
    fi;
    
    # Check minimum (warn for aggressive polling)
    if [[ "$interval" -lt 10 ]]; then
        warn "Interval %ss may trigger rate limits from WHOIS servers" "$interval";
    fi;
    
    # Check maximum (sanity check)
    if [[ "$interval" -gt 86400 ]]; then
        warn "Interval %ss is longer than 24 hours" "$interval";
    fi;
    
    trace "Interval validation passed: %ss" "$interval";
    return 0;
}

################################################################################
# _check_dependencies - Required command validation
################################################################################
_check_dependencies() {
    local missing=0;
    
    # Check for whois
    if ! command -v whois >/dev/null 2>&1; then
        error "Required command 'whois' not found";
        info "Install with: apt-get install whois (Ubuntu/Debian) or brew install whois (macOS)";
        missing=1;
    fi;
    
    # Check for date command
    if ! command -v date >/dev/null 2>&1; then
        error "Required command 'date' not found";
        missing=1;
    fi;
    
    # Check for timeout command (optional but recommended)
    if ! command -v timeout >/dev/null 2>&1; then
        warn "Command 'timeout' not found - WHOIS queries may hang";
    fi;
    
    if [[ "$missing" -eq 1 ]]; then
        return 1;
    fi;
    
    trace "All dependencies satisfied";
    return 0;
}

################################################################################
# _is_tld_supported - Check if TLD has configuration
################################################################################
_is_tld_supported() {
    local domain="$1";
    local tld="";
    
    # Extract TLD
    tld=$(echo "$domain" | grep -o '\.[^.]*$');
    
    # Check in built-in registry
    if [[ -n "${TLD_REGISTRY[$tld]:-}" ]]; then
        trace "TLD %s supported (built-in)" "$tld";
        return 0;
    fi;
    
    # Check in user config if it exists
    if [[ -f "$WATCHDOM_RC" ]] && grep -q "^$tld|" "$WATCHDOM_RC" 2>/dev/null; then
        trace "TLD %s supported (user config)" "$tld";
        return 0;
    fi;
    
    warn "TLD %s not configured - using generic WHOIS" "$tld";
    return 1;
}

################################################################################
# _load_tld_config - Load TLD configuration from user file
################################################################################
_load_tld_config() {
    local tld_file="$WATCHDOM_RC";
    local line tld server pattern;
    
    [[ ! -f "$tld_file" ]] && return 0;
    
    trace "Loading TLD configuration from %s" "$tld_file";
    
    while IFS='|' read -r tld server pattern; do
        # Skip comments and empty lines
        [[ "$tld" =~ ^#.*$ ]] || [[ -z "$tld" ]] && continue;
        
        # Validate format
        if [[ -n "$tld" && -n "$server" && -n "$pattern" ]]; then
            TLD_REGISTRY["$tld"]="$server|$pattern";
            trace "Loaded TLD config: %s -> %s | %s" "$tld" "$server" "$pattern";
        fi;
    done < "$tld_file";
    
    return 0;
}

################################################################################
# _get_tld_config - Get WHOIS server and pattern for TLD
################################################################################
_get_tld_config() {
    local domain="$1";
    local tld server pattern;
    
    # Extract TLD
    tld=$(echo "$domain" | grep -o '\.[^.]*$');
    
    # Look up in registry
    local config="${TLD_REGISTRY[$tld]:-}";
    
    if [[ -n "$config" ]]; then
        server=$(echo "$config" | cut -d'|' -f1);
        pattern=$(echo "$config" | cut -d'|' -f2);
        echo "$server|$pattern";
        return 0;
    fi;
    
    # Fallback to generic
    echo "|available";
    return 1;
}
