#!/bin/bash
#
# claude-statusline — a themeable Claude Code status line.
#
# Claude Code pipes session JSON to this script on stdin and renders whatever
# we print to stdout (one row per line). Contract:
#   https://code.claude.com/docs/en/statusline
#
# The look is carried by COLOR, not emoji: a gradient gauge reused for context
# usage AND the 5h/7d rate limits. The palette comes from a theme — a thin
# colour-only file in themes/<name>/colors.sh. Pick one with:
#   export STATUSLINE_THEME=summer        # default; christmas is a scaffold
#
# COLOR DEPTH — auto-detected, with a curated 256-color fallback so the
# gradient never bands on terminals without 24-bit color (e.g. Apple
# Terminal.app). Force a mode if detection is wrong:
#   export STATUSLINE_COLOR=truecolor     # or: 256  (legacy STATUSLINE_SUMMER_COLOR still works)
# Inside tmux, truecolor also needs:  set -ga terminal-overrides ",*:Tc"
#
# Requires: jq.
#
# Test with mock input:
#   m='{"model":{"display_name":"Opus 4.8"},"workspace":{"current_dir":"/x"},"context_window":{"used_percentage":62},"session_id":"t"}'
#   echo "$m" | STATUSLINE_COLOR=truecolor ./statusline.sh
#   echo "$m" | STATUSLINE_COLOR=256       ./statusline.sh

input=$(cat)

RESET=$'\033[0m'
DIM=$'\033[2m'
US=$'\x1f'   # Unit Separator: a NON-whitespace field delimiter for `read`

# --- Detect color depth ---------------------------------------------------
# Positive confirmation -> truecolor; otherwise fall back to 256 (safe almost
# everywhere). An explicit override always wins.
case "${STATUSLINE_COLOR:-${STATUSLINE_SUMMER_COLOR:-auto}}" in
  truecolor|24bit) TRUECOLOR=1 ;;
  256|ansi)        TRUECOLOR=0 ;;
  *)
    case "$COLORTERM" in
      *truecolor*|*24bit*) TRUECOLOR=1 ;;
      *) case "$TERM" in *direct*) TRUECOLOR=1 ;; *) TRUECOLOR=0 ;; esac ;;
    esac ;;
esac

# --- Load the selected theme's palette ------------------------------------
# A theme is COLOUR ONLY: themes/<name>/colors.sh defines SUNSET (10 gradient
# stops) and the C_* accents for the colour depth detected above. The engine
# below is theme-agnostic. STATUSLINE_THEME picks the theme (default: summer);
# an unknown name falls back to summer so the status line never blanks.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME="${STATUSLINE_THEME:-summer}"
[ -f "$SCRIPT_DIR/themes/$THEME/colors.sh" ] || THEME=summer
. "$SCRIPT_DIR/themes/$THEME/colors.sh"

