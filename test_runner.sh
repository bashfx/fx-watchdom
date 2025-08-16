#!/usr/bin/env bash
# test_runner.sh - Comprehensive test runner for watchdom  
# Follows BashFX standards and tests without spamming servers

################################################################################
# readonly  
################################################################################
readonly TEST_NAME="test_runner"
readonly TEST_VERSION="1.0.0"
readonly TEST_PATH="$(realpath "${BASH_SOURCE[0]}")"
readonly TEST_DIR="$(dirname "$TEST_PATH")"

# Test target configuration
readonly TARGET_SCRIPT="${TEST_DIR}/watchdom_fixed.sh"

################################################################################
# config
################################################################################
VERBOSE=${VERBOSE:-0}
QUICK_MODE=${QUICK_MODE:-0}

################################################################################
# escape sequences (BashFX standard)
################################################################################
readonly red=$'\x1B[38;5;9m'
readonly green=$'\x1B[32m' 
readonly blue=$'\x1B[38;5;39m'
readonly yellow=$'\x1B[33m'
readonly purple=$'\x1B[38;5;213m'
readonly cyan=$'\x1B[38;5;14m'
readonly grey=$'\x1B[38;5;249m'
readonly red2=$'\x1B[38;5;196m'
readonly white=$'\x1B[38;5;15m'
readonly x=$'\x1B[38;5;244m'

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
info()  { printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ "$VERBOSE" -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# includes (modular test system)
################################################################################

# Load test helper functions
if [[ -f "${TEST_DIR}/test/01_helpers.sh" ]]; then
    source "${TEST_DIR}/test/01_helpers.sh";
    trace "Loaded test helpers from modular system";
else
    # Fallback: inline essential helpers if modules not found
    warn "Modular test helpers not found, using fallback";
    
    setup_test_env() {
        local test_rc="${HOME}/.watchdomrc.test";
        export WATCHDOM_RC="$test_rc";
        cat > "$test_rc" << 'EOF'
.test|whois.test.example|Domain not found
.example|whois.example.com|No such domain
EOF
    }
    
    cleanup_test_env() {
        [[ -f "${HOME}/.watchdomrc.test" ]] && rm -f "${HOME}/.watchdomrc.test";
        unset WATCHDOM_RC;
    }
    
    assert_success() {
        local cmd="$1" desc="$2";
        if eval "$cmd" >/dev/null 2>&1; then
            okay "✓ $desc"; return 0;
        else
            error "✗ $desc"; return 1;
        fi;
    }
    
    assert_exit_code() {
        local expected="$1" cmd="$2" desc="$3" actual;
        eval "$cmd" >/dev/null 2>&1; actual=$?;
        if [[ "$actual" -eq "$expected" ]]; then
            okay "✓ $desc"; return 0;
        else
            error "✗ $desc (expected $expected, got $actual)"; return 1;
        fi;
    }
    
    assert_contains() {
        local haystack="$1" needle="$2" desc="$3";
        if printf "%s" "$haystack" | grep -q "$needle"; then
            okay "✓ $desc"; return 0;
        else
            error "✗ $desc"; return 1;
        fi;
    }
    
    init_test_counters() { TEST_TOTAL=0; TEST_PASSED=0; TEST_FAILED=0; }
    record_test_result() { ((TEST_TOTAL++)); [[ "$1" -eq 0 ]] && ((TEST_PASSED++)) || ((TEST_FAILED++)); }
    show_test_summary() { 
        printf "\n📊 %s: %d/%d passed\n" "$1" "$TEST_PASSED" "$TEST_TOTAL" >&2;
        return $TEST_FAILED;
    }
fi;

# Load test suites
if [[ -f "${TEST_DIR}/test/02_suites.sh" ]]; then
    source "${TEST_DIR}/test/02_suites.sh";
    trace "Loaded test suites from modular system";
else
    warn "Modular test suites not found, using essential tests";
    
    # Essential fallback tests
    test_basic_functionality() {
        info "🔍 Testing basic functionality...";
        init_test_counters;
        
        assert_success "[[ -x '$TARGET_SCRIPT' ]]" "Script executable";
        record_test_result $?;
        
        assert_success "bash -n '$TARGET_SCRIPT'" "Syntax valid";
        record_test_result $?;
        
        assert_success "bash '$TARGET_SCRIPT' --help" "Help works";
        record_test_result $?;
        
        assert_exit_code 2 "bash '$TARGET_SCRIPT'" "No args error";
        record_test_result $?;
        
        show_test_summary "Basic Tests";
    }
    
    test_dispatch_system() {
        info "🔍 Testing commands...";
        init_test_counters;
        
        local commands=("status" "list_tlds" "time");
        for cmd in "${commands[@]}"; do
            case "$cmd" in
                time)
                    assert_exit_code 1 "bash '$TARGET_SCRIPT' time" "Command $cmd";
                    ;;
                *)
                    assert_success "bash '$TARGET_SCRIPT' $cmd" "Command $cmd";
                    ;;
            esac;
            record_test_result $?;
        done;
        
        show_test_summary "Command Tests";
    }
fi;

################################################################################
# main test runners
################################################################################

