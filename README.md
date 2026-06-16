# claude-statusline-summer 🌞🌴

A summer-themed [status line](https://code.claude.com/docs/en/statusline) for
Claude Code. One Bash script reads the session JSON Claude Code pipes to it and
prints a colorful, multi-line summary at the bottom of your terminal.

```
🌞 [Opus] 📁 claude-statusline-summer 🌴 main +1 ~3
🌅 ███████░░░ 72% used (28% left) · 💰 $0.42 · ⏳ 12m 30s
🍹 5h 77% left · 7d 59% left
```

## What it shows

| Segment | Source field | Notes |
|---|---|---|
| 🌞 Model + 📁 dir | `model.display_name`, `workspace.current_dir` | folder name only |
| 🌴 branch `+staged ~modified` | `git` (cached per session) | hidden outside a repo |
| 🌊🐠🌞🌅🔥 heat gauge | `context_window.used_percentage` | summer "temperature" — calm sea → heatwave as context fills |
| used / left % | `context_window.used_percentage` / `remaining_percentage` | |
| 💰 cost · ⏳ time | `cost.total_cost_usd`, `cost.total_duration_ms` | |
| 🍹 rate limits | `rate_limits.five_hour` / `seven_day` | **Pro/Max only**, after the first response — otherwise hidden |

## Requirements

- **bash** (works on macOS's stock bash 3.2)
- **[jq](https://jqlang.github.io/jq/)** for JSON parsing — `brew install jq`

## Install (any machine)

1. Copy `statusline.sh` somewhere stable (e.g. `~/.claude/statusline.sh`).
2. Make it executable: `chmod +x ~/.claude/statusline.sh`
3. Point your **user** settings (`~/.claude/settings.json`) at it:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/statusline.sh",
       "refreshInterval": 10
     }
   }
   ```
   `refreshInterval` (seconds) keeps the clock and rate-limit numbers fresh
   while the session is idle. Drop it to update only on new messages.

In **this** repo it's already wired up via `.claude/settings.local.json` (using
an absolute path), so it's live whenever you work here.

## Test it without Claude Code

Pipe mock JSON straight into the script:

```bash
echo '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"'"$PWD"'"},"context_window":{"used_percentage":72,"remaining_percentage":28},"cost":{"total_cost_usd":0.42,"total_duration_ms":750000},"session_id":"demo","rate_limits":{"five_hour":{"used_percentage":23},"seven_day":{"used_percentage":41}}}' | ./statusline.sh
```

## Customize the theme

The look lives in two places in `statusline.sh`:

- the **palette** constants near the top (`SEA`, `SKY`, `SUN`, `CORAL`, `FIRE`), and
- `heat_segment()`, which maps context usage to an emoji + bar color.

Edit those to taste, then re-run the test command above to preview.
