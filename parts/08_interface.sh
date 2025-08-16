################################################################################
# interface - user interface with proper BashFX separation
################################################################################

################################################################################
# usage - Help documentation
################################################################################
usage() {
    cat <<'EOF'
watchdom - registry WHOIS watcher with phase-aware polling

USAGE:
  watchdom COMMAND [OPTIONS]

COMMANDS:
  query DOMAIN                     Single WHOIS lookup
  watch DOMAIN [OPTIONS]           Monitor domain with polling  
  time "DATETIME" [OPTIONS]        Countdown to target time
  list_tlds                        Show supported TLD configurations
  add_tld TLD SERVER PATTERN       Add custom TLD configuration
  test_tld TLD DOMAIN              Test TLD pattern matching
  install                          Install to system paths
  uninstall                        Remove from system paths
  status                           Show installation status

WATCH OPTIONS:
  -i SECONDS      Base polling interval (default: 60)
  -e PATTERN      Expected availability pattern (custom regex)
  -n MAX_CHECKS   Stop after N checks (default: unlimited)
  --until WHEN    Target datetime ("YYYY-MM-DD HH:MM:SS UTC" or epoch)
  --time-utc      Display times in UTC instead of local

GLOBAL OPTIONS:
  -d, --debug     Enable debug messages (default: ON)
  -t, --trace     Enable trace messages (verbose polling)
  -q, --quiet     Force quiet mode (errors only)
  -y, --yes       Auto-confirm prompts
  -h, --help      Show this help

EXAMPLES:
  watchdom query example.com
  watchdom watch example.com -i 30
  watchdom watch premium.com --until "2025-12-25 18:00:00 UTC" -i 10
  watchdom time "2025-12-25 18:00:00 UTC"
  watchdom add_tld .uk whois.nominet.uk "No such domain"

PHASE SYSTEM:
  λ POLL  - Normal polling intervals
  ▲ HEAT  - Aggressive polling as target approaches  
  ▵ GRACE - Post-target monitoring window
  ❅ COOL  - Backing off with longer intervals

EXIT CODES:
  0: Success (pattern matched/available)
  1: Not found (timeout/unavailable)
  2: Bad arguments
  3: Missing dependencies
  4: Date parse error
EOF
}

################################################################################
# options - Argument parsing (extracted from main for BashFX compliance)
################################################################################
options() {
    # Initialize option variables with defaults
    opt_debug=${DEFAULT_DEBUG};  # Debug ON by default now
    opt_trace=0;
    opt_quiet=0;
    opt_yes=0;
    opt_interval="";
    opt_expect="";
    opt_max_checks="";
    opt_until="";
    opt_time_utc=0;
    
    # Parse all options, separating them from positional arguments
    local args=();
    while [[ $# -gt 0 ]]; do
        case "$1" in
            (-d|--debug) opt_debug=1; shift ;;
            (-t|--trace) opt_trace=1; opt_debug=1; shift ;;
            (-q|--quiet) opt_quiet=1; opt_debug=0; opt_trace=0; shift ;;
            (-y|--yes) opt_yes=1; shift ;;
            (-i)
                [[ $# -ge 2 ]] || { error "Option -i requires an argument"; return 2; };
                opt_interval="$2"; shift 2 ;;
            (-e)
                [[ $# -ge 2 ]] || { error "Option -e requires an argument"; return 2; };
                opt_expect="$2"; shift 2 ;;
            (-n)
                [[ $# -ge 2 ]] || { error "Option -n requires an argument"; return 2; };
                opt_max_checks="$2"; shift 2 ;;
            (--until)
                [[ $# -ge 2 ]] || { error "Option --until requires an argument"; return 2; };
                opt_until="$2"; shift 2 ;;
            (--time-utc|--utc) opt_time_utc=1; shift ;;
            (--time-local) opt_time_utc=0; shift ;;
            (-h|--help) usage; exit 0 ;;
            (--) shift; args+=("$@"); break ;;
            (-*) error "Unknown option: %s" "$1"; usage; return 2 ;;
            (*) args+=("$1"); shift ;;
        esac;
    done;
    
    # Restore positional arguments
    [[ ${#args[@]} -gt 0 ]] && set -- "${args[@]}";
    
    # Apply quiet mode override
    if [[ "$opt_quiet" -eq 1 ]]; then
        opt_debug=0;
        opt_trace=0;
    fi;
    
    # Export parsed arguments
    export opt_debug opt_trace opt_quiet opt_yes opt_interval opt_expect opt_max_checks opt_until opt_time_utc;
    
    # Return remaining arguments via global array
    remaining_args=("$@");
    return 0;
}

################################################################################
# dispatch - Command routing (extracted from main for BashFX compliance)
################################################################################
dispatch() {
    local cmd="${1:-}";
    local ret=1;
    
    # Validate command
    if [[ -z "$cmd" ]]; then
        error "No command specified";
        usage;
        return 2;
    fi;
    
    # Route to command functions
    case "$cmd" in
        (query)
            [[ $# -ge 2 ]] || { error "Command 'query' requires a domain"; return 2; };
            shift;
            do_query "$@";
            ret=$?;
            ;;
        (watch)
            [[ $# -ge 2 ]] || { error "Command 'watch' requires a domain"; return 2; };
            shift;
            do_watch "$@";
            ret=$?;
            ;;
        (time)
            [[ $# -ge 2 ]] || { error "Command 'time' requires a datetime"; return 2; };
            shift;
            do_time "$@";
            ret=$?;
            ;;
        (list_tlds)
            do_list_tlds;
            ret=$?;
            ;;
        (add_tld)
            [[ $# -ge 4 ]] || { error "Command 'add_tld' requires TLD, server, and pattern"; return 2; };
            shift;
            do_add_tld "$@";
            ret=$?;
            ;;
        (test_tld)
            [[ $# -ge 3 ]] || { error "Command 'test_tld' requires TLD and test domain"; return 2; };
            shift;
            do_test_tld "$@";
            ret=$?;
            ;;
        (install)
            do_install;
            ret=$?;
            ;;
        (uninstall)
            do_uninstall;
            ret=$?;
            ;;
        (status)
            do_status;
            ret=$?;
            ;;
        (*)
            error "Unknown command: %s" "$cmd";
            usage;
            ret=2;
            ;;
    esac;
    
    return $ret;
}

################################################################################
# main - Entry point (BashFX compliant: parse and dispatch only)
################################################################################
main() {
    local ret=1;
    
    # Set up signal handling
    trap '_cleanup' INT TERM;
    
    # Parse arguments
    local remaining_args=();
    if ! options "$@"; then
        return 2;
    fi;
    
    # Dispatch to command
    if [[ ${#remaining_args[@]} -gt 0 ]]; then
        dispatch "${remaining_args[@]}";
        ret=$?;
    else
        error "No command specified";
        usage;
        ret=2;
    fi;
    
    return $ret;
}
