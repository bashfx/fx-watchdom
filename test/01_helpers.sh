#!/usr/bin/env bash
# test/01_helpers.sh - Core test helper functions for watchdom testing
# Part of modular test system following BashFX conventions

################################################################################
# test helpers
################################################################################

# Test environment configuration
setup_test_env() {
    local test_rc="${HOME}/.watchdomrc.test";
    
    info "Setting up isolated test environment...";
    
    # Backup existing config
    if [[ -f "${HOME}/.watchdomrc" ]]; then
        cp "${HOME}/.watchdomrc" "${HOME}/.watchdomrc.backup";
        trace "Backed up existing config";
    fi;
    
    # Create isolated test config
    cat > "$test_rc" << 'EOF'
# Test watchdom configuration  
.test|whois.test.example|Domain not found
.example|whois.example.com|No such domain
.uk|whois.nominet.uk|No such domain
.dev|whois.dev.example|Not found
EOF
    
    export WATCHDOM_RC="$test_rc";
    trace "Test environment ready with isolated config";
}

cleanup_test_env() {
    info "Cleaning up test environment...";
    
    # Remove test files
    [[ -f "${HOME}/.watchdomrc.test" ]] && rm -f "${HOME}/.watchdomrc.test";
    
    # Restore original config
    if [[ -f "${HOME}/.watchdomrc.backup" ]]; then
        mv "${HOME}/.watchdomrc.backup" "${HOME}/.watchdomrc";
        trace "Restored original config";
    fi;
    
    # Clean up any test installation artifacts
    local test_install_dir="${HOME}/.local/lib/fx";
    if [[ -d "$test_install_dir" ]] && [[ -f "$test_install_dir/watchdom" ]]; then
        rm -f "$test_install_dir/watchdom";
        trace "Cleaned up test installation";
    fi;
    
    unset WATCHDOM_RC;
}

################################################################################
# core assertions
################################################################################

# Assert command succeeds
assert_success() {
    local cmd="$1";
    local desc="$2";
    local ret;
    
    trace "Running: $cmd";
    if eval "$cmd" >/dev/null 2>&1; then
        okay "✓ $desc";
        return 0;
    else
        ret=$?;
        error "✗ $desc (exit: $ret)";
        return 1;
    fi;
}

# Assert command fails
assert_failure() {
    local cmd="$1"; 
    local desc="$2";
    
    trace "Running (expect fail): $cmd";
    if eval "$cmd" >/dev/null 2>&1; then
        error "✗ $desc (expected failure)";
        return 1;
    else
        okay "✓ $desc";
        return 0;
    fi;
}

# Assert specific exit code
assert_exit_code() {
    local expected="$1";
    local cmd="$2";
    local desc="$3";
    local actual;
    
    trace "Running (expect exit $expected): $cmd";
    eval "$cmd" >/dev/null 2>&1;
    actual=$?;
    
    if [[ "$actual" -eq "$expected" ]]; then
        okay "✓ $desc";
        return 0;
    else
        error "✗ $desc (expected $expected, got $actual)";
        return 1;
    fi;
}

# Assert output contains pattern
assert_contains() {
    local haystack="$1";
    local needle="$2";
    local desc="$3";
    
    if printf "%s" "$haystack" | grep -q "$needle"; then
        okay "✓ $desc";
        return 0;
    else
        error "✗ $desc (missing: $needle)";
        [[ "${VERBOSE:-0}" -eq 1 ]] && printf "Output was: %s\n" "$haystack" >&2;
        return 1;
    fi;
}

# Assert output does NOT contain pattern  
assert_not_contains() {
    local haystack="$1";
    local needle="$2";
    local desc="$3";
    
    if printf "%s" "$haystack" | grep -q "$needle"; then
        error "✗ $desc (unexpectedly found: $needle)";
        return 1;
    else
        okay "✓ $desc";
        return 0;
    fi;
}

# Assert file exists
assert_file_exists() {
    local file="$1";
    local desc="$2";
    
    if [[ -f "$file" ]]; then
        okay "✓ $desc";
        return 0;
    else
        error "✗ $desc (file not found: $file)";
        return 1;
    fi;
}

# Assert function exists (by sourcing script)
assert_function_exists() {
    local func_name="$1";
    local desc="$2";
    
    if declare -f "$func_name" >/dev/null 2>&1; then
        okay "✓ $desc";
        return 0;
    else
        error "✗ $desc (function not found: $func_name)";
        return 1;
    fi;
}

################################################################################
# advanced test helpers
################################################################################

# Test function output by sourcing
test_function_output() {
    local func_name="$1";
    local args="$2";
    local expected_pattern="$3";
    local desc="$4";
    local output;
    
    if ! declare -f "$func_name" >/dev/null 2>&1; then
        error "✗ $desc (function $func_name not found)";
        return 1;
    fi;
    
    # Capture function output
    output="$($func_name $args 2>&1)";
    
    if printf "%s" "$output" | grep -q "$expected_pattern"; then
        okay "✓ $desc";
        return 0;
    else
        error "✗ $desc (output didn't match pattern: $expected_pattern)";
        [[ "${VERBOSE:-0}" -eq 1 ]] && printf "Function output: %s\n" "$output" >&2;
        return 1;
    fi;
}

# Test with timeout (for commands that might hang)
test_with_timeout() {
    local timeout_sec="$1";
    local cmd="$2";
    local desc="$3";
    
    if timeout "$timeout_sec" bash -c "$cmd" >/dev/null 2>&1; then
        okay "✓ $desc (completed within ${timeout_sec}s)";
        return 0;
    else
        error "✗ $desc (timeout after ${timeout_sec}s)";
        return 1;
    fi;
}

# Test BashFX compliance by checking semicolons
test_bashfx_semicolons() {
    local script_path="$1";
    local desc="$2";
    local issues;
    
    # Check for common semicolon issues
    issues="$(grep -n -E '(^[[:space:]]*if.*then$|^[[:space:]]*for.*do$|^[[:space:]]*while.*do$)' "$script_path" | grep -v ';')";
    
    if [[ -z "$issues" ]]; then
        okay "✓ $desc";
        return 0;
    else
        error "✗ $desc (missing semicolons)";
        [[ "${VERBOSE:-0}" -eq 1 ]] && printf "Issues:\n%s\n" "$issues" >&2;
        return 1;
    fi;
}

################################################################################
# test result tracking
################################################################################

# Initialize test counters
init_test_counters() {
    TEST_TOTAL=0;
    TEST_PASSED=0;
    TEST_FAILED=0;
}

# Record test result
record_test_result() {
    local result="$1";  # 0 for pass, non-zero for fail
    
    ((TEST_TOTAL++));
    if [[ "$result" -eq 0 ]]; then
        ((TEST_PASSED++));
    else
        ((TEST_FAILED++));
    fi;
}

# Show test summary
show_test_summary() {
    local suite_name="${1:-Test Suite}";
    
    printf "\n";
    info "📊 $suite_name Results:";
    printf "   Total: %d\n" "$TEST_TOTAL" >&2;
    printf "   %sPassed: %d%s\n" "$green" "$TEST_PASSED" "$x" >&2;
    
    if [[ "$TEST_FAILED" -gt 0 ]]; then
        printf "   %sFailed: %d%s\n" "$red" "$TEST_FAILED" "$x" >&2;
        return 1;
    else
        printf "   %sAll tests passed!%s\n" "$green" "$x" >&2;
        return 0;
    fi;
}