# Run all comprehensive tests
run_all_tests() {
    local total_failures=0;
    
    info "🚀 Starting comprehensive watchdom test suite";
    info "📁 Target script: $TARGET_SCRIPT";
    
    # Verify target script exists
    if [[ ! -f "$TARGET_SCRIPT" ]]; then
        fatal "❌ Target script not found: $TARGET_SCRIPT";
    fi;
    
    setup_test_env;
    
    # Run all test suites
    test_basic_functionality    && trace "✅ Basic tests passed"    || ((total_failures++));
    test_dispatch_system        && trace "✅ Dispatch tests passed" || ((total_failures++));
    
    # Only run extended tests if functions exist
    if declare -f test_time_functionality >/dev/null 2>&1; then
        test_time_functionality     && trace "✅ Time tests passed"     || ((total_failures++));
        test_tld_management         && trace "✅ TLD tests passed"      || ((total_failures++));
        test_option_parsing         && trace "✅ Option tests passed"   || ((total_failures++));
        test_installation_system    && trace "✅ Install tests passed"  || ((total_failures++));
        test_domain_watching        && trace "✅ Watch tests passed"    || ((total_failures++));
        test_bashfx_compliance      && trace "✅ BashFX tests passed"   || ((total_failures++));
        
        # Internal function testing
        if declare -f test_internal_functions >/dev/null 2>&1; then
            test_internal_functions && trace "✅ Internal tests passed" || ((total_failures++));
        fi;
    else
        warn "⚠️  Extended test suites not available (using fallback)";
    fi;
    
    cleanup_test_env;
    
    # Final summary
    printf "\n" >&2;
    if [[ "$total_failures" -eq 0 ]]; then
        okay "🎉 ALL TESTS PASSED! Watchdom is working correctly.";
        return 0;
    else
        error "💥 $total_failures test suite(s) had failures";
        warn "🔧 Check specific failures above to identify issues";
        return 1;
    fi;
}

# Quick smoke test
run_quick_test() {
    info "⚡ Running quick smoke tests...";
    init_test_counters;
    
    # Essential functionality only
    assert_success "bash '$TARGET_SCRIPT' --help" "Help works";
    record_test_result $?;
    
    assert_success "bash '$TARGET_SCRIPT' status" "Status works";
    record_test_result $?;
    
    assert_success "bash '$TARGET_SCRIPT' list_tlds" "List TLDs works";
    record_test_result $?;
    
    assert_success "bash '$TARGET_SCRIPT' time '2025-12-25 12:00:00 UTC'" "Time works";
    record_test_result $?;
    
    show_test_summary "Quick Tests";
}

# Test specific area
run_single_test() {
    local test_name="${1:-}";
    
    if [[ -z "$test_name" ]]; then
        error "Test name required";
        info "Available tests: basic, dispatch, time, tld, options, install, watch, bashfx, internal";
        return 2;
    fi;
    
    setup_test_env;
    
    case "$test_name" in
        basic)    test_basic_functionality ;;
        dispatch) test_dispatch_system ;;
        time)     test_time_functionality ;;
        tld)      test_tld_management ;;
        options)  test_option_parsing ;;
        install)  test_installation_system ;;
        watch)    test_domain_watching ;;
        bashfx)   test_bashfx_compliance ;;
        internal) test_internal_functions ;;
        *)
            error "Unknown test: $test_name";
            info "Available: basic, dispatch, time, tld, options, install, watch, bashfx, internal";
            cleanup_test_env;
            return 2;
            ;;
    esac;
    
    local ret=$?;
    cleanup_test_env;
    return $ret;
}

# Dev function for comprehensive testing
dev_test() {
    local mode="${1:-all}";
    
    case "$mode" in
        all)      run_all_tests ;;
        quick)    run_quick_test ;;
        *)        run_single_test "$mode" ;;
    esac;
}

################################################################################
# usage
################################################################################
usage() {
    cat << 'EOF'
test_runner.sh - Comprehensive test suite for watchdom

USAGE:
  test_runner.sh [OPTIONS] [COMMAND]

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
  watch                     Domain watching (no server calls)
  bashfx                    BashFX compliance validation
  internal                  Internal function testing

OPTIONS:
  -s, --script PATH         Test specific watchdom script
  -v, --verbose             Enable verbose trace output
  -q, --quick               Quick mode (same as 'quick' command)
  -h, --help                Show this help

EXAMPLES:
  ./test_runner.sh                    # Run all tests
  ./test_runner.sh quick              # Quick smoke test
  ./test_runner.sh time               # Test time functionality only
  ./test_runner.sh -v all             # Verbose full test
  ./test_runner.sh -s ./my_script.sh  # Test custom script

TESTING APPROACH:
  • No external server calls (safe for CI/automation)
  • Comprehensive functionality validation
  • BashFX architectural compliance checks
  • Internal function testing via sourcing
  • Isolated test environment

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
    local command="all";
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--script)
                [[ $# -ge 2 ]] || { error "Option $1 requires argument"; return 2; };
                TARGET_SCRIPT="$2";
                shift 2;
                ;;
            -v|--verbose)
                VERBOSE=1;
                shift;
                ;;
            -q|--quick)
                command="quick";
                shift;
                ;;
            -h|--help)
                usage;
                return 0;
                ;;
            -*)
                error "Unknown option: $1";
                usage;
                return 2;
                ;;
            *)
                command="$1";
                shift;
                ;;
        esac;
    done;
    
    # Validate target script
    if [[ ! -f "$TARGET_SCRIPT" ]]; then
        error "Target script not found: $TARGET_SCRIPT";
        return 2;
    fi;
    
    # Run the requested command
    case "$command" in
        all)
            run_all_tests;
            ;;
        quick)
            run_quick_test;
            ;;
        basic|dispatch|time|tld|options|install|watch|bashfx|internal)
            run_single_test "$command";
            ;;
        *)
            error "Unknown command: $command";
            usage;
            return 2;
            ;;
    esac;
}

################################################################################
# invocation
################################################################################
main "$@"
