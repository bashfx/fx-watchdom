# BashFX Compliance Plan for `watchdom.sh`

## 🎯 **Overall Strategy**
Convert from traditional shell script → **BashFX Utility Script** with extensible TLD support, proper architectural patterns, and user configuration.

## 📋 **Key Misalignments & Solutions**

| Issue | Current State | BashFX Solution |
|-------|---------------|-----------------|
| **No Standard Interface** | Inline arg parsing | Implement `main()`, `dispatch()`, `options()` |
| **Missing Function Ordinality** | Flat function structure | Add `do_*`, `_*`, `__*` hierarchy |
| **No QUIET/Logging Spec** | Raw `echo`/`printf` | Implement `stderr` logging levels |
| **Hardcoded TLD Logic** | Switch statement | Extensible TLD registry + `.watchdomrc` |
| **Global Execution** | Script runs in global scope | Proper `main "$@"` invocation |
| **Mixed Concerns** | Logic + parsing together | Separate parsing, validation, execution |
| **No User Config** | Hardcoded patterns | Load `.watchdomrc` for custom TLDs |

## 🏗️ **Function Architecture**

### **Super-Ordinal Functions**
```bash
main()          # Entry point, orchestrates lifecycle
dispatch()      # Command router: watch|time|list-tlds|add-tld
```

### **High-Order Functions (do_*)**
```bash
do_watch()      # Primary domain watching (current main logic)
do_time()       # Time-only mode (--time-until)
do_list_tlds()  # Show supported TLD patterns
do_add_tld()    # Add custom TLD to ~/.watchdomrc
```

### **Independent Functions**
```bash
options()       # Parse flags, set opt_* variables  
usage()         # Help text (integrate existing)
```

### **Mid-Level Helpers (_*)**
```bash
_validate_domain()      # Domain format validation
_load_tld_config()      # Load built-in + ~/.watchdomrc patterns
_get_tld_config()       # Get server/pattern for specific TLD
_calculate_interval()   # Smart interval ramping (PRE/HEAT/GRACE/COOL phases)
_format_countdown()     # Dynamic countdown display with phase-aware styling
_extract_tld()          # Extract TLD from domain (handle edge cases)
_check_grace_timeout()  # Check if 3hr grace period exceeded, prompt user
_get_phase_label()      # Determine current phase (PRE/HEAT/GRACE/COOL)
_notify_event()         # Send email notification for key events
```

### **Low-Level Literals (__*)**
```bash
__whois_query()         # Raw whois execution with error handling
__parse_datetime()      # Date parsing (consolidate current functions)
__print_status_line()   # Single dynamic status line with cursor control
__save_tld_config()     # Write new TLD config to ~/.watchdomrc
__test_tld_pattern()    # Test if pattern works for given domain
__send_email()          # Low-level email sending via mutt/msmtp
```

## 🎨 **Enhanced Phase-Based Polling System**

### **Polling Phases & Visual Design**

| Phase | Time Relative to Target | Interval Logic | Color | Glyph | Label |
|-------|------------------------|----------------|-------|-------|-------|
| **PRE** | >30min before target | Base interval (default 60s) | `blue` | `λ` | `[PRE]` |
| **HEAT** | ≤30min before target | Ramp down: 30s → 10s | `red` | `▲` | `[HEAT]` |
| **GRACE** | 0-3hrs after target | Stick at 10s | `purple` | `△` | `[GRACE]` |
| **COOL** | >3hrs after target | Cool up: 30s → 1m → 5m → 10m → 30m → 1hr | `cyan` | `❄` | `[COOL]` |

### **Cooldown Sequence**
```bash
# After target passes, intervals increase gradually:
# 0-10min past:   10s  (GRACE phase)
# 10-20min past: 30s  (COOL phase begins)
# 20-30min past: 1m
# 30-60min past: 5m
# 1-2hrs past:   10m
# 2-3hrs past:   30m
# 3hrs+ past:    1hr (with user prompt)
```

### **3-Hour Grace Prompt**
After 3 hours past target, watchdom prompts:
```
Grace period expired (3hrs past target). Continue watching?
[y] Yes, keep 1hr intervals
[n] No, exit
[c] Custom interval (specify seconds)
```

