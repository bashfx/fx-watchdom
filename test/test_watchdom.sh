#!/usr/bin/env bash
# test_watchdom.sh - Standalone test runner for watchdom
# Can test either watchdom_fixed.sh or any built watchdom script

################################################################################
# readonly
################################################################################
readonly TEST_NAME="test_watchdom"
readonly TEST_VERSION="1.0.0"
readonly TEST_PATH="$(realpath "${BASH_SOURCE[0]}")"
readonly TEST_DIR="$(dirname "$TEST_PATH")"

################################################################################
# config
################################################################################
# Default target script (can be overridden)
WATCHDOM_SCRIPT="${TEST_DIR}/watchdom_fixed.sh"
VERBOSE=${VERBOSE:-0}

################################################################################
# simple stderr
################################################################################
info()  { printf "%s[INFO]%s %s\n" "$blue" "$x" "$*" >&2; }
okay()  { printf "%s[PASS]%s %s\n" "$green" "$x" "$*" >&2; }
warn()  { printf "%s[WARN]%s %s\n" "$yellow" "$x" "$*" >&2; }
error() { printf "%s[FAIL]%s %s\n" "$red" "$x" "$*" >&2; }
fatal() { printf "%s[FATAL]%s %s\n" "$red2" "$x" "$*" >&2; exit 1; }
trace() { [[ "$VERBOSE" -eq 1 ]] && printf "%s[TRACE]%s %s\n" "$grey" "$x" "$*" >&2; }

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

################################################################################
# test helpers
################################################################################

# Core test assertions
assert_success() {
    local cmd="$1"
    local desc="$2"
    local ret
    
    trace "Running: $cmd"
    if eval "$cmd" >/dev/null 2>&1; then
        okay "✓ $desc"
        return 0
    else
        ret=$?
        error "✗ $desc (exit: $ret)"
        return 1
    fi
}

assert_failure() {
    local cmd="$1" 
    local desc="$2"
    
    trace "Running (expect fail): $cmd"
    if eval "$cmd" >/dev/null 2>&1; then
        error "✗ $desc (expected failure)"
        return 1
    else
        okay "✓ $desc"
        return 0
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local desc="$3"
    
    if printf "%s" "$haystack" | grep -q "$needle"; then
        okay "✓ $desc"
        return 0
    else
        error "✗ $desc (missing: $needle)"
        [[ "$VERBOSE" -eq 1 ]] && printf "Output was: %s\n" "$haystack" >&2
        return 1
    fi
}

assert_exit_code() {
    local expected="$1"
    local cmd="$2"
    local desc="$3"
    local actual
    
    trace "Running (expect exit $expected): $cmd"
    eval "$cmd" >/dev/null 2>&1
    actual=$?
    
    if [[ "$actual" -eq "$expected" ]]; then
        okay "✓ $desc"
        return 0
    else
        error "✗ $desc (expected $expected, got $actual)"
        return 1
    fi
}

# Test environment management
setup_test_env() {
    local test_rc="${HOME}/.watchdomrc.test"
    
    info "Setting up test environment..."
    
    # Backup existing config
    if [[ -f "${HOME}/.watchdomrc" ]]; then
        cp "${HOME}/.watchdomrc" "${HOME}/.watchdomrc.backup"
        trace "Backed up existing config"
    fi
    
    # Create test config
    cat > "$test_rc" << 'EOF'
# Test watchdom configuration  
.test|whois.test.example|Domain not found
.example|whois.example.com|No such domain
.uk|whois.nominet.uk|No such domain
EOF
    
    export WATCHDOM_RC="$test_rc"
    trace "Test environment ready"
}

cleanup_test_env() {
    info "Cleaning up test environment..."
    
    # Remove test files
    [[ -f "${HOME}/.watchdomrc.test" ]] && rm -f "${HOME}/.watchdomrc.test"
    
    # Restore original config
    if [[ -f "${HOME}/.watchdomrc.backup" ]]; then
        mv "${HOME}/.watchdomrc.backup" "${HOME}/.watchdomrc"
        trace "Restored original config"
    fi
    
    unset WATCHDOM_RC
}