# --- Parse every field we need in a single jq pass ------------------------
# One `read`, split on US (0x1f) — a NON-whitespace delimiter. A tab is
# whitespace, so a tab-delimited read collapses empty fields (an absent 5h
# rate limit would shift 7d into its slot); US never collapses. The separator
# is passed to jq via --arg so there is no control char in the source. Rate
# limits floor to an int, or become "" when absent (Pro/Max, after 1st reply).
IFS="$US" read -r MODEL DIR USED REMAIN COST DURATION_MS SESSION_ID RL5 RL7 EFFORT RL5_RESET RL7_RESET <<EOF
$(printf '%s' "$input" | jq -j --arg sep "$US" '
  [ .model.display_name                              // "Claude",
    .workspace.current_dir                           // ".",
    (.context_window.used_percentage      // 0   | floor),
    (.context_window.remaining_percentage // 100 | floor),
    .cost.total_cost_usd                             // 0,
    .cost.total_duration_ms                          // 0,
    .session_id                                      // "nosession",
    (.rate_limits.five_hour.used_percentage | if type == "number" then floor else "" end),
    (.rate_limits.seven_day.used_percentage | if type == "number" then floor else "" end),
    (.effort.level // ""),
    (.rate_limits.five_hour.resets_at | if type == "number" then floor else "" end),
    (.rate_limits.seven_day.resets_at | if type == "number" then floor else "" end)
  ] | map(tostring) | join($sep)')
EOF

# --- Demo override: STATUSLINE_DEMO_PCT -----------------------------------
# For screenshots of any theme at an arbitrary fill: when set to a whole number,
# every gauge (ctx, 5h, 7d) renders at that percent instead of real session data.
# Non-numeric/empty is ignored; bar() clamps to 0-100 so out-of-range is harmless.
case "${STATUSLINE_DEMO_PCT:-}" in
  ''|*[!0-9]*) ;;
  *) USED=$STATUSLINE_DEMO_PCT; RL5=$STATUSLINE_DEMO_PCT; RL7=$STATUSLINE_DEMO_PCT ;;
esac

# === bar: the one gauge to rule them all =================================
# A percentage (0-100 int) -> a 10-cell sunset gradient bar with half-cell
# (5%) resolution via the left-half block U+258C. Reused for context usage
# and both rate-limit windows so every gauge shares one visual language.
bar() {
  local pct=$1 esc=$'\033' out="" i n halves
  [ -z "$pct" ] && pct=0
  [ "$pct" -lt 0 ]   && pct=0
  [ "$pct" -gt 100 ] && pct=100
  halves=$(( (pct + 2) / 5 )); [ "$halves" -gt 20 ] && halves=20

  for i in 0 1 2 3 4 5 6 7 8 9; do
    n=$(( halves - i * 2 ))
    if   [ "$n" -ge 2 ]; then out="${out}${esc}[${SUNSET[$i]}m█"   # full
    elif [ "$n" -eq 1 ]; then out="${out}${esc}[${SUNSET[$i]}m▌"   # half = 5%
    else                      out="${out}${DIM}${esc}[${SUNSET[$i]}m░" # empty: dim gradient
    fi
  done
  printf '%s%s' "$out" "$RESET"
}

# === fmt_reset: epoch + strftime fmt -> local time, cross-platform date ===
# resets_at is a Unix epoch (the jq parse floors it as a number). BSD date takes
# `-r <epoch>`, GNU date takes `-d @<epoch>`; try BSD first, fall back to GNU
# (GNU's `date -r` means "reference FILE", so it fails cleanly on a number).
# LC_TIME=C forces English weekday abbreviations regardless of locale.
fmt_reset() {
  local epoch=$1 fmt=$2
  LC_TIME=C date -r "$epoch" +"$fmt" 2>/dev/null || \
  LC_TIME=C date -d "@$epoch" +"$fmt" 2>/dev/null
}

# === fmt_remain: seconds-until -> "HHh MMm" (zero-padded; clamps negatives) ===
fmt_remain() {
  local s=$1
  [ "$s" -lt 0 ] && s=0
  printf '%02dh %02dm' "$((s/3600))" "$(((s%3600)/60))"
}

# === gauge_row: aligned "<label> <bar>  <pct>%  <trailing>" ===============
# Label left-padded to 3 cols and pct right-aligned to 3 so ctx/5h/7d line up.
# `trailing` is pre-formatted (may be empty) and already includes its separator.
gauge_row() {
  local label=$1 pct=$2 trailing=$3 labelpad pctpad idx esc=$'\033'
  printf -v labelpad '%-3s' "$label"
  if [ -n "$pct" ]; then
    printf -v pctpad '%3d' "$pct"
    idx=$((pct * 10 / 100)); [ "$idx" -gt 9 ] && idx=9   # pct -> fill color, like the bar
    printf '%s\n' "${C_MUTE}${labelpad}${RESET} $(bar "$pct")  ${esc}[${SUNSET[$idx]}m${pctpad}%${RESET}${trailing}"
  else
    # no data yet (before 1st API response): empty gauge + dim "--%" placeholder
    printf -v pctpad '%3s' '--'
    printf '%s\n' "${C_MUTE}${labelpad}${RESET} $(bar 0)  ${DIM}${pctpad}%${RESET}${trailing}"
  fi
}

# === git_segment: branch + staged/modified, cached per session ===========
# This script reruns on every assistant message, so the git calls are cached
# to a temp file keyed on SESSION_ID (stable per session, unlike $$) with a
# 5s TTL. Sets GIT_BRANCH / GIT_STAGED / GIT_MODIFIED.
git_segment() {
  local dir=$1 sid=$2
  local cache="/tmp/statusline-$sid"
  local max_age=5
  local now mtime stale=1

  now=$(date +%s)
  if [ -f "$cache" ]; then
    mtime=$(stat -c %Y "$cache" 2>/dev/null || stat -f %m "$cache" 2>/dev/null || echo 0)
    [ $((now - mtime)) -le "$max_age" ] && stale=0
  fi

  if [ "$stale" -eq 1 ]; then
    if git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
      local b s m ah bh
      b=$(git -C "$dir" branch --show-current 2>/dev/null)
      s=$(git -C "$dir" diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
      m=$(git -C "$dir" diff --numstat 2>/dev/null | wc -l | tr -d ' ')
      # ahead/behind vs upstream — empty when there's no upstream (@{u} errors,
      # stderr silenced) so the row simply omits ↑/↓.
      ah=$(git -C "$dir" rev-list --count @{u}..HEAD 2>/dev/null)
      bh=$(git -C "$dir" rev-list --count HEAD..@{u} 2>/dev/null)
      printf '%s\n' "${b}${US}${s}${US}${m}${US}${ah}${US}${bh}" > "$cache"
    else
      printf '%s\n' "${US}${US}${US}${US}" > "$cache"   # not a repo: all fields empty
    fi
  fi

  IFS="$US" read -r GIT_BRANCH GIT_STAGED GIT_MODIFIED GIT_AHEAD GIT_BEHIND < "$cache"
}

# --- Assemble ------------------------------------------------------------
git_segment "$DIR" "$SESSION_ID"
DIR_NAME="${DIR##*/}"

# Effort level, just right of the model — color rises with intensity (summer heat).
# Absent when the current model doesn't support the effort parameter.
EFFORT_DISPLAY=""
if [ -n "$EFFORT" ]; then
  case "$EFFORT" in
    low)       ec="$C_MUTE"  ;;
    medium)    ec="$C_DIR"   ;;
    high)      ec="$C_STAGE" ;;
    xhigh|max) ec="$C_MOD"   ;;
    *)         ec="$C_MUTE"  ;;
  esac
  EFFORT_DISPLAY=" ${ec}${EFFORT}${RESET}"
