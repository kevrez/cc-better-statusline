#!/bin/bash
# anim-preview.sh - Preview all animations and choose which to include in the playlist.
# Run standalone in a terminal: ~/.config/ccstatusline/anim-preview.sh

export LANG=en_US.UTF-8

PLAYLIST_FILE="$HOME/.config/ccstatusline/anim-playlist"

# ── Animation frames read from anim-frames.txt ──
FRAMES_FILE="$HOME/.config/ccstatusline/anim-frames.txt"

get_entry() {
    local name="$1" in_anim=false result=""
    [[ ! -f "$FRAMES_FILE" ]] && return
    while IFS= read -r line; do
        if [[ "$line" =~ ^\[([A-Za-z0-9]+)\]$ ]]; then
            [[ "$in_anim" == true ]] && break
            if [[ "${BASH_REMATCH[1]}" == "$name" ]]; then
                in_anim=true; result="${name}"
            fi
        elif [[ "$in_anim" == true && -n "$line" && "$line" != '#'* ]]; then
            result+="|${line}"
        fi
    done < "$FRAMES_FILE"
    printf '%s' "$result"
}

ALL_NAMES=()
if [[ -f "$FRAMES_FILE" ]]; then
    while IFS= read -r line; do
        [[ "$line" =~ ^\[([A-Za-z0-9]+)\]$ ]] && ALL_NAMES+=("${BASH_REMATCH[1]}")
    done < "$FRAMES_FILE"
fi

# ── 144-step gradient colors ──
COLORS=(
    "13 43 158"   "13 49 158"   "12 54 157"   "12 60 157"   "12 66 156"   "11 71 156"
    "11 77 155"   "11 82 155"   "10 88 154"   "10 94 154"   "10 99 153"   "9 105 153"
    "9 111 152"   "9 116 152"   "8 122 151"   "8 127 151"   "8 133 150"   "7 139 150"
    "7 144 149"   "7 150 149"   "6 156 148"   "6 161 148"   "6 167 147"   "5 172 147"
    "5 178 146"   "15 179 140"  "25 180 135"  "34 181 129"  "44 182 123"  "54 183 117"
    "64 184 112"  "74 185 106"  "83 186 100"  "93 187 94"   "103 188 89"  "113 189 83"
    "123 191 77"  "132 192 71"  "142 193 66"  "152 194 60"  "162 195 54"  "171 196 48"
    "181 197 43"  "191 198 37"  "201 199 31"  "211 200 25"  "220 201 20"  "230 202 14"
    "240 203 8"   "240 200 8"   "240 196 7"   "241 193 7"   "241 190 7"   "241 186 6"
    "241 183 6"   "241 179 6"   "242 176 5"   "242 173 5"   "242 169 5"   "242 166 4"
    "243 163 4"   "243 159 4"   "243 156 3"   "243 152 3"   "243 149 3"   "244 146 2"
    "244 142 2"   "244 139 2"   "244 136 1"   "244 132 1"   "245 129 1"   "245 125 0"
    "245 122 0"   "245 120 1"   "244 118 3"   "244 116 4"   "243 114 5"   "243 112 7"
    "242 110 8"   "242 107 9"   "241 105 11"  "241 103 12"  "240 101 13"  "240 99 15"
    "240 97 16"   "239 95 17"   "239 93 19"   "238 91 20"   "238 89 21"   "237 87 23"
    "237 85 24"   "236 82 25"   "236 80 27"   "235 78 28"   "235 76 29"   "234 74 31"
    "234 72 32"   "232 70 32"   "230 68 32"   "228 66 31"   "226 65 31"   "224 63 31"
    "222 61 31"   "220 59 31"   "218 57 30"   "216 55 30"   "214 53 30"   "212 51 30"
    "210 50 30"   "207 48 29"   "205 46 29"   "203 44 29"   "201 42 29"   "199 40 28"
    "197 38 28"   "195 36 28"   "193 35 28"   "191 33 28"   "189 31 27"   "187 29 27"
    "185 27 27"   "178 28 32"   "171 28 38"   "164 29 43"   "156 30 49"   "149 30 54"
    "142 31 60"   "135 32 65"   "128 32 71"   "121 33 76"   "113 34 82"   "106 34 87"
    "99 35 93"    "92 36 98"    "85 36 103"   "78 37 109"   "70 38 114"   "63 38 120"
    "56 39 125"   "49 40 131"   "42 40 136"   "35 41 142"   "27 42 147"   "20 42 153"
)

# ── Speed selection ──
echo ""
echo "Preview speed:"
echo "  [1] 0.25s/frame   [2] 0.5s/frame   [3] 1s/frame   [4] 2s/frame"
printf "Enter choice (default 2): "
read -r speed_choice
case "$speed_choice" in
    1) DELAY=0.25 ;;
    3) DELAY=1 ;;
    4) DELAY=2 ;;
    *) DELAY=0.5 ;;
esac

# ── Preview each animation ──
echo ""
echo "Previewing ${#ALL_NAMES[@]} animations (Ctrl+C to stop preview early)..."
echo ""

NUM=${#ALL_NAMES[@]}
color_step=0

for (( i=0; i<NUM; i++ )); do
    name="${ALL_NAMES[$i]}"
    entry=$(get_entry "$name")
    IFS='|' read -ra P <<< "$entry"
    fc=$(( ${#P[@]} - 1 ))

    # Show enough frames for ~2 full cycles, capped at 20 frames
    total_frames=$(( fc * 2 ))
    [[ $total_frames -gt 20 ]] && total_frames=20
    [[ $total_frames -lt 8 ]] && total_frames=8

    label=$(printf "[%2d/%d] %-14s" "$((i+1))" "$NUM" "$name")

    for (( f=0; f<total_frames; f++ )); do
        frame="${P[$((f % fc + 1))]}"
        read -ra rgb <<< "${COLORS[$color_step]}"
        printf "\r%s \033[38;2;%d;%d;%dm%s\033[0m   " \
            "$label" "${rgb[0]}" "${rgb[1]}" "${rgb[2]}" "$frame"
        color_step=$(( (color_step + 1) % 144 ))
        sleep "$DELAY"
    done
    echo ""
done

# ── Selection ──
echo ""
echo "────────────────────────────────────────"
for (( i=0; i<NUM; i++ )); do
    printf "  %2d  %s\n" "$((i+1))" "${ALL_NAMES[$i]}"
done
echo ""
printf "Enter numbers to REMOVE (space-separated), or press Enter to keep all: "
read -r remove_input

# Build new playlist
KEEP=()
for (( i=0; i<NUM; i++ )); do
    keep=true
    for n in $remove_input; do
        if [[ "$n" =~ ^[0-9]+$ ]] && [[ "$n" -eq "$((i+1))" ]]; then
            keep=false
            break
        fi
    done
    $keep && KEEP+=("${ALL_NAMES[$i]}")
done

if [[ ${#KEEP[@]} -eq 0 ]]; then
    echo "No animations selected — keeping all."
    KEEP=("${ALL_NAMES[@]}")
fi

printf '%s\n' "${KEEP[@]}" > "$PLAYLIST_FILE"
echo "Saved ${#KEEP[@]} animation(s) to $PLAYLIST_FILE"
echo ""
echo "Reload the daemon to apply:"
echo "  kill \$(cat /tmp/ccstatusline-anim.pid 2>/dev/null) ; ~/.config/ccstatusline/anim-daemon.sh &"