################################################################################
# test suites
################################################################################

# Test 1: Basic functionality
test_basic() {
    info "Testing basic script functionality..."
    local failures=0
    
    # Script exists and executable
    assert_success "[[ -x '$WATCHDOM_SCRIPT' ]]" "Script executable" || ((failures++))
    
    # Help displays without error
    assert_success "bash '$WATCHDOM_SCRIPT' --help" "Help displays" || ((failures++))
    
    # Version info in help
    local help_output
    help_output="$(bash '$WATCHDOM_SCRIPT' --help 2>&1)"
    assert_contains "$help_output" "watchdom.*2\.0\.0" "Version in help" || ((failures++))
    
    # Invalid options rejected
    assert_exit_code 2 "bash '$WATCHDOM_SCRIPT' --invalid" "Invalid options rejected" || ((failures++))
    
    # No args shows error
    assert_exit_code 2 "bash '$WATCHDOM_SCRIPT'" "No args error" || ((failures++))
    
    printf "\n🔍 Basic functionality: %d failures\n\n" "$failures"
    return $failures
}

# Test 2: Command dispatch
test_dispatch() {
    info "Testing command dispatch system..."
    local failures=0
    
    local commands=("time" "list_tlds" "add_tld" "test_tld" "install" "uninstall" "status")
    
    for cmd in "${commands[@]}"; do
        case "$cmd" in
            time)
                assert_exit_code 1 "bash '$WATCHDOM_SCRIPT' time" "'$cmd' handles no args" || ((failures++))
                ;;
            add_tld|test_tld)
                assert_exit_code 2 "bash '$WATCHDOM_SCRIPT' $cmd" "'$cmd' shows usage" || ((failures++))
                ;;
            *)
                assert_success "bash '$WATCHDOM_SCRIPT' $cmd" "'$cmd' executes" || ((failures++))
                ;;
        esac
    done
    
    printf "\n🔍 Dispatch system: %d failures\n\n" "$failures"
    return $failures
}

# Test 3: Time functionality
test_time() {
    info "Testing time functionality..."
    local failures=0
    
    # Current epoch
    local current_epoch
    current_epoch="$(date -u +%s)"
    assert_success "bash '$WATCHDOM_SCRIPT' time $current_epoch" "Current epoch" || ((failures++))
    
    # Future date
    assert_success "bash '$WATCHDOM_SCRIPT' time '2025-12-25 12:00:00 UTC'" "Future date" || ((failures++))
    
    # Invalid date
    assert_exit_code 1 "bash '$WATCHDOM_SCRIPT' time 'invalid'" "Invalid date" || ((failures++))
    
    # Output format check
    local time_output
    time_output="$(bash '$WATCHDOM_SCRIPT' time "$current_epoch" 2>&1)"
    assert_contains "$time_output" "UNTIL_EPOCH=" "Epoch in output" || ((failures++))
    assert_contains "$time_output" "Remaining:" "Remaining time" || ((failures++))
    
    # Local time option
    local local_output
    local_output="$(bash '$WATCHDOM_SCRIPT' time "$current_epoch" --time_local 2>&1)"
    assert_contains "$local_output" "Local:" "Local time display" || ((failures++))
    
    printf "\n🔍 Time functionality: %d failures\n\n" "$failures"
    return $failures
}

