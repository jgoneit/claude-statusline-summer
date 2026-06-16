# claude-statusline-summer 🌞🌴

[한국어](#korean) | [English](#english)

---

<a name="korean"></a>
## 한국어

Claude Code 프롬프트 입력창 아래에 표시되는 여름 테마 statusline.
모델명, rate limit (5h/7d) 잔여량, 컨텍스트 사용량, git 브랜치, 그리고 컨텍스트
사용량을 여름 **"체감 온도"** 게이지(잔잔한 바다 → 폭염)로 보여줍니다.

단일 Bash 스크립트(`statusline.sh`) + `jq`로 동작합니다. 플러그인이 아니라
직접 등록하는 방식이라 내부가 훤히 보이고 고치기 쉽습니다.

### 미리보기

컨텍스트 사용량이 오를수록 게이지가 "뜨거워집니다":

```
# 🌊 여유 (0–24%)
🌞 [Opus] 📁 my-app 🌴 main
🌊 █░░░░░░░░░ 10% used (90% left) · 💰 $0.05 · ⏳ 2m 10s
🍹 5h 88% left · 7d 73% left

# 🐠 따뜻한 얕은 물 (25–49%)
🌞 [Opus] 📁 my-app 🌴 feature/login +1 ~2
🐠 ████░░░░░░ 42% used (58% left) · 💰 $0.21 · ⏳ 9m 30s
🍹 5h 70% left · 7d 65% left

# 🌞 한낮 (50–69%)
🌞 [Opus] 📁 my-app 🌴 main +1
🌞 ██████░░░░ 60% used (40% left) · 💰 $0.33 · ⏳ 14m 20s
🍹 5h 58% left · 7d 63% left

# 🌅 달아오름 (70–89%)
🌞 [Opus] 📁 my-app 🌴 feature/login +2 ~3
🌅 ███████░░░ 75% used (25% left) · 💰 $0.42 · ⏳ 18m 04s
🍹 5h 41% left · 7d 60% left

# 🔥 폭염 (90%+)
🌞 [Sonnet] 📁 my-app 🌴 hotfix
🔥 █████████░ 95% used (5% left) · 💰 $0.88 · ⏳ 31m 12s
🍹 5h 12% left · 7d 55% left
```

> rate limit 행(🍹)은 Claude.ai **Pro/Max** 사용자에게 첫 응답 이후에만 표시됩니다.

### 요구 사항

- **bash** (macOS 기본 bash 3.2에서 동작)
- **[jq](https://jqlang.github.io/jq/)** — `brew install jq`

### 설치

1. `statusline.sh`를 안정적인 위치에 복사 (예: `~/.claude/statusline.sh`)
2. 실행 권한 부여: `chmod +x ~/.claude/statusline.sh`
3. `~/.claude/settings.json`에 등록:

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/statusline.sh",
       "refreshInterval": 10
     }
   }
   ```

설정을 바꿔도 다음 상호작용 때 반영됩니다.

> 이 저장소에서 바로 작업한다면 `.claude/settings.local.json`에 절대 경로로
> 이미 연결돼 있어, 별도 설치 없이 바로 동작합니다.

### 설정

| 키 | 설명 |
|----|------|
| `command` | `statusline.sh`의 경로 |
| `refreshInterval` | 유휴 상태에서도 시계·rate limit을 갱신하는 주기(초). 빼면 새 메시지마다만 갱신 |

### 표시 항목

| 항목 | 설명 |
|------|------|
| `🌞 [Model]` | 현재 Claude 모델 |
| `📁 dir` | 현재 폴더 이름 |
| `🌴 branch +staged ~modified` | git 브랜치 + 스테이지/변경 파일 수 (저장소 안에서만) |
| 🌊 🐠 🌞 🌅 🔥 게이지 | 컨텍스트 사용량을 여름 체감 온도로 (잔잔한 바다 → 폭염) |
| `72% used (28% left)` | 컨텍스트 사용/잔여 % |
| `💰 $0.42 · ⏳ 12m 30s` | 세션 비용 + 경과 시간 |
| `🍹 5h … · 7d …` | 5시간/7일 rate limit **잔여량** (Pro/Max) |

게이지 색은 사용량에 따라 바다색 → 노랑 → 빨강으로 바뀝니다.

### 커스터마이즈

전부 `statusline.sh` 한 파일에서 편집합니다:

- **색상** — 상단 팔레트 상수 (`SEA` `SKY` `SUN` `CORAL` `FIRE`)
- **이모지 / 임계값** — `heat_segment()`의 `if … -ge` 사다리
- **표시 항목·순서·줄 수** — 하단의 `printf '%s\n' …` 행

수정 후 mock JSON으로 바로 미리보기:

```bash
echo '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"'"$PWD"'"},"context_window":{"used_percentage":72,"remaining_percentage":28},"cost":{"total_cost_usd":0.42,"total_duration_ms":750000},"session_id":"demo","rate_limits":{"five_hour":{"used_percentage":23},"seven_day":{"used_percentage":41}}}' | ./statusline.sh
```

### 기여하기

커밋은 [Conventional Commits](https://www.conventionalcommits.org/)
(`feat:`, `fix:`, `docs:`, `chore:` …)를 따릅니다. PR 환영합니다 🎉

---

<a name="english"></a>
## English

A summer-themed Claude Code statusline that displays below the prompt input.
Shows model name, rate limits (5h/7d) remaining, context-window usage, git
branch, and renders context usage as a summer **"heat gauge"** (calm sea →
heatwave).

It's a single Bash script (`statusline.sh`) + `jq` — not a plugin, but a script
you register yourself, so it's transparent and easy to tweak.

### Preview

The gauge gets "hotter" as the context fills up:

```
# 🌊 Plenty of room (0–24%)
🌞 [Opus] 📁 my-app 🌴 main
🌊 █░░░░░░░░░ 10% used (90% left) · 💰 $0.05 · ⏳ 2m 10s
🍹 5h 88% left · 7d 73% left

