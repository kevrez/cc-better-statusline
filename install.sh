#!/usr/bin/env bash
# install.sh — set up the cc-better-statusline (animated, color-gradient ccstatusline)
#
# Idempotent. Safe to re-run. Backs up anything it overwrites.
#
# What it does:
#   1. Installs the pinned ccstatusline binary into ~/.local/share/ccstatusline
#   2. Copies the scripts + animation data into ~/.config/ccstatusline (paths rewritten to your $HOME)
#   3. Writes ~/.config/ccstatusline/settings.json (the widget layout)
#   4. Merges the statusLine block into ~/.claude/settings.json (preserving your other settings)
#
# Animations are opt-in: the installer shows a live braille preview and asks
# whether to include the animated spinner. Decline and you get the same layout
# without the spinner (and its files aren't installed).
#
# Flags:
#   --no-claude        skip step 4 (just install files; wire up Claude Code yourself)
#   --width-fix        also append the CCSTATUSLINE_WIDTH precmd to ~/.zshrc (closes the right-edge gap)
#   --animations       include the animated spinner without prompting
#   --no-animations    omit the animated spinner without prompting
# (When stdin isn't a tty and neither flag is given, the spinner is included.)

set -euo pipefail

CCSTATUSLINE_VERSION="2.2.19"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/ccstatusline"
SHARE_DIR="$HOME/.local/share/ccstatusline"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
BIN_PATH="$SHARE_DIR/node_modules/.bin/ccstatusline"

DO_CLAUDE=1
DO_WIDTH_FIX=0
ANIM_CHOICE=""   # "", "yes", or "no" — empty means prompt (or default when non-tty)
for arg in "$@"; do
  case "$arg" in
    --no-claude) DO_CLAUDE=0 ;;
    --width-fix) DO_WIDTH_FIX=1 ;;
    --animations) ANIM_CHOICE="yes" ;;
    --no-animations) ANIM_CHOICE="no" ;;
    *) echo "Unknown flag: $arg" >&2; exit 2 ;;
  esac
done

say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }

# Ask whether to include the animated spinner, showing a live braille preview
# while waiting. Returns 0 (include) or 1 (omit). bash 3.2 compatible: uses
# `stty min 0 time N` + `dd` as a combined frame delay and non-blocking key poll
# (macOS bash has no fractional `read -t`).
prompt_animations() {
  [ "$ANIM_CHOICE" = "yes" ] && return 0
  [ "$ANIM_CHOICE" = "no" ] && return 1
  if [ ! -t 0 ] || [ ! -t 1 ]; then
    say "Non-interactive shell — including the animated spinner (use --no-animations to omit)."
    return 0
  fi

  local frames="⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏"
  # A short navy→teal→yellow→orange→red→… loop echoing the status line's gradient.
  local colors="13,43,158 8,122,151 5,178,146 123,191,77 240,203,8 244,132,1 245,122,0 234,72,32 185,27,27 234,72,32 245,122,0 240,203,8"
  local FR=() CO=()
  FR=($frames); CO=($colors)
  local nf=${#FR[@]} nc=${#CO[@]} i=0 key="" saved rgb f
  saved=$(stty -g 2>/dev/null)
  stty -echo -icanon min 0 time 2 2>/dev/null   # time 2 = 0.2s per frame
  printf '\n'
  while :; do
    f="${FR[$((i % nf))]}"
    IFS=',' read -r -a rgb <<< "${CO[$((i % nc))]}"
    printf '\r  \033[38;2;%d;%d;%dm%s\033[0m  Include the animated spinner? [Y/n] ' \
      "${rgb[0]}" "${rgb[1]}" "${rgb[2]}" "$f"
    key=$(dd bs=1 count=1 2>/dev/null; echo x); key="${key%x}"
    [ -n "$key" ] && break
    i=$((i + 1))
  done
  [ -n "$saved" ] && stty "$saved" 2>/dev/null
  printf '\n'
  case "$key" in
    n|N) return 1 ;;
    *)   return 0 ;;   # Enter / y / Y / anything else -> include
  esac
}

# ── Preflight ──
for cmd in node npm jq; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Missing required command: $cmd" >&2; exit 1; }
done

# ── Animation choice (live preview prompt) ──
if prompt_animations; then INCLUDE_ANIM=1; else INCLUDE_ANIM=0; fi
if [ "$INCLUDE_ANIM" -eq 1 ]; then
  say "Animated spinner: included"
else
  say "Animated spinner: omitted (static status line)"
fi

# ── 1. Pinned ccstatusline binary ──
say "Installing ccstatusline@$CCSTATUSLINE_VERSION into $SHARE_DIR"
mkdir -p "$SHARE_DIR"
if [ -x "$BIN_PATH" ] && \
   [ "$(cat "$SHARE_DIR/node_modules/ccstatusline/package.json" 2>/dev/null | jq -r '.version' 2>/dev/null)" = "$CCSTATUSLINE_VERSION" ]; then
  say "  already at $CCSTATUSLINE_VERSION — skipping"
else
  ( cd "$SHARE_DIR" && npm install --no-save --no-audit --no-fund "ccstatusline@$CCSTATUSLINE_VERSION" >/dev/null )
fi
[ -x "$BIN_PATH" ] || { echo "ccstatusline binary not found at $BIN_PATH after install" >&2; exit 1; }

