---
name: ccstatusline-config
description: Use when editing, redesigning, or debugging the Claude Code status bar powered by ccstatusline — adding/removing widgets, fixing layout issues, changing colors, adjusting separators, or troubleshooting the flex gap on the right side.
---

# ccstatusline Config Reference

## Quick Facts

- **Config file:** `~/.config/ccstatusline/settings.json`
- **Repo:** https://github.com/sirmalloc/ccstatusline
- **Installed:** pinned v2.2.19 at `~/.local/share/ccstatusline/node_modules/ccstatusline/`
- **Invocation:** `~/.claude/settings.json` statusLine.command runs the binary directly: `/Users/kevin/.local/share/ccstatusline/node_modules/.bin/ccstatusline` — **not** `npx ccstatusline@latest`. npx cost ~0.7s extra latency per repaint (registry check for `@latest` + resolution) and let long-running instances drift onto different versions. Full render is now ~0.4–0.5s vs ~0.9–1.2s under npx. To upgrade: `cd ~/.local/share/ccstatusline && npm install ccstatusline@<ver>` — the `.bin` path stays stable, no settings change needed.
- **Current layout:** single line — `anim repo · branch │ ctx % · $cost` ←flex→ `session % · ↺ block-reset │ wk % · ↺ weekly-reset`
- **Shareable repo:** `/Users/kevin/Library/CloudStorage/Dropbox/dev/cc-better-statusline` — full from-scratch setup (install.sh, all scripts, this skill) for replicating the statusline on another machine. Keep it in sync when making changes here.

---

## JSON Structure

```json
{
  "version": 3,
  "lines": [
    [ ...widgets... ],
    [],
    []
  ],
  "flexMode": "full",
  "colorLevel": 3
}
```

Each line is an array of widget objects. Empty arrays render as blank lines — keep 3 entries to preserve structure.

---

## Widget Object Schema

```json
{
  "id": "unique-string",
  "type": "widget-type-name",
  "color": "magenta",
  "rawValue": true,
  "metadata": { "hideNoGit": "true" },
  "character": " │ ",
  "customText": "ctx"
}
```

| Field | Notes |
|-------|-------|
| `id` | Any unique string |
| `type` | Widget type (see below) |
| `color` | Foreground color name or `ansi256:N` or `hex:RRGGBB` |
| `rawValue` | `true` strips "Label: " prefix, shows value only |
| `metadata` | Widget-specific flags — values are **strings**, not booleans |
| `character` | Separator-only: the literal separator string, e.g. `" · "` |
| `customText` | custom-text only: the static string to display |

---

## Key Widget Types

### Git
| Type | Shows | Notes |
|------|-------|-------|
| `git-root-dir` | Repo folder name | Supports `hideNoGit` |
| `git-branch` | Branch name | Supports `hideNoGit` |

### Context
| Type | Shows |
|------|-------|
| `context-percentage` | % of context window used |
| `context-bar` | Full-width visual bar |

### Billing / Usage
| Type | Shows |
|------|-------|
| `session-usage` | % of current 5-hr Pro block used |
| `session-cost` | USD cost this session |
| `weekly-usage` | % of weekly Pro allotment used |
| `weekly-reset-timer` | Countdown to weekly Pro reset |
| `block-timer` | 5-hr block visual progress |
| `reset-timer` | Countdown to 5-hr block reset (the class is named BlockResetTimerWidget but the **type string is `reset-timer`**) |

Usage/reset widgets read `rate_limits.{five_hour,seven_day}.{used_percentage,resets_at}` live from the stdin JSON — accurate, no caching, no API call needed. Metadata flags (string values): `"compact": "true"` → `4h30m` instead of `4hr 30m`; `"absolute": "true"` → show the reset clock time instead of a countdown.

### Layout
| Type | Notes |
|------|-------|
| `flex-separator` | Fills all remaining space — everything after it is right-aligned |
| `separator` | Static divider; set `character` to control content, e.g. `" │ "`, `" · "`, `"."` |
| `custom-text` | Static label; set `customText` |

### Other
| Type | Shows |
|------|-------|
| `model` | Model name |
| `thinking-effort` | Effort level (blank when unset — disappears cleanly) |

