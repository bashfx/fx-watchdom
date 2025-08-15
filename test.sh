#!/bin/bash

# ==============================================================================
# Final Test Suite - Final Version
# ==============================================================================

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
        printf "%sResult: All %d tests passed! 🎉%s\n" "$green" "$TOTAL_TESTS" "$reset"; exit 0;
    else
        printf "%sResult: %d/%d tests passed. %d failed.%s\n" "$red" "$PASSED_TESTS" "$TOTAL_TESTS" "$FAILED_TESTS" "$reset";
        printf "\n%sFailed tests:%s\n" "$yellow" "$reset";
        for desc in "${FAILED_DESCRIPTIONS[@]}"; do printf "  - %s\n" "$desc"; done
        exit 1
    fi
}
trap print_summary EXIT

# --- Main Test Execution ---
print_header "Setup"
chmod +x watchdom_advanced.sh
./watchdom_advanced.sh uninstall > /dev/null 2>&1 || true

print_header "Installation and Core Tests"

((TOTAL_TESTS++)); current_test_desc="Initial status check (not installed)"
printf "\nRunning Test %d: %s\n" "$TOTAL_TESTS" "$current_test_desc"
output=$(./watchdom_advanced.sh status 2>&1); exit_code=$?
echo "$output"
if [[ $exit_code -ne 1 ]]; then print_fail "Incorrect exit code. Expected 1, got $exit_code."; else print_pass; fi

((TOTAL_TESTS++)); current_test_desc="Install script"
printf "\nRunning Test %d: %s\n" "$TOTAL_TESTS" "$current_test_desc"
output=$(./watchdom_advanced.sh install 2>&1); exit_code=$?
echo "$output"
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
hash -r

((TOTAL_TESTS++)); current_test_desc="Status check (installed)"
printf "\nRunning Test %d: %s\n" "$TOTAL_TESTS" "$current_test_desc"
output=$(watchdom status -d 2>&1); exit_code=$?
echo "$output"
if [[ $exit_code -ne 0 ]]; then print_fail "Status failed. Expected 0, got $exit_code."; elif ! printf "%s" "$output" | grep -q "is properly installed"; then print_fail "Did not print success message."; else print_pass; fi

((TOTAL_TESTS++)); current_test_desc="List TLDs"
printf "\nRunning Test %d: %s\n" "$TOTAL_TESTS" "$current_test_desc"
output=$(watchdom list_tlds 2>&1); exit_code=$?
echo "$output"
if [[ $exit_code -ne 0 ]]; then print_fail "list_tlds failed. Expected 0, got $exit_code."; elif ! printf "%s" "$output" | grep -q ".com"; then print_fail "Did not list .com TLD."; else print_pass; fi

((TOTAL_TESTS++)); current_test_desc="Test TLD on registered domain"
printf "\nRunning Test %d: %s\n" "$TOTAL_TESTS" "$current_test_desc"
output=$(watchdom test_tld .com google.com 2>&1); exit_code=$?
echo "$output"
if [[ $exit_code -ne 1 ]]; then print_fail "Incorrect exit code. Expected 1, got $exit_code."; elif ! printf "%s" "$output" | grep -q "Pattern NOT matched"; then print_fail "Did not print 'NOT matched' message."; else print_pass; fi

((TOTAL_TESTS++)); current_test_desc="Test TLD on available domain"
printf "\nRunning Test %d: %s\n" "$TOTAL_TESTS" "$current_test_desc"
output=$(watchdom test_tld .com a-domain-that-does-not-exist-for-sure12345.com 2>&1); exit_code=$?
echo "$output"
if [[ $exit_code -ne 0 ]]; then print_fail "Incorrect exit code. Expected 0, got $exit_code."; elif ! printf "%s" "$output" | grep -q "Pattern MATCHED"; then print_fail "Did not print 'MATCHED' message."; else print_pass; fi

((TOTAL_TESTS++)); current_test_desc="Time command"
printf "\nRunning Test %d: %s\n" "$TOTAL_TESTS" "$current_test_desc"
output=$(watchdom time '2099-01-01 00:00:00 UTC' 2>&1); exit_code=$?
echo "$output"
if [[ $exit_code -ne 0 ]]; then print_fail "Time command failed. Expected 0, got $exit_code."; elif ! printf "%s" "$output" | grep -q "Remaining"; then print_fail "Did not print 'Remaining' message."; else print_pass; fi

print_header "Feature and Flag Tests"

((TOTAL_TESTS++)); current_test_desc="One-time query feature"
printf "\nRunning Test %d: %s\n" "$TOTAL_TESTS" "$current_test_desc"
output=$(watchdom google.com 2>&1); exit_code=$?
echo "$output"
if [[ $exit_code -ne 1 ]]; then print_fail "Incorrect exit code. Expected 1, got $exit_code."; elif ! printf "%s" "$output" | grep -q "Domain Name:"; then print_fail "Did not print WHOIS info."; else print_pass; fi

((TOTAL_TESTS++)); current_test_desc="Interval flag (-i 10)"
printf "\nRunning Test %d: %s\n" "$TOTAL_TESTS" "$current_test_desc"
output=$(watchdom -d google.com -i 10 -n 1 2>&1); exit_code=$?
echo "$output"
if [[ $exit_code -ne 1 ]]; then print_fail "Incorrect exit code. Expected 1, got $exit_code."; elif ! printf "%s" "$output" | grep -q "base interval=10s"; then print_fail "Did not print correct interval message."; else print_pass; fi

((TOTAL_TESTS++)); current_test_desc="Until flag (--until)"
printf "\nRunning Test %d: %s\n" "$TOTAL_TESTS" "$current_test_desc"
output=$(watchdom -d google.com --until '2099-01-01 00:00:00 UTC' -i 1 -n 1 2>&1); exit_code=$?
echo "$output"
if [[ $exit_code -ne 1 ]]; then print_fail "Incorrect exit code. Expected 1, got $exit_code."; elif ! printf "%s" "$output" | grep -q "Target UTC"; then print_fail "Did not print correct target message."; else print_pass; fi

((TOTAL_TESTS++)); current_test_desc="Auto-yes flag (-y) for grace period"
printf "\nRunning Test %d: %s\n" "$TOTAL_TESTS" "$current_test_desc"
output=$(watchdom -d -y google.com --until "2020-01-01 00:00:00 UTC" -n 1 2>&1); exit_code=$?
echo "$output"
if [[ $exit_code -ne 1 ]]; then print_fail "Incorrect exit code. Expected 1, got $exit_code."; elif ! printf "%s" "$output" | grep -q "y (auto-confirmed)"; then print_fail "Did not auto-confirm prompt."; else print_pass; fi

print_header "Uninstallation"

((TOTAL_TESTS++)); current_test_desc="Uninstall command"
printf "\nRunning Test %d: %s\n" "$TOTAL_TESTS" "$current_test_desc"
output=$(watchdom uninstall 2>&1); exit_code=$?
echo "$output"
if [[ $exit_code -ne 0 ]]; then print_fail "Uninstall failed. Expected 0, got $exit_code."; else print_pass; fi

((TOTAL_TESTS++)); current_test_desc="Final status check (not installed)"
printf "\nRunning Test %d: %s\n" "$TOTAL_TESTS" "$current_test_desc"
output=$(./watchdom_advanced.sh status 2>&1); exit_code=$?
echo "$output"
if [[ $exit_code -ne 1 ]]; then print_fail "Incorrect exit code. Expected 1, got $exit_code."; else print_pass; fi