### **Enhanced Status Line Examples**
```bash
# PRE phase (before target)
printf "\r%s%s%s next poll in 60s | target in 2h 15m | [PRE] UTC: ... %s" "$blue" "$lambda" "$x" "$eol"

# HEAT phase (approaching target)  
printf "\r%s%s%s next poll in 10s | target in 8m | [HEAT] UTC: ... %s" "$red" "$delta" "$x" "$eol"

# GRACE phase (just past target)
printf "\r%s%s%s next poll in 10s | target since 15m | [GRACE] UTC: ... %s" "$purple" "$delta" "$x" "$eol"

# COOL phase (cooling down)
printf "\r%s%s%s next poll in 5m | target since 1h 30m | [COOL] UTC: ... %s" "$cyan" "$spark" "$x" "$eol"
```

## 📊 **stderr Logging Plan**
```bash
# Current → BashFX Equivalent
echo -e "${GREEN}[...] SUCCESS"     → okay "Pattern matched for %s" "$domain"
echo -e "${GREY}[...] not yet"      → info "Waiting - next poll in %ss" "$interval"  
echo -e "${YEL}WARN: interval..."   → warn "Interval %ss may trigger rate limits" "$eff"
echo "ERR: cannot parse..."         → error "Cannot parse time '%s'" "$when"
echo "ERR: 'whois' not found"       → fatal "Required command 'whois' not found"
printf "\r${BLUE}%s${NC}" "$line"   → trace "Countdown: %s" "$line"
```

### **QUIET Compliance Levels**
```bash
# Default (no flags): Only error/fatal visible
# -d (debug): Enable info/okay/warn  
# -t (trace): Enable trace (verbose polling details)
# -q (quiet): Force quiet, override inherited modes
# -D (dev): Enable debug + trace + dev_* functions
```

### **Simple stderr Implementation**
```bash
# Inline stderr functions (no external dependency)
info()  { [[ $opt_debug -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ $opt_debug -eq 1 ]] && printf "%s[%s]%s %s\n" "$green" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
warn()  { [[ $opt_debug -eq 1 ]] && printf "%s[%s]%s %s\n" "$yellow" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
error() { printf "%s[%s]%s %s\n" "$red" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
fatal() { printf "%s[%s]%s %s\n" "$red2" "$(date +%H:%M:%S)" "$x" "$*" >&2; exit 1; }
trace() { [[ $opt_trace -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
```

## 📧 **Email Notification System**

### **Notification Triggers**
- **SUCCESS**: Domain becomes available (pattern matched)
- **TARGET_REACHED**: Target time reached, entering grace period  
- **GRACE_ENTERED**: 3+ hours past target, grace period exceeded

### **Configuration Requirements**
All environment variables must be set to enable notifications:
```bash
export NOTIFY_EMAIL="user@domain.com"        # Recipient
export NOTIFY_FROM="watchdom@server.com"     # Sender  
export NOTIFY_SMTP_HOST="smtp.gmail.com"     # SMTP server
export NOTIFY_SMTP_PORT="587"                # SMTP port
export NOTIFY_SMTP_USER="username"           # SMTP auth user
export NOTIFY_SMTP_PASS="app_password"       # SMTP auth password
```

### **Email Client Priority**
1. **mutt** (preferred - most reliable)
2. **msmtp + mail** (fallback)
3. **sendmail** (last resort)

### **Usage Examples**
```bash
# In do_watch() when success detected:
okay "Domain available: %s" "$domain"
_notify_event "success" "$domain" "Detected at $(date)"

# When target time reached:
info "Target time reached, entering grace period"
_notify_event "target_reached" "$domain" "Target: $(fmt_utc $target_epoch)"

# When 3hr grace exceeded:
warn "Grace period exceeded (3+ hours past target)"
_notify_event "grace_entered" "$domain" "Exceeded at $(date)"
```

## 🌐 **TLD Registry System**
```bash
declare -A TLD_SERVERS TLD_PATTERNS
TLD_SERVERS[".com"]="whois.verisign-grs.com"
TLD_SERVERS[".net"]="whois.verisign-grs.com" 
TLD_SERVERS[".org"]="whois.pir.org"

TLD_PATTERNS[".com"]="No match for"
TLD_PATTERNS[".net"]="No match for"
TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
```

### **User Configuration (~/.watchdomrc)**
```bash
# Format: TLD|SERVER|PATTERN
# Examples:
.uk|whois.nominet.uk|No such domain
.de|whois.denic.de|Status: free
.fr|whois.afnic.fr|No entries found
.io|whois.nic.io|is available for purchase
```

### **Extensible Commands**
```bash
watchdom list_tlds                      # Show supported TLDs
watchdom add_tld .uk whois.nominet.uk "No such domain"  # Add to ~/.watchdomrc
watchdom test_tld .com example-test.com      # Test TLD pattern works
```

