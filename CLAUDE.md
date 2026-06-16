# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A single Bash + `jq` **status line** script (`statusline.sh`) for Claude Code,
with a summer theme. There is **no build system and no test framework** — that
is expected for a one-script project. "Testing" means piping mock JSON at it
(below). The README documents the human-facing install; this file covers how
the script works and how to change it safely.

## The status line contract

Claude Code runs `statusline.sh`, pipes a session **JSON object on stdin**, and
renders the script's **stdout** — one printed line per row. Key rules the
script must keep honoring:

- Read all of stdin (`input=$(cat)`), parse with `jq`.
- Must be **executable**, write to **stdout** (not stderr), and **`exit 0`** —
  a non-zero exit or empty output blanks the status line.
- Stay **fast**: it reruns after every assistant message (debounced 300ms), and
  a slow run blocks/cancels the update. `refreshInterval: 10` in the settings
  also reruns it on a timer so the clock/rate-limits stay current while idle.
- Fields are routinely **`null` or absent** — always supply fallbacks.

Full field reference: https://code.claude.com/docs/en/statusline

## Test (the one real "command")

Pipe mock JSON — no Claude Code session needed. Run each and check `echo $?` is `0`:

```bash
# Full input → 3 rows
echo '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"/Users/jgoneit/opensource_library/claude-statusline-summer"},"context_window":{"used_percentage":42,"remaining_percentage":58},"cost":{"total_cost_usd":0.12,"total_duration_ms":185000},"session_id":"test-abc","rate_limits":{"five_hour":{"used_percentage":23},"seven_day":{"used_percentage":41}}}' | ./statusline.sh

# Minimal / null fields → must not error, uses fallbacks
echo '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"/tmp"}}' | ./statusline.sh

# No rate_limits → the 🍹 row is omitted
echo '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"/tmp"},"context_window":{"used_percentage":10,"remaining_percentage":90}}' | ./statusline.sh
```

## Architecture (`statusline.sh`)

- **Single `jq` pass** unpacks all needed fields as one tab-separated line read
  into shell vars. `// 0` / `// 100` / `// ""` are the null/absent guards —
  keep new fields in this pattern.
- **Palette constants** (`SEA SKY SUN CORAL FIRE`, `RESET DIM`) hold real ESC
  bytes via `$'\033[...'`, so output uses plain `printf '%s'` — deliberately
  **not** `echo -e` (unreliable on macOS bash 3.2).
- **`heat_segment()`** is the theme's core: maps `used_percentage` to an emoji +
  colored 10-block bar (the summer "temperature"). Sets `HEAT_EMOJI`/`HEAT_BAR`.
  Change the theme here or in the palette constants.
- **`git_segment()`** caches branch + staged/modified counts to
  `/tmp/statusline-summer-$SESSION_ID` with a 5s TTL. The cache key is
  **`session_id`, not `$$`** — the PID changes every invocation and would defeat
  the cache. Uses `git -C "$DIR"` and stays silent outside a repo.
- **Rate-limit row** computes `remaining = 100 - used` and prints only when the
  fields are present.

## Config / activation

- This repo: registered in `.claude/settings.local.json` (the *local* file) with
  an **absolute** path — correct home for a machine-specific path; keeps any
  shared `settings.json` clean. Adjust the path if you move the repo.
- Other machines: install per `README.md` (user `~/.claude/settings.json`).
- Changes won't appear until the next interaction triggers a rerun.
- The shared `.claude/settings.json` holds a **Claude Code hook** (no machine
  paths): a `PostToolUse` (Edit|Write) hook that runs `bash -n statusline.sh`
  after the script is edited and bounces syntax errors straight back to Claude.

## Git conventions

Commits follow **Conventional Commits**: `<type>(<optional scope>): <description>`.

- **Types:** `feat fix docs style refactor perf test build ci chore revert`.
- **Scope** (optional): the area touched — e.g. `heat`, `git`, `rate-limits`, `readme`, `hooks`.
- **Imperative, lowercase** subject, no trailing period: `feat(heat): add sunset tier`.
- **Branches:** `<type>/<short-desc>` (e.g. `feat/heat-gauge`, `fix/null-context`).
  Don't develop changes directly on `main`.
- Claude commits keep the `Co-Authored-By: Claude ...` trailer.
- Never commit `.claude/settings.local.json` (machine-specific; gitignored).

### Enforcement (git hooks)

Hooks live in `.githooks/` and are committed, but git requires a one-time opt-in per clone:

```bash
git config core.hooksPath .githooks
```

- `commit-msg` — rejects non-Conventional-Commits subjects (Merge/Revert/fixup! exempt).
- `pre-commit` — runs `bash -n` (and `shellcheck` if installed) on `statusline.sh`,
  and blocks staging `.claude/settings.local.json`.

These are git-native (apply to any committer); the Claude Code hook above is the
in-session equivalent for Claude's own edits.

## Gotchas

- **`rate_limits`** only exists for Claude.ai **Pro/Max** users, and only after
  the first API response — guard with `// ""`, never assume it's there.
- **`context_window.*`** can be `null` early in a session and right after
  `/compact` — that's why the script floors with a `// 0` fallback.
- **macOS ships bash 3.2**: no associative arrays, no `${var,,}`. Keep to
  POSIX-ish bash; test changes under `/bin/bash`, not just a newer Homebrew bash.
- **`jq` is required** — the script no-ops without it.
- **Keep output short**: long rows wrap or get truncated, and notifications
  share the right side of the row.
