# Primary domain watching function
do_watch() {
    local domain="${1:-}"
    local ret=1
    
    # User-level validation (high-order function responsibility)
    if [[ -z "$domain" ]]; then 
        error "Domain required for watch command"
        usage
        return 2
    fi
    
    # Validate dependencies
    if ! command -v whois >/dev/null 2>&1; then
        fatal "Required command 'whois' not found"
    fi
    
    # Validate domain format
    if ! _validate_domain "$domain"; then
        fatal "Invalid domain format: %s" "$domain"
    fi
    
    # Load TLD configurations
    _load_tld_config
    
    # Get TLD configuration
    local config server pattern
    config=$(_get_tld_config "$domain")
    if [[ $? -ne 0 || -z "$config" ]]; then
        local tld
        tld=$(_extract_tld "$domain")
        fatal "TLD %s not supported yet. Use 'add_tld' to add support." "$tld"
    fi
    
    IFS='|' read -r server pattern <<< "$config"
    
    # CRITICAL FIX: Pattern override (-e) must take precedence over TLD config
    if [[ -n "${opt_expect:-}" ]]; then
        pattern="$opt_expect"
        trace "Using pattern override: %s" "$pattern"
    fi
    
    # Validate interval (user-level validation)
    local interval="${opt_interval:-$DEFAULT_INTERVAL}"
    if [[ ! "$interval" =~ ^[0-9]+$ ]] || (( interval <= 0 )); then
        fatal "Invalid interval: %s (must be positive integer)" "$interval"
    fi
    
    if [[ "$interval" -lt 10 ]]; then
        warn "Interval %ss is aggressive; consider >=30s" "$interval"
    fi
    
    # Parse target time if provided
    local target_epoch=""
    local grace_start_epoch=""
    if [[ -n "${opt_until:-}" ]]; then
        target_epoch=$(__parse_datetime "$opt_until")
        if [[ $? -ne 0 ]]; then
            fatal "Cannot parse target time: %s" "$opt_until"
        fi
        grace_start_epoch=$((target_epoch + 10800))  # 3 hours after target
    fi
    
    # Display initial information
    info "Watching %s via %s; base interval=%ss; expect=/%s/i" \
        "$domain" "$server" "$interval" "$pattern"
    
    if [[ -n "$target_epoch" ]]; then
        if [[ "${opt_time_local:-0}" -eq 1 ]]; then
            info "Target Local: %s (epoch %s)" \
                "$(__format_date "$target_epoch" "local")" "$target_epoch"
        else
            info "Target UTC  : %s" "$(__format_date "$target_epoch" "utc")"
            info "Target Local: %s (epoch %s)" \
                "$(__format_date "$target_epoch" "local")" "$target_epoch"
        fi
    fi
    
    info "(Ctrl-C to stop)"
    
    # Main polling loop
    local count=0
    local target_alerted=0
    
    while :; do
        local now_epoch
        now_epoch=$(date -u +%s)
        
        # Calculate effective interval and phase
        local calc_result eff_interval phase
        calc_result=$(_calculate_interval "$interval" "$target_epoch" "$grace_start_epoch" "$now_epoch")
        if [[ $? -ne 0 ]]; then
            error "Failed to calculate polling interval"
            return 1
        fi
        
        IFS='|' read -r eff_interval phase <<< "$calc_result"
        
        # Warn about aggressive intervals
        if (( eff_interval < 10 )); then
            warn "Effective interval %ss may trigger rate limits" "$eff_interval"
        fi
        
        # Execute whois query
        local timestamp output
        timestamp="$(date -Is)"
        output=$(__whois_query "$domain" "$server")
        
        # Check for success pattern
        if printf "%s" "$output" | grep -Eiq -- "$pattern"; then
            okay "Pattern matched for %s" "$domain"
            printf "%s" "$output" | sed -n '1,20p'
            _notify_event "success" "$domain" "Detected at $(date)"
            return 0
        else
            trace "No match yet - effective interval %ss" "$eff_interval"
        fi
        
        # Check target time alerts
        if [[ -n "$target_epoch" ]]; then
            local time_since_target=$((now_epoch - target_epoch))
            
            # Target reached notification (once)
            if (( time_since_target >= 0 && target_alerted == 0 )); then
                warn "TARGET INTERVAL reached"
                _notify_event "target_reached" "$domain" "Target: $(__format_date "$target_epoch" "utc")"
                target_alerted=1
            fi
            
            # Grace period check
            _check_grace_timeout "$target_epoch" "$now_epoch" "$domain"
        fi
        
        # Check max polls limit
        count=$((count + 1))
        if [[ "${opt_max_checks:-0}" -gt 0 && "$count" -ge "${opt_max_checks}" ]]; then
            info "Max checks (%s) reached without matching pattern" "${opt_max_checks}"
            return 1
        fi
        
        # Dynamic countdown between polls
        local r
        for (( r=eff_interval; r>=1; r-- )); do
            now_epoch=$(date -u +%s)
            local time_info=""
            
            if [[ -n "$target_epoch" ]]; then
                local delta=$((target_epoch - now_epoch))
                if (( delta > 0 )); then
                    time_info="target in $(__human_duration "$delta")"
                else
                    time_info="target since $(__human_duration $((-delta)))"
                fi
                
                if [[ "${opt_time_local:-0}" -eq 1 ]]; then
                    time_info+=" | Local: $(__format_date "$target_epoch" "local")"
                else
                    time_info+=" | UTC: $(__format_date "$target_epoch" "utc") | Local: $(__format_date "$target_epoch" "local")"
                fi
            fi
            
            local status_line
            status_line=$(_format_countdown "$phase" "$r" "$time_info")
            __print_status_line "$status_line"
            sleep 1
        done
        
        # Clear status line
        printf "\r%80s\r" "" >&2
    done
}#!/usr/bin/env bash
# watchdom - registry WHOIS watcher with dynamic countdown
# version: 2.0.0-bashfx
# portable: whois, date, grep, sed
# builtins: printf, read, local, declare, case, if, for, while

