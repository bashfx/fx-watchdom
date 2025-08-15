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
readonly SELF_PATH="$(realpath "${BASH_SOURCE[0]}")"
readonly SELF_DIR="$(dirname "$SELF_PATH")"
readonly WATCHDOM_RC="$HOME/.watchdomrc"

# XDG+ compliant paths for BashFX framework
readonly XDG_HOME="${HOME}/.local"
readonly XDG_LIB="${XDG_HOME}/lib"
readonly XDG_BIN="${XDG_HOME}/bin"
readonly XDG_ETC="${XDG_HOME}/etc"
readonly XDG_TMP="${HOME}/.cache/tmp"

# BashFX namespace paths (first-party code goes in /fx/)
readonly FX_LIB_DIR="${XDG_LIB}/fx"
readonly FX_BIN_DIR="${XDG_BIN}/fx"
readonly FX_INSTALL_PATH="${FX_LIB_DIR}/${SELF_NAME}"
readonly FX_BIN_LINK="${FX_BIN_DIR}/${SELF_NAME}"

################################################################################
# config
################################################################################
# Default settings (overridable by environment)
DEFAULT_INTERVAL="${WATCHDOM_INTERVAL:-60}"
DEFAULT_MAX_CHECKS="${WATCHDOM_MAX_CHECKS:-0}"
DEFAULT_TIME_LOCAL="${WATCHDOM_TIME_LOCAL:-0}"

# Email notification settings (all must be set to enable notifications)
NOTIFY_EMAIL="${NOTIFY_EMAIL:-}"           # Recipient email (e.g., "user@domain.com")
NOTIFY_FROM="${NOTIFY_FROM:-}"            # Sender email (e.g., "watchdom@server.com")
NOTIFY_SMTP_HOST="${NOTIFY_SMTP_HOST:-}"       # SMTP server (e.g., "smtp.gmail.com")
NOTIFY_SMTP_PORT="${NOTIFY_SMTP_PORT:-}"       # SMTP port (e.g., "587")
NOTIFY_SMTP_USER="${NOTIFY_SMTP_USER:-}"       # SMTP username
NOTIFY_SMTP_PASS="${NOTIFY_SMTP_PASS:-}"       # SMTP password or app token

################################################################################
# escape sequences
################################################################################
readonly  red2=$'\x1B[38;5;197m';
readonly  red=$'\x1B[31m';
readonly  orange=$'\x1B[38;5;214m';
readonly  yellow=$'\x1B[33m';

readonly  green=$'\x1B[32m';
readonly  blue=$'\x1B[36m';
readonly  blue2=$'\x1B[38;5;39m';
readonly  cyan=$'\x1B[38;5;14m';
readonly  magenta=$'\x1B[35m';

readonly  purple=$'\x1B[38;5;213m';
readonly  purple2=$'\x1B[38;5;141m';
readonly  white=$'\x1B[38;5;248m';
readonly  white2=$'\x1B[38;5;15m';
readonly  grey=$'\x1B[38;5;244m';
readonly  grey2=$'\x1B[38;5;240m';


revc=$'\x1B[7m';   # Reverse video
bld=$'\x1B[1m';    # Bold
x=$'\x1B[0m';      # Reset all attributes
xx=$'\x1B[0m';     # Alias for reset

eol=$'\x1B[K';    # Erase to end of line
eos=$'\x1B[J';    # Erase to end of display
cll=$'\x1B[1A\x1B[K'; # Move cursor up one line and erase line

tab=$'\t';
nl=$'\n';
sp=' ';

snek=$'\xe2\x99\x8b';

# Glyphs
flag_off=$'\xe2\x9a\x90';
flag_on=$'\xe2\x9a\x91';
diamond=$'\xE1\x9B\x9C';
arrup=$'\xE2\x86\x91';
arrdn=$'\xE2\x86\x93';
darr=$'\u21B3';
uarr=$'\u21B0';
delim=$'\x01';
delta=$'\xE2\x96\xB3';

#matching icon set now
fail=$'\u2715';
pass=$'\u2713';
recv=$'\u27F2';

star=$'\xE2\x98\x85';
lambda=$'\xCE\xBB';
idots=$'\xE2\x80\xA6';
bolt=$'\xE2\x86\xAF';
redo=$'\xE2\x86\xBB';

uage=$'\u2756';    # ❖
cmdr=$'\u2318';    # ⌘
boto=$'\u232C';    # ⌬ robot great
gear=$'\u26ED'     # ⛭ gear
rook=$'\u265C'     # ♜ rook
pawn=$'\u265F'     # ♟ pawn
king=$'\u26ED'     # ♕ queen/crown
vtri=$'\u25BD'     # ▽ down triangle
utri=$'\u25B3'     # △ up triangle <-- delta
xmark=$'\u292C'    # ⤬ heavy cross
sword=$'\u2694'    # ⚔︎ crossed swords
moon=$'\u263E'     # ☾ crescent moon
sun=$'\u2600'      # ☀︎ sun
spark=$'\u273B'    # ✻ snowflake/star
colon2=$'\u2237'   # ∷ double colon
theref=$'\u2234'   # ∴ therefore
bull=$'\u29BF'     # ⦿ circled bullet
sect=$'\u00A7'     # § section symbol
bowtie=$'\u22C8'   # ⋈ bowtie
sum=$'\u2211'      # ∑ summation
prod=$'\u220F'     # ∏ product
dharm=$'\u2638'    # ☸︎ dharma wheel
scroll=$'\u07F7'   # ߷ paragraphus / ornament
note=$'\u266A'     # ♪ music note
anchor=$'\u2693'   # ⚓ anchor
unlock=$'\u26BF'   # ⚿ unlocked padlock
spindle=$'\u27D0'  # ⟐ circled dash / orbital
anote=$'\u260D'