# ── 2. Scripts + data into ~/.config/ccstatusline ──
say "Installing scripts into $CONFIG_DIR"
mkdir -p "$CONFIG_DIR"
# Color/gradient widgets are always installed; the animation files only when opted in.
CORE_FILES="ctx-color.sh session-color.sh wk-color.sh gradient-test.sh"
ANIM_FILES="anim-widget.sh anim-gallery.sh anim-preview.sh anim-frames.txt"
COPY_FILES="$CORE_FILES"
[ "$INCLUDE_ANIM" -eq 1 ] && COPY_FILES="$CORE_FILES $ANIM_FILES"
for f in $COPY_FILES; do
  [ -f "$REPO_DIR/config/$f" ] || { warn "missing $f in repo — skipping"; continue; }
  if [ -f "$CONFIG_DIR/$f" ] && ! cmp -s "$REPO_DIR/config/$f" "$CONFIG_DIR/$f"; then
    cp "$CONFIG_DIR/$f" "$CONFIG_DIR/$f.bak.$(date +%Y%m%d%H%M%S)"
  fi
  cp "$REPO_DIR/config/$f" "$CONFIG_DIR/$f"
done
chmod +x "$CONFIG_DIR"/*.sh
if [ "$INCLUDE_ANIM" -eq 1 ]; then
  # anim-playlist is only copied if absent, so a re-run doesn't clobber the user's selection
  if [ ! -f "$CONFIG_DIR/anim-playlist" ]; then
    cp "$REPO_DIR/config/anim-playlist" "$CONFIG_DIR/anim-playlist"
    say "  wrote default anim-playlist (all 95 animations)"
  else
    say "  kept existing anim-playlist"
  fi
fi

# ── 3. ccstatusline settings.json (path-substituted) ──
say "Writing $CONFIG_DIR/settings.json"
if [ -f "$CONFIG_DIR/settings.json" ]; then
  cp "$CONFIG_DIR/settings.json" "$CONFIG_DIR/settings.json.bak.$(date +%Y%m%d%H%M%S)"
fi
sed "s#__CONFIG_DIR__#$CONFIG_DIR#g" "$REPO_DIR/config/settings.json.template" > "$CONFIG_DIR/settings.json"
if [ "$INCLUDE_ANIM" -eq 0 ]; then
  # Drop the spinner widget and its trailing separator; the line then starts with git info.
  tmp="$(mktemp)"
  jq '.lines[0] |= map(select(.id != "anim" and .id != "anim-sep"))' \
    "$CONFIG_DIR/settings.json" > "$tmp" && mv "$tmp" "$CONFIG_DIR/settings.json"
fi
# Validate the result is well-formed JSON
jq empty "$CONFIG_DIR/settings.json" || { echo "Generated settings.json is invalid JSON" >&2; exit 1; }

# ── 4. Wire up Claude Code ──
if [ "$DO_CLAUDE" -eq 1 ]; then
  say "Merging statusLine block into $CLAUDE_SETTINGS"
  mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
  [ -f "$CLAUDE_SETTINGS" ] || echo '{}' > "$CLAUDE_SETTINGS"
  jq empty "$CLAUDE_SETTINGS" 2>/dev/null || { echo "$CLAUDE_SETTINGS is not valid JSON — fix or move it first" >&2; exit 1; }
  cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
  tmp="$(mktemp)"
  jq --arg bin "$BIN_PATH" '
    .statusLine = {
      "type": "command",
      "command": $bin,
      "padding": 0,
      "refreshInterval": 1
    }
  ' "$CLAUDE_SETTINGS" > "$tmp" && mv "$tmp" "$CLAUDE_SETTINGS"
  say "  statusLine wired to $BIN_PATH"
else
  say "Skipping Claude Code wiring (--no-claude). Add this to $CLAUDE_SETTINGS yourself:"
  cat <<EOF
  "statusLine": {
    "type": "command",
    "command": "$BIN_PATH",
    "padding": 0,
    "refreshInterval": 1
  }
EOF
fi

# ── Optional: right-edge gap fix ──
if [ "$DO_WIDTH_FIX" -eq 1 ]; then
  ZSHRC="$HOME/.zshrc"
  if grep -q 'CCSTATUSLINE_WIDTH' "$ZSHRC" 2>/dev/null; then
    say "CCSTATUSLINE_WIDTH already present in $ZSHRC — skipping width fix"
  else
    say "Appending CCSTATUSLINE_WIDTH precmd to $ZSHRC"
    cat >> "$ZSHRC" <<'EOF'

# cc-better-statusline: close the ~6-char right-edge gap (flexMode "full")
precmd() { export CCSTATUSLINE_WIDTH=$(( COLUMNS + 6 )); }
EOF
    say "  open a new shell (or 'source ~/.zshrc') to apply"
  fi
fi

# ── Smoke test ──
say "Smoke test (synthetic render):"
NOW=$(date +%s)
printf '{"workspace":{"current_dir":"%s"},"cost":{"total_cost_usd":1.23},"context_window":{"total_input_tokens":30000,"total_output_tokens":4000,"context_window_size":200000},"rate_limits":{"five_hour":{"used_percentage":41.2,"resets_at":%s},"seven_day":{"used_percentage":12.3,"resets_at":%s}}}' \
  "$HOME" "$((NOW+9000))" "$((NOW+280000))" | CCSTATUSLINE_WIDTH=110 "$BIN_PATH" || true
echo
say "Done. Restart Claude Code (or wait for the next repaint) to see the new status line."
if [ "$INCLUDE_ANIM" -eq 1 ]; then
  say "Pick animations any time:  $CONFIG_DIR/anim-gallery.sh"
else
  say "Want the animated spinner later? Re-run with --animations."
fi
