################################################################################
# commands (do_*) - business logic with enhanced UX (Phase 2)
################################################################################

################################################################################
# do_query - Single WHOIS query command with enhanced output
################################################################################
do_query() {
    local domain="$1";
    local ret=1;
    
    # Validate input
    if ! _validate_domain "$domain"; then
        return 2;
    fi;
    
    # Load TLD configuration
    _load_tld_config;
    
    info "Performing single WHOIS query for %s" "$domain";
    
    # Execute WHOIS query
    local whois_output;
    if whois_output=$(__whois_query "$domain"); then
        # Extract domain status and registrar
        local domain_status registrar;
        domain_status=$(__extract_domain_status "$whois_output");
        registrar=$(__extract_registrar "$whois_output");
        
        # Enhanced results display with colors and glyphs
        printf "\n%s%s Domain Query Results %s%s\n" "$blue" "$lambda" "$lambda" "$x";
        printf "%sDomain:%s %s\n" "$white" "$x" "$domain";
        
        # Status with appropriate color
        case "$domain_status" in
            (AVAILABLE)
                printf "%sStatus:%s %s%s %s%s\n" "$white" "$x" "$green" "$pass" "$domain_status" "$x";
                ret=0;  # Success - domain is available
                ;;
            (PENDING-DELETE)
                printf "%sStatus:%s %s%s %s%s\n" "$white" "$x" "$yellow" "$delta" "$domain_status" "$x";
                ret=1;  # Pending status
                ;;
            (*)
                printf "%sStatus:%s %s%s %s%s\n" "$white" "$x" "$red" "$fail" "$domain_status" "$x";
                ret=1;  # Not available
                ;;
        esac;
        
        printf "%sRegistrar:%s %s\n" "$white" "$x" "$registrar";
        
        # Show query timestamp
        printf "%sQueried:%s %s\n" "$white" "$x" "$(date '+%Y-%m-%d %H:%M:%S %Z')";
        
        # Raw WHOIS output in collapsed format
        printf "\n%s%s Raw WHOIS Output:%s\n" "$grey" "$delta" "$x";
        echo "$whois_output" | head -20;
        local total_lines;
        total_lines=$(echo "$whois_output" | wc -l);
        if [[ $total_lines -gt 20 ]]; then
            printf "%s... (%d more lines, use -t for full output)%s\n" "$grey" $((total_lines - 20)) "$x";
        fi;
        
    else
        error "WHOIS query failed for %s" "$domain";
        ret=3;
    fi;
    
    return $ret;
}

################################################################################
# do_watch - Domain monitoring with enhanced live UX
################################################################################
do_watch() {
    local domain="$1";
    local interval="${opt_interval:-$DEFAULT_INTERVAL}";
    local max_checks="${opt_max_checks:-$DEFAULT_MAX_CHECKS}";
    local target_epoch=0;
    local expect_pattern="${opt_expect:-}";
    local use_utc="${opt_time_utc:-0}";
    local ret=1;
    
    # Validate inputs
    if ! _validate_domain "$domain"; then
        return 2;
    fi;
    
    if ! _validate_interval "$interval"; then
        return 2;
    fi;
    
    # Parse target time if provided
    if [[ -n "${opt_until:-}" ]]; then
        if ! target_epoch=$(__parse_epoch "${opt_until}"); then
            error "Invalid target time: %s" "${opt_until}";
            return 4;
        fi;
        info "Target time set: %s" "$(__format_time_display "$target_epoch" "$use_utc")";
    fi;
    
    # Check dependencies
    if ! _check_dependencies; then
        return 3;
    fi;
    
    # Load TLD configuration
    _load_tld_config;
    
    # Enhanced startup display
    printf "\n%s%s Watchdom Monitor Starting %s%s\n" "$blue" "$lambda" "$lambda" "$x";
    printf "%sDomain:%s %s\n" "$white" "$x" "$domain";
    printf "%sInterval:%s %ss base, phase-aware scaling\n" "$white" "$x" "$interval";
    if [[ "$target_epoch" -gt 0 ]]; then
        printf "%sTarget:%s %s\n" "$white" "$x" "$(__format_time_display "$target_epoch" "$use_utc")";
    fi;
    printf "%sPhases:%s %s%sPOLL %s%sHEAT %s%sGRACE %s%sCOOL%s\n" "$white" "$x" "$blue" "$lambda" "$red" "$triangle" "$purple" "$triangle_up" "$cyan" "$snowflake" "$x";
    printf "\n";
    
    # Start monitoring
    _start_polling "$domain" "$interval" "$max_checks" "$target_epoch" "$expect_pattern" "$use_utc";
    ret=$?;
    
    return $ret;
}

