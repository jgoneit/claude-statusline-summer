#!/bin/bash
#
# claude-statusline-summer 🌞 — a summer-themed Claude Code status line.
#
# Claude Code pipes session JSON to this script on stdin and renders whatever
# we print to stdout (one row per line). See the contract in CLAUDE.md or
# https://code.claude.com/docs/en/statusline
#
# Requires: jq (https://jqlang.github.io/jq/)

input=$(cat)

# --- Summer palette -------------------------------------------------------
# Real ESC bytes baked in via $'...', so plain `printf '%s'` emits them
# correctly — no `echo -e` (unreliable on macOS's bash 3.2).
RESET=$'\033[0m'
DIM=$'\033[2m'
SEA=$'\033[36m'           # cyan   — calm water
SKY=$'\033[34m'           # blue   — open sky
SUN=$'\033[33m'           # yellow — sunshine
CORAL=$'\033[38;5;209m'   # coral  — warming up
FIRE=$'\033[31m'          # red    — scorching

# --- Parse every field we need in a single jq pass ------------------------
# Tab-separated so one `read` can unpack it. `// 0` / `// 100` / `// ""`
# guard against fields that are null (early in a session) or absent
# (e.g. rate_limits only exist for Pro/Max users after the first response).
IFS=$'\t' read -r MODEL DIR USED REMAIN COST DURATION_MS SESSION_ID RL5_USED RL7_USED <<EOF
$(printf '%s' "$input" | jq -r '
  [ .model.display_name                              // "Claude",
    .workspace.current_dir                           // ".",
    (.context_window.used_percentage      // 0   | floor),
    (.context_window.remaining_percentage // 100 | floor),
    .cost.total_cost_usd                             // 0,
    .cost.total_duration_ms                          // 0,
    .session_id                                      // "nosession",
    (.rate_limits.five_hour.used_percentage          // ""),
    (.rate_limits.seven_day.used_percentage          // "")
  ] | @tsv')
EOF

# === heat_segment: the summer "temperature" gauge ========================
# Turns context-window usage into a summer heat reading: an emoji plus a
# colored 10-block bar that gets "hotter" as the context fills up. Sets the
# globals HEAT_EMOJI and HEAT_BAR.
heat_segment() {
  local pct=$1
  local filled=$((pct / 10)); [ "$filled" -gt 10 ] && filled=10
  local empty=$((10 - filled))

  local emoji color fill
  # pct(0–100)로 heat 결정 — 0=잔잔한 바다 … 100=폭염
  if   [ "$pct" -ge 90 ]; then emoji="🔥"; color="$FIRE";  fill="█"   # 거의 꽉 참 — 폭염
  elif [ "$pct" -ge 70 ]; then emoji="🌅"; color="$CORAL"; fill="█"   # 달아오름 — 노을
  elif [ "$pct" -ge 50 ]; then emoji="🌞"; color="$SUN";   fill="█"   # 한낮 태양
  elif [ "$pct" -ge 25 ]; then emoji="🐠"; color="$SKY";   fill="█"   # 따뜻한 얕은 물
  else                         emoji="🌊"; color="$SEA";   fill="█"   # 잔잔, 여유 충분
  fi

  # Build the bar: a run of spaces, then swap spaces for the block chars.
  local fillbar="" emptybar=""
  [ "$filled" -gt 0 ] && { printf -v fillbar "%${filled}s" ""; fillbar="${fillbar// /$fill}"; }
  [ "$empty"  -gt 0 ] && { printf -v emptybar "%${empty}s" ""; emptybar="${emptybar// /░}"; }

  HEAT_EMOJI="$emoji"
  HEAT_BAR="${color}${fillbar}${RESET}${DIM}${emptybar}${RESET}"
}

# === git_segment: branch + staged/modified counts, cached per session =====
# This script reruns on every assistant message, so the git calls are cached
# to a temp file keyed on SESSION_ID (stable per session, unlike $$ which
# changes each invocation) with a 5s TTL. Sets GIT_BRANCH/STAGED/MODIFIED.
git_segment() {
  local dir=$1 sid=$2
  local cache="/tmp/statusline-summer-$sid"
  local max_age=5
  local now mtime stale=1

  now=$(date +%s)
  if [ -f "$cache" ]; then
    mtime=$(stat -f %m "$cache" 2>/dev/null || stat -c %Y "$cache" 2>/dev/null || echo 0)
    [ $((now - mtime)) -le "$max_age" ] && stale=0
  fi

  if [ "$stale" -eq 1 ]; then
    if git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
      local b s m
      b=$(git -C "$dir" branch --show-current 2>/dev/null)
      s=$(git -C "$dir" diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
      m=$(git -C "$dir" diff --numstat 2>/dev/null | wc -l | tr -d ' ')
      printf '%s\t%s\t%s\n' "$b" "$s" "$m" > "$cache"
    else
      printf '\t\t\n' > "$cache"   # mark "not a repo" so we don't re-check for 5s
    fi
  fi

  IFS=$'\t' read -r GIT_BRANCH GIT_STAGED GIT_MODIFIED < "$cache"
}

# --- Assemble the segments ------------------------------------------------
heat_segment "$USED"
git_segment "$DIR" "$SESSION_ID"

DIR_NAME="${DIR##*/}"

# Git display (only when inside a repo)
GIT_DISPLAY=""
if [ -n "$GIT_BRANCH" ]; then
  GIT_DISPLAY=" ${SEA}🌴 ${GIT_BRANCH}${RESET}"
  [ "${GIT_STAGED:-0}" -gt 0 ] 2>/dev/null && GIT_DISPLAY="${GIT_DISPLAY} ${SUN}+${GIT_STAGED}${RESET}"
  [ "${GIT_MODIFIED:-0}" -gt 0 ] 2>/dev/null && GIT_DISPLAY="${GIT_DISPLAY} ${CORAL}~${GIT_MODIFIED}${RESET}"
fi

# Cost + elapsed time
COST_FMT=$(printf '$%.2f' "$COST")
DURATION_SEC=$((DURATION_MS / 1000))
MINS=$((DURATION_SEC / 60))
SECS=$((DURATION_SEC % 60))

# --- Print the status line (one echo == one row) --------------------------
printf '%s\n' "${SUN}🌞 [${MODEL}]${RESET} 📁 ${DIR_NAME}${GIT_DISPLAY}"
printf '%s\n' "${HEAT_EMOJI} ${HEAT_BAR} ${USED}% used (${REMAIN}% left) ${DIM}·${RESET} ${SUN}💰 ${COST_FMT}${RESET} ${DIM}·${RESET} ⏳ ${MINS}m ${SECS}s"

# Rate-limit row (only when the data is present, i.e. Pro/Max after 1st call)
if [ -n "$RL5_USED" ] || [ -n "$RL7_USED" ]; then
  RL_PARTS=""
  if [ -n "$RL5_USED" ]; then
    RL5_LEFT=$((100 - $(printf '%.0f' "$RL5_USED")))
    RL_PARTS="5h ${RL5_LEFT}% left"
  fi
  if [ -n "$RL7_USED" ]; then
    RL7_LEFT=$((100 - $(printf '%.0f' "$RL7_USED")))
    RL_PARTS="${RL_PARTS:+$RL_PARTS ${DIM}·${RESET} }7d ${RL7_LEFT}% left"
  fi
  printf '%s\n' "${SEA}🍹 ${RL_PARTS}${RESET}"
fi

exit 0