---

## Important Behaviors

### `hideNoGit` — hide when not in a git repo
Set on `git-branch` and `git-root-dir` to return null outside a repo:
```json
"metadata": { "hideNoGit": "true" }
```
Note: value must be the **string** `"true"`, not boolean `true`.

### Separator auto-collapse
A `separator` widget checks whether the preceding non-separator widget produced any content. If not (e.g. `git-branch` returned null), the separator is silently skipped. This means the ` │ ` between git info and ctx disappears automatically when not in a git repo — no extra config needed.

### `rawValue` behavior
Without it, widgets prepend a label: `"Ctx Used: 22.0%"`, `"Session: 15.0%"`, `"Weekly: 2.0%"`.
With `"rawValue": true`: `"22.0%"`, `"15.0%"`, `"2.0%"`.
Pair with a `custom-text` widget ahead of it to use your own short label.

---

## flexMode and the Right-Edge Gap

**Problem:** `flexMode: "full"` always computes `effectiveWidth = detectedWidth - 6`, so there is always a ~6-character gap between the rightmost widget and the terminal edge. This is hardcoded — no settings.json value eliminates it.

**Fix via env var:** Add to `~/.zshrc`:
```zsh
precmd() {
  export CCSTATUSLINE_WIDTH=$(( COLUMNS + 6 ))
}
```
`COLUMNS` updates on terminal resize. Adding 6 makes `effectiveWidth = COLUMNS`, closing the gap. Use `+5` to keep 1 char of right breathing room.

---

## Color Reference

**Named colors:** `black`, `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`, `white` and `brightBlack` … `brightWhite`

**256-color** (`colorLevel: 2`): `"color": "ansi256:196"`

**Truecolor** (`colorLevel: 3`): `"color": "hex:FF6600"` (no `#`)

**Current palette in use:**
- Git info: `magenta`
- Context / usage percentages: truecolor gradient via custom-command scripts (see Dynamic Color Scripts)
- Cost and `↺` reset timer: `brightBlack` (dim gray)
- Separators: inherit terminal default

---

## Separator Style Conventions (current config)

| Purpose | `character` value |
|---------|-------------------|
| Between groups | `" │ "` |
| Within a group | `" · "` |
| Between repo and branch | `" · "` |

---

## Dynamic Color Scripts

Three shell scripts in `~/.config/ccstatusline/` handle threshold-based coloring. Each reads stdin JSON piped by ccstatusline and outputs ANSI-colored text. The widgets use `"type": "custom-command"` with `"preserveColors": true`.

| Script | JSON field read | Label output |
|--------|----------------|--------------|
| `ctx-color.sh` | `(total_input_tokens + total_output_tokens) / context_window_size` | `ctx X.X%` |
| `session-color.sh` | `rate_limits.five_hour.used_percentage` | `session X.X%` |
| `wk-color.sh` | `rate_limits.seven_day.used_percentage` | `wk X.X%` |

If the JSON field is missing/null, the script exits silently — the widget collapses and adjacent separators auto-hide.

**No caching — deliberately.** These scripts once cached output to fixed `/tmp` paths with a 15s TTL. That was a real bug: the cache files were shared by every Claude Code window, so a fresh session displayed another window's ctx %, and idle windows periodically published stale `rate_limits` snapshots for all windows to show ("numbers randomly jumping"). The scripts only parse JSON that ccstatusline already pipes in (~30ms of jq+awk), so there is nothing worth caching. Do not reintroduce a cache here.

**Why ctx doesn't use `used_percentage`:** That field is `input_tokens / window_size` only — it excludes output tokens. The manual calculation `(input + output) / window` is more accurate. It still reads slightly low vs Claude Code's own display because Claude Code updates after the response completes, while the JSON snapshot is taken at turn-start (output tokens mid-generation are tiny). This lag is inherent and unavoidable. Falls back to `used_percentage` if `context_window_size` is 0 or missing.

Widget config entry (same pattern for all three):
```json
{
  "id": "ctx-cmd",
  "type": "custom-command",
  "commandPath": "/Users/kevin/.config/ccstatusline/ctx-color.sh",
  "preserveColors": true,
  "timeout": 2000
}
```