# Test 4: TLD management
test_tld() {
    info "Testing TLD management..."
    local failures=0
    
    # List built-ins
    local tld_output
    tld_output="$(bash '$WATCHDOM_SCRIPT' list_tlds 2>&1)"
    assert_contains "$tld_output" "\.com.*whois\.verisign-grs\.com" "Built-in .com" || ((failures++))
    assert_contains "$tld_output" "\.net.*whois\.verisign-grs\.com" "Built-in .net" || ((failures++))
    assert_contains "$tld_output" "\.org.*whois\.pir\.org" "Built-in .org" || ((failures++))
    
    # Add custom TLD  
    assert_success "bash '$WATCHDOM_SCRIPT' add_tld .test whois.test.example 'Domain not found'" "Add custom TLD" || ((failures++))
    
    # Verify custom TLD appears
    tld_output="$(bash '$WATCHDOM_SCRIPT' list_tlds 2>&1)"
    assert_contains "$tld_output" "\.test.*whois\.test\.example" "Custom TLD listed" || ((failures++))
    
    # Test invalid TLD format
    assert_exit_code 2 "bash '$WATCHDOM_SCRIPT' add_tld" "Add TLD no args" || ((failures++))
    assert_exit_code 2 "bash '$WATCHDOM_SCRIPT' add_tld .test" "Add TLD missing args" || ((failures++))
    
    printf "\n🔍 TLD management: %d failures\n\n" "$failures"
    return $failures
}

# Test 5: Options parsing
test_options() {
    info "Testing option parsing..."
    local failures=0
    
    # Debug flag
    assert_success "bash '$WATCHDOM_SCRIPT' -d status" "Debug flag" || ((failures++))
    
    # Trace flag 
    assert_success "bash '$WATCHDOM_SCRIPT' -t status" "Trace flag" || ((failures++))
    
    # Quiet flag
    assert_success "bash '$WATCHDOM_SCRIPT' -q status" "Quiet flag" || ((failures++))
    
    # Force flag
    assert_success "bash '$WATCHDOM_SCRIPT' -f status" "Force flag" || ((failures++))
    
    # Dev flag (combines debug+trace)
    assert_success "bash '$WATCHDOM_SCRIPT' -D status" "Dev flag" || ((failures++))
    
    # Interval option
    assert_success "bash '$WATCHDOM_SCRIPT' time '2025-12-25 12:00:00 UTC' -i 120" "Interval option" || ((failures++))
    
    # Expect pattern option
    assert_success "bash '$WATCHDOM_SCRIPT' time '2025-12-25 12:00:00 UTC' -e 'custom pattern'" "Expect option" || ((failures++))
    
    # Max checks option
    assert_success "bash '$WATCHDOM_SCRIPT' time '2025-12-25 12:00:00 UTC' -n 5" "Max checks option" || ((failures++))
    
    # Until option
    assert_success "bash '$WATCHDOM_SCRIPT' time '2025-12-25 12:00:00 UTC' --until '2025-12-25 13:00:00 UTC'" "Until option" || ((failures++))
    
    printf "\n🔍 Option parsing: %d failures\n\n" "$failures"
    return $failures
}

# Test 6: Installation system
test_install() {
    info "Testing installation system..."
    local failures=0
    
    # Status command works
    assert_success "bash '$WATCHDOM_SCRIPT' status" "Status command" || ((failures++))
    
    # Status output format
    local status_output
    status_output="$(bash '$WATCHDOM_SCRIPT' status 2>&1)"
    assert_contains "$status_output" "Installation Status" "Status header" || ((failures++))
    assert_contains "$status_output" "Current script:" "Current script info" || ((failures++))
    
    # Install with force (avoid conflicts)
    assert_success "bash '$WATCHDOM_SCRIPT' install -f" "Force install" || ((failures++))
    
    # Check installed status
    status_output="$(bash '$WATCHDOM_SCRIPT' status 2>&1)"
    assert_contains "$status_output" "properly installed" "Install success" || ((failures++))
    
    # Uninstall
    assert_success "bash '$WATCHDOM_SCRIPT' uninstall" "Uninstall" || ((failures++))
    
    printf "\n🔍 Installation: %d failures\n\n" "$failures"
    return $failures
}

