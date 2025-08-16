################################################################################
# simple stderr (BashFX compliant logging)
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# utility helpers
################################################################################
_human_time() {
    local s=$1 d h m
    ((d=s/86400, s%=86400, h=s/3600, s%=3600, m=s/60, s%=60))
    local out=""
    [[ $d -gt 0 ]] && out+="${d}d "
    [[ $h -gt 0 ]] && out+="${h}h "
    [[ $m -gt 0 ]] && out+="${m}m "
    out+="${s}s"
    echo "$out"
}

_format_timer() {
    local seconds="$1"
    
    if [[ $seconds -lt 60 ]]; then
        # Use "30s" format for seconds only
        echo "${seconds}s"
    elif [[ $seconds -lt 3600 ]]; then
        # Use "5:30" format for minutes:seconds
        printf "%d:%02d" $((seconds/60)) $((seconds%60))
    elif [[ $seconds -lt 86400 ]]; then
        # Use "1:30:27" format for hours:minutes:seconds
        printf "%d:%02d:%02d" $((seconds/3600)) $(((seconds%3600)/60)) $((seconds%60))
    else
        # Use "2d 1:30:27" format for days + time
        local days=$((seconds/86400))
        local remaining=$((seconds%86400))
        printf "%dd %d:%02d:%02d" $days $((remaining/3600)) $(((remaining%3600)/60)) $((remaining%60))
    fi
}

_format_target_time() {
    local seconds="$1"
    local sign=""
    
    # Handle negative time (past target)
    if [[ $seconds -lt 0 ]]; then
        sign="-"
        seconds=$((seconds * -1))
    fi
    
    # Use same format as timer but with sign
    echo "${sign}$(_format_timer "$seconds")"
}

_format_completion_time() {
    local epoch="$1"
    # 12h format with am/pm lowercase
    date -d "@$epoch" "+%-I:%M:%S %P" 2>/dev/null || date -r "$epoch" "+%-I:%M:%S %P"
}

_cleanup() {
    local grace_files
    grace_files=$(find /tmp -name ".watchdom_grace_*_$$" 2>/dev/null || true)
    if [[ -n "$grace_files" ]]; then
        rm -f $grace_files 2>/dev/null || true
    fi
    printf "\n" >&2
    info "Monitoring stopped"
    exit 130
}