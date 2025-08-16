################################################################################
# commands (do_*) - business logic with proper BashFX hierarchy
################################################################################

################################################################################
# do_query - Single WHOIS query command (FIX: was buried in watch logic)
################################################################################
do_query() {
    local domain="$1"
    local ret=1
    
    # Validate input
    if ! _validate_domain "$domain"; then
        return 2
    fi
    
    # Load TLD configuration
    _load_tld_config
    
    info "Performing single WHOIS query for %s" "$domain"
    
    # Execute WHOIS query
    local whois_output
    if whois_output=$(__whois_query "$domain"); then
        # Extract domain status and registrar
        local domain_status registrar
        domain_status=$(__extract_domain_status "$whois_output")
        registrar=$(__extract_registrar "$whois_output")
        
        # Print results
        printf "\n%sDomain Query Results%s\n" "$blue" "$x"
        printf "Domain: %s\n" "$domain"
        printf "Status: %s\n" "$domain_status"
        printf "Registrar: %s\n" "$registrar"
        printf "\n%sRaw WHOIS Output:%s\n" "$grey" "$x"
        echo "$whois_output"
        
        # Set return code based on status
        if [[ "$domain_status" == "AVAILABLE" ]]; then
            ret=0  # Success - domain is available
        else
            ret=1  # Not available
        fi
    else
        error "WHOIS query failed for %s" "$domain"
        ret=3
    fi
    
    return $ret
}

################################################################################
# do_watch - Domain monitoring with phase-aware polling
################################################################################
do_watch() {
    local domain="$1"
    local interval="${opt_interval:-$DEFAULT_INTERVAL}"
    local max_checks="${opt_max_checks:-$DEFAULT_MAX_CHECKS}"
    local target_epoch=0
    local expect_pattern="${opt_expect:-}"
    local use_utc="${opt_time_utc:-0}"
    local ret=1
    
    # Validate inputs
    if ! _validate_domain "$domain"; then
        return 2
    fi
    
    if ! _validate_interval "$interval"; then
        return 2
    fi
    
    # Parse target time if provided
    if [[ -n "${opt_until:-}" ]]; then
        if ! target_epoch=$(__parse_epoch "${opt_until}"); then
            error "Invalid target time: %s" "${opt_until}"
            return 4
        fi
        info "Target time set: %s" "$(__format_time_display "$target_epoch" "$use_utc")"
    fi
    
    # Check dependencies
    if ! _check_dependencies; then
        return 3
    fi
    
    # Load TLD configuration
    _load_tld_config
    
    # Start monitoring
    _start_polling "$domain" "$interval" "$max_checks" "$target_epoch" "$expect_pattern" "$use_utc"
    ret=$?
    
    return $ret
}

################################################################################
# _start_polling - Polling loop coordination (mid-level helper)
################################################################################
_start_polling() {
    local domain="$1"
    local base_interval="$2"
    local max_checks="$3"
    local target_epoch="$4"
    local expect_pattern="$5"
    local use_utc="$6"
    
    local check_count=0
    local start_epoch=$(__get_current_epoch)
    local whois_output="" domain_status="" registrar=""
    local matched=0
    
    info "Starting monitoring for %s with base interval=%ss" "$domain" "$base_interval"
    [[ "$target_epoch" -gt 0 ]] && info "Target UTC: %s" "$(__format_time_display "$target_epoch" 1)"
    
    while true; do
        ((check_count++))
        local current_epoch=$(__get_current_epoch)
        
        # Execute WHOIS query
        if ! whois_output=$(__whois_query "$domain"); then
            error "WHOIS query failed, stopping monitoring"
            return 3
        fi
        
        # Extract domain information
        domain_status=$(__extract_domain_status "$whois_output")
        registrar=$(__extract_registrar "$whois_output")
        
        # Check for pattern match
        if _check_pattern_match "$whois_output" "$expect_pattern" "$domain_status"; then
            matched=1
            break
        fi
        
        # Check max checks limit
        if [[ "$max_checks" -gt 0 && "$check_count" -ge "$max_checks" ]]; then
            warn "Maximum checks (%d) reached" "$max_checks"
            break
        fi
        
        # Calculate next poll interval based on phase
        local phase=$(_determine_phase "$target_epoch" "$current_epoch")
        local time_to_target=$((target_epoch - current_epoch))
        local next_interval=$(_calculate_interval "$base_interval" "$phase" "$time_to_target")
        
        # Display live status line
        local status_line
        status_line=$(_format_status_line "$domain" "$next_interval" "$target_epoch" "$current_epoch" "$whois_output" "$expect_pattern" "$use_utc")
        _print_live_line "$status_line"
        
        # Check grace period timeout
        if _check_grace_timeout "$target_epoch" "$current_epoch" "$domain"; then
            break
        fi
        
        # Sleep until next poll
        trace "Sleeping %ss until next poll (phase: %s)" "$next_interval" "$phase"
        sleep "$next_interval"
    done
    
    # Calculate total monitoring time
    local end_epoch=$(__get_current_epoch)
    local total_time=$(_human_time $((end_epoch - start_epoch)))
    local activity=$(_get_activity_code "$whois_output" "$expect_pattern")
    
    # Print completion message
    _format_completion_message "$matched" "$domain" "$domain_status" "$registrar" "$total_time" "$activity" "$end_epoch"
    
    return $((1 - matched))  # 0 if matched, 1 if not
}

################################################################################
# _check_pattern_match - Check if domain matches expected pattern
################################################################################
_check_pattern_match() {
    local whois_output="$1"
    local expect_pattern="$2"
    local domain_status="$3"
    
    # Custom pattern specified
    if [[ -n "$expect_pattern" ]]; then
        if echo "$whois_output" | grep -qi "$expect_pattern"; then
            trace "Custom pattern matched: %s" "$expect_pattern"
            return 0
        fi
        return 1
    fi
    
    # Default pattern: look for availability
    if [[ "$domain_status" == "AVAILABLE" ]]; then
        trace "Domain became available"
        return 0
    fi
    
    return 1
}