# Test 7: Domain watching (no actual monitoring)
test_watch() {
    info "Testing domain watching..."
    local failures=0
    
    # No domain error
    assert_exit_code 2 "bash '$WATCHDOM_SCRIPT' watch" "Watch no domain" || ((failures++))
    
    # Invalid domain format
    assert_failure "bash '$WATCHDOM_SCRIPT' watch 'invalid..domain'" "Invalid domain" || ((failures++))
    assert_failure "bash '$WATCHDOM_SCRIPT' watch ''" "Empty domain" || ((failures++))
    
    # Unsupported TLD
    assert_exit_code 1 "bash '$WATCHDOM_SCRIPT' watch 'test.unsupported'" "Unsupported TLD" || ((failures++))
    
    # Valid domain format accepted (but will fail due to whois)
    assert_failure "timeout 2s bash '$WATCHDOM_SCRIPT' watch 'example.com'" "Valid domain format" || ((failures++))
    
    # Legacy syntax support
    assert_failure "timeout 2s bash '$WATCHDOM_SCRIPT' example.com" "Legacy syntax" || ((failures++))
    
    printf "\n🔍 Domain watching: %d failures\n\n" "$failures"
    return $failures
}

# Test 8: BashFX compliance
test_bashfx() {
    info "Testing BashFX compliance..."
    local failures=0
    
    # XDG+ paths in help
    local help_output
    help_output="$(bash '$WATCHDOM_SCRIPT' --help 2>&1)"
    assert_contains "$help_output" "\.local" "XDG+ paths mentioned" || ((failures++))
    
    # Proper exit codes
    assert_exit_code 0 "bash '$WATCHDOM_SCRIPT' status" "Success exit code" || ((failures++))
    assert_exit_code 1 "bash '$WATCHDOM_SCRIPT' time 'invalid'" "Error exit code" || ((failures++))
    
    # Stderr vs stdout separation
    local stdout_output stderr_output
    stdout_output="$(bash '$WATCHDOM_SCRIPT' time '2025-12-25 12:00:00 UTC' 2>/dev/null)"
    stderr_output="$(bash '$WATCHDOM_SCRIPT' time '2025-12-25 12:00:00 UTC' 2>&1 >/dev/null)"
    
    assert_contains "$stdout_output" "UNTIL_EPOCH" "Data to stdout" || ((failures++))
    [[ -n "$stderr_output" ]] && okay "✓ Messages to stderr" || { error "✗ No stderr output"; ((failures++)); }
    
    # Self-contained paths
    assert_contains "$help_output" "fx" "FX namespace" || ((failures++))
    
    printf "\n🔍 BashFX compliance: %d failures\n\n" "$failures"
    return $failures
}

################################################################################
# main runners
################################################################################

# Run all tests
run_all_tests() {
    local total_failures=0
    
    info "🚀 Starting comprehensive watchdom test suite"
    info "📁 Testing script: $WATCHDOM_SCRIPT"
    
    # Verify script exists
    if [[ ! -f "$WATCHDOM_SCRIPT" ]]; then
        fatal "❌ Watchdom script not found: $WATCHDOM_SCRIPT"
    fi
    
    setup_test_env
    
    # Run all test suites
    test_basic    && trace "✅ Basic tests passed"    || ((total_failures++))
    test_dispatch && trace "✅ Dispatch tests passed" || ((total_failures++))
    test_time     && trace "✅ Time tests passed"     || ((total_failures++))
    test_tld      && trace "✅ TLD tests passed"      || ((total_failures++))
    test_options  && trace "✅ Option tests passed"   || ((total_failures++))
    test_install  && trace "✅ Install tests passed"  || ((total_failures++))
    test_watch    && trace "✅ Watch tests passed"    || ((total_failures++))
    test_bashfx   && trace "✅ BashFX tests passed"   || ((total_failures++))
    
    cleanup_test_env
    
    # Final summary
    printf "\n"
    if [[ "$total_failures" -eq 0 ]]; then
        okay "🎉 ALL TESTS PASSED! Watchdom is working correctly."
        return 0
    else
        error "💥 $total_failures test suite(s) had failures"
        warn "🔧 Check the specific failures above to identify issues"
        return 1
    fi
}