################################################################################
# _start_polling - Enhanced polling loop with superior UX
################################################################################
_start_polling() {
    local domain="$1";
    local base_interval="$2";
    local max_checks="$3";
    local target_epoch="$4";
    local expect_pattern="$5";
    local use_utc="$6";
    
    local check_count=0;
    local start_epoch=$(__get_current_epoch);
    local whois_output="" domain_status="" registrar="";
    local matched=0;
    local previous_phase="";
    
    info "Starting enhanced monitoring for %s with base interval=%ss" "$domain" "$base_interval";
    [[ "$target_epoch" -gt 0 ]] && info "Target UTC: %s" "$(__format_time_display "$target_epoch" 1)";
    
    while true; do
        ((check_count++));
        local current_epoch=$(__get_current_epoch);
        
        # Execute WHOIS query
        if ! whois_output=$(__whois_query "$domain"); then
            error "WHOIS query failed, stopping monitoring";
            return 3;
        fi;
        
        # Extract domain information
        domain_status=$(__extract_domain_status "$whois_output");
        registrar=$(__extract_registrar "$whois_output");
        
        # Check for pattern match
        if _check_pattern_match "$whois_output" "$expect_pattern" "$domain_status"; then
            matched=1;
            break;
        fi;
        
        # Check max checks limit
        if [[ "$max_checks" -gt 0 && "$check_count" -ge "$max_checks" ]]; then
            warn "Maximum checks (%d) reached" "$max_checks";
            break;
        fi;
        
        # Calculate next poll interval based on phase
        local phase=$(_determine_phase "$target_epoch" "$current_epoch");
        local time_to_target=$((target_epoch - current_epoch));
        local next_interval=$(_calculate_interval "$base_interval" "$phase" "$time_to_target");
        
        # Enhanced phase transition detection
        if [[ "$phase" != "$previous_phase" && -n "$previous_phase" ]]; then
            _announce_phase_transition "$previous_phase" "$phase" "$time_to_target";
        fi;
        previous_phase="$phase";
        
        # Display enhanced live status line
        local status_line;
        status_line=$(_format_enhanced_status_line "$domain" "$next_interval" "$target_epoch" "$current_epoch" "$whois_output" "$expect_pattern" "$use_utc" "$check_count");
        _print_live_line "$status_line";
        
        # Check grace period timeout
        if _check_grace_timeout "$target_epoch" "$current_epoch" "$domain"; then
            break;
        fi;
        
        # Sleep until next poll
        trace "Sleeping %ss until next poll (phase: %s)" "$next_interval" "$phase";
        sleep "$next_interval";
    done;
    
    # Calculate total monitoring time
    local end_epoch=$(__get_current_epoch);
    local total_time=$(_human_time $((end_epoch - start_epoch)));
    local activity=$(_get_activity_code "$whois_output" "$expect_pattern");
    
    # Enhanced completion message with celebration
    _format_enhanced_completion_message "$matched" "$domain" "$domain_status" "$registrar" "$total_time" "$activity" "$end_epoch" "$check_count";
    
    return $((1 - matched));  # 0 if matched, 1 if not
}

################################################################################
# _announce_phase_transition - Announce phase changes prominently
################################################################################
_announce_phase_transition() {
    local old_phase="$1";
    local new_phase="$2";
    local time_to_target="$3";
    
    local old_glyph new_glyph old_color new_color;
    old_glyph=$(_get_phase_glyph "$old_phase");
    new_glyph=$(_get_phase_glyph "$new_phase");
    old_color=$(_get_phase_color "$old_phase");
    new_color=$(_get_phase_color "$new_phase");
    
    printf "\n\n%s%s Phase Transition %s%s\n" "$yellow" "$spark" "$spark" "$x";
    printf "%s%s %s%s %s→%s %s%s %s%s\n" "$old_color" "$old_glyph" "$old_phase" "$x" "$yellow" "$x" "$new_color" "$new_glyph" "$new_phase" "$x";
    
    case "$new_phase" in
        (HEAT)
            printf "%sEntering aggressive polling phase - target approaching!%s\n" "$red" "$x";
            ;;
        (GRACE)
            printf "%sTarget time reached - entering grace period monitoring%s\n" "$purple" "$x";
            ;;
        (COOL)
            printf "%sEntering cooldown phase - backing off polling frequency%s\n" "$cyan" "$x";
            ;;
    esac;
    printf "\n";
}

