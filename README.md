# cc-better-statusline

A polished, animated status line for [Claude Code](https://claude.com/claude-code), built on
[ccstatusline](https://github.com/sirmalloc/ccstatusline). What you get:

```
⠋  repo · branch │ ctx 17.0% · $1.23      …      session 41.2% · ↺ 2hr 29m │ wk 12.3% · ↺ 3d 5hr 46m
└┬┘  └─────┬────┘  └──────┬────────┘                └─────┬─────┘           └────┬──────┘
 │         │              │                               │                      │
 │         │              │                               │                      └ weekly usage % + reset countdown
 │         │              │                               └ 5-hour block usage % + reset countdown
 │         │              └ context window used % + this session's $ cost
 │         └ git repo + branch (auto-hides outside a repo)
 └ animated spinner — 95 animations, random order, color-cycling
```

- **Accurate usage numbers.** Session (5-hour) and weekly usage + reset countdowns read straight
  from the live data Claude Code provides — no caching, no drift, no random jumping.
- **Smooth truecolor gradient.** Context / session / weekly percentages sweep
  navy → teal → yellow → orange → red as they climb.
- **95 animated spinners** that play in a random order you can't predict, fully synchronized
  across every open Claude Code window. Pick which ones you want from a live gallery.

Built and tested on macOS (zsh, stock bash 3.2). The shell scripts are bash 3.2 compatible.

---

## Requirements

- **Claude Code**
- **Node.js + npm** (ccstatusline is an npm package)
- **jq** (`brew install jq`) — used by the installer and the color scripts
- A **truecolor terminal** for the smooth gradient (iTerm2, modern Terminal.app, Ghostty, WezTerm, …).
  Without truecolor the gradient still works but bands more coarsely.

## Install

```bash
git clone <this-repo> cc-better-statusline
cd cc-better-statusline
./install.sh
```

That will:

1. Install the pinned `ccstatusline@2.2.19` binary into `~/.local/share/ccstatusline`.
2. Ask whether you want the **animated spinner**, showing a live braille preview while you decide.
3. Copy the scripts (+ animation data, if you opted in) into `~/.config/ccstatusline`, rewriting paths to your `$HOME`.
4. Write `~/.config/ccstatusline/settings.json` (the widget layout).
5. Merge a `statusLine` block into `~/.claude/settings.json`, preserving everything else.

Everything it overwrites is backed up first (`*.bak.<timestamp>`). Re-running is safe and idempotent;
it won't clobber your `anim-playlist` selection.

Restart Claude Code (or just wait for the next repaint) and you're done.

### The animation prompt

```
  ⠹  Include the animated spinner? [Y/n]
```

The braille glyph spins (in the status line's color gradient) while it waits. Press **Enter** or **y**
to include it, **n** to omit it. Decline and you get the exact same layout minus the spinner — and the
animation files aren't installed at all. You can change your mind later by re-running with a flag below.

### Install flags

| Flag | Effect |
|------|--------|
| `--animations` | Include the spinner without prompting. |
| `--no-animations` | Omit the spinner without prompting. |
| `--no-claude` | Install the files but don't touch `~/.claude/settings.json` (it prints the block to add yourself). |
| `--width-fix` | Also append a `precmd` to `~/.zshrc` that closes the ~6-char gap on the right edge (see below). |

When stdin isn't a tty (piped/CI) and neither animation flag is given, the spinner is included by default.

## Picking animations

```bash
~/.config/ccstatusline/anim-gallery.sh
```

Animates **all 95 at once** in a paged grid (an `*` marks ones currently in your playlist). Press any
key to page through, `q` to stop and choose. Then type the numbers/ranges you want to **keep**:

```
> 1 4 7-12 30          # keep just these
> all                  # keep everything
> same                 # leave the playlist unchanged
```

It writes `~/.config/ccstatusline/anim-playlist`; the status line picks it up on the next repaint —
no restart. Order in the file doesn't matter: playback is randomized every cycle.

`anim-gallery.sh --list` prints the names + frame counts without the UI.

There's also an older one-at-a-time previewer at `~/.config/ccstatusline/anim-preview.sh`.

## The right-edge gap (optional fix)

ccstatusline's `flexMode: "full"` always leaves a ~6-character gap between the rightmost widget and
the terminal edge. To close it, add this to `~/.zshrc` (or run the installer with `--width-fix`):

```zsh
precmd() { export CCSTATUSLINE_WIDTH=$(( COLUMNS + 6 )); }
```

`COLUMNS` tracks terminal resizes; `+6` cancels the gap (use `+5` to keep one space of breathing room).

## How it works

See [`skill/SKILL.md`](skill/SKILL.md) — the complete reference for the layout, the color gradient,
the stateless time-derived animation engine, the random-order shuffle, and every gotcha encountered
building it. It's written as a Claude Code skill (drop it in `~/.claude/skills/ccstatusline-config/`
if you use Claude Code, and Claude will know how to edit this status line for you), but it reads fine
as plain documentation.

### Files

| Path (after install) | What it is |
|----------------------|------------|
| `~/.config/ccstatusline/settings.json` | The widget layout. |
| `~/.config/ccstatusline/anim-widget.sh` | The animation engine. Stateless; the frame is a pure function of wall-clock time, so every window stays in sync. |
| `~/.config/ccstatusline/anim-frames.txt` | All 95 animation definitions (`[name]` + one frame per line). |
| `~/.config/ccstatusline/anim-playlist` | Which animations are active, one name per line. |
| `~/.config/ccstatusline/anim-gallery.sh` | Live grid picker. |
| `~/.config/ccstatusline/anim-preview.sh` | Sequential picker. |
| `~/.config/ccstatusline/ctx-color.sh` | Context-% widget with gradient color. |
| `~/.config/ccstatusline/session-color.sh` | Session-% widget with gradient color. |
| `~/.config/ccstatusline/wk-color.sh` | Weekly-% widget with gradient color. |
| `~/.config/ccstatusline/gradient-test.sh` | Standalone helper to eyeball the gradient. |

## Uninstall

```bash
# Restore Claude Code's previous settings (or just delete the statusLine block):
mv ~/.claude/settings.json.bak.<timestamp> ~/.claude/settings.json

# Remove the config + binary:
rm -rf ~/.config/ccstatusline ~/.local/share/ccstatusline
```

## Credits

- [ccstatusline](https://github.com/sirmalloc/ccstatusline) by sirmalloc — the rendering engine.
- Spinner frames harvested from [cli-spinners](https://github.com/sindresorhus/cli-spinners)
  by Sindre Sorhus (the dataset behind many terminal spinner galleries), plus custom additions.
