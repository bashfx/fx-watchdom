#!/usr/bin/env bash
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
    
    # Try mutt first (most common) - use config files to avoid credential exposure
    if command -v mutt >/dev/null 2>&1; then
        # Create temporary config to avoid credential exposure in process list
        local temp_config="/tmp/.watchdom_mutt_$$"
        {
            printf "set smtp_url=\"smtp://%s:%s@%s:%s/\"\n" \
                "$NOTIFY_SMTP_USER" "$NOTIFY_SMTP_PASS" "$NOTIFY_SMTP_HOST" "$NOTIFY_SMTP_PORT"
            printf "set from=\"%s\"\n" "$NOTIFY_FROM"
            printf "set realname=\"watchdom\"\n"
        } > "$temp_config"
        
        printf "%s" "$body" | mutt -F "$temp_config" -s "$subject" "$NOTIFY_EMAIL" 2>/dev/null
        ret=$?
        rm -f "$temp_config"
        
    # Fallback to msmtp + mail if available
    elif command -v msmtp >/dev/null 2>&1 && command -v mail >/dev/null 2>&1; then
        # Use environment variables for msmtp (more secure than command line)
        export MSMTP_HOST="$NOTIFY_SMTP_HOST"
        export MSMTP_PORT="$NOTIFY_SMTP_PORT" 
        export MSMTP_USER="$NOTIFY_SMTP_USER"
        export MSMTP_PASS="$NOTIFY_SMTP_PASS"
        
        printf "%s" "$body" | mail -s "$subject" "$NOTIFY_EMAIL" 2>/dev/null
        ret=$?
        
        # Clean up environment
        unset MSMTP_HOST MSMTP_PORT MSMTP_USER MSMTP_PASS
        
    # Fallback to sendmail if available
    elif command -v sendmail >/dev/null 2>&1; then
        # sendmail doesn't expose credentials in process list
        {
            printf "To: %s\n" "$NOTIFY_EMAIL"
            printf "From: %s\n" "$NOTIFY_FROM"
            printf "Subject: %s\n\n" "$subject"
            printf "%s\n" "$body"
        } | sendmail "$NOTIFY_EMAIL" 2>/dev/null
        ret=$?
    fi
    
    if [[ $ret -eq 0 ]]; then
        trace "Email notification sent: %s" "$subject"
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
    local grace_start_epoch="$3"  # Not used currently, reserved for future
    local now_epoch="$4"
    local ret=0
    local interval="$base_interval"
    local phase="PRE"
    
    # Validate inputs
    if [[ ! "$base_interval" =~ ^[0-9]+$ ]] || (( base_interval <= 0 )); then
        error "Invalid base interval: %s" "$base_interval"
        return 1
    fi
    
    if [[ -z "$target_epoch" ]]; then
        # No target time set, use base interval
        printf "%s|%s" "$interval" "$phase"
        return $ret
    fi
    
    # Validate epoch times
    if [[ ! "$target_epoch" =~ ^[0-9]+$ ]] || [[ ! "$now_epoch" =~ ^[0-9]+$ ]]; then
        error "Invalid epoch time values"
        return 1
    fi
    
    local time_to_target=$((target_epoch - now_epoch))
    local time_since_target=$((now_epoch - target_epoch))
    
    # Phase determination with clear boundaries
    if (( time_to_target > 1800 )); then
        # PRE: >30min before target
        phase="PRE"
        interval="$base_interval"
    elif (( time_to_target > 0 )); then
        # HEAT: ≤30min before target (between 0 and 30min)
        phase="HEAT"
        if (( time_to_target <= 300 )); then
            interval=10  # ≤5min: aggressive
        else
            interval=30  # 5-30min: moderate ramp
        fi
    elif (( time_since_target <= 10800 )); then
        # GRACE: 0-3hrs after target (10800 = 3 * 60 * 60)
        phase="GRACE"
        interval=10
    else
        # COOL: >3hrs after target - progressive cooldown
        phase="COOL"
        local grace_elapsed=$((time_since_target - 10800))
        
        # Progressive cooldown with clear boundaries
        if (( grace_elapsed <= 600 )); then        # 0-10min past grace (600s)
            interval=30
        elif (( grace_elapsed <= 1200 )); then     # 10-20min past grace (1200s)
            interval=60     # 1min
        elif (( grace_elapsed <= 1800 )); then     # 20-30min past grace (1800s)
            interval=300    # 5min
        elif (( grace_elapsed <= 3600 )); then     # 30-60min past grace (3600s)
            interval=600    # 10min
        elif (( grace_elapsed <= 7200 )); then     # 1-2hrs past grace (7200s)
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
    # Create unique filename per domain to avoid conflicts with concurrent runs
    local domain_hash
    domain_hash="$(printf "%s" "$domain" | md5sum 2>/dev/null | cut -d' ' -f1 || printf "%s" "$domain" | cksum | cut -d' ' -f1)"
    local grace_prompted_file="/tmp/.watchdom_grace_${domain_hash}_$$"
    local ret=0
    
    [[ -z "$target_epoch" ]] && return 0
    
    local time_since_target=$((target_epoch - now_epoch))
    
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
            printf "Remaining (Local): 0s (