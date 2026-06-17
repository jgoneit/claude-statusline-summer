#!/bin/bash
#
# claude-statusline-summer — a summer-themed Claude Code status line.
#
# Claude Code pipes session JSON to this script on stdin and renders whatever
# we print to stdout (one row per line). Contract:
#   https://code.claude.com/docs/en/statusline
#
# The "summer" feeling is carried by COLOR, not emoji: a sunset gradient gauge
# (calm turquoise -> blazing red) reused for context usage AND the 5h/7d rate
# limits.
#
# COLOR DEPTH — auto-detected, with a curated 256-color fallback so the
# gradient never bands on terminals without 24-bit color (e.g. Apple
# Terminal.app). Force a mode if detection is wrong:
#   export STATUSLINE_SUMMER_COLOR=truecolor   # or: 256
# Inside tmux, truecolor also needs:  set -ga terminal-overrides ",*:Tc"
#
# Requires: jq.
#
# Test both palettes with mock input:
#   m='{"model":{"display_name":"Opus 4.8"},"workspace":{"current_dir":"/x/summer"},"context_window":{"used_percentage":62},"session_id":"t"}'
#   echo "$m" | STATUSLINE_SUMMER_COLOR=truecolor ./statusline.sh
#   echo "$m" | STATUSLINE_SUMMER_COLOR=256       ./statusline.sh

input=$(cat)

RESET=$'\033[0m'
DIM=$'\033[2m'
US=$'\x1f'   # Unit Separator: a NON-whitespace field delimiter for `read`

# --- Detect color depth ---------------------------------------------------
# Positive confirmation -> truecolor; otherwise fall back to 256 (safe almost
# everywhere). An explicit override always wins.
case "${STATUSLINE_SUMMER_COLOR:-auto}" in
  truecolor|24bit) TRUECOLOR=1 ;;
  256|ansi)        TRUECOLOR=0 ;;
  *)
    case "$COLORTERM" in
      *truecolor*|*24bit*) TRUECOLOR=1 ;;
      *) case "$TERM" in *direct*) TRUECOLOR=1 ;; *) TRUECOLOR=0 ;; esac ;;
    esac ;;
esac

# --- Summer palette (mode-appropriate) ------------------------------------
# SUNSET holds the bare SGR params (bar() wraps them in ESC [ ... m); empty
# cells reuse the same per-index color, dimmed, so the ramp is always present.
# The 256 ramp is hand-picked for 10 distinct steps: teal -> seafoam -> sand
# -> gold -> amber -> coral -> red. No auto-conversion, so no banding.
if [ "$TRUECOLOR" -eq 1 ]; then
  SUNSET=(
    "38;2;46;196;182"  "38;2;91;202;191"  "38;2;154;217;201" "38;2;232;224;168" "38;2;255;212;91"
    "38;2;255;192;58"  "38;2;255;165;58"  "38;2;255;133;82"  "38;2;255;107;74"  "38;2;255;77;77"
  )
  C_MODEL=$'\033[38;2;255;212;91m'   # sun gold
  C_DIR=$'\033[38;2;234;217;176m'    # warm sand
  C_GIT=$'\033[38;2;46;196;182m'     # turquoise water
  C_STAGE=$'\033[38;2;255;212;91m'   # gold
  C_MOD=$'\033[38;2;255;133;82m'     # coral
  C_MUTE=$'\033[38;2;138;151;161m'   # faded
else
  SUNSET=( "38;5;43" "38;5;79" "38;5;115" "38;5;187" "38;5;223"
           "38;5;221" "38;5;215" "38;5;209" "38;5;203" "38;5;196" )
  C_MODEL=$'\033[38;5;221m'
  C_DIR=$'\033[38;5;187m'
  C_GIT=$'\033[38;5;43m'
  C_STAGE=$'\033[38;5;221m'
  C_MOD=$'\033[38;5;209m'
  C_MUTE=$'\033[38;5;102m'
fi

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
  printf -v pctpad '%3d' "$pct"
  idx=$((pct * 10 / 100)); [ "$idx" -gt 9 ] && idx=9   # pct -> fill color, like the bar
  printf '%s\n' "${C_MUTE}${labelpad}${RESET} $(bar "$pct")  ${esc}[${SUNSET[$idx]}m${pctpad}%${RESET}${trailing}"
}

# === git_segment: branch + staged/modified, cached per session ===========
# This script reruns on every assistant message, so the git calls are cached
# to a temp file keyed on SESSION_ID (stable per session, unlike $$) with a
# 5s TTL. Sets GIT_BRANCH / GIT_STAGED / GIT_MODIFIED.
git_segment() {
  local dir=$1 sid=$2
  local cache="/tmp/statusline-summer-$sid"
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

# Rows 3-4: rate-limit gauges (Pro/Max only), same bar, aligned with ctx.
# % USED + 5h shows time REMAINING (countdown), 7d shows the absolute reset moment.
if [ -n "$RL5" ]; then
  t=""
  [ -n "$RL5_RESET" ] && t="  ${DIM}·${RESET}  ${C_MUTE}⧗ $(fmt_remain $((RL5_RESET - NOW)))${RESET}"
  gauge_row "5h" "$RL5" "$t"
fi
if [ -n "$RL7" ]; then
  t=""
  [ -n "$RL7_RESET" ] && t="  ${DIM}·${RESET}  ${C_MUTE}⧗ $(fmt_reset "$RL7_RESET" '%a %H:%M')${RESET}"
  gauge_row "7d" "$RL7" "$t"
fi

exit 0