################################################################################
# _format_enhanced_status_line - Enhanced status line with better formatting
################################################################################
_format_enhanced_status_line() {
    local domain="$1";
    local next_poll_seconds="$2";
    local target_epoch="$3";
    local current_epoch="$4";
    local whois_output="$5";
    local expect_pattern="${6:-}";
    local use_utc="${7:-0}";
    local check_count="$8";
    
    local phase glyph color activity timer target_time time_mode check_display;
    
    # Determine phase and get visual elements
    phase=$(_determine_phase "$target_epoch" "$current_epoch");
    glyph=$(_get_phase_glyph "$phase");
    color=$(_get_phase_color "$phase");
    
    # Determine activity
    activity=$(_get_activity_code "$whois_output" "$expect_pattern");
    
    # Format timer (next poll countdown)
    timer=$(_format_timer "$next_poll_seconds");
    
    # Format target time distance
    if [[ "$target_epoch" -gt 0 ]]; then
        local time_to_target=$((target_epoch - current_epoch));
        target_time=$(_format_target_time "$time_to_target");
    else
        target_time="none";
    fi;
    
    # Time mode indicator
    time_mode=$([ "$use_utc" -eq 1 ] && echo "UTC" || echo "LOCAL");
    
    # Check count display
    check_display="[#$check_count]";
    
    # Build enhanced status line with better spacing
    printf "%s%s %s%s │ %s │ %s │ %s │ %s │ %s %s%s" \
        "$color" "$glyph" "$phase" "$x" \
        "$activity" \
        "$timer" \
        "$target_time" \
        "$domain" \
        "$time_mode" \
        "$check_display" \
        "$x";
}

################################################################################
# _format_enhanced_completion_message - Celebration and detailed completion
################################################################################
_format_enhanced_completion_message() {
    local success="$1";
    local domain="$2";
    local domain_status="$3";
    local registrar="$4";
    local total_time="$5";
    local activity="$6";
    local completion_epoch="$7";
    local total_checks="$8";
    
    local symbol color completion_time result_text celebration;
    
    # Format completion time (12h with am/pm)
    completion_time=$(_format_completion_time "$completion_epoch");
    
    # Determine success/failure styling and celebration
    if [[ "$success" -eq 0 ]]; then
        symbol="$pass";
        color="$green";
        celebration="🎉";
        case "$activity" in
            (DROP)  result_text="Domain Drop Detected!" ;;
            (AVAL)  result_text="Domain Available!" ;;
            (PTRN)  result_text="Pattern Matched!" ;;
            (EXPR)  result_text="Expiration Detected!" ;;
            (*)     result_text="Success!" ;;
        esac;
    else
        symbol="$fail";
        color="$red";
        celebration="⏰";
        case "$activity" in
            (DROP)  result_text="Drop Monitoring Timeout" ;;
            (AVAL)  result_text="Availability Check Timeout" ;;
            (PTRN)  result_text="Pattern Search Timeout" ;;
            (EXPR)  result_text="Expiration Watch Timeout" ;;
            (*)     result_text="Monitoring Timeout" ;;
        esac;
    fi;
    
    # Enhanced completion display
    printf "\n\n%s%s%s Monitoring Complete %s%s%s\n\n" "$color" "$celebration" "$spark" "$spark" "$celebration" "$x";
    printf "%s%s %s%s at %s\n" "$color" "$symbol" "$result_text" "$x" "$completion_time";
    printf "\n%sResults:%s\n" "$white" "$x";
    printf "  %sDomain:%s     %s\n" "$white" "$x" "$domain";
    printf "  %sStatus:%s     %s\n" "$white" "$x" "$domain_status";
    printf "  %sRegistrar:%s  %s\n" "$white" "$x" "$registrar";
    printf "  %sDuration:%s   %s\n" "$white" "$x" "$total_time";
    printf "  %sChecks:%s     %d queries\n" "$white" "$x" "$total_checks";
    printf "  %sActivity:%s   %s monitoring\n" "$white" "$x" "$activity";
    
    # Add trailing completion record for history
    _add_completion_history "$domain" "$domain_status" "$registrar" "$total_time" "$completion_time" "$success";
}

