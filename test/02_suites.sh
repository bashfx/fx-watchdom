#!/usr/bin/env bash  
# test/02_suites.sh - Comprehensive test suites for watchdom
# Tests all functionality without spamming external servers

################################################################################
# test suites
################################################################################

# Test 1: Basic functionality and structure
test_basic_functionality() {
    info "🔍 Testing basic script functionality...";
    init_test_counters;
    
    # Script exists and executable
    assert_success "[[ -x '$TARGET_SCRIPT' ]]" "Script is executable";
    record_test_result $?;
    
    # Syntax validation
    assert_success "bash -n '$TARGET_SCRIPT'" "Script syntax valid";
    record_test_result $?;
    
    # Help displays without error
    assert_success "bash '$TARGET_SCRIPT' --help" "Help displays";
    record_test_result $?;
    
    # Version info in help
    local help_output;
    help_output="$(bash '$TARGET_SCRIPT' --help 2>&1)";
    assert_contains "$help_output" "watchdom.*2\.0\.0" "Version in help";
    record_test_result $?;
    
    # Usage examples in help
    assert_contains "$help_output" "EXAMPLES:" "Examples section";
    record_test_result $?;
    
    # Exit codes documented
    assert_contains "$help_output" "EXIT CODES:" "Exit codes documented";
    record_test_result $?;
    
    # Invalid options rejected
    assert_exit_code 2 "bash '$TARGET_SCRIPT' --invalid-option" "Invalid options rejected";
    record_test_result $?;
    
    # No args shows error
    assert_exit_code 2 "bash '$TARGET_SCRIPT'" "No args shows error";
    record_test_result $?;
    
    show_test_summary "Basic Functionality";
}

# Test 2: Command dispatch system
test_dispatch_system() {
    info "🔍 Testing command dispatch system...";
    init_test_counters;
    
    local commands=("time" "list_tlds" "add_tld" "test_tld" "install" "uninstall" "status");
    
    for cmd in "${commands[@]}"; do
        case "$cmd" in
            time)
                assert_exit_code 1 "bash '$TARGET_SCRIPT' time" "Command '$cmd' handles no args";
                record_test_result $?;
                ;;
            add_tld|test_tld)
                assert_exit_code 2 "bash '$TARGET_SCRIPT' $cmd" "Command '$cmd' shows usage";
                record_test_result $?;
                ;;
            *)
                assert_success "bash '$TARGET_SCRIPT' $cmd" "Command '$cmd' executes";
                record_test_result $?;
                ;;
        esac;
    done;
    
    # Test unknown command handling
    assert_exit_code 1 "bash '$TARGET_SCRIPT' unknown_command" "Unknown command rejected";
    record_test_result $?;
    
    show_test_summary "Command Dispatch";
}

# Test 3: Time functionality
test_time_functionality() {
    info "🔍 Testing time functionality...";
    init_test_counters;
    
    # Current epoch time
    local current_epoch;
    current_epoch="$(date -u +%s)";
    assert_success "bash '$TARGET_SCRIPT' time $current_epoch" "Current epoch parsing";
    record_test_result $?;
    
    # Future date parsing
    assert_success "bash '$TARGET_SCRIPT' time '2025-12-25 12:00:00 UTC'" "Future date parsing";
    record_test_result $?;
    
    # Past date handling
    assert_success "bash '$TARGET_SCRIPT' time '2020-01-01 00:00:00 UTC'" "Past date handling";
    record_test_result $?;
    
    # Invalid date handling
    assert_exit_code 1 "bash '$TARGET_SCRIPT' time 'invalid-date'" "Invalid date rejected";
    record_test_result $?;
    
    # Empty time argument
    assert_exit_code 1 "bash '$TARGET_SCRIPT' time" "Empty time argument";
    record_test_result $?;
    
    # Output format validation
    local time_output;
    time_output="$(bash '$TARGET_SCRIPT' time "$current_epoch" 2>&1)";
    assert_contains "$time_output" "UNTIL_EPOCH=" "Epoch in output";
    record_test_result $?;
    
    assert_contains "$time_output" "Remaining:" "Remaining time shown";
    record_test_result $?;
    
    # Local time option
    local local_output;
    local_output="$(bash '$TARGET_SCRIPT' time "$current_epoch" --time_local 2>&1)";
    assert_contains "$local_output" "Local:" "Local time option works";
    record_test_result $?;
    
    show_test_summary "Time Functionality";
}

