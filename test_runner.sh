#!/usr/bin/env bash
# test_runner.sh - Validate watchdom features without spamming WHOIS servers
# Updated for Phase 2: Enhanced UX Testing

set -euo pipefail;

# Colors for test output
readonly green=$'\033[32m';
readonly red=$'\033[31m';
readonly blue=$'\033[34m';
readonly yellow=$'\033[33m';
readonly purple=$'\033[35m';
readonly cyan=$'\033[36m';
readonly x=$'\033[38;5;244m';

# Test counters
TOTAL_TESTS=0;
PASSED_TESTS=0;
FAILED_TESTS=0;
FAILED_DESCRIPTIONS=();

# Configuration
WATCHDOM_SCRIPT="./watchdom_fixed.sh";

print_header() { 
    printf "\n%s=== %s ===%s\n" "$blue" "$1" "$x"; 
}

print_test() {
    ((TOTAL_TESTS++));
    printf "\n%s[%02d]%s %s" "$yellow" "$TOTAL_TESTS" "$x" "$1";
}

print_pass() { 
    ((PASSED_TESTS++)); 
    printf " %s[PASS]%s\n" "$green" "$x"; 
}

print_fail() {
    ((FAILED_TESTS++));
    FAILED_DESCRIPTIONS+=("Test $TOTAL_TESTS: $1");
    printf " %s[FAIL]%s\n" "$red" "$x";
    [[ -n "${2:-}" ]] && printf "    Reason: %s\n" "$2";
}

print_summary() {
    print_header "Test Summary";
    if [[ $FAILED_TESTS -eq 0 ]]; then
        printf "%sResult: All %d tests passed! 🎉%s\n" "$green" "$TOTAL_TESTS" "$x";
        exit 0;
    else
        printf "%sResult: %d/%d tests passed. %d failed.%s\n" "$red" "$PASSED_TESTS" "$TOTAL_TESTS" "$FAILED_TESTS" "$x";
        printf "\n%sFailed tests:%s\n" "$yellow" "$x";
        for desc in "${FAILED_DESCRIPTIONS[@]}"; do 
            printf "  - %s\n" "$desc"; 
        done;
        exit 1;
    fi;
}

# Test internal functions
test_internal_functions() {
    print_header "Phase 1: Internal Function Tests";
    
    # Source script and check if it loads without errors
    print_test "Script sourcing and syntax validation";
    if source "$WATCHDOM_SCRIPT" 2>/dev/null; then
        print_pass;
    else
        print_fail "Script failed to source" "Syntax errors prevent testing";
        return 1;
    fi;
    
    # Test date parsing
    print_test "Date parsing (__parse_epoch)";
    local test_epoch;
    if test_epoch=$(__parse_epoch "2025-12-25 18:00:00 UTC") && [[ -n "$test_epoch" && "$test_epoch" =~ ^[0-9]+$ ]]; then
        print_pass;
    else
        print_fail "__parse_epoch returned empty" "Got: '$test_epoch'";
    fi;
    
    # Test timer formatting
    print_test "Timer formatting (_format_timer)";
    local timer_30s timer_90s timer_3660s;
    timer_30s=$(_format_timer 30);
    timer_90s=$(_format_timer 90);
    timer_3660s=$(_format_timer 3660);
    
    if [[ "$timer_30s" == "30s" && "$timer_90s" == "1:30" && "$timer_3660s" == "1:01:00" ]]; then
        print_pass;
    else
        print_fail "Timer format incorrect" "30s->$timer_30s, 90s->$timer_90s, 3660s->$timer_3660s";
    fi;
    
    # Test phase detection
    print_test "Phase detection (_determine_phase)";
    local current_epoch target_epoch phase;
    current_epoch=$(date +%s);
    target_epoch=$((current_epoch + 3600));
    phase=$(_determine_phase "$target_epoch" "$current_epoch");
    
    if [[ "$phase" == "POLL" ]]; then
        print_pass;
    else
        print_fail "Phase incorrect" "Expected POLL, got: $phase";
    fi;
    
    # Test activity codes
    print_test "Activity code detection (_get_activity_code)";
    local activity_available activity_pending;
    activity_available=$(_get_activity_code "No match for domain.com");
    activity_pending=$(_get_activity_code "Status: pendingDelete");
    
    if [[ "$activity_available" == "AVAL" && "$activity_pending" == "DROP" ]]; then
        print_pass;
    else
        print_fail "Activity detection wrong" "AVAL:$activity_available DROP:$activity_pending";
    fi;
    
    # Test domain status extraction
    print_test "Domain status extraction (__extract_domain_status)";
    local status_available status_pending;
    status_available=$(__extract_domain_status "No match for domain.com");
    status_pending=$(__extract_domain_status "Status: pendingDelete");
    
    if [[ "$status_available" == "AVAILABLE" && "$status_pending" == "PENDING-DELETE" ]]; then
        print_pass;
    else
        print_fail "Domain status extraction failed" "AVAILABLE:$status_available PENDING:$status_pending";
    fi;
    
    # Test phase glyph and color functions
    print_test "Phase visual elements (_get_phase_glyph/_get_phase_color)";
    local poll_glyph heat_glyph poll_color heat_color;
    poll_glyph=$(_get_phase_glyph "POLL");
    heat_glyph=$(_get_phase_glyph "HEAT");
    poll_color=$(_get_phase_color "POLL");
    heat_color=$(_get_phase_color "HEAT");
    
    if [[ -n "$poll_glyph" && -n "$heat_glyph" && -n "$poll_color" && -n "$heat_color" ]]; then
        print_pass;
    else
        print_fail "Phase visual elements missing" "Glyphs or colors returned empty";
    fi;
}

# Test commands
test_commands() {
    print_header "Command Interface Tests";
    
    print_test "Help command";
    if "$WATCHDOM_SCRIPT" --help >/dev/null 2>&1; then
        print_pass;
    else
        print_fail "Help failed";
    fi;
    
    print_test "TLD listing";
    if "$WATCHDOM_SCRIPT" list_tlds 2>&1 | grep -q "\.com"; then
        print_pass;
    else
        print_fail "TLD listing failed";
    fi;
    
    print_test "Time command";
    if "$WATCHDOM_SCRIPT" time "2099-01-01 00:00:00 UTC" 2>&1 | grep -q "remaining"; then
        print_pass;
    else
        print_fail "Time command failed";
    fi;
}

# Main execution
main() {
    printf "%sWatchdom Test Runner - Phase 1 & 2%s\n" "$blue" "$x";
    printf "Testing: %s\n\n" "$WATCHDOM_SCRIPT";
    
    if [[ ! -f "$WATCHDOM_SCRIPT" ]]; then
        printf "%sERROR:%s Script not found: %s\n" "$red" "$x" "$WATCHDOM_SCRIPT" >&2;
        exit 1;
    fi;
    
    if [[ ! -x "$WATCHDOM_SCRIPT" ]]; then
        printf "%sERROR:%s Script not executable\n" "$red" "$x" >&2;
        exit 1;
    fi;
    
    test_internal_functions;
    test_commands;
    
    print_summary;
}

trap print_summary EXIT;
main "$@";