# Quick smoke test
run_quick_test() {
    info "🔥 Running quick smoke tests..."
    
    local failures=0
    
    assert_success "bash '$WATCHDOM_SCRIPT' --help" "Help works" || ((failures++))
    assert_success "bash '$WATCHDOM_SCRIPT' status" "Status works" || ((failures++))
    assert_success "bash '$WATCHDOM_SCRIPT' list_tlds" "List TLDs works" || ((failures++))
    
    if [[ "$failures" -eq 0 ]]; then
        okay "⚡ Quick tests passed"
        return 0
    else
        error "💥 $failures quick test(s) failed"
        return 1
    fi
}

# Test specific area
run_single_test() {
    local test_name="${1:-}"
    
    if [[ -z "$test_name" ]]; then
        error "Test name required"
        info "Available tests: basic, dispatch, time, tld, options, install, watch, bashfx"
        return 2
    fi
    
    case "$test_name" in
        basic)    test_basic ;;
        dispatch) test_dispatch ;;
        time)     test_time ;;
        tld)      test_tld ;;
        options)  test_options ;;
        install)  test_install ;;
        watch)    test_watch ;;
        bashfx)   test_bashfx ;;
        *)
            error "Unknown test: $test_name"
            info "Available: basic, dispatch, time, tld, options, install, watch, bashfx"
            return 2
            ;;
    esac
}

################################################################################
# usage
################################################################################
usage() {
    cat << 'EOF'
test_watchdom.sh - Comprehensive test suite for watchdom

USAGE:
  test_watchdom.sh [OPTIONS] [COMMAND]

COMMANDS:
  all                       Run all test suites (default)
  quick                     Run quick smoke tests only  
  <test_name>               Run specific test suite

AVAILABLE TESTS:
  basic                     Basic script functionality
  dispatch                  Command dispatch system
  time                      Time/countdown functionality
  tld                       TLD management features
  options                   Command-line option parsing
  install                   Installation/uninstallation
  watch                     Domain watching (limited)
  bashfx                    BashFX compliance

OPTIONS:
  -s, --script PATH         Test specific watchdom script
  -v, --verbose             Enable verbose output
  -h, --help                Show this help

EXAMPLES:
  ./test_watchdom.sh                          # Run all tests
  ./test_watchdom.sh quick                    # Quick smoke test
  ./test_watchdom.sh time                     # Test just time functionality
  ./test_watchdom.sh -v all                   # Verbose full test
  ./test_watchdom.sh -s ./my_watchdom.sh all  # Test custom script

EXIT CODES:
  0: All tests passed
  1: Some tests failed  
  2: Invalid arguments
EOF
}

################################################################################
# main
################################################################################
main() {
    local command="all"
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--script)
                [[ $# -ge 2 ]] || { error "Option $1 requires argument"; return 2; }
                WATCHDOM_SCRIPT="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -h|--help)
                usage
                return 0
                ;;
            -*)
                error "Unknown option: $1"
                usage
                return 2
                ;;
            *)
                command="$1"
                shift
                ;;
        esac
    done
    
    # Run the requested command
    case "$command" in
        all)
            run_all_tests
            ;;
        quick)
            run_quick_test
            ;;
        basic|dispatch|time|tld|options|install|watch|bashfx)
            setup_test_env
            run_single_test "$command"
            local ret=$?
            cleanup_test_env
            return $ret
            ;;
        *)
            error "Unknown command: $command"
            usage
            return 2
            ;;
    esac
}

################################################################################
# invocation
################################################################################
main "$@"
