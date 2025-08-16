################################################################################
# escape sequences (BashFX standard from esc.sh.*)
################################################################################
readonly red=$'\x1B[31m'
readonly green=$'\x1B[32m'
readonly blue=$'\x1B[34m'
readonly yellow=$'\x1B[33m'
readonly purple=$'\x1B[35m'
readonly cyan=$'\x1B[36m'
readonly grey=$'\x1B[38;5;244m'
readonly red2=$'\x1B[38;5;196m'
readonly x=$'\x1B[38;5;244m'

################################################################################
# glyphs (phase indicators and symbols)
################################################################################
readonly lambda=$'\xCE\xBB'              # λ - POLL phase
readonly triangle=$'\xe2\x96\xb2'        # ▲ - HEAT phase  
readonly triangle_up=$'\xe2\x96\xb5'     # ▵ - GRACE phase
readonly snowflake=$'\xe2\x9d\x85'       # ❅ - COOL phase
readonly pass=$'\xe2\x9c\x93'            # ✓ - success
readonly fail=$'\xe2\x9c\x97'            # ✗ - failure
readonly delta=$'\xe2\x96\xb3'           # △ - warning/change
readonly spark=$'\xe2\x9c\xa8'           # ✨ - completion

################################################################################
# phase color mapping
################################################################################
_get_phase_color() {
    local phase="$1"
    case "$phase" in
        (POLL)  echo "$blue" ;;
        (HEAT)  echo "$red" ;;
        (GRACE) echo "$purple" ;;
        (COOL)  echo "$cyan" ;;
        (*)     echo "$grey" ;;
    esac
}

_get_phase_glyph() {
    local phase="$1"
    case "$phase" in
        (POLL)  echo "$lambda" ;;
        (HEAT)  echo "$triangle" ;;
        (GRACE) echo "$triangle_up" ;;
        (COOL)  echo "$snowflake" ;;
        (*)     echo "?" ;;
    esac
}