################################################################################
# _add_completion_history - Add completed poll to trailing history
################################################################################
_add_completion_history() {
    local domain="$1";
    local status="$2";
    local registrar="$3";
    local duration="$4";
    local time_done="$5";
    local success="$6";
    
    local result_icon;
    result_icon=$([ "$success" -eq 0 ] && echo "$pass" || echo "$fail");
    
    # Format as trailing grey history entry
    printf "\n%sDone%s %s %s at %s │ %s %s │ %s │ %s │ %s\n" \
        "$grey" "$x" "$result_icon" "$time_done" \
        "$domain" "$status" "$registrar" "$duration" \
        $([ "$success" -eq 0 ] && echo "SUCCESS" || echo "TIMEOUT");
}

################################################################################
# Remaining do_* functions with standard formatting
################################################################################

################################################################################
# do_time - Standalone time countdown mode with enhanced display
################################################################################
do_time() {
    local target_time="$1";
    local use_utc="${opt_time_utc:-0}";
    local target_epoch;
    
    # Validate and parse target time
    if ! target_epoch=$(__parse_epoch "$target_time"); then
        error "Invalid target time: %s" "$target_time";
        return 4;
    fi;
    
    printf "\n%s%s Time Countdown Mode %s%s\n" "$blue" "$lambda" "$lambda" "$x";
    info "Target: %s" "$(__format_time_display "$target_epoch" "$use_utc")";
    
    # Enhanced countdown display
    _format_countdown "$target_epoch" "$(__get_current_epoch)" "$use_utc";
    
    return 0;
}

################################################################################
# Standard do_* functions (unchanged)
################################################################################
do_list_tlds() {
    printf "\n%s%s Supported TLD Configurations %s%s\n\n" "$blue" "$lambda" "$lambda" "$x";
    
    # Load user config
    _load_tld_config;
    
    printf "%-8s %-25s %s\n" "TLD" "WHOIS Server" "Available Pattern";
    printf "%-8s %-25s %s\n" "---" "------------" "-----------------";
    
    # Show built-in and user-configured TLDs
    local tld server pattern;
    for tld in "${!TLD_REGISTRY[@]}"; do
        IFS='|' read -r server pattern <<< "${TLD_REGISTRY[$tld]}";
        printf "%-8s %-25s %s\n" "$tld" "$server" "$pattern";
    done;
    
    printf "\nUser configuration file: %s\n" "$WATCHDOM_RC";
    
    return 0;
}

do_add_tld() {
    local tld="$1";
    local server="$2";
    local pattern="$3";
    
    # Validate inputs
    if [[ -z "$tld" || -z "$server" || -z "$pattern" ]]; then
        error "Usage: add_tld TLD WHOIS_SERVER AVAILABLE_PATTERN";
        return 2;
    fi;
    
    # Ensure TLD starts with dot
    [[ "$tld" != .* ]] && tld=".$tld";
    
    # Add to user configuration
    echo "$tld|$server|$pattern" >> "$WATCHDOM_RC";
    
    okay "Added TLD configuration: %s -> %s | %s" "$tld" "$server" "$pattern";
    return 0;
}

do_test_tld() {
    local tld="$1";
    local test_domain="$2";
    
    if [[ -z "$tld" || -z "$test_domain" ]]; then
        error "Usage: test_tld TLD TEST_DOMAIN";
        return 2;
    fi;
    
    # Load configuration
    _load_tld_config;
    
    # Get TLD configuration
    local config server pattern;
    config=$(_get_tld_config "$test_domain");
    IFS='|' read -r server pattern <<< "$config";
    
    printf "\n%s%s TLD Test Results %s%s\n" "$blue" "$lambda" "$lambda" "$x";
    printf "TLD: %s\n" "$tld";
    printf "Test domain: %s\n" "$test_domain";
    printf "WHOIS server: %s\n" "${server:-default}";
    printf "Expected pattern: %s\n" "${pattern:-available}";
    
    # Execute test query
    local whois_output;
    if whois_output=$(__whois_query "$test_domain"); then
        printf "\n%sPattern Match Test:%s\n" "$yellow" "$x";
        if echo "$whois_output" | grep -qi "${pattern:-available}"; then
            printf "%s%s Pattern MATCHED%s\n" "$green" "$pass" "$x";
            return 0;
        else
            printf "%s%s Pattern NOT matched%s\n" "$red" "$fail" "$x";
            return 1;
        fi;
    else
        error "WHOIS query failed for test domain";
        return 3;
    fi;
}