Note: `colorLevel` in settings.json does NOT affect custom-command output — colors come from the scripts' raw ANSI codes. But set `"colorLevel": 3` anyway so ccstatusline's own widgets also use truecolor.

---

## Color Gradient Options

### Active: Truecolor smooth gradient (colorLevel: 3)

Five RGB anchor points, linearly interpolated per percentage point. Requires `colorLevel: 3` and a truecolor-capable terminal (iTerm2, modern Terminal.app, etc.).

Color stops:
| % | RGB | Appearance |
|---|-----|------------|
| 0% | (13, 43, 158) | dark navy |
| 25% | (5, 178, 146) | teal |
| 50% | (240, 203, 8) | golden yellow |
| 75% | (245, 122, 0) | orange |
| 90% | (234, 72, 32) | red-orange |
| 100% | (185, 27, 27) | dark red |

awk core (shared across all three scripts):
```awk
function lerp(a, b, t) { return int(a + (b-a)*t + 0.5) }
if      (p <= 25) { t=(p   )/25; r=lerp( 13,  5,t); g=lerp( 43,178,t); b=lerp(158,146,t) }
else if (p <= 50) { t=(p-25)/25; r=lerp(  5,240,t); g=lerp(178,203,t); b=lerp(146,  8,t) }
else if (p <= 75) { t=(p-50)/25; r=lerp(240,245,t); g=lerp(203,122,t); b=lerp(  8,  0,t) }
else if (p <= 90) { t=(p-75)/15; r=lerp(245,234,t); g=lerp(122, 72,t); b=lerp(  0, 32,t) }
else              { t=(p-90)/10; r=lerp(234,185,t); g=lerp( 72, 27,t); b=lerp( 32, 27,t) }
printf "\033[38;2;%d;%d;%dm<label> %.1f%%\033[0m", r, g, b, p
```

### Fallback: 256-color stepped gradient (colorLevel: 2)

20 discrete ANSI 256-color steps. No interpolation math — just a lookup. Use if the terminal doesn't support truecolor.

**To switch to 256-color:**
1. Set `"colorLevel": 2` in settings.json
2. Replace the awk block in each script with:

```bash
awk -v p="$PCT" -v label="ctx" 'BEGIN {
    n = split("17 18 19 20 27 33 39 45 51 49 46 82 118 154 226 220 214 208 202 196", steps, " ")
    idx = int(p / 100 * (n-1) + 0.5) + 1
    if (idx < 1) idx = 1
    if (idx > n) idx = n
    printf "\033[38;5;%dm%s %.1f%%\033[0m", steps[idx], label, p
}'
```

The 20 steps map to these approximate hues (dark navy → bright red):
`17 18 19 20 27 33 39 45 51 49 46 82 118 154 226 220 214 208 202 196`

**To add back the test gradient line** (for comparing both options visually), temporarily add to `lines[1]`:
```json
{
  "id": "gradient-test",
  "type": "custom-command",
  "commandPath": "/Users/kevin/.config/ccstatusline/gradient-test.sh",
  "preserveColors": true,
  "timeout": 2000
}
```
The `gradient-test.sh` script still exists at `~/.config/ccstatusline/gradient-test.sh`.

---

## Current Config Snapshot

```
⠋  repo · branch │ ctx X.X% · $D.DD   [flex]   session X.X% · ↺ 2hr 29m │ wk X.X% · ↺ 3d 5hr 46m
```

Left side: animated spinner + git identity + context health + session cost  
Right side: session (5h) usage + block reset countdown · weekly usage + weekly reset countdown

Widgets in order: `custom-command(anim-widget.sh)`, sep` `, `git-root-dir`, sep` · `, `git-branch`, sep` │ `, `custom-command(ctx-color.sh)`, sep` · `, `session-cost`, `flex-separator`, `custom-command(session-color.sh)`, sep` · `, `custom-text(↺)`, sep` `, `reset-timer`, sep` │ `, `custom-command(wk-color.sh)`, sep` · `, `custom-text(↺)`, sep` `, `weekly-reset-timer`

---

## Animation System

### Architecture — stateless, time-derived

**No daemon, no state file, no mutable animation state at all.** The displayed frame is a pure function of wall-clock time:

```
cycle = epoch / total_ticks   → seeds a Fisher-Yates shuffle of animation order
pos   = epoch % total_ticks   → position within the shuffled cycle
color = epoch % 144           → gradient step
```

The playlist is flattened into a **schedule cache** at `/tmp/ccstatusline-anim-schedule` (`ccanim2` format): a signature header line, then a `seg <len> <len> …` line recording each animation's tick count, then one pre-rendered display string per tick (expand/narrow slices included) with segments in playlist order. The runtime hot path is: validate header + seg line → seeded shuffle + segment walk (pure bash arithmetic, ~95 iterations) → `sed -n` one line → wrap in the color escape. ~25ms, far under the widget's 500ms timeout.

**Random playback order (stateless):** the cycle number seeds an LCG (`x₀ = (cycle·2654435761 + 1013904223) & 0x7FFFFFFF`, step `x = (x·1103515245 + 12345) & 0x7FFFFFFF`) driving a Fisher-Yates shuffle of the segment indices; `pos` is walked through the permuted segments to find the cache line. Every cycle (~30 min at 95 animations) plays each animation exactly once in a fresh pseudo-random order; all windows compute the identical permutation from the same clock, so they stay in sync, and order still never steps backward. Verified property: each cycle is a perfect bijection onto the tick lines.

**Why stateless:** the previous design kept shared state in `/tmp/ccstatusline-anim-main` with read-modify-write advancement. Claude Code repaints on many events per second and kills superseded renders, so concurrent instances raced (same-second double advances), stale writers rolled state backward (the visible "animations jumping back and forth" bug), and SIGKILLed writes leaked dozens of `.tmp` orphans. Deriving everything from the epoch eliminates all of that by construction:

- **Monotonic:** time only moves forward — a missed repaint lands slightly ahead, never backward.
- **Instance-proof:** every Claude Code window computes the same pure function of the same clock; all windows render identical frames in sync and cannot interfere with each other.
- **Self-repairing:** any signature mismatch (edited inputs, file restored to an *older* mtime, corrupt/foreign/truncated cache) triggers a rebuild; an unreadable tick line triggers one rebuild-and-retry; if no schedule can be built at all (e.g. frames file missing), a static color-cycling ⠋ renders so the line never goes blank. Playlist names with no `[section]` in `anim-frames.txt` are silently skipped at build time.

**Cache invalidation is by exact mtime signature, not `-nt`:** the header line is `ccanim2 <frames-mtime> <playlist-mtime> <script-mtime>`. Any mismatch → rebuild. (`-nt` misses same-second edits and restores to older file versions — both were real bugs in testing.) Bumping the magic (`ccanim1`→`ccanim2` when the seg line was added) makes old-format caches self-invalidate.

Rebuilds publish atomically (`mv` of a PID-suffixed tmp; stale tmps are swept at build start). Concurrent rebuilds are harmless — the content is deterministic, so any winner is correct. `/tmp` is wiped on reboot; the first render rebuilds.

Files:
| Path | Purpose |
|------|---------|
| `~/.config/ccstatusline/anim-widget.sh` | Stateless widget; builds + reads the schedule cache. Pure bash 3.2 (no awk/cut forks, no mapfile/assoc arrays) |
| `~/.config/ccstatusline/anim-frames.txt` | Animation definitions (95: originals + cli-spinners + customs), `[name]` sections, one frame per line |
| `~/.config/ccstatusline/anim-playlist` | Plain text, one animation name per line (currently all 95) |
| `~/.config/ccstatusline/anim-gallery.sh` | **Preferred picker**: animates ALL animations at once in a paged color-cycling grid, then selection by numbers/ranges (`1 4 7-12`, `all`, `same`) writes the playlist. `--list` prints names non-interactively |
| `~/.config/ccstatusline/anim-preview.sh` | Older one-at-a-time preview + playlist selection (still works; gallery is faster for 95) |
| `~/.config/ccstatusline/anim-frames.txt.bak` | Pre-expansion backup (40-animation version) |
| `/tmp/ccstatusline-anim-schedule` | Derived cache: signature header + seg-lengths line + one display string per tick |