uclock=$'\u23F1'    # ⏱
uclock2=$'\u23F2'   # ⏲
uhour=$'\u29D6'     # ⧖
udate=$'\u1F5D3'    # 🗓

itime=$'\xe2\xa7\x97'; # dup?

uspark=$'\xe2\x9f\xa1'; #todo: change to unicode format

################################################################################
# simple stderr
################################################################################
info()  { [[ ${opt_debug:-0} -eq 1 ]] && { local msg; msg=$(printf "$@"); printf "%s[%s]%s %s\n" "$blue" "$(date +%H:%M:%S)" "$x" "$msg" >&2; }; };
okay()  { [[ ${opt_debug:-0} -eq 1 ]] && { local msg; msg=$(printf "$@"); printf "%s%s%s %s\n" "$green" "$pass" "$x" "$msg" >&2; }; };
warn()  { [[ ${opt_debug:-0} -eq 1 ]] && { local msg; msg=$(printf "$@"); printf "%s%s%s %s\n" "$yellow" "$delta" "$x" "$msg" >&2; }; };
error() { local msg; msg=$(printf "$@"); printf "%s%s%s %s\n" "$red" "$fail" "$x" "$msg" >&2; };
fatal() { local msg; msg=$(printf "$@"); printf "%s%s%s %s\n" "$red2" "$fail" "$x" "$msg" >&2; exit 1; };
trace() { [[ ${opt_trace:-0} -eq 1 ]] && { local msg; msg=$(printf "$@"); printf "%s[%s]%s %s\n" "$grey" "$(date +%H:%M:%S)" "$x" "$msg" >&2; }; };

################################################################################
# notification system
################################################################################
################################################################################
# is_notify_configured
################################################################################
is_notify_configured() {
    [[ -n "$NOTIFY_EMAIL" && -n "$NOTIFY_FROM" && -n "$NOTIFY_SMTP_HOST" &&
       -n "$NOTIFY_SMTP_PORT" && -n "$NOTIFY_SMTP_USER" && -n "$NOTIFY_SMTP_PASS" ]];
};

################################################################################
# _notify_event
################################################################################
_notify_event() {
    local event="$1";
    local domain="$2";
    local details="$3";

    is_notify_configured || return 0;

    case "$event" in
        (success)
            __send_email "Domain Available: $domain" "SUCCESS: $domain is now available for registration!\n\nDetails: $details";
            ;;
        (target_reached)
            __send_email "Target Time Reached: $domain" "Target time reached for $domain monitoring.\n\nEntering grace period...\n\nDetails: $details";
            ;;
        (grace_entered)
            __send_email "Grace Period: $domain" "Grace period exceeded for $domain (3+ hours past target).\n\nDetails: $details";
            ;;
    esac;
};

################################################################################
# __send_email
################################################################################
__send_email() {
    local subject="$1";
    local body="$2";
    local ret=1;

    if command -v mutt >/dev/null 2>&1; then
        local temp_config="/tmp/.watchdom_mutt_$$";
        {
            printf "set smtp_url=\"smtp://%s:%s@%s:%s/\"\n" \
                "$NOTIFY_SMTP_USER" "$NOTIFY_SMTP_PASS" "$NOTIFY_SMTP_HOST" "$NOTIFY_SMTP_PORT";
            printf "set from=\"%s\"\n" "$NOTIFY_FROM";
            printf "set realname=\"watchdom\"\n";
        } > "$temp_config";

        printf "%s" "$body" | mutt -F "$temp_config" -s "$subject" "$NOTIFY_EMAIL" 2>/dev/null;
        ret=$?;
        rm -f "$temp_config";

    elif command -v msmtp >/dev/null 2>&1 && command -v mail >/dev/null 2>&1; then
        export MSMTP_HOST="$NOTIFY_SMTP_HOST";
        export MSMTP_PORT="$NOTIFY_SMTP_PORT";
        export MSMTP_USER="$NOTIFY_SMTP_USER";
        export MSMTP_PASS="$NOTIFY_SMTP_PASS";

        printf "%s" "$body" | mail -s "$subject" "$NOTIFY_EMAIL" 2>/dev/null;
        ret=$?;

        unset MSMTP_HOST MSMTP_PORT MSMTP_USER MSMTP_PASS;

    elif command -v sendmail >/dev/null 2>&1; then
        {
            printf "To: %s\n" "$NOTIFY_EMAIL";
            printf "From: %s\n" "$NOTIFY_FROM";
            printf "Subject: %s\n\n" "$subject";
            printf "%s\n" "$body";
        } | sendmail "$NOTIFY_EMAIL" 2>/dev/null;
        ret=$?;
    fi;

    if [[ $ret -eq 0 ]]; then
        trace "Email notification sent: %s" "$subject";
    else
        warn "Failed to send email notification";
    fi;

    return $ret;
};

################################################################################
# TLD registry
################################################################################
declare -A TLD_SERVERS TLD_PATTERNS

################################################################################
# _init_builtin_tlds
################################################################################
_init_builtin_tlds() {
    TLD_SERVERS[".com"]="whois.verisign-grs.com"
    TLD_SERVERS[".net"]="whois.verisign-grs.com"
    TLD_SERVERS[".org"]="whois.pir.org"

    TLD_PATTERNS[".com"]="No match for"
    TLD_PATTERNS[".net"]="No match for"
    TLD_PATTERNS[".org"]="(NOT FOUND|Domain not found)"
};

################################################################################
# simple helpers
################################################################################

################################################################################
# _extract_tld
################################################################################
_extract_tld() {
    local domain="$1";
    local tld="";

    # Remove any protocol prefix
    domain="${domain#*://}";
    # Remove any path suffix
    domain="${domain%%/*}";
    # Get the TLD portion
    tld=".${domain##*.}";

    printf "%s" "$tld";
    return 0;
};