################################################################################
# readonly
################################################################################
readonly SELF_NAME="watchdom"
readonly SELF_VERSION="2.0.0-bashfx"  
readonly SELF_PATH="$(realpath "${BASH_SOURCE[0]}")"
readonly SELF_DIR="$(dirname "$SELF_PATH")"
readonly WATCHDOM_RC="$HOME/.watchdomrc"

# XDG+ compliant paths for BashFX framework
readonly XDG_HOME="${HOME}/.local"
readonly XDG_LIB="${XDG_HOME}/lib"
readonly XDG_BIN="${XDG_HOME}/bin"
readonly XDG_ETC="${XDG_HOME}/etc"

# BashFX namespace paths (first-party code goes in /fx/)
readonly FX_LIB_DIR="${XDG_LIB}/fx"
readonly FX_INSTALL_PATH="${FX_LIB_DIR}/${SELF_NAME}"
readonly FX_BIN_LINK="${XDG_BIN}/${SELF_NAME}"

################################################################################
# config  
################################################################################
# Default settings (overridable by environment)
DEFAULT_INTERVAL="${WATCHDOM_INTERVAL:-60}"
DEFAULT_MAX_CHECKS="${WATCHDOM_MAX_CHECKS:-0}"
DEFAULT_TIME_LOCAL="${WATCHDOM_TIME_LOCAL:-0}"

# Email notification settings (all must be set to enable notifications)
NOTIFY_EMAIL="${NOTIFY_EMAIL:-}"           # Recipient email (e.g., "user@domain.com")
NOTIFY_FROM="${NOTIFY_FROM:-}"            # Sender email (e.g., "watchdom@server.com")  
NOTIFY_SMTP_HOST="${NOTIFY_SMTP_HOST:-}"       # SMTP server (e.g., "smtp.gmail.com")
NOTIFY_SMTP_PORT="${NOTIFY_SMTP_PORT:-}"       # SMTP port (e.g., "587")
NOTIFY_SMTP_USER="${NOTIFY_SMTP_USER:-}"       # SMTP username
NOTIFY_SMTP_PASS="${NOTIFY_SMTP_PASS:-}"       # SMTP password or app token

################################################################################
# escape sequences
################################################################################
readonly red2=$'\x1B[38;5;197m'
readonly red=$'\x1B[31m'
readonly yellow=$'\x1B[33m'
readonly green=$'\x1B[32m'
readonly blue=$'\x1B[36m'
readonly purple=$'\x1B[38;5;213m'
readonly cyan=$'\x1B[38;5;14m'
readonly grey=$'\x1B[38;5;244m'
readonly x=$'\x1B[0m'
readonly eol=$'\x1B[K'

# Glyphs
readonly pass=$'\u2713'
readonly fail=$'\u2715' 
readonly uclock=$'\u23F1'
readonly delta=$'\xE2\x96\xB3'
readonly lambda=$'\xCE\xBB'
readonly spark=$'\u273B'

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# notification system
################################################################################
_is_notify_configured() {
    [[ -n "$NOTIFY_EMAIL" && -n "$NOTIFY_FROM" && -n "$NOTIFY_SMTP_HOST" && 
       -n "$NOTIFY_SMTP_PORT" && -n "$NOTIFY_SMTP_USER" && -n "$NOTIFY_SMTP_PASS" ]]
}

_notify_event() {
    local event="$1"    # "success"|"target_reached"|"grace_entered"
    local domain="$2"
    local details="$3"
    
    _is_notify_configured || return 0
    
    case "$event" in
        (success)
            __send_email "Domain Available: $domain" "SUCCESS: $domain is now available for registration!\n\nDetails: $details"
            ;;
        (target_reached)
            __send_email "Target Time Reached: $domain" "Target time reached for $domain monitoring.\n\nEntering grace period...\n\nDetails: $details"
            ;;
        (grace_entered)
            __send_email "Grace Period: $domain" "Grace period exceeded for $domain (3+ hours past target).\n\nDetails: $details"
            ;;
    esac
}

__send_email() {
    local subject="$1"
    local body="$2"
    local ret=1
    
    # Try mutt first (most common)
    if command -v mutt >/dev/null 2>&1; then
        printf "%s" "$body" | mutt -s "$subject" "$NOTIFY_EMAIL" 2>/dev/null
        ret=$?
    # Fallback to msmtp + mail
    elif command -v msmtp >/dev/null 2>&1 && command -v mail >/dev/null 2>&1; then
        printf "%s" "$body" | mail -s "$subject" "$NOTIFY_EMAIL" 2>/dev/null
        ret=$?
    # Fallback to sendmail if available
    elif command -v sendmail >/dev/null 2>&1; then
        {
            printf "To: %s\n" "$NOTIFY_EMAIL"
            printf "From: %s\n" "$NOTIFY_FROM"
            printf "Subject: %s\n\n" "$subject"
            printf "%s\n" "$body"
        } | sendmail "$NOTIFY_EMAIL" 2>/dev/null
        ret=$?
    fi
    
    if [[ $ret -eq 0 ]]; then
        trace "Email notification sent: $subject"
    else
        warn "Failed to send email notification"
    fi
    
    return $ret
}

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################

# Extract TLD from domain (handle edge cases)
_extract_tld() {
    local domain="$1"
    local tld=""
    
    # Remove any protocol prefix
    domain="${domain#*://}"
    # Remove any path suffix
    domain="${domain%%/*}"
    # Get the TLD portion
    tld=".${domain##*.}"
    
    printf "%s" "$tld"
    return 0
}