**Test hook:** `ANIM_EPOCH=<n>` overrides the clock. `echo '{}' | ANIM_EPOCH=1234 anim-widget.sh` is byte-for-byte deterministic — loop over a `seq` range to verify frame sequences.

To force a rebuild: `rm /tmp/ccstatusline-anim-schedule` (or just edit the playlist/frames — the signature change rebuilds automatically). There is no per-terminal position to reset anymore; every terminal always shows the schedule position for "now".

### refreshInterval and the smoothness ceiling

`~/.claude/settings.json` has `"refreshInterval": 1` (Claude Code's minimum; 0.5s is not supported). The widget renders the correct frame for whatever moment it runs, so event-driven repaints during activity show correct intermediate ticks; idle cadence is ~1 frame/sec. The remaining smoothness ceiling is repaint latency itself — that's why the statusLine command points at the pinned binary instead of `npx @latest` (see Quick Facts).

### Animation Playlist

`~/.config/ccstatusline/anim-playlist` — one name per line. Run `anim-gallery.sh` to re-select (grid view, fastest) or `anim-preview.sh` (sequential). If the file is empty or missing, all animations in `anim-frames.txt` are used. Playlist order no longer matters for playback — the shuffle randomizes it per cycle.

Playlist edits take effect on the next render (signature mismatch → automatic rebuild). No restart needed.

### Animations Reference

The tables below are a representative subset — `anim-frames.txt` is the source of truth (currently **95 animations**: the ~40 originals, +39 harvested from `sindresorhus/cli-spinners` — all one-line, non-emoji, ≤12 chars wide, ≤40 frames, no `|` characters — and +16 customs: `quadrant`, `moonPhase`, `hollowPulse`, `trigramSpin`, `diceRoll`, `music`, `brailleStack`, `sparkline`, `boxFill`, `sonar`, `firework`, `suits`, `hourglass`, `crossBloom`, `asteriskBloom`, `heartbeat`).

**Padding convention:** every width-1 animation is hard-coded to ≥2 full loops and ≥16 frames by repeating its pattern verbatim in the file (`loops = max(2, ceil(16/frame_count))`). Apply the same padding when adding new 1-char animations. Known prune candidates: `arc2` duplicates `arc`; `toggle6` uses Myanmar script (may render as boxes without font support).

**Single-char (width = 1):**
| Name | Frames | Description |
|------|--------|-------------|
| `dots` | ⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏ | classic braille spinner |
| `dots2` | ⣾⣽⣻⢿⡿⣟⣯⣷ | heavy braille |
| `arc` | ◜◠◝◞◡◟ | arc rotation |
| `pipe` | ┤┘┴└├┌┬┐ | box-drawing corners |
| `star` | ✶✸✹✺✹✸ | pulsing star |
| `circleHalves` | ◐◓◑◒ | circle sweep |
| `triangle` | ◢◣◤◥ | rotating triangle |
| `growVertical` | ▁▃▄▅▆▇▆▅▄▃ | breathing bar |
| `boxBounce2` | ▌▀▐▄ | box quarter sweep |
| `hamburger` | ☱☲☴ | line stack |
| `layer` | `-=≡` | density increase |
| `noise` | ▓▒░ | density pulse |
| `toggle9` | ◉◎ | filled/empty circle |

**Multi-char (statusline widens to play these):**
| Name | Width | Frames | Description |
|------|-------|--------|-------------|
| `simpleDots` | 3 | `.  ` `.. ` `...` | classic loading dots |
| `point` | 3 | `∙∙∙` `●∙∙` `∙●∙` `∙∙●` | bouncing dot |
| `arrow3` | 5 | `▸▹▹▹▹` → `▹▹▹▹▸` | scanning marker |
| `bouncingBar` | 6 | `[    ]`…`[====]`…`[   =]` | bouncing bar |
| `aesthetic` | 7 | `▰▱▱▱▱▱▱`…`▰▰▰▰▰▰▰`…`▰▱▱▱▱▱▱` | fill/drain |
| `betaWave` | 7 | `ρββββββ`…`ββββββρ` | scanning rho |

### Width Transitions (schedule build rules)

Per playlist entry, the builder emits ticks in this order:

- **expand** — only when the *first* frame is wider than 1 char: the first frame sliced to widths `1..w-1`
- **play** — `ceil(5/frame_count)` full cycles (always whole cycles, minimum ~5 ticks), frame 0 through the last frame
- **narrow** — only when the *last* frame is wider than 1 char: the last frame sliced to widths `w-1..1`

Most multi-char animations in `anim-frames.txt` self-ramp (start and end at width 1), so only `bouncingBar`, `bouncingBar2`, `aesthetic`, `aestheticScan`, `betaWave`, plus the cli-spinners additions `simpleDotsScrolling`, `binary`, `bouncingBall`, `pong`, and `dotsCircle`/`dots14` get expand/narrow ticks. Each animation's total tick count (expand + play + narrow) is recorded in the cache's `seg` line and is what the shuffle permutes.

Slicing uses pure-bash `${s:0:w}` and `${#s}` under `LANG=en_US.UTF-8` — character-correct for multibyte Unicode, no awk/cut forks. Frames must not contain `|` (used as the internal frame delimiter).

### Color Cycling

144 pre-computed RGB stops cycling navy→teal→yellow→orange→red-orange→dark red→navy. Color step = `epoch % 144`, so a full cycle takes 144 seconds and is identical across all instances. Color advances independently of frame progression.

Color anchor points: (13,43,158) → (5,178,146) → (240,203,8) → (245,122,0) → (234,72,32) → (185,27,27) → (13,43,158)

COLORS array is defined in `anim-widget.sh`, `anim-preview.sh`, and `anim-gallery.sh` (identical copy in all three).

### Gallery Script (preferred picker)

```bash
~/.config/ccstatusline/anim-gallery.sh        # interactive grid
~/.config/ccstatusline/anim-gallery.sh --list # names + frame counts, no UI
```

Animates **all 95 at once** in a paged grid (geometry adapts to terminal size; `*` marks current playlist members; per-cell gradient offsets). Any key → next page, `q` → selection. Selection accepts numbers and ranges to KEEP (`1 4 7-12 30`), `all`, or `same` (leave playlist untouched). Writes `anim-playlist`; effective on next render.

**bash 3.2 gotcha baked into this script:** macOS bash has no fractional `read -t 0.25` (added in bash 4) — it fails instantly and busy-loops. On a tty the gallery uses `stty -echo -icanon min 0 time 3` + `dd bs=1 count=1` as a combined 0.3s frame delay and key poll (with a sentinel `; echo x` to survive command-substitution whitespace stripping); on non-tty stdin it falls back to integer `read -t 1 -n1` so it stays scriptable. The tty state is restored both before the selection prompt and in the EXIT trap. Reuse this pattern for any sub-second interactive loop on stock macOS bash.

### Preview Script (older, sequential)

```bash
~/.config/ccstatusline/anim-preview.sh
```

1. Prompts for speed: `[1] 0.25s  [2] 0.5s  [3] 1s  [4] 2s` per frame (default 0.5s — not limited by the 1s minimum since preview runs standalone)
2. Shows all animations one at a time with color cycling
3. Prompts for numbers to REMOVE; saves result to `anim-playlist`
4. Changes take effect immediately on next statusline render (no restart needed)

Gallery is faster for browsing 95 animations; preview is handy for studying one closely. It sidesteps the bash 3.2 `read -t` issue with plain `sleep` and blocking prompts.

### Color Scripts Run Uncached

With `refreshInterval: 1`, ctx/session/wk scripts run on every repaint and parse their piped stdin fresh each time (~30ms). They previously had a shared 15s `/tmp` TTL cache — removed because cross-window contamination made the numbers jump (see "No caching — deliberately" under Dynamic Color Scripts). Don't add it back.

### Adding a New Animation

1. Add a `[name]` block to `anim-frames.txt` with one frame per line
2. Add the name to `anim-playlist`
3. No restart needed — takes effect on next statusline render

Width is inferred automatically from the frames:
- If `frame[0]` is wider than 1 char → expand phase grows into it
- If the last played frame is wider than 1 char → narrow phase contracts out of it
- Animations that start and end at 1 char self-ramp through their own frames with no separate expand/narrow
