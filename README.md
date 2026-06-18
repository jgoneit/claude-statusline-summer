# claude-statusline-summer

> A summer-themed status line for [Claude Code](https://code.claude.com/) — the theme lives in the color, not in emoji.

**English** | [한국어](./README.ko.md)

![claude-statusline-summer](./docs/claude-statusline-summer.png)

Shows your model, folder, git status, context-window usage, session cost/time,
and 5h/7d rate limits. A single sunset-gradient gauge — calm turquoise → blazing
red — is reused for context usage **and** both rate-limit windows, so every
gauge shares one visual language: **the fuller it gets, the hotter it looks.**

## Requirements

- **bash** (works on macOS's stock bash 3.2)
- **[jq](https://jqlang.github.io/jq/)** — `brew install jq` / `sudo apt install jq`
- **A color terminal.** Truecolor (24-bit) is auto-detected and preferred; on
  terminals without it (e.g. Apple Terminal.app) it falls back to a curated
  256-color palette with no banding.

## Install

```bash
git clone https://github.com/jgoneit/claude-statusline.git
cd claude-statusline
./install.sh
```

`install.sh` checks for `jq`, copies the script to `~/.claude/statusline.sh`,
and registers it in `~/.claude/settings.json` — backing up your settings first
and asking before replacing any existing status line.

<details>
<summary>Manual install</summary>

1. Copy `statusline.sh` **and the `themes/` folder** side by side (e.g. `~/.claude/statusline.sh` + `~/.claude/themes/`) and `chmod +x` the script.
2. Register it in `~/.claude/settings.json` with an **absolute** path:

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "/absolute/path/to/statusline.sh",
       "refreshInterval": 10
     }
   }
   ```
</details>

## Configuration

| Variable | Values | Effect |
|---|---|---|
| `STATUSLINE_THEME` | `summer` (default) \| `christmas`† | Pick the palette `themes/<name>/colors.sh`; an unknown name falls back to summer |
| `STATUSLINE_COLOR` | `truecolor` \| `256` | Force a color mode (overrides auto-detection). Legacy `STATUSLINE_SUMMER_COLOR` still works |
| `STATUSLINE_DEMO_PCT` | `0`–`100` | Screenshot helper: fill every gauge at this percent instead of real session data |

- † `christmas` is a scaffold (empty palette) — it renders uncoloured until its `colors.sh` is filled in.
- In tmux, truecolor also needs `set -ga terminal-overrides ",*:Tc"` in `~/.tmux.conf`.
- `refreshInterval` (in settings.json) re-runs the script on a timer so the
  elapsed clock stays current while idle; omit it to update only on new messages.

## What it shows

| Section | Description |
|---|---|
| `Opus 4.8` | Current model (gold) |
| `xhigh` | Reasoning effort, right of the model (low→max); omitted on models without it |
| `my-app` | Current folder (sand) |
| `main +1 ~2 ↑1 ↓3` | branch (turquoise) · staged `+` (gold) · modified `~` (coral) · ahead `↑` · behind `↓` vs upstream — inside a repo |
| `ctx ████▌░░░░░ 43%` | Context usage — turquoise→red gradient gauge; the % is tinted to the gauge color |
| `$0.21` · `⧗ 00h 09m` | Session cost · elapsed time |
| `5h … 58% · ⧗ 04h 35m` | 5-hour rate limit usage + time remaining — Pro/Max |
| `7d … 40% · ⧗ Wed 15:47` | 7-day rate limit usage + reset moment — Pro/Max |

Before the first response, the 5h/7d rows show a dim `--` placeholder so the
layout doesn't jump once the data arrives.

## Customize

Themes are colour-only files in `themes/<name>/colors.sh`; the engine lives in `statusline.sh`:

- **Theme palette** — `themes/<name>/colors.sh` sets the 10-step `SUNSET` gradient and the `C_*` accents (`C_MODEL` `C_DIR` `C_GIT` `C_STAGE` `C_MOD` `C_MUTE`), in truecolor and 256 sets. Copy `summer/` to start a new theme.
- **Gauge shape** — the `bar()` function in `statusline.sh` (10 cells, 5% via the half-block `▌`).
- **Segments / order** — the `printf '%s\n' …` rows at the bottom of `statusline.sh`.

Preview a change with mock JSON:

```bash
echo '{"model":{"display_name":"Opus 4.8"},"workspace":{"current_dir":"'"$PWD"'"},"context_window":{"used_percentage":43},"cost":{"total_cost_usd":0.21,"total_duration_ms":570000},"session_id":"demo","rate_limits":{"five_hour":{"used_percentage":58},"seven_day":{"used_percentage":40}}}' | ./statusline.sh
```

## License

MIT © jgoneit
