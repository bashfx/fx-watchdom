#!/bin/bash

# ==============================================================================
# Comprehensive Test Suite for watchdom (Robust UX)
# ==============================================================================
# This script explicitly checks the exit code of each command instead of
# relying on `set -e`, which was causing mysterious exits.

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
# Check if tput is available, otherwise default to 80 columns
cols=$(tput cols 2>/dev/null || echo 80)
hr=$(printf '%*s' "$cols" '' | tr ' ' '-')

print_header() { printf "\n%s\n%s[ %s ]%s\n%s\n" "$hr" "$blue" "$1" "$reset" "$hr"; }
print_pass() { ((TOTAL_TESTS++)); printf "%s[PASS] Test %d: %s%s\n" "$green" "$TOTAL_TESTS" "$1" "$reset"; ((PASSED_TESTS++)); }
print_fail() { ((TOTAL_TESTS++)); printf "%s[FAIL] Test %d: %s%s\n" "$red" "$TOTAL_TESTS" "$1" "$reset"; echo "       Reason: $2" >&2; ((FAILED_TESTS++)); FAILED_DESCRIPTIONS+=("$1"); }
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
# Trap EXIT to ensure summary is always printed, even on manual exit (Ctrl-C)
trap print_summary EXIT

# --- Main Test Execution ---
print_header "Setup and Installation"
chmod +x watchdom_advanced.sh
./watchdom_advanced.sh uninstall > /dev/null 2>&1 || true

# Test 1
desc="Initial status check (not installed)"
output=$(./watchdom_advanced.sh status 2>&1); exit_code=$?
if [[ $exit_code -ne 1 ]]; then print_fail "$desc" "Incorrect exit code. Expected 1, got $exit_code."; else print_pass "$desc"; fi

# Test 2
desc="Install script"
output=$(./watchdom_advanced.sh install 2>&1); exit_code=$?
if [[ $exit_code -ne 0 ]]; then print_fail "$desc" "Install failed. Expected exit code 0, got $exit_code."; elif ! printf "%s" "$output" | grep -q "export PATH"; then print_fail "$desc" "Did not print 'export PATH' message."; else print_pass "$desc"; fi

export PATH="$HOME/.local/bin/fx:$PATH"

print_header "Core Functionality Tests"

# Test 3
desc="Status check (installed)"
output=$(watchdom status -d 2>&1); exit_code=$?
if [[ $exit_code -ne 0 ]]; then print_fail "$desc" "Status failed. Expected exit code 0, got $exit_code."; elif ! printf "%s" "$output" | grep -q "is properly installed"; then print_fail "$desc" "Did not print success message."; else print_pass "$desc"; fi

# Test 4
desc="List TLDs"
output=$(watchdom list_tlds 2>&1); exit_code=$?
if [[ $exit_code -ne 0 ]]; then print_fail "$desc" "list_tlds failed. Expected exit code 0, got $exit_code."; elif ! printf "%s" "$output" | grep -q ".com"; then print_fail "$desc" "Did not list .com TLD."; else print_pass "$desc"; fi

# Test 5
desc="Test TLD on registered domain"
output=$(watchdom test_tld .com google.com 2>&1); exit_code=$?
if [[ $exit_code -ne 1 ]]; then print_fail "$desc" "Incorrect exit code. Expected 1, got $exit_code."; elif ! printf "%s" "$output" | grep -q "Pattern NOT matched"; then print_fail "$desc" "Did not print 'NOT matched' message."; else print_pass "$desc"; fi

# Test 6
desc="Test TLD on available domain"
output=$(watchdom test_tld .com a-domain-that-does-not-exist-for-sure12345.com 2>&1); exit_code=$?
if [[ $exit_code -ne 0 ]]; then print_fail "$desc" "Incorrect exit code. Expected 0, got $exit_code."; elif ! printf "%s" "$output" | grep -q "Pattern MATCHED"; then print_fail "$desc" "Did not print 'MATCHED' message."; else print_pass "$desc"; fi

# Test 7
desc="Time command"
output=$(watchdom time '2099-01-01 00:00:00 UTC' 2>&1); exit_code=$?
if [[ $exit_code -ne 0 ]]; then print_fail "$desc" "Time command failed. Expected exit code 0, got $exit_code."; elif ! printf "%s" "$output" | grep -q "Remaining"; then print_fail "$desc" "Did not print 'Remaining' message."; else print_pass "$desc"; fi

print_header "Feature and Flag Tests"

# Test 8
desc="One-time query feature"
output=$(watchdom google.com 2>&1); exit_code=$?
if [[ $exit_code -ne 1 ]]; then print_fail "$desc" "Incorrect exit code. Expected 1, got $exit_code."; elif ! printf "%s" "$output" | grep -q "Domain Name:"; then print_fail "$desc" "Did not print WHOIS info."; else print_pass "$desc"; fi

# Test 9
desc="Interval flag (-i)"
output=$(watchdom -d google.com -i 1 -n 1 2>&1); exit_code=$?
if [[ $exit_code -ne 1 ]]; then print_fail "$desc" "Incorrect exit code. Expected 1, got $exit_code."; elif ! printf "%s" "$output" | grep -q "base interval=1s"; then print_fail "$desc" "Did not print correct interval message."; else print_pass "$desc"; fi

# Test 10
desc="Until flag (--until)"
output=$(watchdom -d google.com --until '2099-01-01 00:00:00 UTC' -i 1 -n 1 2>&1); exit_code=$?
if [[ $exit_code -ne 1 ]]; then print_fail "$desc" "Incorrect exit code. Expected 1, got $exit_code."; elif ! printf "%s" "$output" | grep -q "Target UTC"; then print_fail "$desc" "Did not print correct target message."; else print_pass "$desc"; fi

print_header "Uninstallation"

# Test 11
desc="Uninstall command"
output=$(watchdom uninstall 2>&1); exit_code=$?
if [[ $exit_code -ne 0 ]]; then print_fail "$desc" "Uninstall failed. Expected exit code 0, got $exit_code."; else print_pass "$desc"; fi

# Test 12
desc="Final status check (not installed)"
output=$(./watchdom_advanced.sh status 2>&1); exit_code=$?
if [[ $exit_code -ne 1 ]]; then print_fail "$desc" "Incorrect exit code. Expected 1, got $exit_code."; else print_pass "$desc"; fi