# Test 4: TLD management
test_tld_management() {
    info "🔍 Testing TLD management...";
    init_test_counters;
    
    # List built-in TLDs
    local tld_output;
    tld_output="$(bash '$TARGET_SCRIPT' list_tlds 2>&1)";
    
    assert_contains "$tld_output" "\.com.*whois\.verisign-grs\.com" "Built-in .com TLD";
    record_test_result $?;
    
    assert_contains "$tld_output" "\.net.*whois\.verisign-grs\.com" "Built-in .net TLD";
    record_test_result $?;
    
    assert_contains "$tld_output" "\.org.*whois\.pir\.org" "Built-in .org TLD";
    record_test_result $?;
    
    # Configuration sources shown
    assert_contains "$tld_output" "Configuration sources:" "Config sources listed";
    record_test_result $?;
    
    # Add custom TLD
    assert_success "bash '$TARGET_SCRIPT' add_tld .test whois.test.example 'Domain not found'" "Add custom TLD";
    record_test_result $?;
    
    # Verify custom TLD appears in list
    tld_output="$(bash '$TARGET_SCRIPT' list_tlds 2>&1)";
    assert_contains "$tld_output" "\.test.*whois\.test\.example" "Custom TLD listed";
    record_test_result $?;
    
    # Test add_tld error handling
    assert_exit_code 2 "bash '$TARGET_SCRIPT' add_tld" "add_tld no args error";
    record_test_result $?;
    
    assert_exit_code 2 "bash '$TARGET_SCRIPT' add_tld .test" "add_tld missing args error";
    record_test_result $?;
    
    # Test invalid TLD format
    assert_exit_code 2 "bash '$TARGET_SCRIPT' add_tld 'invalid_tld' server pattern" "Invalid TLD format";
    record_test_result $?;
    
    show_test_summary "TLD Management";
}

# Test 5: Option parsing
test_option_parsing() {
    info "🔍 Testing option parsing...";
    init_test_counters;
    
    # Standard BashFX flags
    assert_success "bash '$TARGET_SCRIPT' -d status" "Debug flag";
    record_test_result $?;
    
    assert_success "bash '$TARGET_SCRIPT' -t status" "Trace flag";
    record_test_result $?;
    
    assert_success "bash '$TARGET_SCRIPT' -q status" "Quiet flag";
    record_test_result $?;
    
    assert_success "bash '$TARGET_SCRIPT' -f status" "Force flag";
    record_test_result $?;
    
    assert_success "bash '$TARGET_SCRIPT' -D status" "Dev flag (combines debug+trace)";
    record_test_result $?;
    
    # Command-specific options
    assert_success "bash '$TARGET_SCRIPT' time '2025-12-25 12:00:00 UTC' -i 120" "Interval option";
    record_test_result $?;
    
    assert_success "bash '$TARGET_SCRIPT' time '2025-12-25 12:00:00 UTC' -e 'custom pattern'" "Expect option";
    record_test_result $?;
    
    assert_success "bash '$TARGET_SCRIPT' time '2025-12-25 12:00:00 UTC' -n 5" "Max checks option";
    record_test_result $?;
    
    assert_success "bash '$TARGET_SCRIPT' time '2025-12-25 12:00:00 UTC' --until '2025-12-25 13:00:00 UTC'" "Until option";
    record_test_result $?;
    
    # Option error handling
    assert_exit_code 2 "bash '$TARGET_SCRIPT' -i" "Missing interval value";
    record_test_result $?;
    
    assert_exit_code 2 "bash '$TARGET_SCRIPT' -e" "Missing expect value";
    record_test_result $?;
    
    show_test_summary "Option Parsing";
}

# Test 6: Installation system
test_installation_system() {
    info "🔍 Testing installation system...";
    init_test_counters;
    
    # Status command works
    assert_success "bash '$TARGET_SCRIPT' status" "Status command executes";
    record_test_result $?;
    
    # Status output format
    local status_output;
    status_output="$(bash '$TARGET_SCRIPT' status 2>&1)";
    
    assert_contains "$status_output" "Installation Status" "Status header present";
    record_test_result $?;
    
    assert_contains "$status_output" "Current script:" "Current script info";
    record_test_result $?;
    
    assert_contains "$status_output" "Installed at" "Installation path info";
    record_test_result $?;
    
    # Install with force (to avoid conflicts)
    assert_success "bash '$TARGET_SCRIPT' install -f" "Force install works";
    record_test_result $?;
    
    # Verify installation status
    status_output="$(bash '$TARGET_SCRIPT' status 2>&1)";
    assert_contains "$status_output" "properly installed" "Install success reported";
    record_test_result $?;
    
    # Uninstall
    assert_success "bash '$TARGET_SCRIPT' uninstall" "Uninstall works";
    record_test_result $?;
    
    # Double uninstall handling
    local uninstall_output;
    uninstall_output="$(bash '$TARGET_SCRIPT' uninstall 2>&1)";
    assert_contains "$uninstall_output" "not installed\|already removed" "Double uninstall handled";
    record_test_result $?;
    
    show_test_summary "Installation System";
}