fi

# Git display (only inside a repo) — color does the work, no glyphs
GIT_DISPLAY=""
if [ -n "$GIT_BRANCH" ]; then
  GIT_DISPLAY="  ${C_GIT}${GIT_BRANCH}${RESET}"
  [ "${GIT_STAGED:-0}"   -gt 0 ] 2>/dev/null && GIT_DISPLAY="${GIT_DISPLAY} ${C_STAGE}+${GIT_STAGED}${RESET}"
  [ "${GIT_MODIFIED:-0}" -gt 0 ] 2>/dev/null && GIT_DISPLAY="${GIT_DISPLAY} ${C_MOD}~${GIT_MODIFIED}${RESET}"
  [ "${GIT_AHEAD:-0}"    -gt 0 ] 2>/dev/null && GIT_DISPLAY="${GIT_DISPLAY} ${C_GIT}↑${GIT_AHEAD}${RESET}"
  [ "${GIT_BEHIND:-0}"   -gt 0 ] 2>/dev/null && GIT_DISPLAY="${GIT_DISPLAY} ${C_MOD}↓${GIT_BEHIND}${RESET}"
fi

# Cost + elapsed time (zero-padded HHh MMm, no seconds; hours always shown)
COST_FMT=$(printf '$%.2f' "$COST")
DURATION_SEC=$((DURATION_MS / 1000))
printf -v DUR_FMT '%02dh %02dm' "$((DURATION_SEC / 3600))" "$(((DURATION_SEC % 3600) / 60))"
NOW=$(date +%s)   # for the 5h "remaining" countdown

# --- Print (one printf == one row) ---------------------------------------
# Row 1: identity
printf '%s\n' "${C_MODEL}${MODEL}${RESET}${EFFORT_DISPLAY}  ${C_DIR}${DIR_NAME}${RESET}${GIT_DISPLAY}"

# Row 2: context gauge + cost + time (ctx label aligns with 5h/7d below)
gauge_row "ctx" "$USED" "  ${DIM}·${RESET}  ${C_STAGE}${COST_FMT}${RESET}  ${DIM}·${RESET}  ${C_MUTE}⧗ ${DUR_FMT}${RESET}"

# Rows 3-4: rate-limit gauges — ALWAYS rendered so the layout is stable from the
# start (placeholder before the first API response). % USED is fill-tinted; 5h
# shows time REMAINING, 7d the absolute reset moment. Missing data shows dim "--"
# (never a fake 0%/weekday). 5h and 7d judged independently, width-matched.
if [ -n "$RL5_RESET" ]; then
  t5="  ${DIM}·${RESET}  ${C_MUTE}⧗ $(fmt_remain $((RL5_RESET - NOW)))${RESET}"
else
  t5="  ${DIM}·${RESET}  ${DIM}⧗ --h --m${RESET}"
fi
gauge_row "5h" "$RL5" "$t5"
if [ -n "$RL7_RESET" ]; then
  t7="  ${DIM}·${RESET}  ${C_MUTE}⧗ $(fmt_reset "$RL7_RESET" '%a %H:%M')${RESET}"
else
  t7="  ${DIM}·${RESET}  ${DIM}⧗ --- --:--${RESET}"
fi
gauge_row "7d" "$RL7" "$t7"

exit 0