################################################################################
# _check_grace_timeout - Check if grace period exceeded
################################################################################
_check_grace_timeout() {
    local target_epoch="$1"
    local current_epoch="$2" 
    local domain="$3"
    
    # No target set, no grace period
    [[ "$target_epoch" -eq 0 ]] && return 1
    
    # Before target, no grace period yet
    [[ "$current_epoch" -lt "$target_epoch" ]] && return 1
    
    local time_past_target=$((current_epoch - target_epoch))
    
    # Within grace period
    [[ "$time_past_target" -lt "$GRACE_THRESHOLD" ]] && return 1
    
    # Grace period exceeded - prompt user
    printf "\n\n%sGrace period exceeded%s\n" "$yellow" "$x"
    printf "Target time was %s ago. Continue monitoring %s?\n" "$(_human_time "$time_past_target")" "$domain"
    printf "[y] Yes, keep monitoring  [n] No, exit  [c] Custom interval: "
    
    local response
    if [[ "${opt_yes:-0}" -eq 1 ]]; then
        response="y"
        printf "y (auto-confirmed)\n"
    else
        read -r response
    fi
    
    case "$response" in
        (y|Y|yes|YES)
            info "Continuing monitoring with extended intervals"
            return 1  # Continue monitoring
            ;;
        (n|N|no|NO|"")
            info "User chose to exit monitoring"
            return 0  # Stop monitoring
            ;;
        (c|C|custom|CUSTOM)
            printf "Enter new interval in seconds: "
            local new_interval
            read -r new_interval
            if _validate_interval "$new_interval"; then
                opt_interval="$new_interval"
                info "Interval updated to %ss" "$new_interval"
                return 1  # Continue with new interval
            else
                warn "Invalid interval, continuing with current settings"
                return 1
            fi
            ;;
        (*)
            warn "Invalid response, continuing monitoring"
            return 1
            ;;
    esac
}

################################################################################
# do_time - Standalone time countdown mode
################################################################################
do_time() {
    local target_time="$1"
    local use_utc="${opt_time_utc:-0}"
    local target_epoch
    
    # Validate and parse target time
    if ! target_epoch=$(__parse_epoch "$target_time"); then
        error "Invalid target time: %s" "$target_time"
        return 4
    fi
    
    info "Time countdown mode - target: %s" "$(__format_time_display "$target_epoch" "$use_utc")"
    
    # Simple countdown display
    _format_countdown "$target_epoch" "$(__get_current_epoch)" "$use_utc"
    
    return 0
}

################################################################################
# do_list_tlds - Show supported TLD configurations
################################################################################
do_list_tlds() {
    printf "\n%sSupported TLD Configurations%s\n\n" "$blue" "$x"
    
    # Load user config
    _load_tld_config
    
    printf "%-8s %-25s %s\n" "TLD" "WHOIS Server" "Available Pattern"
    printf "%-8s %-25s %s\n" "---" "------------" "-----------------"
    
    # Show built-in and user-configured TLDs
    local tld server pattern
    for tld in "${!TLD_REGISTRY[@]}"; do
        IFS='|' read -r server pattern <<< "${TLD_REGISTRY[$tld]}"
        printf "%-8s %-25s %s\n" "$tld" "$server" "$pattern"
    done
    
    printf "\nUser configuration file: %s\n" "$WATCHDOM_RC"
    
    return 0
}

################################################################################
# do_add_tld - Add TLD configuration
################################################################################
do_add_tld() {
    local tld="$1"
    local server="$2"
    local pattern="$3"
    
    # Validate inputs
    if [[ -z "$tld" || -z "$server" || -z "$pattern" ]]; then
        error "Usage: add_tld TLD WHOIS_SERVER AVAILABLE_PATTERN"
        return 2
    fi
    
    # Ensure TLD starts with dot
    [[ "$tld" != .* ]] && tld=".$tld"
    
    # Add to user configuration
    echo "$tld|$server|$pattern" >> "$WATCHDOM_RC"
    
    okay "Added TLD configuration: %s -> %s | %s" "$tld" "$server" "$pattern"
    return 0
}

################################################################################
# do_test_tld - Test TLD configuration
################################################################################
do_test_tld() {
    local tld="$1"
    local test_domain="$2"
    
    if [[ -z "$tld" || -z "$test_domain" ]]; then
        error "Usage: test_tld TLD TEST_DOMAIN"
        return 2
    fi
    
    # Load configuration
    _load_tld_config
    
    # Get TLD configuration
    local config server pattern
    config=$(_get_tld_config "$test_domain")
    IFS='|' read -r server pattern <<< "$config"
    
    printf "\n%sTLD Test Results%s\n" "$blue" "$x"
    printf "TLD: %s\n" "$tld"
    printf "Test domain: %s\n" "$test_domain"
    printf "WHOIS server: %s\n" "${server:-default}"
    printf "Expected pattern: %s\n" "${pattern:-available}"
    
    # Execute test query
    local whois_output
    if whois_output=$(__whois_query "$test_domain"); then
        printf "\n%sPattern Match Test:%s\n" "$yellow" "$x"
        if echo "$whois_output" | grep -qi "${pattern:-available}"; then
            printf "%s%s Pattern MATCHED%s\n" "$green" "$pass" "$x"
            return 0
        else
            printf "%s%s Pattern NOT matched%s\n" "$red" "$fail" "$x"
            return 1
        fi
    else
        error "WHOIS query failed for test domain"
        return 3
    fi
}