# 🐠 Warm shallows (25–49%)
🌞 [Opus] 📁 my-app 🌴 feature/login +1 ~2
🐠 ████░░░░░░ 42% used (58% left) · 💰 $0.21 · ⏳ 9m 30s
🍹 5h 70% left · 7d 65% left

# 🌞 Midday (50–69%)
🌞 [Opus] 📁 my-app 🌴 main +1
🌞 ██████░░░░ 60% used (40% left) · 💰 $0.33 · ⏳ 14m 20s
🍹 5h 58% left · 7d 63% left

# 🌅 Heating up (70–89%)
🌞 [Opus] 📁 my-app 🌴 feature/login +2 ~3
🌅 ███████░░░ 75% used (25% left) · 💰 $0.42 · ⏳ 18m 04s
🍹 5h 41% left · 7d 60% left

# 🔥 Heatwave (90%+)
🌞 [Sonnet] 📁 my-app 🌴 hotfix
🔥 █████████░ 95% used (5% left) · 💰 $0.88 · ⏳ 31m 12s
🍹 5h 12% left · 7d 55% left
```

> The rate-limit row (🍹) appears only for Claude.ai **Pro/Max** users, after the
> first response.

### Requirements

- **bash** (works on macOS's stock bash 3.2)
- **[jq](https://jqlang.github.io/jq/)** — `brew install jq`

### Install

1. Copy `statusline.sh` somewhere stable (e.g. `~/.claude/statusline.sh`)
2. Make it executable: `chmod +x ~/.claude/statusline.sh`
3. Register it in `~/.claude/settings.json`:

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/statusline.sh",
       "refreshInterval": 10
     }
   }
   ```

Changes take effect on your next interaction.

> If you're working inside this repo, it's already wired up via
> `.claude/settings.local.json` (absolute path) — no install needed.

### Configuration

| Key | Description |
|-----|-------------|
| `command` | Path to `statusline.sh` |
| `refreshInterval` | Seconds between idle refreshes (keeps clock/rate-limits current). Omit to update only on new messages |

### What it shows

| Section | Description |
|---------|-------------|
| `🌞 [Model]` | Current Claude model |
| `📁 dir` | Current folder name |
| `🌴 branch +staged ~modified` | git branch + staged/modified counts (inside a repo) |
| 🌊 🐠 🌞 🌅 🔥 gauge | Context usage as a summer temperature (calm sea → heatwave) |
| `72% used (28% left)` | Context used / remaining % |
| `💰 $0.42 · ⏳ 12m 30s` | Session cost + elapsed time |
| `🍹 5h … · 7d …` | 5-hour / 7-day rate limit **remaining** (Pro/Max) |

The gauge color shifts sea → yellow → red as usage rises.

### Customize

Everything lives in the one `statusline.sh` file:

- **Colors** — the palette constants up top (`SEA` `SKY` `SUN` `CORAL` `FIRE`)
- **Emoji / thresholds** — the `if … -ge` ladder in `heat_segment()`
- **Segments, order, line count** — the `printf '%s\n' …` rows at the bottom

Preview a change instantly with mock JSON:

```bash
echo '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"'"$PWD"'"},"context_window":{"used_percentage":72,"remaining_percentage":28},"cost":{"total_cost_usd":0.42,"total_duration_ms":750000},"session_id":"demo","rate_limits":{"five_hour":{"used_percentage":23},"seven_day":{"used_percentage":41}}}' | ./statusline.sh
```

### Contributing

Commits follow [Conventional Commits](https://www.conventionalcommits.org/)
(`feat:`, `fix:`, `docs:`, `chore:`, …). PRs welcome 🎉

## License

MIT