################################################################################
# _load_tld_config
################################################################################
_load_tld_config() {
    local ret=0;

    # Initialize built-in TLDs
    _init_builtin_tlds;

    # Load user config if it exists
    if [[ -f "$WATCHDOM_RC" ]]; then
        local line tld server pattern;
        while IFS='|' read -r tld server pattern; do
            # Skip comments and empty lines
            [[ "$tld" =~ ^[[:space:]]*# ]] && continue;
            [[ -z "$tld" ]] && continue;

            # Store in arrays
            TLD_SERVERS["$tld"]="$server";
            TLD_PATTERNS["$tld"]="$pattern";
            trace "Loaded custom TLD: %s -> %s" "$tld" "$server";
        done < "$WATCHDOM_RC";
    fi;

    return $ret;
};

################################################################################
# _validate_domain
################################################################################
_validate_domain() {
    local domain="$1";

    if [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$ ]]; then
        return 0;
    fi;

    return 1;
};

################################################################################
# _get_tld_config
################################################################################
_get_tld_config() {
    local domain="$1";
    local tld="";
    local server="";
    local pattern="";
    local ret=1;

    tld=$(_extract_tld "$domain");

    if [[ -n "${TLD_SERVERS[$tld]:-}" ]]; then
        server="${TLD_SERVERS[$tld]}";
        pattern="${TLD_PATTERNS[$tld]}";
        printf "%s|%s" "$server" "$pattern";
        ret=0;
    fi;

    return $ret;
};

################################################################################
# _calculate_interval
################################################################################
_calculate_interval() {
    local base_interval="$1";
    local target_epoch="$2";
    local grace_start_epoch="$3";
    local now_epoch="$4";
    local ret=0;
    local interval="$base_interval";
    local phase="PRE";

    if [[ ! "$base_interval" =~ ^[0-9]+$ ]] || (( base_interval <= 0 )); then
        error "Invalid base interval: %s" "$base_interval";
        return 1;
    fi;

    if [[ -z "$target_epoch" ]]; then
        printf "%s|%s" "$interval" "$phase";
        return $ret;
    fi;

    if [[ ! "$target_epoch" =~ ^[0-9]+$ ]] || [[ ! "$now_epoch" =~ ^[0-9]+$ ]]; then
        error "Invalid epoch time values";
        return 1;
    fi;

    local time_to_target=$((target_epoch - now_epoch));
    local time_since_target=$((now_epoch - target_epoch));

    if (( time_to_target > 1800 )); then
        phase="PRE";
        interval="$base_interval";
    elif (( time_to_target > 0 )); then
        phase="HEAT";
        if (( time_to_target <= 300 )); then
            interval=10;
        else
            interval=30;
        fi;
    elif (( time_since_target <= 10800 )); then
        phase="GRACE";
        interval=10;
    else
        phase="COOL";
        local grace_elapsed=$((time_since_target - 10800));

        if (( grace_elapsed <= 600 )); then
            interval=30;
        elif (( grace_elapsed <= 1200 )); then
            interval=60;
        elif (( grace_elapsed <= 1800 )); then
            interval=300;
        elif (( grace_elapsed <= 3600 )); then
            interval=600;
        elif (( grace_elapsed <= 7200 )); then
            interval=1800;
        else
            interval=3600;
        fi;
    fi;

    printf "%s|%s" "$interval" "$phase";
    return $ret;
};

################################################################################
# _format_countdown
################################################################################
_format_countdown() {
    local phase="$1";
    local interval="$2";
    local time_info="$3";
    local color glyph label;

    case "$phase" in
        (PRE)
            color="$blue";
            glyph="$lambda";
            label="[PRE]";
            ;;
        (HEAT)
            color="$red";
            glyph="$delta";
            label="[HEAT]";
            ;;
        (GRACE)
            color="$purple";
            glyph="$delta";
            label="[GRACE]";
            ;;
        (COOL)
            color="$cyan";
            glyph="$spark";
            label="[COOL]";
            ;;
        (*)
            color="$grey";
            glyph="$uclock";
            label="[POLL]";
            ;;
    esac;

    printf "%s%s next poll in %ss | %s | %s%s%s" \
        "$color" "$glyph" "$interval" "$time_info" "$label" "$x" "$eol";
};

################################################################################
# _check_grace_timeout
################################################################################
_check_grace_timeout() {
    local target_epoch="$1";
    local now_epoch="$2";
    local domain="$3";
    local domain_hash;
    domain_hash="$(printf "%s" "$domain" | md5sum 2>/dev/null | cut -d' ' -f1 || printf "%s" "$domain" | cksum | cut -d' ' -f1)";
    mkdir -p "$XDG_TMP";
    local grace_prompted_file="${XDG_TMP}/.watchdom_grace_${domain_hash}_$$";
    local ret=0;

    [[ -z "$target_epoch" ]] && return 0;

    local time_since_target=$((now_epoch - target_epoch));

    if (( time_since_target > 10800 )); then
        if [[ ! -f "$grace_prompted_file" ]]; then
            local grace_hours=$((time_since_target / 3600));
            warn "Grace period expired (%d hours past target)" "$grace_hours";
            _notify_event "grace_entered" "$domain" "Exceeded at $(date)";

            touch "$grace_prompted_file";

            printf "\n%sGrace period expired (3hrs past target). Continue watching?%s\n" "$yellow" "$x" >&2;
            printf "[y] Yes, keep 1hr intervals\n" >&2;
            printf "[n] No, exit\n" >&2;
            printf "[c] Custom interval (specify seconds)\n" >&2;
            printf "Choice [y/n/c]: " >&2;

            local choice;
            read -r choice;

            case "${choice,,}" in
                (n|no)
                    info "Exiting per user request";
                    rm -f "$grace_prompted_file";
                    exit 0;
                    ;;
                (c|custom)
                    printf "Enter custom interval in seconds: " >&2;
                    local custom_interval;
                    read -r custom_interval;
                    if [[ "$custom_interval" =~ ^[0-9]+$ ]] && (( custom_interval > 0 )); then
                        DEFAULT_INTERVAL="$custom_interval";
                        info "Using custom interval: %s seconds" "$custom_interval";
                    else
                        warn "Invalid interval, using 1hr default";
                    fi;
                    ;;
                (*)
                    info "Continuing with 1hr intervals";
                    ;;
            esac;
        fi;
    fi;

    return $ret;
};

################################################################################
# complex helpers
################################################################################

################################################################################
# __parse_datetime
################################################################################
__parse_datetime() {
    local when="$1";
    local epoch="";

    if [[ "$when" =~ ^[0-9]+$ ]]; then
        printf "%s" "$when";
        return 0;
    fi;

    if epoch=$(date -u -d "$when" +%s 2>/dev/null); then
        printf "%s" "$epoch";
        return 0;
    elif command -v gdate >/dev/null 2>&1 && epoch=$(gdate -u -d "$when" +%s 2>/dev/null); then
        printf "%s" "$epoch";
        return 0;
    elif epoch=$(date -u -j -f "%Y-%m-%d %H:%M:%S %Z" "$when" +%s 2>/dev/null); then
        printf "%s" "$epoch";
        return 0;
    fi;

    return 1;
};

################################################################################
# __whois_query
################################################################################
__whois_query() {
    local domain="$1";
    local server="$2";
    local ret=1;
    local output="";

    if output=$(whois -h "$server" "$domain" 2>/dev/null); then
        printf "%s" "$output";
        ret=0;
    fi;

    return $ret;
};

################################################################################
# __print_status_line
################################################################################
__print_status_line() {
    local text="$1";
    printf "\r%s" "$text" >&2;
};

################################################################################
# __save_tld_config
################################################################################
__save_tld_config() {
    local tld="$1";
    local server="$2";
    local pattern="$3";
    local ret=1;

    if [[ ! -f "$WATCHDOM_RC" ]]; then
        printf "# watchdom TLD configuration\n# Format: TLD|SERVER|PATTERN\n" > "$WATCHDOM_RC";
    fi;

    printf "%s|%s|%s\n" "$tld" "$server" "$pattern" >> "$WATCHDOM_RC";
    ret=$?;

    return $ret;
};

################################################################################
# __test_tld_pattern
################################################################################
__test_tld_pattern() {
    local tld="$1";
    local test_domain="$2";
    local ret=1;
    local config server pattern output;

    config=$(_get_tld_config "$test_domain");
    if [[ $? -eq 0 && -n "$config" ]]; then
        IFS='|' read -r server pattern <<< "$config";
        output=$(__whois_query "$test_domain" "$server");

        if printf "%s" "$output" | grep -Eiq -- "$pattern"; then
            ret=0;
        fi;
    fi;

    return $ret;
};

################################################################################
# __human_duration
################################################################################
__human_duration() {
    local s="$1";
    local d h m out="";

    (( d=s/86400, s%=86400, h=s/3600, s%=3600, m=s/60, s%=60 ));
    [[ $d -gt 0 ]] && out+="${d}d ";
    [[ $h -gt 0 ]] && out+="${h}h ";
    [[ $m -gt 0 ]] && out+="${m}m ";
    out+="${s}s";

    printf "%s" "$out";
};

################################################################################
# __format_date
################################################################################
__format_date() {
    local epoch="$1";
    local format="$2";
    local ret=1;

    if [[ ! "$epoch" =~ ^[0-9]+$ ]]; then
        printf "INVALID_DATE";
        return 1;
    fi;

    case "$format" in
        (utc)
            if date -u -d "@$epoch" "+%a %b %d %H:%M:%S UTC %Y" 2>/dev/null; then
                ret=0;
            elif date -u -r "$epoch" "+%a %b %d %H:%M:%S UTC %Y" 2>/dev/null; then
                ret=0;
            elif command -v gdate >/dev/null 2>&1 && gdate -u -d "@$epoch" "+%a %b %d %H:%M:%S UTC %Y" 2>/dev/null; then
                ret=0;
            else
                printf "UTC_TIME_EPOCH_%s" "$epoch";
                ret=1;
            fi;
            ;;
        (local)
            if date -d "@$epoch" "+%a %b %d %H:%M:%S %Z %Y" 2>/dev/null; then
                ret=0;
            elif date -r "$epoch" "+%a %b %d %H:%M:%S %Z %Y" 2>/dev/null; then
                ret=0;
            elif command -v gdate >/dev/null 2>&1 && gdate -d "@$epoch" "+%a %b %d %H:%M:%S %Z %Y" 2>/dev/null; then
                ret=0;
            else
                printf "LOCAL_TIME_EPOCH_%s" "$epoch";
                ret=1;
            fi;
            ;;
        (*)
            printf "INVALID_FORMAT";
            ret=1;
            ;;
    esac;

    return $ret;
};

################################################################################
# api functions
################################################################################

################################################################################
# do_watch
################################################################################
do_watch() {
    local domain="${1:-}";
    local ret=1;

    if [[ -z "$domain" ]]; then
        error "Domain required for watch command";
        usage;
        return 2;
    fi;

    if ! command -v whois >/dev/null 2>&1; then
        fatal "Required command 'whois' not found";
    fi;

    if ! _validate_domain "$domain"; then
        fatal "Invalid domain format: %s" "$domain";
    fi;

    _load_tld_config;

    # If no polling options are set, perform a one-time query and exit.
    if [[ -z "$opt_interval" && -z "$opt_until" && -z "$opt_max_checks" ]]; then
        local config server pattern output
        config=$(_get_tld_config "$domain")
        if [[ $? -ne 0 || -z "$config" ]]; then
            local tld=$(_extract_tld "$domain")
            fatal "TLD %s not supported yet. Use 'add_tld' to add support." "$tld"
        fi
        IFS='|' read -r server pattern <<< "$config"

        info "Performing one-time query for %s on %s" "$domain" "$server"
        output=$(__whois_query "$domain" "$server")
        if [[ $? -ne 0 ]]; then
            error "Failed to query whois server %s" "$server"
            return 1
        fi

        # Print the full output for the user
        printf "%s\n" "$output"

        # Check for availability and set exit code
        if printf "%s" "$output" | grep -Eiq -- "$pattern"; then
            okay "Domain %s appears to be AVAILABLE." "$domain"
            return 0
        else
            warn "Domain %s appears to be REGISTERED." "$domain"
            return 1
        fi
    fi;

    local config server pattern;
    config=$(_get_tld_config "$domain");
    if [[ $? -ne 0 || -z "$config" ]]; then
        local tld;
        tld=$(_extract_tld "$domain");
        fatal "TLD %s not supported yet. Use 'add_tld' to add support." "$tld";
    fi;

    IFS='|' read -r server pattern <<< "$config";

    if [[ -n "${opt_expect:-}" ]]; then
        pattern="$opt_expect";
        trace "Using pattern override: %s" "$pattern";
    fi;

    local interval="${opt_interval:-$DEFAULT_INTERVAL}";
    if [[ ! "$interval" =~ ^[0-9]+$ ]] || (( interval <= 0 )); then
        fatal "Invalid interval: %s (must be positive integer)" "$interval";
    fi;

    if [[ "$interval" -lt 10 ]]; then
        warn "Interval %ss is aggressive; consider >=30s" "$interval";
    fi;

    local target_epoch="";
    local grace_start_epoch="";
    if [[ -n "${opt_until:-}" ]]; then
        target_epoch=$(__parse_datetime "$opt_until");
        if [[ $? -ne 0 ]]; then
            fatal "Cannot parse target time: %s" "$opt_until";
        fi;
        grace_start_epoch=$((target_epoch + 10800));
    fi;

    info "Watching %s via %s; base interval=%ss; expect=/%s/i" \
        "$domain" "$server" "$interval" "$pattern";

    if [[ -n "$target_epoch" ]]; then
        if [[ "${opt_time_local:-0}" -eq 1 ]]; then
            info "Target Local: %s (epoch %s)" \
                "$(__format_date "$target_epoch" "local")" "$target_epoch";
        else
            info "Target UTC  : %s" "$(__format_date "$target_epoch" "utc")";
            info "Target Local: %s (epoch %s)" \
                "$(__format_date "$target_epoch" "local")" "$target_epoch";
        fi;
    fi;

    info "(Ctrl-C to stop)";

    local count=0;
    local target_alerted=0;

    while :; do
        local now_epoch;
        now_epoch=$(date -u +%s);

        local calc_result eff_interval phase;
        calc_result=$(_calculate_interval "$interval" "$target_epoch" "$grace_start_epoch" "$now_epoch");
        if [[ $? -ne 0 ]]; then
            error "Failed to calculate polling interval";
            return 1;
        fi;

        IFS='|' read -r eff_interval phase <<< "$calc_result";

        if (( eff_interval < 10 )); then
            warn "Effective interval %ss may trigger rate limits" "$eff_interval";
        fi;

        local timestamp output;
        timestamp="$(date -Is)";
        output=$(__whois_query "$domain" "$server");

        if printf "%s" "$output" | grep -Eiq -- "$pattern"; then
            okay "Pattern matched for %s" "$domain";
            printf "%s" "$output" | sed -n '1,20p';
            _notify_event "success" "$domain" "Detected at $(date)";
            return 0;
        else
            trace "No match yet - effective interval %ss" "$eff_interval";
        fi;

        if [[ -n "$target_epoch" ]]; then
            local time_since_target=$((now_epoch - target_epoch));

            if (( time_since_target >= 0 && target_alerted == 0 )); then
                warn "TARGET INTERVAL reached";
                _notify_event "target_reached" "$domain" "Target: $(__format_date "$target_epoch" "utc")";
                target_alerted=1;
            fi;

            _check_grace_timeout "$target_epoch" "$now_epoch" "$domain";
        fi;

        count=$((count + 1));
        if [[ "${opt_max_checks:-0}" -gt 0 && "$count" -ge "${opt_max_checks}" ]]; then
            info "Max checks (%s) reached without matching pattern" "${opt_max_checks}";
            return 1;
        fi;

        local r;
        for (( r=eff_interval; r>=1; r-- )); do
            now_epoch=$(date -u +%s);
            local time_info="";

            if [[ -n "$target_epoch" ]]; then
                local delta=$((target_epoch - now_epoch));
                if (( delta > 0 )); then
                    time_info="target in $(__human_duration "$delta")";
                else
                    time_info="target since $(__human_duration $((-delta)))";
                fi;

                if [[ "${opt_time_local:-0}" -eq 1 ]]; then
                    time_info+=" | Local: $(__format_date "$target_epoch" "local")";
                else
                    time_info+=" | UTC: $(__format_date "$target_epoch" "utc") | Local: $(__format_date "$target_epoch" "local")";
                fi;
            fi;

            local status_line;
            status_line=$(_format_countdown "$phase" "$r" "$time_info");
            __print_status_line "$status_line";
            trace "Countdown sleeping for 1s...";
            sleep 1;
            trace "Countdown sleep finished.";
        done;

        printf "\r%80s\r" "" >&2;
    done;
};

################################################################################
# do_time
################################################################################
do_time() {
    local when="${1:-}";
    local ret=0;

    [[ -z "$when" ]] && { error "Time argument required for time command"; return 1; };

    local target_epoch;
    target_epoch=$(__parse_datetime "$when");
    [[ $? -ne 0 ]] && { error "Cannot parse time: %s" "$when"; return 1; };

    local now_epoch;
    now_epoch=$(date -u +%s);
    local remaining=$((target_epoch - now_epoch));

    if (( remaining < 0 )); then
        if [[ "${opt_time_local:-0}" -eq 1 ]]; then
            printf "Remaining (Local): 0s (time passed)\n";
        else
            printf "Remaining: 0s (time passed)\n";
        fi;
    else
        if [[ "${opt_time_local:-0}" -eq 1 ]]; then
            printf "Remaining (Local): %s\n" "$(__human_duration "$remaining")";
        else
            printf "Remaining: %s\n" "$(__human_duration "$remaining")";
        fi;
    fi;

    if [[ "${opt_time_local:-0}" -eq 1 ]]; then
        printf "Target Local: %s\n" "$(__format_date "$target_epoch" "local")";
    else
        printf "Target UTC  : %s\n" "$(__format_date "$target_epoch" "utc")";
        printf "Target Local: %s\n" "$(__format_date "$target_epoch" "local")";
    fi;

    printf "UNTIL_EPOCH=%s\n" "$target_epoch";
    return $ret;
};

################################################################################
# do_list_tlds
################################################################################
do_list_tlds() {
    local ret=0;

    _load_tld_config;

    printf "Supported TLD patterns:\n\n";
    printf "%-8s %-25s %s\n" "TLD" "WHOIS SERVER" "AVAILABLE PATTERN";
    printf "%-8s %-25s %s\n" "---" "------------" "-----------------";

    local tld;
    for tld in "${!TLD_SERVERS[@]}"; do
        printf "%-8s %-25s %s\n" "$tld" "${TLD_SERVERS[$tld]}" "${TLD_PATTERNS[$tld]}";
    done | sort;

    printf "\nConfiguration sources:\n";
    printf "  Built-in: .com, .net, .org\n";
    if [[ -f "$WATCHDOM_RC" ]]; then
        printf "  User config: %s\n" "$WATCHDOM_RC";
    else
        printf "  User config: %s (not found)\n" "$WATCHDOM_RC";
    fi;

    return $ret;
};

################################################################################
# do_add_tld
################################################################################
do_add_tld() {
    local tld="${1:-}";
    local server="${2:-}";
    local pattern="${3:-}";
    local ret=1;

    if [[ -z "$tld" || -z "$server" || -z "$pattern" ]]; then
        error "Usage: add_tld TLD SERVER PATTERN";
        error "Example: add_tld .uk whois.nominet.uk \"No such domain\"";
        usage;
        return 2;
    fi;

    [[ "$tld" =~ ^\. ]] || tld=".$tld";

    if [[ ! "$tld" =~ ^\.[a-zA-Z0-9-]+$ ]]; then
        error "Invalid TLD format: %s (should be like .com, .org, .uk)" "$tld";
        return 2;
    fi;

    if [[ ! "$server" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        error "Invalid server format: %s (should be like whois.example.com)" "$server";
        return 2;
    fi;

    if [[ -z "$pattern" || "$pattern" =~ ^[[:space:]]*$ ]]; then
        error "Pattern cannot be empty";
        return 2;
    fi;

    _load_tld_config;
    if [[ -n "${TLD_SERVERS[$tld]:-}" ]]; then
        warn "TLD %s already configured with server %s" "$tld" "${TLD_SERVERS[$tld]}";
        if [[ "${opt_force:-0}" -ne 1 ]]; then
            error "Use -f to force override existing configuration";
            return 1;
        fi;
    fi;

    if __save_tld_config "$tld" "$server" "$pattern"; then
        okay "Added TLD configuration: %s -> %s" "$tld" "$server";
        trace "Pattern: %s" "$pattern";
        ret=0;
    else
        error "Failed to save TLD configuration";
        ret=1;
    fi;

    return $ret;
};

################################################################################
# do_test_tld
################################################################################
do_test_tld() {
    local tld="${1:-}";
    local test_domain="${2:-}";
    local ret=1;

    # Temporarily enable debug mode for rich output, per user suggestion
    local was_debug=$opt_debug;
    opt_debug=1;

    if [[ -z "$tld" || -z "$test_domain" ]]; then
        error "Usage: test_tld TLD DOMAIN";
        error "Example: test_tld .com nonexistent-test-domain.com";
        usage;
        opt_debug=$was_debug; # Restore debug state
        return 2;
    fi;

    [[ "$tld" =~ ^\. ]] || tld=".$tld";

    if ! _validate_domain "$test_domain"; then
        error "Invalid domain format: %s" "$test_domain";
        opt_debug=$was_debug; # Restore debug state
        return 2;
    fi;

    _load_tld_config;

    if [[ -z "${TLD_SERVERS[$tld]:-}" ]]; then
        error "TLD %s is not configured" "$tld";
        error "Use 'list_tlds' to see supported TLDs or 'add_tld' to add support";
        opt_debug=$was_debug; # Restore debug state
        return 1;
    fi;

    local server="${TLD_SERVERS[$tld]}";
    local pattern="${TLD_PATTERNS[$tld]}";

    info "Testing TLD %s against domain %s" "$tld" "$test_domain";
    info "Server: %s" "$server";
    info "Pattern: /%s/i" "$pattern";

    local output;
    output=$(__whois_query "$test_domain" "$server");
    if [[ $? -ne 0 ]]; then
        error "Failed to query whois server %s" "$server";
        opt_debug=$was_debug; # Restore debug state
        return 1;
    fi;

    if printf "%s" "$output" | grep -Eiq -- "$pattern"; then
        okay "Pattern MATCHED - domain appears available";
        ret=0;
    else
        warn "Pattern NOT matched - domain may be registered or pattern incorrect";
        info "Full whois output for debugging:";
        printf -- "----\n%s\n----\n" "$output" >&2
        ret=1;
    fi;

    opt_debug=$was_debug; # Restore debug state
    return $ret;
};

################################################################################
# do_install
################################################################################
do_install() {
    local ret=1;
    local force="${opt_force:-0}";

    info "Installing %s v%s..." "$SELF_NAME" "$SELF_VERSION";

    if [[ -L "$FX_BIN_LINK" ]] && [[ "$force" -eq 0 ]]; then
        warn "%s is already installed at %s" "$SELF_NAME" "$FX_BIN_LINK";
        error "Use -f to force reinstall";
        return 1;
    fi;

    if ! mkdir -p "$FX_LIB_DIR" "$FX_BIN_DIR"; then
        error "Failed to create installation directories";
        return 1;
    fi;

    if ! cp "$SELF_PATH" "$FX_INSTALL_PATH"; then
        error "Failed to copy script to %s" "$FX_INSTALL_PATH";
        return 1;
    fi;

    if ! chmod +x "$FX_INSTALL_PATH"; then
        error "Failed to make script executable";
        return 1;
    fi;

    if ! ln -sf "../../lib/fx/$SELF_NAME" "$FX_BIN_LINK"; then
        error "Failed to create symlink at %s" "$FX_BIN_LINK";
        return 1;
    fi;

    okay "Installed %s to %s" "$SELF_NAME" "$FX_INSTALL_PATH";
    okay "Created symlink at %s" "$FX_BIN_LINK";

    if [[ ":$PATH:" != *":$FX_BIN_DIR:"* ]]; then
        warn "Add %s to your PATH to use %s from anywhere:" "$FX_BIN_DIR" "$SELF_NAME";
        printf "  export PATH=\"%s:\$PATH\"\n" "$FX_BIN_DIR" >&2;
    else
        info "%s is now available in your PATH" "$SELF_NAME";
    fi;

    ret=0;
    return $ret;
};

################################################################################
# do_uninstall
################################################################################
do_uninstall() {
    local ret=1;
    local removed_items=0;

    info "Uninstalling %s..." "$SELF_NAME";

    if [[ -L "$FX_BIN_LINK" ]]; then
        if rm "$FX_BIN_LINK"; then
            okay "Removed symlink: %s" "$FX_BIN_LINK";
            removed_items=$((removed_items + 1));
        else
            error "Failed to remove symlink: %s" "$FX_BIN_LINK";
        fi;
    fi;

    if [[ -f "$FX_INSTALL_PATH" ]]; then
        if rm "$FX_INSTALL_PATH"; then
            okay "Removed script: %s" "$FX_INSTALL_PATH";
            removed_items=$((removed_items + 1));
        else
            error "Failed to remove script: %s" "$FX_INSTALL_PATH";
        fi;
    fi;

    if [[ -d "$FX_LIB_DIR" ]] && [[ -z "$(ls -A "$FX_LIB_DIR" 2>/dev/null)" ]]; then
        if rmdir "$FX_LIB_DIR"; then
            trace "Removed empty directory: %s" "$FX_LIB_DIR";
        fi;
    fi;

    if [[ "$removed_items" -eq 0 ]]; then
        warn "%s was not installed or already removed" "$SELF_NAME";
        ret=1;
    else
        okay "Successfully uninstalled %s (%d items removed)" "$SELF_NAME" "$removed_items";
        info "User configuration preserved at %s" "$WATCHDOM_RC";
        ret=0;
    fi;

    return $ret;
};

################################################################################
# do_status
################################################################################
do_status() {
    local ret=0;

    printf "watchdom v%s - Installation Status\n\n" "$SELF_VERSION";

    printf "Current script: %s\n" "$SELF_PATH";

    if [[ -f "$FX_INSTALL_PATH" ]]; then
        printf "Installed at  : %s ✓\n" "$FX_INSTALL_PATH";
    else
        printf "Installed at  : %s ✗\n" "$FX_INSTALL_PATH";
        ret=1;
    fi;

    if [[ -L "$FX_BIN_LINK" ]]; then
        local link_target;
        link_target="$(readlink "$FX_BIN_LINK")";
        printf "Symlink       : %s -> %s ✓\n" "$FX_BIN_LINK" "$link_target";
    else
        printf "Symlink       : %s ✗\n" "$FX_BIN_LINK";
        ret=1;
    fi;

    if [[ ":$PATH:" == *":$XDG_BIN:"* ]]; then
        printf "PATH includes : %s ✓\n" "$XDG_BIN";
    else
        printf "PATH includes : %s ✗\n" "$XDG_BIN";
    fi;

    if [[ -f "$WATCHDOM_RC" ]]; then
        local tld_count;
        tld_count="$(grep -c '^[^#]' "$WATCHDOM_RC" 2>/dev/null || echo 0)";
        printf "User config   : %s (%s custom TLDs) ✓\n" "$WATCHDOM_RC" "$tld_count";
    else
        printf "User config   : %s ✗\n" "$WATCHDOM_RC";
    fi;

    printf "\n";

    if [[ "$ret" -eq 0 ]]; then
        okay "watchdom is properly installed and ready to use";
    else
        warn "watchdom installation is incomplete - run 'watchdom install'";
    fi;

    return $ret;
};

################################################################################
# dispatch
################################################################################
dispatch() {
    local cmd="${1:-}";
    local ret=1;

    case "$cmd" in
        (watch|time|list_tlds|add_tld|test_tld|install|uninstall|status)
            shift;
            "do_$cmd" "$@";
            ret=$?;
            ;;
        (*)
            error "Unknown command: %s" "$cmd";
            usage;
            ret=1;
            ;;
    esac;

    return $ret;
};

################################################################################
# usage
################################################################################
usage() {
    cat <<'EOF'
watchdom v2.0.0-bashfx - registry WHOIS watcher with dynamic countdown

USAGE:
  # Domain watching
  watchdom [watch] DOMAIN [OPTIONS]
  watchdom DOMAIN [OPTIONS]                    # Legacy compatibility

  # Time utilities
  watchdom time "YYYY-MM-DD HH:MMS UTC"     # Time countdown only
  watchdom time EPOCH_SECONDS                 # Time countdown only

  # TLD management
  watchdom list_tlds                          # Show supported TLDs
  watchdom add_tld TLD SERVER PATTERN         # Add custom TLD support
  watchdom test_tld TLD DOMAIN                # Test TLD pattern

  # Installation management
  watchdom install                            # Install to ~/.local/lib/fx/
  watchdom uninstall                          # Remove installation
  watchdom status                             # Show installation status

OPTIONS:
  Standard BashFX flags:
    -d, --debug     Enable info/okay/warn messages
    -t, --trace     Enable trace messages (verbose polling)
    -q, --quiet     Force quiet mode
    -f, --force     Skip safety guards
    -D, --dev       Developer mode (implies -d -t)

  Domain watching flags:
    -i SECONDS      Base poll interval (default: 60)
    -e REGEX        Override expected pattern
    -n MAX_CHECKS   Stop after N checks (default: unlimited)
    --until WHEN    Target datetime or epoch seconds
    --time_local    Display timestamps in local time only

POLLING PHASES:
  [PRE]   >30min before target: base interval (blue λ)
  [HEAT]  ≤30min before target: ramp to 10s (red ▲)
  [GRACE] 0-3hrs after target: stick at 10s (purple △)
  [COOL]  >3hrs after target: progressive cooldown (cyan ❄)

EMAIL NOTIFICATIONS:
  Set all variables to enable email alerts:
    NOTIFY_EMAIL, NOTIFY_FROM, NOTIFY_SMTP_HOST,
    NOTIFY_SMTP_PORT, NOTIFY_SMTP_USER, NOTIFY_SMTP_PASS

EXAMPLES:
  watchdom example.com -i 30                  # Watch with 30s base interval
  watchdom watch example.com --until "2025-12-25 18:00:00 UTC"
  watchdom time "2025-12-25 18:00:00 UTC"     # Time countdown only
  watchdom list_tlds                          # Show supported TLDs
  watchdom add_tld .uk whois.nominet.uk "No such domain"
  watchdom test_tld .com test-domain.com      # Test pattern
  watchdom install                            # Install system-wide
  watchdom status                             # Check installation

EXIT CODES:
  0: Success (pattern matched)
  1: Not found (max checks reached or user exit)
  2: Bad arguments
  3: Missing dependencies
  4: Date parse error
EOF
};

################################################################################
# options
################################################################################
# Note: Options parsing is now handled directly in main() for robustness
# This ensures that `shift` operates on the correct argument scope.

################################################################################
# main
################################################################################

################################################################################
# _cleanup
################################################################################
_cleanup() {
    local grace_files;
    grace_files=$(find /tmp -name ".watchdom_grace_*_$$" 2>/dev/null);
    if [[ -n "$grace_files" ]]; then
        rm -f $grace_files;
    fi;
    printf "\n" >&2;
    info "Monitoring stopped";
    exit 130;
};

main() {
    local ret=1;
    trap '_cleanup' INT TERM;

    # Initialize option variables
    opt_debug=0
    opt_trace=0
    opt_quiet=0
    opt_force=0
    opt_dev=0
    opt_interval=""
    opt_expect=""
    opt_max_checks=""
    opt_until=""
    opt_time_local=0

    # Parse all options, separating them from positional arguments
    local args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            (-d|--debug) opt_debug=1; shift ;;
            (-t|--trace) opt_trace=1; opt_debug=1; shift ;;
            (-q|--quiet) opt_quiet=1; opt_debug=0; opt_trace=0; shift ;;
            (-f|--force) opt_force=1; shift ;;
            (-D|--dev) opt_dev=1; opt_debug=1; opt_trace=1; shift ;;
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
            (--time_local) opt_time_local=1; shift ;;
            (--time_until) # Legacy compatibility
                [[ $# -ge 2 ]] || { error "Option --time_until requires an argument"; return 2; };
                set -- "time" "$2"; # Convert to 'time' command
                break ;;
            (-h|--help) usage; exit 0 ;;
            (--) shift; args+=("$@"); break ;; # All remaining are positional
            (-*) error "Unknown option: $1"; usage; return 2 ;;
            (*) args+=("$1"); shift ;; # It's a positional argument
        esac
    done
    # Restore positional arguments
    [[ ${#args[@]} -gt 0 ]] && set -- "${args[@]}"

    # Apply quiet mode
    if [[ "$opt_quiet" -eq 1 ]]; then
        opt_debug=0;
        opt_trace=0;
    fi;

    # If no positional args, show usage
    if [[ $# -eq 0 ]]; then
        error "No command or domain specified";
        usage;
        return 2;
    fi;

    # Detect legacy `watchdom domain.com` syntax and prepend 'watch' command
    local cmd="${1:-}"
    case "$cmd" in
        (watch|time|list_tlds|add_tld|test_tld|install|uninstall|status)
             # It's a normal command, do nothing
            ;;
        (*)
            # It's not a known command. Check if it's a domain (legacy mode).
            if [[ -n "$cmd" && "$cmd" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                # Prepend 'watch' to the argument list
                set -- watch "$@";
            fi;
            ;;
    esac;

    dispatch "$@";
    ret=$?;
    return $ret;
};

################################################################################
# invocation
################################################################################
main "$@"