#!/usr/bin/env bash
# watchdom - registry WHOIS watcher with phase-aware polling
# version: 2.1.0-bashfx-fixed
# portable: whois, date, grep, sed
# builtins: printf, read, local, declare, case, if, for, while

################################################################################
# readonly
################################################################################
readonly SELF_NAME="watchdom"
readonly SELF_VERSION="2.1.0-bashfx-fixed"
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

# Rate limiting and error patterns
readonly RATE_LIMIT_PATTERN="rate limit|exceeded|too many|try again|access denied|quota"

################################################################################
# config
################################################################################
# Default settings (overridable by environment)
DEFAULT_INTERVAL="${WATCHDOM_INTERVAL:-60}"
DEFAULT_MAX_CHECKS="${WATCHDOM_MAX_CHECKS:-0}"
DEFAULT_TIME_LOCAL="${WATCHDOM_TIME_LOCAL:-1}"

# Email notification settings (all must be set to enable notifications)
NOTIFY_EMAIL="${NOTIFY_EMAIL:-}"           # Recipient email
NOTIFY_FROM="${NOTIFY_FROM:-}"             # Sender email  
NOTIFY_SMTP_HOST="${NOTIFY_SMTP_HOST:-}"   # SMTP server
NOTIFY_SMTP_PORT="${NOTIFY_SMTP_PORT:-}"   # SMTP port
NOTIFY_SMTP_USER="${NOTIFY_SMTP_USER:-}"   # SMTP username
NOTIFY_SMTP_PASS="${NOTIFY_SMTP_PASS:-}"   # SMTP password

# Phase timing thresholds (in seconds)
readonly HEAT_THRESHOLD=1800    # 30 minutes - switch to HEAT phase
readonly GRACE_THRESHOLD=10800  # 3 hours - switch to COOL phase

# TLD Registry defaults (can be extended via ~/.watchdomrc)
declare -A TLD_REGISTRY=(
    [".com"]="whois.verisign-grs.com|No match for"
    [".net"]="whois.verisign-grs.com|No match for"
    [".org"]="whois.pir.org|NOT FOUND"
    [".info"]="whois.afilias.net|Not found"
    [".biz"]="whois.nic.biz|Not found"
)