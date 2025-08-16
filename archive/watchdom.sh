#!/usr/bin/env bash
# watchdom — registry WHOIS watcher with dynamic countdown, UTC+Local display, ramping.
# Colors: grey (no match), green (success), red (target reached once)
# Exit codes: 0 success | 1 not seen | 2 bad args | 3 whois missing | 4 date parse error

set -euo pipefail

# ANSI colors
BLUE="\033[94m"; GREY="\033[90m"; GREEN="\033[92m"; YEL="\033[93m"; RED="\033[91m"; NC="\033[0m"

usage() {
  cat <<'EOF'
Usage:
  # Standalone time readout (no WHOIS)
  watchdom --time-until "YYYY-MM-DD HH:MM:SS UTC" [--time-local] | <epoch>

  # Watch a domain
  watchdom DOMAIN [-i SECONDS] [-e EXPECT_REGEX] [-n MAX_CHECKS] [--until "YYYY-MM-DD HH:MM:SS UTC"|<EPOCH>] [--time-local]

Options:
  -i SECONDS     Base poll interval (default: 60). Warns if <10s.
  -e REGEX       Expected pattern (default: registry 'available' text)
                 Examples: 'No match for' (Verisign available), 'pendingDelete'
  -n MAX_CHECKS  Stop after N checks (default: unlimited)
  --until WHEN   Datetime (e.g., "2025-08-15 18:00:00 UTC") or epoch seconds.
                 Auto-ramps: >30m -> base, <=30m -> 30s, <=5m -> 10s (sticks after target)
  --time-until   Print remaining time + target timestamps, then exit (no WHOIS)
  --time-local   Display timestamps/countdown in LOCAL ONLY (no UTC shown)
EOF
}

# ---------- helpers ----------
human() {  # seconds -> compact "Xd Xh Xm Xs"
  local s=$1 d h m; (( d=s/86400, s%=86400, h=s/3600, s%=3600, m=s/60, s%=60 ))
  local out=""; [[ $d -gt 0 ]] && out+="${d}d "; [[ $h -gt 0 ]] && out+="${h}h "; [[ $m -gt 0 ]] && out+="${m}m "; out+="${s}s"; echo "$out"
}

# print date safely on GNU/BSD
fmt_utc()   { date -u    -d @"$1" "+%a %b %d %H:%M:%S UTC %Y" 2>/dev/null || date -u -r "$1" "+%a %b %d %H:%M:%S UTC %Y"; }
fmt_local() { date       -d @"$1" "+%a %b %d %H:%M:%S %Z %Y"  2>/dev/null || date    -r "$1" "+%a %b %d %H:%M:%S %Z %Y"; }

parse_when_to_epoch() {
  local WHEN="$1" E=""
  [[ "$WHEN" =~ ^[0-9]+$ ]] && { echo "$WHEN"; return 0; }
  if date -u -d "$WHEN" +%s >/dev/null 2>&1; then echo "$(date -u -d "$WHEN" +%s)"; return 0; fi
  if command -v gdate >/dev/null 2>&1 && gdate -u -d "$WHEN" +%s >/dev/null 2>&1; then echo "$(gdate -u -d "$WHEN" +%s)"; return 0; fi
  if date -u -j -f "%Y-%m-%d %H:%M:%S %Z" "$WHEN" +%s >/dev/null 2>&1; then echo "$(date -u -j -f "%Y-%m-%d %H:%M:%S %Z" "$WHEN" +%s)"; return 0; fi
  return 4
}

print_time_until() {
  local WHEN="$1" LOCAL_ONLY="${2:-0}"
  local EPOCH; EPOCH=$(parse_when_to_epoch "$WHEN") || { echo "ERR: cannot parse time '$WHEN'"; exit 4; }
  local NOW=$(date -u +%s); local REM=$((EPOCH-NOW))
  if (( REM < 0 )); then
    [[ "$LOCAL_ONLY" -eq 1 ]] && echo "Remaining (Local): 0s (time passed)" || echo "Remaining: 0s (time passed)"
  else
    if [[ "$LOCAL_ONLY" -eq 1 ]]; then
      echo "Remaining (Local): $(human $REM)"
    else
      echo "Remaining: $(human $REM)"
    fi
  fi
  if [[ "$LOCAL_ONLY" -eq 1 ]]; then
    echo "Target Local: $(fmt_local "$EPOCH")"
  else
    echo "Target UTC  : $(fmt_utc   "$EPOCH")"
    echo "Target Local: $(fmt_local "$EPOCH")"
  fi
  echo "UNTIL_EPOCH=$EPOCH"
}