# Load TLD configurations from built-in and ~/.watchdomrc
_load_tld_config() {
    local ret=0
    
    # Initialize built-in TLDs
    _init_builtin_tlds
    
    # Load user config if it exists
    if [[ -f "$WATCHDOM_RC" ]]; then
        local line tld server pattern
        while IFS='|' read -r tld server pattern; do
            # Skip comments and empty lines
            [[ "$tld" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$tld" ]] && continue
            
            # Store in arrays
            TLD_SERVERS["$tld"]="$server"
            TLD_PATTERNS["$tld"]="$pattern"
            trace "Loaded custom TLD: %s -> %s" "$tld" "$server"
        done < "$WATCHDOM_RC"
    fi
    
    return $ret
}

# Validate domain format
_validate_domain() {
    local domain="$1"
    
    # Basic domain validation - helper function, no user-level guards
    if [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$ ]]; then
        return 0
    fi
    
    return 1
}

# Get TLD configuration for a domain
_get_tld_config() {
    local domain="$1"
    local tld=""
    local server=""
    local pattern=""
    local ret=1
    
    tld=$(_extract_tld "$domain")
    
    if [[ -n "${TLD_SERVERS[$tld]:-}" ]]; then
        server="${TLD_SERVERS[$tld]}"
        pattern="${TLD_PATTERNS[$tld]}"
        printf "%s|%s" "$server" "$pattern"
        ret=0
    fi
    
    return $ret
}

# Determine current phase and calculate interval
_calculate_interval() {
    local base_interval="$1"
    local target_epoch="$2"
    local grace_start_epoch="$3"
    local now_epoch="$4"
    local ret=0
    local interval="$base_interval"
    local phase="PRE"
    
    if [[ -z "$target_epoch" ]]; then
        # No target time set, use base interval
        printf "%s|%s" "$interval" "$phase"
        return $ret
    fi
    
    local time_to_target=$((target_epoch - now_epoch))
    local time_since_target=$((now_epoch - target_epoch))
    
    if (( time_to_target > 1800 )); then
        # PRE: >30min before target
        phase="PRE"
        interval="$base_interval"
    elif (( time_to_target > 0 )); then
        # HEAT: <=30min before target
        phase="HEAT"
        if (( time_to_target <= 300 )); then
            interval=10
        else
            interval=30
        fi
    elif (( time_since_target <= 10800 )); then
        # GRACE: 0-3hrs after target (10800 = 3 * 60 * 60)
        phase="GRACE"
        interval=10
    else
        # COOL: >3hrs after target - progressive cooldown
        phase="COOL"
        local grace_elapsed=$((time_since_target - 10800))
        
        if (( grace_elapsed <= 600 )); then        # 0-10min past grace
            interval=30
        elif (( grace_elapsed <= 1200 )); then     # 10-20min past grace
            interval=60
        elif (( grace_elapsed <= 1800 )); then     # 20-30min past grace
            interval=300    # 5min
        elif (( grace_elapsed <= 3600 )); then     # 30-60min past grace
            interval=600    # 10min
        elif (( grace_elapsed <= 7200 )); then     # 1-2hrs past grace
            interval=1800   # 30min
        else                                        # 2+ hrs past grace
            interval=3600   # 1hr
        fi
    fi
    
    printf "%s|%s" "$interval" "$phase"
    return $ret
}

# Format countdown display with phase-aware styling
_format_countdown() {
    local phase="$1"
    local interval="$2"
    local time_info="$3"
    local color glyph label
    
    case "$phase" in
        (PRE)
            color="$blue"
            glyph="$lambda"
            label="[PRE]"
            ;;
        (HEAT)
            color="$red"
            glyph="$delta"
            label="[HEAT]"
            ;;
        (GRACE)
            color="$purple"
            glyph="$delta"
            label="[GRACE]"
            ;;
        (COOL)
            color="$cyan"
            glyph="$spark"
            label="[COOL]"
            ;;
        (*)
            color="$grey"
            glyph="$uclock"
            label="[POLL]"
            ;;
    esac
    
    printf "%s%s%s next poll in %ss | %s | %s%s" \
        "$color" "$glyph" "$x" "$interval" "$time_info" "$label" "$eol"
}

# Check if grace period exceeded and prompt user
_check_grace_timeout() {
    local target_epoch="$1"
    local now_epoch="$2"
    local domain="$3"
    local grace_prompted_file="/tmp/.watchdom_grace_prompted_$"
    local ret=0
    
    [[ -z "$target_epoch" ]] && return 0
    
    local time_since_target=$((now_epoch - target_epoch))
    
    # Check if we just entered the extended grace period (3+ hours)
    if (( time_since_target > 10800 )); then
        # Only prompt once per session using temp file
        if [[ ! -f "$grace_prompted_file" ]]; then
            local grace_hours=$((time_since_target / 3600))
            warn "Grace period expired (%d hours past target)" "$grace_hours"
            _notify_event "grace_entered" "$domain" "Exceeded at $(date)"
            
            # Create marker file to prevent re-prompting
            touch "$grace_prompted_file"
            
            printf "\n%sGrace period expired (3hrs past target). Continue watching?%s\n" "$yellow" "$x" >&2
            printf "[y] Yes, keep 1hr intervals\n" >&2
            printf "[n] No, exit\n" >&2
            printf "[c] Custom interval (specify seconds)\n" >&2
            printf "Choice [y/n/c]: " >&2
            
            local choice
            read -r choice
            
            case "${choice,,}" in
                (n|no)
                    info "Exiting per user request"
                    rm -f "$grace_prompted_file"
                    exit 0
                    ;;
                (c|custom)
                    printf "Enter custom interval in seconds: " >&2
                    local custom_interval
                    read -r custom_interval
                    if [[ "$custom_interval" =~ ^[0-9]+$ ]] && (( custom_interval > 0 )); then
                        # Override the base interval for future calculations
                        DEFAULT_INTERVAL="$custom_interval"
                        info "Using custom interval: %s seconds" "$custom_interval"
                    else
                        warn "Invalid interval, using 1hr default"
                    fi
                    ;;
                (*)
                    info "Continuing with 1hr intervals"
                    ;;
            esac
        fi
    fi
    
    return $ret
}

################################################################################
# complex helpers  
################################################################################

# Parse datetime string to epoch
__parse_datetime() {
    local when="$1"
    local epoch=""
    
    # Check if already epoch seconds
    if [[ "$when" =~ ^[0-9]+$ ]]; then
        printf "%s" "$when"
        return 0
    fi
    
    # Try different date parsing methods
    if epoch=$(date -u -d "$when" +%s 2>/dev/null); then
        printf "%s" "$epoch"
        return 0
    elif command -v gdate >/dev/null 2>&1 && epoch=$(gdate -u -d "$when" +%s 2>/dev/null); then
        printf "%s" "$epoch"
        return 0
    elif epoch=$(date -u -j -f "%Y-%m-%d %H:%M:%S %Z" "$when" +%s 2>/dev/null); then
        printf "%s" "$epoch"
        return 0
    fi
    
    return 1
}

# Execute whois query with error handling
__whois_query() {
    local domain="$1"
    local server="$2"
    local ret=1
    local output=""
    
    if output=$(whois -h "$server" "$domain" 2>/dev/null); then
        printf "%s" "$output"
        ret=0
    fi
    
    return $ret
}

# Print status line with cursor control
__print_status_line() {
    local text="$1"
    printf "\r%s" "$text" >&2
}

# Save TLD configuration to ~/.watchdomrc
__save_tld_config() {
    local tld="$1"
    local server="$2" 
    local pattern="$3"
    local ret=1
    
    # Create file if it doesn't exist
    if [[ ! -f "$WATCHDOM_RC" ]]; then
        printf "# watchdom TLD configuration\n# Format: TLD|SERVER|PATTERN\n" > "$WATCHDOM_RC"
    fi
    
    # Append new configuration
    printf "%s|%s|%s\n" "$tld" "$server" "$pattern" >> "$WATCHDOM_RC"
    ret=$?
    
    return $ret
}

# Test if TLD pattern works for given domain
__test_tld_pattern() {
    local tld="$1"
    local test_domain="$2"
    local ret=1
    local config server pattern output
    
    config=$(_get_tld_config "$test_domain")
    if [[ $? -eq 0 && -n "$config" ]]; then
        IFS='|' read -r server pattern <<< "$config"
        output=$(__whois_query "$test_domain" "$server")
        
        if printf "%s" "$output" | grep -Eiq -- "$pattern"; then
            ret=0
        fi
    fi
    
    return $ret
}

# Convert seconds to human readable format
__human_duration() {
    local s="$1"
    local d h m out=""
    
    (( d=s/86400, s%=86400, h=s/3600, s%=3600, m=s/60, s%=60 ))
    [[ $d -gt 0 ]] && out+="${d}d "
    [[ $h -gt 0 ]] && out+="${h}h "
    [[ $m -gt 0 ]] && out+="${m}m "
    out+="${s}s"
    
    printf "%s" "$out"
}

# Format date for display with improved cross-platform support
__format_date() {
    local epoch="$1"
    local format="$2"  # "utc" or "local"
    local ret=1
    
    # Validate epoch input
    if [[ ! "$epoch" =~ ^[0-9]+$ ]]; then
        printf "INVALID_DATE"
        return 1
    fi
    
    case "$format" in
        (utc)
            # Try multiple methods for UTC formatting
            if date -u -d "@$epoch" "+%a %b %d %H:%M:%S UTC %Y" 2>/dev/null; then
                ret=0
            elif date -u -r "$epoch" "+%a %b %d %H:%M:%S UTC %Y" 2>/dev/null; then
                ret=0
            elif command -v gdate >/dev/null 2>&1 && gdate -u -d "@$epoch" "+%a %b %d %H:%M:%S UTC %Y" 2>/dev/null; then
                ret=0
            else
                # Fallback for very limited systems
                printf "UTC_TIME_EPOCH_%s" "$epoch"
                ret=1
            fi
            ;;
        (local)
            # Try multiple methods for local formatting
            if date -d "@$epoch" "+%a %b %d %H:%M:%S %Z %Y" 2>/dev/null; then
                ret=0
            elif date -r "$epoch" "+%a %b %d %H:%M:%S %Z %Y" 2>/dev/null; then
                ret=0
            elif command -v gdate >/dev/null 2>&1 && gdate -d "@$epoch" "+%a %b %d %H:%M:%S %Z %Y" 2>/dev/null; then
                ret=0
            else
                # Fallback for very limited systems
                printf "LOCAL_TIME_EPOCH_%s" "$epoch"
                ret=1
            fi
            ;;
        (*)
            printf "INVALID_FORMAT"
            ret=1
            ;;
    esac
    
    return $ret
}

################################################################################
# api functions
################################################################################

# Primary domain watching function
do_watch() {
    local domain="${1:-}"
    local ret=1
    
    [[ -z "$domain" ]] && { error "Domain required for watch command"; return 1; }
    
    # Validate dependencies
    command -v whois >/dev/null 2>&1 || fatal "Required command 'whois' not found"
    
    # Validate domain format
    _validate_domain "$domain" || fatal "Invalid domain format: %s" "$domain"
    
    # Load TLD configurations
    _load_tld_config
    
    # Get TLD configuration
    local config server pattern
    config=$(_get_tld_config "$domain")
    if [[ $? -ne 0 || -z "$config" ]]; then
        local tld
        tld=$(_extract_tld "$domain")
        fatal "TLD %s not supported yet. Use 'add_tld' to add support." "$tld"
    fi
    
    IFS='|' read -r server pattern <<< "$config"
    
    # Override pattern if -e flag provided
    if [[ -n "${opt_expect:-}" ]]; then
        pattern="$opt_expect"
        trace "Using pattern override: %s" "$pattern"
    fi
    
    # Validate interval
    local interval="${opt_interval:-$DEFAULT_INTERVAL}"
    [[ "$interval" -lt 10 ]] && warn "Interval %ss is aggressive; consider >=30s" "$interval"
    
    # Parse target time if provided
    local target_epoch=""
    local grace_start_epoch=""
    if [[ -n "${opt_until:-}" ]]; then
        target_epoch=$(__parse_datetime "$opt_until")
        [[ $? -ne 0 ]] && fatal "Cannot parse target time: %s" "$opt_until"
        grace_start_epoch=$((target_epoch + 10800))  # 3 hours after target
    fi
    
    # Display initial information
    info "Watching %s via %s; base interval=%ss; expect=/%s/i" \
        "$domain" "$server" "$interval" "$pattern"
    
    if [[ -n "$target_epoch" ]]; then
        if [[ "${opt_time_local:-0}" -eq 1 ]]; then
            info "Target Local: %s (epoch %s)" \
                "$(__format_date "$target_epoch" "local")" "$target_epoch"
        else
            info "Target UTC  : %s" "$(__format_date "$target_epoch" "utc")"
            info "Target Local: %s (epoch %s)" \
                "$(__format_date "$target_epoch" "local")" "$target_epoch"
        fi
    fi
    
    info "(Ctrl-C to stop)"
    
    # Main polling loop
    local count=0
    local target_alerted=0
    local grace_alerted=0
    
    while :; do
        local now_epoch
        now_epoch=$(date -u +%s)
        
        # Calculate effective interval and phase
        local calc_result eff_interval phase
        calc_result=$(_calculate_interval "$interval" "$target_epoch" "$grace_start_epoch" "$now_epoch")
        IFS='|' read -r eff_interval phase <<< "$calc_result"
        
        # Warn about aggressive intervals
        (( eff_interval < 10 )) && warn "Effective interval %ss may trigger rate limits" "$eff_interval"
        
        # Execute whois query
        local timestamp output
        timestamp="$(date -Is)"
        output=$(__whois_query "$domain" "$server")
        
        # Check for success pattern
        if printf "%s" "$output" | grep -Eiq -- "$pattern"; then
            okay "Pattern matched for %s" "$domain"
            printf "%s" "$output" | sed -n '1,20p'
            _notify_event "success" "$domain" "Detected at $(date)"
            return 0
        else
            trace "No match yet - effective interval %ss" "$eff_interval"
        fi
        
        # Check target time alerts
        if [[ -n "$target_epoch" ]]; then
            local time_since_target=$((now_epoch - target_epoch))
            
            # Target reached notification (once)
            if (( time_since_target >= 0 && target_alerted == 0 )); then
                warn "TARGET INTERVAL reached"
                _notify_event "target_reached" "$domain" "Target: $(__format_date "$target_epoch" "utc")"
                target_alerted=1
            fi
            
            # Grace period check
            _check_grace_timeout "$target_epoch" "$now_epoch" "$domain"
        fi
        
        # Check max polls limit
        count=$((count + 1))
        if [[ "${opt_max_checks:-0}" -gt 0 && "$count" -ge "${opt_max_checks}" ]]; then
            info "Max checks (%s) reached without matching pattern" "${opt_max_checks}"
            return 1
        fi
        
        # Dynamic countdown between polls
        local r
        for (( r=eff_interval; r>=1; r-- )); do
            now_epoch=$(date -u +%s)
            local time_info=""
            
            if [[ -n "$target_epoch" ]]; then
                local delta=$((target_epoch - now_epoch))
                if (( delta > 0 )); then
                    time_info="target in $(__human_duration "$delta")"
                else
                    time_info="target since $(__human_duration $((-delta)))"
                fi
                
                if [[ "${opt_time_local:-0}" -eq 1 ]]; then
                    time_info+=") | Local: $(__format_date "$target_epoch" "local")"
                else
                    time_info+=" | UTC: $(__format_date "$target_epoch" "utc") | Local: $(__format_date "$target_epoch" "local")"
                fi
            fi
            
            local status_line
            status_line=$(_format_countdown "$phase" "$r" "$time_info")
            __print_status_line "$status_line"
            sleep 1
        done
        
        # Clear status line
        printf "\r%80s\r" "" >&2
    done
}

# Time-only mode (no WHOIS)
do_time() {
    local when="${1:-}"
    local ret=0
    
    [[ -z "$when" ]] && { error "Time argument required for time command"; return 1; }
    
    local target_epoch
    target_epoch=$(__parse_datetime "$when")
    [[ $? -ne 0 ]] && { error "Cannot parse time: %s" "$when"; return 1; }
    
    local now_epoch
    now_epoch=$(date -u +%s)
    local remaining=$((target_epoch - now_epoch))
    
    if (( remaining < 0 )); then
        if [[ "${opt_time_local:-0}" -eq 1 ]]; then
            printf "Remaining (Local): 0s (time passed)\n"
        else
            printf "Remaining: 0s (time passed)\n"
        fi
    else
        if [[ "${opt_time_local:-0}" -eq 1 ]]; then
            printf "Remaining (Local): %s\n" "$(__human_duration "$remaining")"
        else
            printf "Remaining: %s\n" "$(__human_duration "$remaining")"
        fi
    fi
    
    if [[ "${opt_time_local:-0}" -eq 1 ]]; then
        printf "Target Local: %s\n" "$(__format_date "$target_epoch" "local")"
    else
        printf "Target UTC  : %s\n" "$(__format_date "$target_epoch" "utc")"
        printf "Target Local: %s\n" "$(__format_date "$target_epoch" "local")"
    fi
    
    printf "UNTIL_EPOCH=%s\n" "$target_epoch"
    return $ret
}

# List supported TLD patterns
do_list_tlds() {
    local ret=0
    
    _load_tld_config
    
    printf "Supported TLD patterns:\n\n"
    printf "%-8s %-25s %s\n" "TLD" "WHOIS SERVER" "AVAILABLE PATTERN"
    printf "%-8s %-25s %s\n" "---" "------------" "-----------------"
    
    local tld
    for tld in "${!TLD_SERVERS[@]}"; do
        printf "%-8s %-25s %s\n" "$tld" "${TLD_SERVERS[$tld]}" "${TLD_PATTERNS[$tld]}"
    done | sort
    
    printf "\nConfiguration sources:\n"
    printf "  Built-in: .com, .net, .org\n"
    if [[ -f "$WATCHDOM_RC" ]]; then
        printf "  User config: %s\n" "$WATCHDOM_RC"
    else
        printf "  User config: %s (not found)\n" "$WATCHDOM_RC"
    fi
    
    return $ret
}

# Add custom TLD configuration
do_add_tld() {
    local tld="${1:-}"
    local server="${2:-}"
    local pattern="${3:-}"
    local ret=1
    
    # User-level validation (high-order function responsibility)
    if [[ -z "$tld" || -z "$server" || -z "$pattern" ]]; then
        error "Usage: add_tld TLD SERVER PATTERN"
        error "Example: add_tld .uk whois.nominet.uk \"No such domain\""
        usage
        return 2
    fi
    
    # Ensure TLD starts with dot
    [[ "$tld" =~ ^\. ]] || tld=".$tld"
    
    # Validate TLD format (user-level validation)
    if [[ ! "$tld" =~ ^\.[a-zA-Z0-9-]+$ ]]; then
        error "Invalid TLD format: %s (should be like .com, .org, .uk)" "$tld"
        return 2
    fi
    
    # Validate server format (user-level validation)
    if [[ ! "$server" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        error "Invalid server format: %s (should be like whois.example.com)" "$server"
        return 2
    fi
    
    # Validate pattern is not empty (user-level validation)
    if [[ -z "$pattern" || "$pattern" =~ ^[[:space:]]*$ ]]; then
        error "Pattern cannot be empty"
        return 2
    fi
    
    # Check if TLD already exists
    _load_tld_config
    if [[ -n "${TLD_SERVERS[$tld]:-}" ]]; then
        warn "TLD %s already configured with server %s" "$tld" "${TLD_SERVERS[$tld]}"
        if [[ "${opt_force:-0}" -ne 1 ]]; then
            error "Use -f to force override existing configuration"
            return 1
        fi
    fi
    
    # Save to config file
    if __save_tld_config "$tld" "$server" "$pattern"; then
        okay "Added TLD configuration: %s -> %s" "$tld" "$server"
        trace "Pattern: %s" "$pattern"
        ret=0
    else
        error "Failed to save TLD configuration"
        ret=1
    fi
    
    return $ret
}

# Test TLD pattern against a domain
do_test_tld() {
    local tld="${1:-}"
    local test_domain="${2:-}"
    local ret=1
    
    # User-level validation (high-order function responsibility)
    if [[ -z "$tld" || -z "$test_domain" ]]; then
        error "Usage: test_tld TLD DOMAIN"
        error "Example: test_tld .com nonexistent-test-domain.com"
        usage
        return 2
    fi
    
    # Ensure TLD starts with dot
    [[ "$tld" =~ ^\. ]] || tld=".$tld"
    
    # Validate domain format (user-level validation)
    if ! _validate_domain "$test_domain"; then
        error "Invalid domain format: %s" "$test_domain"
        return 2
    fi
    
    _load_tld_config
    
    # Check if TLD is configured (user-level validation)
    if [[ -z "${TLD_SERVERS[$tld]:-}" ]]; then
        error "TLD %s is not configured" "$tld"
        error "Use 'list_tlds' to see supported TLDs or 'add_tld' to add support"
        return 1
    fi
    
    local server="${TLD_SERVERS[$tld]}"
    local pattern="${TLD_PATTERNS[$tld]}"
    
    info "Testing TLD %s against domain %s" "$tld" "$test_domain"
    info "Server: %s" "$server"
    info "Pattern: %s" "$pattern"
    
    # Execute test
    local output
    output=$(__whois_query "$test_domain" "$server")
    if [[ $? -ne 0 ]]; then
        error "Failed to query whois server %s" "$server"
        return 1
    fi
    
    if printf "%s" "$output" | grep -Eiq -- "$pattern"; then
        okay "Pattern MATCHED - domain appears available"
        ret=0
    else
        warn "Pattern NOT matched - domain may be registered or pattern incorrect"
        info "First 10 lines of whois output:"
        printf "%s" "$output" | sed -n '1,10p' | sed 's/^/  /'
        ret=1
    fi
    
    return $ret
}

# Install watchdom to XDG+ compliant location
do_install() {
    local ret=1
    local force="${opt_force:-0}"
    
    info "Installing %s v%s..." "$SELF_NAME" "$SELF_VERSION"
    
    # Check if already installed
    if [[ -L "$FX_BIN_LINK" ]] && [[ "$force" -eq 0 ]]; then
        warn "%s is already installed at %s" "$SELF_NAME" "$FX_BIN_LINK"
        error "Use -f to force reinstall"
        return 1
    fi
    
    # Create XDG+ directory structure
    if ! mkdir -p "$FX_LIB_DIR" "$XDG_BIN"; then
        error "Failed to create installation directories"
        return 1
    fi
    
    # Copy script to FX library location
    if ! cp "$SELF_PATH" "$FX_INSTALL_PATH"; then
        error "Failed to copy script to %s" "$FX_INSTALL_PATH"
        return 1
    fi
    
    # Make executable
    if ! chmod +x "$FX_INSTALL_PATH"; then
        error "Failed to make script executable"
        return 1
    fi
    
    # Create symlink in bin directory
    if ! ln -sf "../lib/fx/$SELF_NAME" "$FX_BIN_LINK"; then
        error "Failed to create symlink at %s" "$FX_BIN_LINK"
        return 1
    fi
    
    okay "Installed %s to %s" "$SELF_NAME" "$FX_INSTALL_PATH"
    okay "Created symlink at %s" "$FX_BIN_LINK"
    
    # Check if ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":$XDG_BIN:"* ]]; then
        warn "Add %s to your PATH to use %s from anywhere:" "$XDG_BIN" "$SELF_NAME"
        printf "  export PATH=\"%s:\$PATH\"\n" "$XDG_BIN" >&2
    else
        info "%s is now available system-wide" "$SELF_NAME"
    fi
    
    ret=0
    return $ret
}

# Uninstall watchdom (rewindable operation)
do_uninstall() {
    local ret=1
    local removed_items=0
    
    info "Uninstalling %s..." "$SELF_NAME"
    
    # Remove symlink
    if [[ -L "$FX_BIN_LINK" ]]; then
        if rm "$FX_BIN_LINK"; then
            okay "Removed symlink: %s" "$FX_BIN_LINK"
            removed_items=$((removed_items + 1))
        else
            error "Failed to remove symlink: %s" "$FX_BIN_LINK"
        fi
    fi
    
    # Remove installed script
    if [[ -f "$FX_INSTALL_PATH" ]]; then
        if rm "$FX_INSTALL_PATH"; then
            okay "Removed script: %s" "$FX_INSTALL_PATH"
            removed_items=$((removed_items + 1))
        else
            error "Failed to remove script: %s" "$FX_INSTALL_PATH"
        fi
    fi
    
    # Clean up empty directories (be careful not to remove user data)
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
        ret=0
    fi
    
    return $ret
}

# Show installation status
do_status() {
    local ret=0
    
    printf "watchdom v%s - Installation Status\n\n" "$SELF_VERSION"
    
    # Check current script location
    printf "Current script: %s\n" "$SELF_PATH"
    
    # Check installation status
    if [[ -f "$FX_INSTALL_PATH" ]]; then
        printf "Installed at  : %s ✓\n" "$FX_INSTALL_PATH"
    else
        printf "Installed at  : %s ✗\n" "$FX_INSTALL_PATH"
        ret=1
    fi
    
    # Check symlink status
    if [[ -L "$FX_BIN_LINK" ]]; then
        local link_target
        link_target="$(readlink "$FX_BIN_LINK")"
        printf "Symlink       : %s -> %s ✓\n" "$FX_BIN_LINK" "$link_target"
    else
        printf "Symlink       : %s ✗\n" "$FX_BIN_LINK"
        ret=1
    fi
    
    # Check PATH
    if [[ ":$PATH:" == *":$XDG_BIN:"* ]]; then
        printf "PATH includes : %s ✓\n" "$XDG_BIN"
    else
        printf "PATH includes : %s ✗\n" "$XDG_BIN"
    fi
    
    # Check user config
    if [[ -f "$WATCHDOM_RC" ]]; then
        local tld_count
        tld_count="$(grep -c '^[^#]' "$WATCHDOM_RC" 2>/dev/null || echo 0)"
        printf "User config   : %s (%s custom TLDs) ✓\n" "$WATCHDOM_RC" "$tld_count"
    else
        printf "User config   : %s ✗\n" "$WATCHDOM_RC"
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
# dispatch
################################################################################
dispatch() {
    local cmd="${1:-}"
    local ret=1
    
    case "$cmd" in
        (watch)
            shift
            do_watch "$@"
            ret=$?
            ;;
        (time)
            shift  
            do_time "$@"
            ret=$?
            ;;
        (list_tlds)
            shift
            do_list_tlds "$@"
            ret=$?
            ;;
        (add_tld)
            shift
            do_add_tld "$@"
            ret=$?
            ;;
        (test_tld)
            shift
            do_test_tld "$@"
            ret=$?
            ;;
        (install)
            shift
            do_install "$@"
            ret=$?
            ;;
        (uninstall)
            shift
            do_uninstall "$@"
            ret=$?
            ;;
        (status)
            shift
            do_status "$@"
            ret=$?
            ;;
        (*)
            # Legacy compatibility - if first arg looks like a domain, assume 'watch'
            if [[ -n "$cmd" && "$cmd" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                do_watch "$@"
                ret=$?
            else
                error "Unknown command: %s" "$cmd"
                usage
                ret=1
            fi
            ;;
    esac
    
    return $ret
}

################################################################################
# usage
################################################################################
usage() {
    cat <<'EOF'
watchdom v2.0.0-bashfx - registry WHOIS watcher with dynamic countdown

USAGE:
  # Domain watching
  watchdom [watch] DOMAIN [OPTIONS]
  watchdom DOMAIN [OPTIONS]                    # Legacy compatibility
  
  # Time utilities  
  watchdom time "YYYY-MM-DD HH:MM:SS UTC"     # Time countdown only
  watchdom time EPOCH_SECONDS                 # Time countdown only
  
  # TLD management
  watchdom list_tlds                          # Show supported TLDs
  watchdom add_tld TLD SERVER PATTERN         # Add custom TLD support
  watchdom test_tld TLD DOMAIN                # Test TLD pattern
  
  # Installation management
  watchdom install                            # Install to ~/.local/lib/fx/
  watchdom uninstall                          # Remove installation
  watchdom status                             # Show installation status

OPTIONS:
  Standard BashFX flags:
    -d, --debug     Enable info/okay/warn messages  
    -t, --trace     Enable trace messages (verbose polling)
    -q, --quiet     Force quiet mode
    -f, --force     Skip safety guards
    -D, --dev       Developer mode (implies -d -t)
  
  Domain watching flags:
    -i SECONDS      Base poll interval (default: 60)
    -e REGEX        Override expected pattern
    -n MAX_CHECKS   Stop after N checks (default: unlimited)
    --until WHEN    Target datetime or epoch seconds
    --time_local    Display timestamps in local time only

POLLING PHASES:
  [PRE]   >30min before target: base interval (blue λ)
  [HEAT]  ≤30min before target: ramp to 10s (red ▲) 
  [GRACE] 0-3hrs after target: stick at 10s (purple △)
  [COOL]  >3hrs after target: progressive cooldown (cyan ❄)

EMAIL NOTIFICATIONS:
  Set all variables to enable email alerts:
    NOTIFY_EMAIL, NOTIFY_FROM, NOTIFY_SMTP_HOST,
    NOTIFY_SMTP_PORT, NOTIFY_SMTP_USER, NOTIFY_SMTP_PASS

EXAMPLES:
  watchdom example.com -i 30                  # Watch with 30s base interval
  watchdom watch example.com --until "2025-12-25 18:00:00 UTC"
  watchdom time "2025-12-25 18:00:00 UTC"     # Time countdown only
  watchdom list_tlds                          # Show supported TLDs
  watchdom add_tld .uk whois.nominet.uk "No such domain"
  watchdom test_tld .com test-domain.com      # Test pattern
  watchdom install                            # Install system-wide
  watchdom status                             # Check installation

EXIT CODES:
  0: Success (pattern matched)
  1: Not found (max checks reached or user exit)
  2: Bad arguments
  3: Missing dependencies
  4: Date parse error
EOF
}

################################################################################
# options
################################################################################
options() {
    # Initialize option variables
    opt_debug=0
    opt_trace=0
    opt_quiet=0
    opt_force=0
    opt_dev=0
    opt_interval=""
    opt_expect=""
    opt_max_checks=""
    opt_until=""
    opt_time_local=0
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            (-d|--debug)
                opt_debug=1
                shift
                ;;
            (-t|--trace)
                opt_trace=1
                opt_debug=1  # Trace implies debug
                shift
                ;;
            (-q|--quiet)
                opt_quiet=1
                opt_debug=0
                opt_trace=0
                shift
                ;;
            (-f|--force)
                opt_force=1
                shift
                ;;
            (-D|--dev)
                opt_dev=1
                opt_debug=1
                opt_trace=1
                shift
                ;;
            (-i)
                shift
                [[ $# -ge 1 ]] || { error "Option -i requires an argument"; return 2; }
                opt_interval="$1"
                shift
                ;;
            (-e)
                shift
                [[ $# -ge 1 ]] || { error "Option -e requires an argument"; return 2; }
                opt_expect="$1"
                shift
                ;;
            (-n)
                shift
                [[ $# -ge 1 ]] || { error "Option -n requires an argument"; return 2; }
                opt_max_checks="$1"
                shift
                ;;
            (--until)
                shift
                [[ $# -ge 1 ]] || { error "Option --until requires an argument"; return 2; }
                opt_until="$1"
                shift
                ;;
            (--time_local)
                opt_time_local=1
                shift
                ;;
            (--time_until)
                # Legacy compatibility for --time-until
                shift
                [[ $# -ge 1 ]] || { error "Option --time_until requires an argument"; return 2; }
                # Convert to 'time' command
                do_time "$1"
                exit $?
                ;;
            (-h|--help)
                usage
                exit 0
                ;;
            (--)
                shift
                break
                ;;
            (-*)
                error "Unknown option: %s" "$1"
                usage
                return 2
                ;;
            (*)
                # Non-option argument, stop processing options
                break
                ;;
        esac
    done
    
    # Apply quiet mode if set
    if [[ "$opt_quiet" -eq 1 ]]; then
        opt_debug=0
        opt_trace=0
    fi
    
    return 0
}

################################################################################
# main
################################################################################

# Cleanup function for graceful shutdown
_cleanup() {
    local grace_file="/tmp/.watchdom_grace_prompted_$"
    [[ -f "$grace_file" ]] && rm -f "$grace_file"
    printf "\n" >&2
    info "Monitoring stopped"
    exit 130  # 128 + SIGINT
}

main() {
    local ret=1
    
    # Set up signal handling for graceful shutdown
    trap '_cleanup' INT TERM
    
    # Parse options first
    options "$@" || return $?
    
    # Remove processed options from argument list
    local args=()
    local skip_next=0
    
    for arg in "$@"; do
        if [[ $skip_next -eq 1 ]]; then
            skip_next=0
            continue
        fi
        
        case "$arg" in
            (-d|--debug|-t|--trace|-q|--quiet|-f|--force|-D|--dev|--time_local|-h|--help|--)
                continue
                ;;
            (-i|-e|-n|--until|--time_until)
                skip_next=1
                continue
                ;;
            (-*)
                continue
                ;;
            (*)
                args+=("$arg")
                ;;
        esac
    done
    
    # Dispatch to appropriate command
    if [[ ${#args[@]} -eq 0 ]]; then
        error "No command or domain specified"
        usage
        return 2
    fi
    
    dispatch "${args[@]}"
    ret=$?
    
    return $ret
}

################################################################################
# invocation
################################################################################
main "$@"