## 🔄 **Enhanced Command Interface**

### **Current Compatibility (Preserved)**
```bash
watchdom DOMAIN [options]              # Auto-dispatch to 'watch'
watchdom --time-until "date"           # Auto-dispatch to 'time'
```

### **New BashFX Dispatch Pattern**
```bash
watchdom watch DOMAIN [options]        # Explicit watch command
watchdom time "date" [options]         # Time-only mode
watchdom list_tlds                     # Show supported TLDs
watchdom add_tld TLD SERVER PATTERN    # Add custom TLD
watchdom test_tld TLD DOMAIN           # Test TLD pattern
```

### **Enhanced Options Support**
```bash
# Standard BashFX flags
-d, --debug     # Enable info/okay/warn messages
-t, --trace     # Enable trace messages (verbose polling)
-q, --quiet     # Force quiet mode
-f, --force     # Skip safety guards
-D, --dev       # Developer mode (implies -d -t)

# Domain-specific flags (preserved)
-i SECONDS      # Base poll interval
-e REGEX        # Expected pattern override
-n MAX_CHECKS   # Stop after N checks
--until WHEN    # Target datetime
--time_local    # Local time display only
```

## 📁 **File Structure Template**

```bash
#!/usr/bin/env bash
# watchdom - registry WHOIS watcher with dynamic countdown
# version: 2.0.0-bashfx
# portable: whois, date, grep, sed
# builtins: printf, read, local, declare, case, if, for, while

################################################################################
# readonly
################################################################################
readonly SELF_NAME="watchdom"
readonly SELF_VERSION="2.0.0-bashfx"  
readonly WATCHDOM_RC="$HOME/.watchdomrc"

################################################################################
# config  
################################################################################
# Default settings (overridable by environment)
DEFAULT_INTERVAL=60
DEFAULT_MAX_CHECKS=0
DEFAULT_TIME_LOCAL=0

# Email notification settings (all must be set to enable notifications)
NOTIFY_EMAIL=""           # Recipient email (e.g., "user@domain.com")
NOTIFY_FROM=""            # Sender email (e.g., "watchdom@server.com")  
NOTIFY_SMTP_HOST=""       # SMTP server (e.g., "smtp.gmail.com")
NOTIFY_SMTP_PORT=""       # SMTP port (e.g., "587")
NOTIFY_SMTP_USER=""       # SMTP username
NOTIFY_SMTP_PASS=""       # SMTP password or app token

################################################################################
# escape sequences (from esc.sh.txt)
################################################################################
readonly red2=

# Glyphs
readonly pass=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# notification system
################################################################################
_is_notify_configured() {
    [[ -n "$NOTIFY_EMAIL" && -n "$NOTIFY_FROM" && -n "$NOTIFY_SMTP_HOST" && 
       -n "$NOTIFY_SMTP_PORT" && -n "$NOTIFY_SMTP_USER" && -n "$NOTIFY_SMTP_PASS" ]]
}

_notify_event() {
    local event="$1"    # "success"|"target_reached"|"grace_entered"
    local domain="$2"
    local details="$3"
    
    _is_notify_configured || return 0
    
    case "$event" in
        (success)
            __send_email "Domain Available: $domain" "SUCCESS: $domain is now available for registration!\n\nDetails: $details"
            ;;
        (target_reached)
            __send_email "Target Time Reached: $domain" "Target time reached for $domain monitoring.\n\nEntering grace period...\n\nDetails: $details"
            ;;
        (grace_entered)
            __send_email "Grace Period: $domain" "Grace period exceeded for $domain (3+ hours past target).\n\nDetails: $details"
            ;;
    esac
}

__send_email() {
    local subject="$1"
    local body="$2"
    local ret=1
    
    # Try mutt first (most common)
    if command -v mutt >/dev/null 2>&1; then
        printf "%s" "$body" | mutt -s "$subject" "$NOTIFY_EMAIL" 2>/dev/null
        ret=$?
    # Fallback to msmtp + mail
    elif command -v msmtp >/dev/null 2>&1 && command -v mail >/dev/null 2>&1; then
        printf "%s" "$body" | mail -s "$subject" "$NOTIFY_EMAIL" 2>/dev/null
        ret=$?
    # Fallback to sendmail if available
    elif command -v sendmail >/dev/null 2>&1; then
        {
            printf "To: %s\n" "$NOTIFY_EMAIL"
            printf "From: %s\n" "$NOTIFY_FROM"
            printf "Subject: %s\n\n" "$subject"
            printf "%s\n" "$body"
        } | sendmail "$NOTIFY_EMAIL" 2>/dev/null
        ret=$?
    fi
    
    if [[ $ret -eq 0 ]]; then
        trace "Email notification sent: $subject"
    else
        warn "Failed to send email notification"
    fi
    
    return $ret
}

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Email Notifications**
- [ ] Implement notification configuration checking
- [ ] Add email sending with mutt/msmtp/sendmail fallbacks
- [ ] Integrate notifications at key trigger points
- [ ] Add notification testing command

### **Phase 5: Enhanced Polling System**
- [ ] Implement phase detection (PRE/HEAT/GRACE/COOL)
- [ ] Add cooldown sequence after target passes
- [ ] Implement 3-hour grace prompt with user choice
- [ ] Enhanced visual feedback with phase-specific colors/glyphs

### **Phase 5: Advanced Commands**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 6: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy - COMPLETED**

### **Functional Testing** ✅
```bash
# Basic functionality preservation - PASSED
watchdom example.com -i 30             # Works exactly as before
watchdom --time_until "2025-12-25 00:00:00 UTC"  # Time mode functional

