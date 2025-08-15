#!/bin/bash

# ==============================================================================
# Comprehensive Test Suite for watchdom (Final UX - Explicit)
# ==============================================================================
# This script explicitly checks each command and prints its output for review.

# --- State and Counters ---
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
FAILED_DESCRIPTIONS=()

# --- Colors and Helpers ---
red=$'\x1B[31m'
green=$'\x1B[32m'
blue=$'\x1B[36m'
yellow=$'\x1B[33m'
reset=$'\x1B[0m'
cols=$(tput cols 2>/dev/null || echo 80)
hr=$(printf '%*s' "$cols" '' | tr ' ' '-')

print_header() { printf "\n%s\n%s[ %s ]%s\n%s\n" "$hr" "$blue" "$1" "$reset" "$hr"; }
print_pass() { ((PASSED_TESTS++)); printf "%s[PASS]%s\n" "$green" "$reset"; }
print_fail() {
    ((FAILED_TESTS++));
    FAILED_DESCRIPTIONS+=("Test $TOTAL_TESTS: $current_test_desc");
    printf "%s[FAIL]%s\n" "$red" "$reset";
    echo "       Reason: $1" >&2;
}
print_summary() {
    print_header "Test Summary"
    if [[ $FAILED_TESTS -eq 0 ]]; then
        printf "%sResult: All %d tests passed! 🎉%s\n" "$green" "$TOTAL_TESTS" "$reset"
        exit 0
    else
        printf "%sResult: %d/%d tests passed. %d failed.%s\n" "$red" "$PASSED_TESTS" "$TOTAL_TESTS" "$FAILED_TESTS" "$reset"
        printf "\n%sFailed tests:%s\n" "$yellow" "$reset"
        for desc in "${FAILED_DESCRIPTIONS[@]}"; do printf "  - %s\n" "$desc"; done
        exit 1
    fi
}
trap print_summary EXIT

run_test_and_print() {
    ((TOTAL_TESTS++))
    current_test_desc="$1"
    command="$2"

    printf "\nRunning Test %d: %s\n" "$TOTAL_TESTS" "$current_test_desc"
    printf "Command: %s\n" "$command"

    output=$(eval "$command" 2>&1)
    exit_code=$?

    echo "--- Output (Exit Code: $exit_code) ---"
    printf "%s\n" "$output"
    echo "------------------------------------"

    # Return the exit code for the caller to evaluate
    return $exit_code
}


# --- Main Test Execution ---
print_header "Setup and Installation"
chmod +x watchdom_advanced.sh
./watchdom_advanced.sh uninstall > /dev/null 2>&1 || true

# Test 1
current_test_desc="Initial status check (not installed)"
run_test_and_print "$current_test_desc" "./watchdom_advanced.sh status"
exit_code=$?
if [[ $exit_code -ne 1 ]]; then print_fail "Incorrect exit code. Expected 1, got $exit_code."; else print_pass; fi

# Test 2
current_test_desc="Install script"
run_test_and_print "$current_test_desc" "./watchdom_advanced.sh install"
exit_code=$?
if [[ $exit_code -ne 0 ]]; then
    print_fail "Install failed. Expected exit code 0, got $exit_code."
else
    if [[ ":$PATH:" != *":$HOME/.local/bin/fx:"* ]]; then
        if ! printf "%s" "$output" | grep -q "export PATH"; then
            print_fail "Did not print 'export PATH' message when it should have."
        else
            print_pass
        fi
    else
        print_pass
    fi
fi

export PATH="$HOME/.local/bin/fx:$PATH"

print_header "Core Functionality Tests"

# Test 3
current_test_desc="Status check (installed)"
run_test_and_print "$current_test_desc" "watchdom status -d"
exit_code=$?
if [[ $exit_code -ne 0 ]]; then print_fail "Status failed. Expected 0, got $exit_code."; elif ! printf "%s" "$output" | grep -q "is properly installed"; then print_fail "Did not print success message."; else print_pass; fi

# Test 4
current_test_desc="List TLDs"
run_test_and_print "$current_test_desc" "watchdom list_tlds"
exit_code=$?
if [[ $exit_code -ne 0 ]]; then print_fail "list_tlds failed. Expected 0, got $exit_code."; elif ! printf "%s" "$output" | grep -q ".com"; then print_fail "Did not list .com TLD."; else print_pass; fi

# Test 5
current_test_desc="Test TLD on registered domain"
run_test_and_print "$current_test_desc" "watchdom test_tld .com google.com"
exit_code=$?
if [[ $exit_code -ne 1 ]]; then print_fail "Incorrect exit code. Expected 1, got $exit_code."; elif ! printf "%s" "$output" | grep -q "Pattern NOT matched"; then print_fail "Did not print 'NOT matched' message."; else print_pass; fi

# Test 6
current_test_desc="Test TLD on available domain"
run_test_and_print "$current_test_desc" "watchdom test_tld .com a-domain-that-does-not-exist-for-sure12345.com"
exit_code=$?
if [[ $exit_code -ne 0 ]]; then print_fail "Incorrect exit code. Expected 0, got $exit_code."; elif ! printf "%s" "$output" | grep -q "Pattern MATCHED"; then print_fail "Did not print 'MATCHED' message."; else print_pass; fi

# Test 7
current_test_desc="Time command"
run_test_and_print "$current_test_desc" "watchdom time '2099-01-01 00:00:00 UTC'"
exit_code=$?
if [[ $exit_code -ne 0 ]]; then print_fail "Time command failed. Expected 0, got $exit_code."; elif ! printf "%s" "$output" | grep -q "Remaining"; then print_fail "Did not print 'Remaining' message."; else print_pass; fi

print_header "Feature and Flag Tests"

# Test 8
current_test_desc="One-time query feature"
run_test_and_print "$current_test_desc" "watchdom google.com"
exit_code=$?
if [[ $exit_code -ne 1 ]]; then print_fail "Incorrect exit code. Expected 1, got $exit_code."; elif ! printf "%s" "$output" | grep -q "Domain Name:"; then print_fail "Did not print WHOIS info."; else print_pass; fi

# Test 9
current_test_desc="Interval flag (-i)"
run_test_and_print "$current_test_desc" "watchdom -d google.com -i 2 -n 1"
exit_code=$?
if [[ $exit_code -ne 1 ]]; then print_fail "Incorrect exit code. Expected 1, got $exit_code."; elif ! printf "%s" "$output" | grep -q "base interval=2s"; then print_fail "Did not print correct interval message."; else print_pass; fi

# Test 10
current_test_desc="Until flag (--until)"
run_test_and_print "$current_test_desc" "watchdom -d google.com --until '2099-01-01 00:00:00 UTC' -i 1 -n 1"
exit_code=$?
if [[ $exit_code -ne 1 ]]; then print_fail "Incorrect exit code. Expected 1, got $exit_code."; elif ! printf "%s" "$output" | grep -q "Target UTC"; then print_fail "Did not print correct target message."; else print_pass; fi

print_header "Uninstallation"

# Test 11
current_test_desc="Uninstall command"
run_test_and_print "$current_test_desc" "watchdom uninstall"
exit_code=$?
if [[ $exit_code -ne 0 ]]; then print_fail "Uninstall failed. Expected 0, got $exit_code."; else print_pass; fi

# Test 12
current_test_desc="Final status check (not installed)"
run_test_and_print "$current_test_desc" "./watchdom_advanced.sh status"
exit_code=$?
if [[ $exit_code -ne 1 ]]; then print_fail "Incorrect exit code. Expected 1, got $exit_code."; else print_pass; fi