# Test 7: Domain watching (no actual monitoring)
test_domain_watching() {
    info "🔍 Testing domain watching functionality...";
    init_test_counters;
    
    # No domain error
    assert_exit_code 2 "bash '$TARGET_SCRIPT' watch" "Watch requires domain";
    record_test_result $?;
    
    # Invalid domain formats
    assert_failure "bash '$TARGET_SCRIPT' watch 'invalid..domain'" "Invalid domain format";
    record_test_result $?;
    
    assert_failure "bash '$TARGET_SCRIPT' watch ''" "Empty domain";
    record_test_result $?;
    
    assert_failure "bash '$TARGET_SCRIPT' watch '...'" "Malformed domain";
    record_test_result $?;
    
    # Unsupported TLD handling
    assert_exit_code 1 "bash '$TARGET_SCRIPT' watch 'test.unsupported12345'" "Unsupported TLD error";
    record_test_result $?;
    
    # Valid domain format accepted (will fail due to missing whois/network)
    test_with_timeout 3 "bash '$TARGET_SCRIPT' watch 'example.com'" "Valid domain format accepted";
    record_test_result $?;
    
    # Legacy syntax support
    test_with_timeout 3 "bash '$TARGET_SCRIPT' example.com" "Legacy syntax works";
    record_test_result $?;
    
    # Watch with options
    test_with_timeout 3 "bash '$TARGET_SCRIPT' watch example.com -i 5 -n 1" "Watch with options";
    record_test_result $?;
    
    show_test_summary "Domain Watching";
}

# Test 8: BashFX compliance
test_bashfx_compliance() {
    info "🔍 Testing BashFX compliance...";
    init_test_counters;
    
    # XDG+ paths mentioned in help
    local help_output;
    help_output="$(bash '$TARGET_SCRIPT' --help 2>&1)";
    assert_contains "$help_output" "\.local" "XDG+ paths mentioned";
    record_test_result $?;
    
    # FX namespace usage
    assert_contains "$help_output" "fx" "FX namespace referenced";
    record_test_result $?;
    
    # Proper exit codes
    assert_exit_code 0 "bash '$TARGET_SCRIPT' status" "Success exit code";
    record_test_result $?;
    
    assert_exit_code 1 "bash '$TARGET_SCRIPT' time 'invalid'" "Error exit code";
    record_test_result $?;
    
    # Stderr vs stdout separation  
    local stdout_output stderr_output;
    stdout_output="$(bash '$TARGET_SCRIPT' time '2025-12-25 12:00:00 UTC' 2>/dev/null)";
    stderr_output="$(bash '$TARGET_SCRIPT' time '2025-12-25 12:00:00 UTC' 2>&1 >/dev/null)";
    
    assert_contains "$stdout_output" "UNTIL_EPOCH" "Data goes to stdout";
    record_test_result $?;
    
    # Should have some stderr output (info messages)
    if [[ -n "$stderr_output" ]]; then
        okay "✓ Messages go to stderr";
        record_test_result 0;
    else
        error "✗ No stderr output detected";
        record_test_result 1;
    fi;
    
    # Test semicolon compliance (basic check)
    test_bashfx_semicolons "$TARGET_SCRIPT" "Basic semicolon compliance";
    record_test_result $?;
    
    show_test_summary "BashFX Compliance";
}

################################################################################
# internal function testing (by sourcing)
################################################################################

# Test internal functions by sourcing the script
test_internal_functions() {
    info "🔍 Testing internal functions...";
    init_test_counters;
    
    # Source the script to test internal functions
    if source "$TARGET_SCRIPT" 2>/dev/null; then
        okay "✓ Script sources successfully";
        record_test_result 0;
    else
        error "✗ Script failed to source";
        record_test_result 1;
        show_test_summary "Internal Functions";
        return 1;
    fi;
    
    # Test key function existence
    local key_functions=(
        "main" "dispatch" "usage" 
        "do_watch" "do_time" "do_list_tlds" "do_add_tld" "do_status"
        "_load_tld_config" "_validate_domain" "_extract_tld"
        "__parse_datetime" "__whois_query" "__human_duration" "__format_date"
    );
    
    for func in "${key_functions[@]}"; do
        assert_function_exists "$func" "Function $func exists";
        record_test_result $?;
    done;
    
    # Test simple helper functions  
    if declare -f "__human_duration" >/dev/null 2>&1; then
        test_function_output "__human_duration" "3661" "1h.*1m.*1s" "Human duration formatting";
        record_test_result $?;
        
        test_function_output "__human_duration" "86400" "1d" "Duration with days";
        record_test_result $?;
    fi;
    
    if declare -f "_extract_tld" >/dev/null 2>&1; then
        test_function_output "_extract_tld" "example.com" "\.com" "TLD extraction";
        record_test_result $?;
        
        test_function_output "_extract_tld" "test.co.uk" "\.uk" "Complex TLD extraction";
        record_test_result $?;
    fi;
    
    show_test_summary "Internal Functions";
}
