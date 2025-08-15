#!/bin/bash

# ==============================================================================
# Comprehensive Test Suite for watchdom
# ==============================================================================
# This script tests all major functionality of the watchdom script, including
# installation, command-line argument parsing, core features, and uninstallation.
#
# It is designed to be self-contained and will exit with a non-zero status
# if any test fails.

# --- Configuration ---
# Exit immediately if a command exits with a non-zero status.
set -e
# Print each command to stdout before executing it.
set -x

# --- Helpers ---
# A function to check the exit code of the last command.
assert_exit_code() {
    local expected_code="$1"
    local last_code="$2"
    local message="$3"
    if [[ "$last_code" -ne "$expected_code" ]]; then
        echo "❌ ERROR: $message" >&2
        echo "Expected exit code $expected_code, but got $last_code." >&2
        exit 1
    fi
    echo "✅ Success: Correct exit code ($expected_code) received."
}

# --- Setup ---
echo "--> Ensuring a clean slate by running uninstall first..."
# This is to clean up from any previous failed test runs.
# We run it with -d to see the output, and ignore errors with `|| true`.
./watchdom_advanced.sh uninstall -d || true

echo "--> Making the watchdom script executable..."
chmod +x watchdom_advanced.sh

# --- Test Initial State ---
echo "--> Testing initial status (should not be installed)"
set +e # Disable exit on error for this specific check
./watchdom_advanced.sh status > /dev/null
exit_code=$?
set -e
assert_exit_code 1 "$exit_code" "Initial status check should fail as not installed."

# --- Test Installation ---
echo "--> Testing installation..."
./watchdom_advanced.sh install

echo "--> Adding new bin directory to PATH for this session..."
export PATH="$HOME/.local/bin/fx:$PATH"

echo "--> Testing status post-installation..."
watchdom status -d 2>&1 | grep "is properly installed"

# --- Test Core Features ---
echo "--> Testing 'list_tlds'..."
watchdom list_tlds | grep ".com"

echo "--> Testing 'test_tld' on a registered domain (should be verbose)..."
set +e
watchdom test_tld .com google.com > test_tld_output.log 2>&1
exit_code=$?
set -e
assert_exit_code 1 "$exit_code" "'test_tld' for registered domain should return 1."
grep "Pattern NOT matched" test_tld_output.log

echo "--> Testing 'test_tld' on an unregistered domain (should be verbose)..."
watchdom test_tld .com a-domain-that-does-not-exist-for-sure12345.com > test_tld_output.log 2>&1
grep "Pattern MATCHED" test_tld_output.log

echo "--> Testing 'time' command..."
watchdom time "2099-01-01 00:00:00 UTC" | grep "Remaining"

# --- Test Argument Parsing and Feature Flags ---
echo "--> Testing one-time query feature..."
# This should not start a poll, but print the whois info and exit.
# We grep for something that is always in a .com whois record.
watchdom google.com | grep "Domain Name:"

echo "--> Testing '-i' interval flag..."
# We can't easily test the poll time, but we can check the startup message.
# The `info` messages go to stderr, so we redirect.
watchdom -d google.com -i 1 -n 1 2>&1 | grep "base interval=1s"

echo "--> Testing '--until' flag..."
# Check the startup message for the target time.
watchdom -d google.com --until "2099-01-01 00:00:00 UTC" -i 1 -n 1 2>&1 | grep "Target UTC"

# --- Test Uninstallation ---
echo "--> Testing uninstallation..."
watchdom uninstall

echo "--> Testing status post-uninstallation..."
set +e
./watchdom_advanced.sh status > /dev/null
exit_code=$?
set -e
assert_exit_code 1 "$exit_code" "Final status check should fail as not installed."

# --- Cleanup ---
rm -f test_tld_output.log
echo ""
echo "=========================================="
echo "✅ All tests passed successfully!"
echo "=========================================="
