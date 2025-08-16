################################################################################
# formatters (_*) - visual display and status line formatting
################################################################################

################################################################################
# _determine_phase - Calculate current polling phase
################################################################################
_determine_phase() {
    local target_epoch="$1"
    local current_epoch="$2"
    local time_diff=$((target_epoch - current_epoch))
    
    # No target set = POLL phase
    if [[ "$target_epoch" -eq 0 ]]; then
        echo "POLL"
        return 0
    fi
    
    # Before target
    if [[ $time_diff -gt $HEAT_THRESHOLD ]]; then
        echo "POLL"  # More than 30 minutes = normal polling
    elif [[ $time_diff -gt 0 ]]; then
        echo "HEAT"  # Approaching target = aggressive polling
    elif [[ $((current_epoch - target_epoch)) -lt $GRACE_THRESHOLD ]]; then
        echo "GRACE" # Just past target = grace period
    else
        echo "COOL"  # Way past target = cooling down
    fi
}

################################################################################
# _get_activity_code - Determine what the poller is doing
################################################################################
_get_activity_code() {
    local whois_output="$1"
    local expect_pattern="${2:-}"
    
    # Custom pattern specified
    if [[ -n "$expect_pattern" ]]; then
        echo "PTRN"
        return 0
    fi
    
    # Analyze WHOIS output to determine activity
    if echo "$whois_output" | grep -qi "pending.*delete\|pendingdelete"; then
        echo "DROP"   # Waiting for domain drop
    elif echo "$whois_output" | grep -qi "no match\|not found\|available"; then
        echo "AVAL"   # Checking availability
    elif echo "$whois_output" | grep -qi "expir\|expires"; then
        echo "EXPR"   # Tracking expiration
    elif echo "$whois_output" | grep -qi "hold\|lock\|suspend"; then
        echo "STAT"   # Monitoring status changes
    else
        echo "POLL"   # General polling
    fi
}

################################################################################
# _format_status_line - Create live polling status line
################################################################################
_format_status_line() {
    local domain="$1"
    local next_poll_seconds="$2"
    local target_epoch="$3"
    local current_epoch="$4"
    local whois_output="$5"
    local expect_pattern="${6:-}"
    local use_utc="${7:-0}"
    
    local phase glyph color activity timer target_time time_mode
    
    # Determine phase and get visual elements
    phase=$(_determine_phase "$target_epoch" "$current_epoch")
    glyph=$(_get_phase_glyph "$phase")
    color=$(_get_phase_color "$phase")
    
    # Determine activity
    activity=$(_get_activity_code "$whois_output" "$expect_pattern")
    
    # Format timer (next poll countdown)
    timer=$(_format_timer "$next_poll_seconds")
    
    # Format target time distance
    if [[ "$target_epoch" -gt 0 ]]; then
        local time_to_target=$((target_epoch - current_epoch))
        target_time=$(_format_target_time "$time_to_target")
    else
        target_time="none"
    fi
    
    # Time mode indicator
    time_mode=$([ "$use_utc" -eq 1 ] && echo "UTC" || echo "LOCAL")
    
    # Build status line
    printf "%s%s %s%s | %s | %s | %s | %s | %s" \
        "$color" "$glyph" "$phase" "$x" \
        "$activity" \
        "$timer" \
        "$target_time" \
        "$domain" \
        "$time_mode"
}

################################################################################
# _print_live_line - Print status line with cursor control
################################################################################
_print_live_line() {
    local status_line="$1"
    
    # Clear current line and print status
    printf "\r\033[K%s" "$status_line"
}

################################################################################
# _format_completion_message - Format final completion message  
################################################################################
_format_completion_message() {
    local success="$1"          # 0=success, 1=failure/timeout
    local domain="$2"
    local domain_status="$3"    # AVAILABLE, REGISTERED, etc.
    local registrar="$4"        # VERISIGN, GODADDY, etc.
    local total_time="$5"       # Total monitoring time
    local activity="$6"         # What we were doing
    local completion_epoch="$7"
    
    local symbol color completion_time result_text
    
    # Format completion time (12h with am/pm)
    completion_time=$(_format_completion_time "$completion_epoch")
    
    # Determine success/failure styling and text
    if [[ "$success" -eq 0 ]]; then
        symbol="$pass"
        color="$green"
        case "$activity" in
            (DROP)  result_text="DROP success" ;;
            (AVAL)  result_text="AVAL success" ;;
            (PTRN)  result_text="PTRN matched" ;;
            (EXPR)  result_text="EXPR detected" ;;
            (*)     result_text="POLL success" ;;
        esac
    else
        symbol="$fail"
        color="$red"
        case "$activity" in
            (DROP)  result_text="DROP timeout" ;;
            (AVAL)  result_text="AVAL timeout" ;;
            (PTRN)  result_text="PTRN timeout" ;;
            (EXPR)  result_text="EXPR timeout" ;;
            (*)     result_text="POLL timeout" ;;
        esac
    fi
    
    # Print completion message
    printf "\n%s%s %s at %s | %s %s | %s | %s%s\n" \
        "$color" "$symbol" "$result_text" "$completion_time" \
        "$domain" "$domain_status" "$registrar" "$total_time" "$x"
}

################################################################################
# _format_countdown - Format countdown display (FIX: was returning empty)
################################################################################
_format_countdown() {
    local target_epoch="$1"
    local current_epoch="${2:-$(__get_current_epoch)}"
    local use_utc="${3:-0}"
    
    local time_diff target_display current_display remaining_display
    
    # Calculate time difference
    time_diff=$((target_epoch - current_epoch))
    
    # Format target time
    target_display=$(__format_time_display "$target_epoch" "$use_utc")
    
    # Format current time  
    current_display=$(__format_time_display "$current_epoch" "$use_utc")
    
    # Format remaining time
    if [[ $time_diff -gt 0 ]]; then
        remaining_display="$(_human_time "$time_diff") remaining"
    elif [[ $time_diff -eq 0 ]]; then
        remaining_display="TARGET REACHED"
    else
        remaining_display="$(_human_time $((time_diff * -1))) past target"
    fi
    
    # Print formatted countdown
    printf "%s\n" "$remaining_display"
    printf "Target: %s\n" "$target_display"
    printf "Current: %s\n" "$current_display"
}

################################################################################
# _calculate_interval - Calculate polling interval based on phase
################################################################################
_calculate_interval() {
    local base_interval="$1"
    local phase="$2"
    local time_to_target="$3"
    
    local interval="$base_interval"
    
    case "$phase" in
        (POLL)
            # Normal polling - use base interval
            interval="$base_interval"
            ;;
        (HEAT)
            # Aggressive polling as target approaches
            if [[ $time_to_target -le 300 ]]; then      # <= 5 minutes
                interval=10
            elif [[ $time_to_target -le 1800 ]]; then   # <= 30 minutes
                interval=30
            else
                interval="$base_interval"
            fi
            ;;
        (GRACE)
            # Continue aggressive polling just past target
            interval=10
            ;;
        (COOL)
            # Back off with longer intervals
            interval=$((base_interval * 2))
            [[ $interval -gt 3600 ]] && interval=3600  # Max 1 hour
            ;;
        (*)
            interval="$base_interval"
            ;;
    esac
    
    echo "$interval"
}