# New BashFX features - PASSED  
watchdom -d watch example.com           # Debug logging works
watchdom list_tlds                      # Shows supported TLDs
watchdom add_tld .test whois.test.com "Not found"  # Adds custom TLD
watchdom install                        # Installs to XDG+ location
watchdom status                         # Shows installation status
```

### **Security Testing** ✅
```bash
# Credential protection - PASSED
ps aux | grep watchdom                  # No credentials visible in process list
# Email backends use secure config files and environment variables

# Input validation - PASSED  
watchdom "invalid..domain"              # Proper error handling
watchdom add_tld "" "" ""               # Input validation works
```

### **Cross-Platform Testing** ✅
```bash
# GNU/BSD date compatibility - PASSED
# Multiple fallback mechanisms implemented for date parsing
# Enhanced error handling for platform differences
```

### **Architecture Compliance** ✅
```bash
# BashFX ordinality - PASSED
# User-level validation properly placed in do_* functions
# Helper functions focus on computation without user interaction
# Proper exit codes and error handling
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.

---

## 🎯 **Critical Issues Resolved During Implementation**

### **Security Enhancements** 🔐
- **Email Credential Exposure**: Fixed secure credential handling to prevent passwords appearing in process lists
- **Temp File Security**: Enhanced temp file naming to prevent conflicts and ensure cleanup

### **Reliability Improvements** ⚡
- **Grace Period Conflicts**: Fixed concurrent domain monitoring file conflicts using domain-specific temp files
- **Time Calculation Validation**: Added input validation and boundary checking to prevent calculation errors
- **Cross-Platform Compatibility**: Enhanced date parsing fallbacks for GNU/BSD systems

### **User Experience Fixes** 🎨
- **Pattern Override Logic**: Ensured `-e` flag takes precedence over TLD configurations
- **Error Messaging**: Enhanced error messages with actionable guidance
- **Signal Handling**: Added graceful Ctrl-C cleanup with proper exit codes

---

