# claude-statusline-summer 🌞🌴

[한국어](#korean) | [English](#english)

---

<a name="korean"></a>
## 한국어

Claude Code 프롬프트 입력창 아래에 표시되는 여름 테마 statusline.
모델명, 현재 폴더, git 브랜치, 컨텍스트 사용량, 비용/시간, 그리고 5h/7d rate
limit을 보여줍니다.

여름 느낌은 **이모지가 아니라 색**으로 표현합니다: 손수 고른 24-bit 트루컬러
팔레트와, 잔잔한 청록 → 타오르는 빨강으로 흐르는 **하나의 선셋 그라데이션
게이지**(`bar`)를 컨텍스트와 5h/7d rate limit에 똑같이 재사용합니다. 채움이
낮으면 시원한 바다색, 가득 차면 뜨거운 색이 드러나 그라데이션 자체가 "열기"를
나타냅니다.

### 미리보기

> 막대는 청록(여유) → 빨강(가득)으로 흐르는 트루컬러 그라데이션입니다.
> 아래 미리보기는 색을 담지 못하니 **채움 정도**만 참고하세요. 반칸(▌)은 5%
> 단위입니다.

```
# 컨텍스트 10% — 이른 세션
Opus 4.8 high  my-app  main
█░░░░░░░░░  10% ctx  ·  $0.05  ·  2m 10s

# 컨텍스트 43% — rate limit 표시 (Pro/Max)
Opus 4.8 xhigh  my-app  feature/login +1 ~2
████▌░░░░░  43% ctx  ·  $0.21  ·  9m 30s
5h ██████░░░░ 58%   ·   7d ████░░░░░░ 40%

# 컨텍스트 95% — 거의 가득
Sonnet 4.6 high  my-app  hotfix ~5
█████████▌  95% ctx  ·  $0.88  ·  31m 12s
5h █████████▌ 95%   ·   7d ██████░░░░ 61%
```

색 가이드: 모델명은 **골드**, 폴더는 **샌드**, 브랜치는 **청록**, `+`스테이지는
**골드**, `~`변경은 **코랄**. rate limit 행은 **사용량(%)**을 보여줘 창을
소진할수록 게이지가 뜨거워집니다.

### 요구 사항

- **bash** (macOS 기본 bash 3.2에서 동작)
- **[jq](https://jqlang.github.io/jq/)** — `brew install jq`
- **색을 지원하는 터미널.** 트루컬러(24-bit)를 자동 감지해 우선 사용하고,
  지원하지 않는 터미널(예: Apple Terminal.app)에서는 띠 없는 **256색 팔레트로
  폴백**합니다. 감지가 틀리면 강제 지정하세요:
  `export STATUSLINE_SUMMER_COLOR=truecolor` (또는 `256`). tmux에서 트루컬러를
  쓰려면 `~/.tmux.conf`에 `set -ga terminal-overrides ",*:Tc"`도 필요합니다.

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
> 이미 연결돼 있어 별도 설치 없이 동작합니다.

### 설정

| 키 | 설명 |
|----|------|
| `command` | `statusline.sh`의 경로 |
| `refreshInterval` | 유휴 상태에서도 시계·rate limit을 갱신하는 주기(초). 빼면 새 메시지마다만 갱신 |

### 표시 항목

| 항목 | 설명 |
|------|------|
| `Opus 4.8` | 현재 Claude 모델 (골드) |
| `xhigh` | 모델 오른쪽의 추론 effort (low→max) — 강도에 따라 색이 진해짐. 미지원 모델에선 생략 |
| `my-app` | 현재 폴더 이름 (샌드) |
| `main +1 ~2` | git 브랜치(청록) + 스테이지(`+`, 골드) / 변경(`~`, 코랄) — 저장소 안에서만 |
| `████▌░░░░░ 43% ctx` | 컨텍스트 사용량 — 청록→빨강 그라데이션 게이지 |
| `$0.21` | 세션 비용 |
| `9m 30s` | 경과 시간 |
| `5h ██████░░░░ 58%` | 5시간 rate limit **사용량** (소진할수록 게이지가 채워짐) — Pro/Max |
| `7d ████░░░░░░ 40%` | 7일 rate limit **사용량** — Pro/Max |

### 커스터마이즈

전부 `statusline.sh` 한 파일에서 편집합니다:

- **색상** — 상단 팔레트 상수 (`C_MODEL` `C_DIR` `C_GIT` `C_STAGE` `C_MOD`
  `C_MUTE`). 트루컬러/256 두 벌이 있으니 쓰는 모드 쪽을 수정하세요.
- **게이지 그라데이션** — 10단계 `SUNSET` 배열과 빈 칸 색 `TRACK`
- **게이지 모양** — `bar()` 함수 (10칸, 반칸 `▌`로 5% 해상도)
- **표시 항목·순서·줄 수** — 하단의 `printf '%s\n' …` 행

수정 후 mock JSON으로 바로 미리보기:

```bash
echo '{"model":{"display_name":"Opus 4.8"},"workspace":{"current_dir":"'"$PWD"'"},"context_window":{"used_percentage":43},"cost":{"total_cost_usd":0.21,"total_duration_ms":570000},"session_id":"demo","rate_limits":{"five_hour":{"used_percentage":58},"seven_day":{"used_percentage":40}}}' | ./statusline.sh
```

### 기여하기

커밋은 [Conventional Commits](https://www.conventionalcommits.org/)
(`feat:`, `fix:`, `docs:`, `chore:` …)를 따릅니다. PR 환영합니다 🎉

---

<a name="english"></a>
## English

A summer-themed Claude Code statusline that displays below the prompt input.
Shows model name, current folder, git branch, context-window usage, cost/time,
and 5h/7d rate limits.

The "summer" feeling is carried by **color, not emoji**: a hand-picked 24-bit
truecolor palette and a single sunset-gradient gauge (`bar`) — calm turquoise →
blazing red — reused for context usage **and** both rate-limit windows. A low
fill is cool sea-tones; a high fill reveals the hot end, so the gradient itself
encodes "heat."

### Preview

> The bar is a turquoise (cool) → red (full) truecolor gradient. These previews
> can't show color, so read the **fill level** only. A half-block (▌) is 5%.

```
# Context 10% — early in the session
Opus 4.8 high  my-app  main
█░░░░░░░░░  10% ctx  ·  $0.05  ·  2m 10s

# Context 43% — with rate limits (Pro/Max)
Opus 4.8 xhigh  my-app  feature/login +1 ~2
████▌░░░░░  43% ctx  ·  $0.21  ·  9m 30s
5h ██████░░░░ 58%   ·   7d ████░░░░░░ 40%

# Context 95% — nearly full
Sonnet 4.6 high  my-app  hotfix ~5
█████████▌  95% ctx  ·  $0.88  ·  31m 12s
5h █████████▌ 95%   ·   7d ██████░░░░ 61%
```

Color guide: model name is **gold**, folder **sand**, branch **turquoise**,
`+`staged **gold**, `~`modified **coral**. The rate-limit row shows **% used**,
so the gauge heats up as you burn the window down.

### Requirements

- **bash** (works on macOS's stock bash 3.2)
- **[jq](https://jqlang.github.io/jq/)** — `brew install jq`
- **A color terminal.** Truecolor (24-bit) is auto-detected and preferred; on
  terminals without it (e.g. Apple Terminal.app) it falls back to a curated
  **256-color palette** with no banding. Force a mode if detection is wrong:
  `export STATUSLINE_SUMMER_COLOR=truecolor` (or `256`). In tmux, truecolor also
  needs `set -ga terminal-overrides ",*:Tc"` in `~/.tmux.conf`.

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
| `Opus 4.8` | Current Claude model (gold) |
| `xhigh` | Reasoning effort, right of the model (low→max) — color deepens with intensity; omitted on models without it |
| `my-app` | Current folder name (sand) |
| `main +1 ~2` | git branch (turquoise) + staged (`+`, gold) / modified (`~`, coral) — inside a repo |
| `████▌░░░░░ 43% ctx` | Context usage — turquoise→red gradient gauge |
| `$0.21` | Session cost |
| `9m 30s` | Elapsed time |
| `5h ██████░░░░ 58%` | 5-hour rate limit **usage** (gauge fills as you burn the window) — Pro/Max |
| `7d ████░░░░░░ 40%` | 7-day rate limit **usage** — Pro/Max |

### Customize

Everything lives in the one `statusline.sh` file:

- **Colors** — the palette constants up top (`C_MODEL` `C_DIR` `C_GIT` `C_STAGE`
  `C_MOD` `C_MUTE`) — truecolor and 256-color sets; edit the one for your mode
- **Gauge gradient** — the 10-step `SUNSET` array and the empty-cell `TRACK` color
- **Gauge shape** — the `bar()` function (10 cells, 5% resolution via the half-block `▌`)
- **Segments, order, line count** — the `printf '%s\n' …` rows at the bottom

Preview a change instantly with mock JSON:

```bash
echo '{"model":{"display_name":"Opus 4.8"},"workspace":{"current_dir":"'"$PWD"'"},"context_window":{"used_percentage":43},"cost":{"total_cost_usd":0.21,"total_duration_ms":570000},"session_id":"demo","rate_limits":{"five_hour":{"used_percentage":58},"seven_day":{"used_percentage":40}}}' | ./statusline.sh
```

### Contributing

Commits follow [Conventional Commits](https://www.conventionalcommits.org/)
(`feat:`, `fix:`, `docs:`, `chore:`, …). PRs welcome 🎉

## License

MIT
