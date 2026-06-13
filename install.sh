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
# Flags:
#   --no-claude   skip step 4 (just install files; wire up Claude Code yourself)
#   --width-fix   also append the CCSTATUSLINE_WIDTH precmd to ~/.zshrc (closes the right-edge gap)

set -euo pipefail

CCSTATUSLINE_VERSION="2.2.19"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/ccstatusline"
SHARE_DIR="$HOME/.local/share/ccstatusline"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
BIN_PATH="$SHARE_DIR/node_modules/.bin/ccstatusline"

DO_CLAUDE=1
DO_WIDTH_FIX=0
for arg in "$@"; do
  case "$arg" in
    --no-claude) DO_CLAUDE=0 ;;
    --width-fix) DO_WIDTH_FIX=1 ;;
    *) echo "Unknown flag: $arg" >&2; exit 2 ;;
  esac
done

say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }

# ── Preflight ──
for cmd in node npm jq; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Missing required command: $cmd" >&2; exit 1; }
done

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
say "Installing scripts + animation data into $CONFIG_DIR"
mkdir -p "$CONFIG_DIR"
SCRIPTS="anim-widget.sh anim-gallery.sh anim-preview.sh ctx-color.sh session-color.sh wk-color.sh gradient-test.sh"
DATA="anim-frames.txt"
# anim-playlist is only copied if absent, so a re-run doesn't clobber the user's selection
for f in $SCRIPTS $DATA; do
  [ -f "$REPO_DIR/config/$f" ] || { warn "missing $f in repo — skipping"; continue; }
  if [ -f "$CONFIG_DIR/$f" ] && ! cmp -s "$REPO_DIR/config/$f" "$CONFIG_DIR/$f"; then
    cp "$CONFIG_DIR/$f" "$CONFIG_DIR/$f.bak.$(date +%Y%m%d%H%M%S)"
  fi
  cp "$REPO_DIR/config/$f" "$CONFIG_DIR/$f"
done
chmod +x "$CONFIG_DIR"/*.sh
if [ ! -f "$CONFIG_DIR/anim-playlist" ]; then
  cp "$REPO_DIR/config/anim-playlist" "$CONFIG_DIR/anim-playlist"
  say "  wrote default anim-playlist (all 95 animations)"
else
  say "  kept existing anim-playlist"
fi

# ── 3. ccstatusline settings.json (path-substituted) ──
say "Writing $CONFIG_DIR/settings.json"
if [ -f "$CONFIG_DIR/settings.json" ]; then
  cp "$CONFIG_DIR/settings.json" "$CONFIG_DIR/settings.json.bak.$(date +%Y%m%d%H%M%S)"
fi
sed "s#__CONFIG_DIR__#$CONFIG_DIR#g" "$REPO_DIR/config/settings.json.template" > "$CONFIG_DIR/settings.json"
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
say "Pick animations any time:  $CONFIG_DIR/anim-gallery.sh"