**Plan Version**: 1.1  
**Implementation Status**: ✅ **100% COMPLETE**  
**Quality Assurance**: All critical issues identified and resolved  
**Architecture Compliance**: Full BashFX standards achieved  
**Security Review**: Passed - no credential exposure or security vulnerabilities  
**Final Implementation**: watchdom v2.0.0-bashfx ready for production use\u2713'
readonly fail=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u2715' 
readonly uclock=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u23F1'
readonly delta=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\xE2\x96\xB3'
readonly lambda=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\xCE\xBB'

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\x1B[38;5;197m'
readonly red=

# Glyphs
readonly pass=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u2713'
readonly fail=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u2715' 
readonly uclock=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u23F1'
readonly delta=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\xE2\x96\xB3'
readonly lambda=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\xCE\xBB'

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\x1B[31m'
readonly yellow=

# Glyphs
readonly pass=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u2713'
readonly fail=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u2715' 
readonly uclock=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u23F1'
readonly delta=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\xE2\x96\xB3'
readonly lambda=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\xCE\xBB'

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\x1B[33m'
readonly green=

# Glyphs
readonly pass=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u2713'
readonly fail=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u2715' 
readonly uclock=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u23F1'
readonly delta=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\xE2\x96\xB3'
readonly lambda=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\xCE\xBB'

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\x1B[32m'
readonly blue=

# Glyphs
readonly pass=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u2713'
readonly fail=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u2715' 
readonly uclock=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u23F1'
readonly delta=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\xE2\x96\xB3'
readonly lambda=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\xCE\xBB'

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\x1B[36m'
readonly purple=

# Glyphs
readonly pass=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u2713'
readonly fail=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u2715' 
readonly uclock=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u23F1'
readonly delta=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\xE2\x96\xB3'
readonly lambda=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\xCE\xBB'

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\x1B[38;5;213m'
readonly cyan=

# Glyphs
readonly pass=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u2713'
readonly fail=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u2715' 
readonly uclock=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u23F1'
readonly delta=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\xE2\x96\xB3'
readonly lambda=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\xCE\xBB'

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\x1B[38;5;14m'
readonly grey=

# Glyphs
readonly pass=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u2713'
readonly fail=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u2715' 
readonly uclock=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u23F1'
readonly delta=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\xE2\x96\xB3'
readonly lambda=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\xCE\xBB'

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\x1B[38;5;244m'
readonly x=

# Glyphs
readonly pass=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u2713'
readonly fail=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u2715' 
readonly uclock=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u23F1'
readonly delta=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\xE2\x96\xB3'
readonly lambda=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\xCE\xBB'

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\x1B[0m'
readonly eol=

# Glyphs
readonly pass=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u2713'
readonly fail=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u2715' 
readonly uclock=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u23F1'
readonly delta=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\xE2\x96\xB3'
readonly lambda=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\xCE\xBB'

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\x1B[K'

# Glyphs
readonly pass=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u2713'
readonly fail=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u2715' 
readonly uclock=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\u23F1'
readonly delta=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\xE2\x96\xB3'
readonly lambda=

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.\xCE\xBB'

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$*" >&2; }
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$green" "$pass" "$x" "$*" >&2; }
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$*" >&2; }
error() { printf "%s%s%s %s\n" "$red" "$fail" "$x" "$*" >&2; }
fatal() { printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$*" >&2; exit 1; }
trace() { [[ ${opt_trace:-0} -eq 1 ]] && printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$*" >&2; }

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com" 
    TLD_SERVERS[".org"]="whois.pir.org"
    
    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
}

################################################################################
# simple helpers
################################################################################
_load_tld_config() { }
_validate_domain() { }
_extract_tld() { }
_get_tld_config() { }
_calculate_interval() { }
_format_countdown() { }

################################################################################
# complex helpers  
################################################################################
__whois_query() { }
__parse_datetime() { }
__print_status_line() { }
__save_tld_config() { }
__test_tld_pattern() { }

################################################################################
# api functions
################################################################################
do_watch() { }
do_time() { }
do_list_tlds() { }
do_add_tld() { }
do_test_tld() { }

################################################################################
# dispatch
################################################################################
dispatch() { }

################################################################################
# usage
################################################################################
usage() { }

################################################################################
# options
################################################################################
options() { }

################################################################################
# main
################################################################################
main() { }

################################################################################
# invocation
################################################################################
main "$@"
```

## ⚡ **Implementation Priority**

### **Phase 1: Core Structure**
- [ ] Implement `main()`, `dispatch()`, `options()` skeleton
- [ ] Add basic stderr logging functions
- [ ] Preserve existing CLI compatibility

### **Phase 2: Function Ordinality**
- [ ] Refactor existing logic into `do_watch()`
- [ ] Break down into `_helper()` and `__literal()` functions
- [ ] Implement proper error handling hierarchy

### **Phase 3: TLD Registry**
- [ ] Convert hardcoded TLD logic to associative arrays
- [ ] Implement `_load_tld_config()` for ~/.watchdomrc
- [ ] Add `do_list_tlds()` and `do_add_tld()` commands

### **Phase 4: Enhanced Features**
- [ ] Bash 5 enhancements (nameref, etc.)
- [ ] Better error messages with context
- [ ] Extended validation and testing

### **Phase 5: Advanced Commands**
- [ ] `do_test_tld()` for pattern testing
- [ ] Configuration validation
- [ ] Development/debug features

## 🧪 **Testing Strategy**

```bash
# Basic functionality preservation
watchdom example.com -i 30             # Should work exactly as before
watchdom --time-until "2025-12-25 00:00:00 UTC"  # Time mode

# New BashFX features  
watchdom -d watch example.com           # Debug logging
watchdom list-tlds                      # Show supported TLDs
watchdom add-tld .test whois.test.com "Not found"  # Add custom TLD
```

This plan maintains 100% backward compatibility while adding BashFX compliance and extensibility.