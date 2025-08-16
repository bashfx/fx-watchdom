################################################################################
# literals (__*) - atomic operations (PHASE 1 CRITICAL FIXES)
################################################################################

################################################################################
# __parse_epoch - FIX: Returns empty epochs
################################################################################
__parse_epoch() {
    local when="$1";
    local epoch="";
    
    # If already epoch, return it
    if [[ "$when" =~ ^[0-9]+$ ]]; then
        echo "$when";
        return 0;
    fi
    
    # Try GNU date first (most common)
    if epoch=$(date -u -d "$when" +%s 2>/dev/null); then
        echo "$epoch";
        return 0;
    fi
    
    # Try BSD date (macOS)
    if epoch=$(date -u -j -f "%Y-%m-%d %H:%M:%S" "$when" +%s 2>/dev/null); then
        echo "$epoch";
        return 0;
    fi
    
    # Try gdate (macOS with GNU coreutils)
    if command -v gdate >/dev/null 2>&1; then
        if epoch=$(gdate -u -d "$when" +%s 2>/dev/null); then
            echo "$epoch";
            return 0;
        fi
    fi
    
    # Last resort: try common format variations
    local formatted_when;
    # Handle common input variations
    formatted_when=$(echo "$when" | sed 's/UTC$//' | sed 's/  */ /g' | sed 's/^ *//' | sed 's/ *$//');
    
    if epoch=$(date -u -d "$formatted_when UTC" +%s 2>/dev/null); then
        echo "$epoch";
        return 0;
    fi
    
    error "Cannot parse datetime: %s" "$when";
    return 1;
}

################################################################################
# __whois_query - FIX: No domain status extraction
################################################################################
__whois_query() {
    local domain="$1";
    local whois_output="";
    local ret=0;
    
    # Check if whois command exists
    if ! command -v whois >/dev/null 2>&1; then
        error "Required command 'whois' not found"
        return 3;
    fi
    
    trace "Executing WHOIS query for %s" "$domain"
    
    # Execute whois with timeout and error handling
    if ! whois_output=$(timeout 30 whois "$domain" 2>/dev/null); then
        error "WHOIS query failed for %s (timeout or network error)" "$domain"
        return 1;
    fi
    
    # Check for empty output
    if [[ -z "$whois_output" ]]; then
        error "WHOIS query returned empty result for %s" "$domain"
        return 1;
    fi
    
    # Check for rate limiting
    if echo "$whois_output" | grep -Eqi "$RATE_LIMIT_PATTERN"; then
        error "Rate limited by WHOIS server for %s" "$domain"
        return 2;
    fi
    
    trace "WHOIS query completed successfully for %s" "$domain"
    echo "$whois_output"
    return 0;
}

################################################################################
# __extract_domain_status - FIX: Missing lifecycle info
################################################################################
__extract_domain_status() {
    local whois_output="$1";
    local status="UNKNOWN";
    
    # Check for availability patterns (most specific first)
    if echo "$whois_output" | grep -qi "no match for\|not found\|no entries found\|available"; then
        status="AVAILABLE";
    elif echo "$whois_output" | grep -qi "pending.*delete\|pendingdelete"; then
        status="PENDING-DELETE";
    elif echo "$whois_output" | grep -qi "client.*hold\|server.*hold"; then
        status="ON-HOLD";
    elif echo "$whois_output" | grep -qi "redemption.*period\|rgp"; then
        status="REDEMPTION";
    elif echo "$whois_output" | grep -qi "domain.*name.*server\|name.*server"; then
        status="REGISTERED";
    elif echo "$whois_output" | grep -qi "reserved\|premium"; then
        status="RESERVED";
    fi
    
    echo "$status"
}

################################################################################
# __extract_registrar - Extract registrar information
################################################################################
__extract_registrar() {
    local whois_output="$1";
    local registrar="UNKNOWN";
    
    # Try to extract registrar name
    if registrar=$(echo "$whois_output" | grep -i "registrar:" | head -1 | sed 's/.*registrar: *//i' | sed 's/ *$//' | tr -d '\r'); then
        [[ -n "$registrar" ]] && echo "$registrar" && return 0
    fi
    
    # Try alternative patterns
    if registrar=$(echo "$whois_output" | grep -i "sponsoring registrar:" | head -1 | sed 's/.*sponsoring registrar: *//i' | sed 's/ *$//' | tr -d '\r'); then
        [[ -n "$registrar" ]] && echo "$registrar" && return 0
    fi
    
    # Default patterns for major registries
    if echo "$whois_output" | grep -qi "verisign"; then
        echo "VERISIGN"
    elif echo "$whois_output" | grep -qi "godaddy"; then
        echo "GODADDY"
    elif echo "$whois_output" | grep -qi "namecheap"; then
        echo "NAMECHEAP"
    else
        echo "UNKNOWN"
    fi
}

################################################################################
# __get_current_epoch - Current time as epoch
################################################################################
__get_current_epoch() {
    date +%s
}

################################################################################
# __format_time_display - Format time for display
################################################################################
__format_time_display() {
    local epoch="$1";
    local use_utc="${2:-0}";
    
    if [[ "$use_utc" -eq 1 ]]; then
        date -u -d "@$epoch" "+%a %b %d %H:%M:%S UTC %Y" 2>/dev/null || date -u -r "$epoch" "+%a %b %d %H:%M:%S UTC %Y"
    else
        date -d "@$epoch" "+%a %b %d %H:%M:%S %Z %Y" 2>/dev/null || date -r "$epoch" "+%a %b %d %H:%M:%S %Z %Y"
    fi
}