# ---------- parse args ----------
DOMAIN=""; INTERVAL=60; EXPECT=""; MAX_CHECKS=0; UNTIL_WHEN=""; TIME_LOCAL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --time-local) TIME_LOCAL=1; shift ;;
    --time-until)
      shift; [[ $# -ge 1 ]] || { usage; exit 2; }
      UNTIL_WHEN="$1"; shift
      print_time_until "$UNTIL_WHEN" "$TIME_LOCAL"; exit 0
      ;;
    --until)
      shift; [[ $# -ge 1 ]] || { usage; exit 2; }
      UNTIL_WHEN="$1"; shift
      ;;
    -i)
      shift; [[ $# -ge 1 ]] || { usage; exit 2; }
      INTERVAL="$1"; shift
      ;;
    -e)
      shift; [[ $# -ge 1 ]] || { usage; exit 2; }
      EXPECT="$1"; shift
      ;;
    -n)
      shift; [[ $# -ge 1 ]] || { usage; exit 2; }
      MAX_CHECKS="$1"; shift
      ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*)
      echo "ERR: unknown option '$1'"; usage; exit 2
      ;;
    *)
      if [[ -z "$DOMAIN" ]]; then DOMAIN="$1"; else
        echo "ERR: unexpected arg '$1'"; usage; exit 2
      fi
      shift
      ;;
  esac
done

# ---------- domain watch mode ----------
[[ -z "$DOMAIN" ]] && { usage; exit 2; }
command -v whois >/dev/null 2>&1 || { echo "ERR: 'whois' not found"; exit 3; }
[[ "$INTERVAL" -lt 10 ]] && echo -e "${YEL}WARN: interval ${INTERVAL}s is aggressive; consider >=30s${NC}" >&2

shopt -s nocasematch
TLD=".${DOMAIN##*.}"; SERVER=""; DEFAULT_EXPECT=""
case "$TLD" in
  .com|.net) SERVER="whois.verisign-grs.com"; DEFAULT_EXPECT="No match for" ;;
  .org)      SERVER="whois.pir.org";          DEFAULT_EXPECT="(NOT FOUND|Domain not found)" ;;
  *) echo "ERR: Only .com, .net, .org supported"; exit 2 ;;
esac
[[ -z "$EXPECT" ]] && EXPECT="$DEFAULT_EXPECT"

UNTIL_EPOCH=""
if [[ -n "${UNTIL_WHEN}" ]]; then
  UNTIL_EPOCH=$(parse_when_to_epoch "$UNTIL_WHEN") || { echo "ERR: cannot parse --until '$UNTIL_WHEN'"; exit 4; }
fi

echo "Watching ${DOMAIN} via ${SERVER}; base interval=${INTERVAL}s; expect=/${EXPECT}/i"
if [[ -n "$UNTIL_EPOCH" ]]; then
  if [[ "$TIME_LOCAL" -eq 1 ]]; then
    echo "Target Local: $(fmt_local "$UNTIL_EPOCH") (epoch ${UNTIL_EPOCH})"
  else
    echo "Target UTC  : $(fmt_utc   "$UNTIL_EPOCH")"
    echo "Target Local: $(fmt_local "$UNTIL_EPOCH") (epoch ${UNTIL_EPOCH})"
  fi
fi
echo "(Ctrl-C to stop)"

COUNT=0; TARGET_ALERTED=0

while :; do
  # Effective interval ramping near target (does NOT cool off after target)
  EFF="$INTERVAL"
  if [[ -n "$UNTIL_EPOCH" ]]; then
    NOW=$(date -u +%s); REM=$((UNTIL_EPOCH-NOW))
    if   (( REM <= 300 ));  then EFF=10
    elif (( REM <= 1800 )); then EFF=30
    fi
  fi
  (( EFF < 10 )) && echo -e "${YEL}WARN: effective interval ${EFF}s may trigger rate limits${NC}" >&2

  TS="$(date -Is)"
  OUT="$(whois -h "$SERVER" "$DOMAIN" 2>/dev/null || true)"

  if echo "$OUT" | grep -Eiq -- "$EXPECT"; then
    echo -e "${GREEN}[$TS] SUCCESS: pattern matched for ${DOMAIN}${NC}"
    echo "$OUT" | sed -n '1,20p'
    exit 0
  else
    echo -e "${GREY}[$TS] not yet — effective interval ${EFF}s${NC}"
  fi

  COUNT=$((COUNT+1))
  if [[ "$MAX_CHECKS" -gt 0 && "$COUNT" -ge "$MAX_CHECKS" ]]; then
    echo "DONE: Max checks ($MAX_CHECKS) reached without matching pattern."
    exit 1
  fi

  # Dynamic single-line countdown between polls
  for ((r=EFF; r>=1; r--)); do
    NOW=$(date -u +%s)
    LINE="next poll in ${r}s"
    if [[ -n "$UNTIL_EPOCH" ]]; then
      DELTA=$((UNTIL_EPOCH-NOW))
      if (( DELTA > 0 )); then
        LINE+=" | target in $(human $DELTA)"
      else
        if (( TARGET_ALERTED == 0 )); then
          echo -e "\n${RED}TARGET INTERVAL reached${NC}"
          TARGET_ALERTED=1
        fi
        LINE+=" | target since $(human $((-DELTA)))"
      fi
      if [[ "$TIME_LOCAL" -eq 1 ]]; then
        LINE+=" | Local: $(fmt_local "$UNTIL_EPOCH")"
      else
        LINE+=" | UTC: $(fmt_utc "$UNTIL_EPOCH") | Local: $(fmt_local "$UNTIL_EPOCH")"
      fi
    fi
    printf "\r${BLUE}%s${NC}" "$LINE"
    sleep 1
  done
  printf "\r%s\r" "                                                                                         "
done
