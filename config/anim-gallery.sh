#!/bin/bash
# anim-gallery.sh - Animate ALL animations at once in a paged grid, then pick a playlist.
# Run standalone in a terminal: ~/.config/ccstatusline/anim-gallery.sh
#   --list  print parsed animation names and exit (no UI)

export LANG=en_US.UTF-8

FRAMES_FILE="$HOME/.config/ccstatusline/anim-frames.txt"
PLAYLIST_FILE="$HOME/.config/ccstatusline/anim-playlist"

# ── Parse anim-frames.txt into parallel arrays (bash 3.2: no assoc arrays) ──
NAMES=()
ENTRIES=()   # "|"-joined frames per animation
cur=-1
while IFS= read -r line; do
    if [[ "$line" =~ ^\[([A-Za-z0-9]+)\]$ ]]; then
        NAMES+=("${BASH_REMATCH[1]}")
        ENTRIES+=("")
        cur=$(( ${#NAMES[@]} - 1 ))
    elif [[ $cur -ge 0 && -n "$line" && "$line" != '#'* ]]; then
        if [[ -z "${ENTRIES[$cur]}" ]]; then
            ENTRIES[$cur]="$line"
        else
            ENTRIES[$cur]+="|$line"
        fi
    fi
done < "$FRAMES_FILE"
NUM=${#NAMES[@]}

if [[ "$1" == "--list" ]]; then
    for (( i=0; i<NUM; i++ )); do
        IFS='|' read -ra P <<< "${ENTRIES[$i]}"
        printf '%3d %-20s %d frames\n' "$((i+1))" "${NAMES[$i]}" "${#P[@]}"
    done
    exit 0
fi

# ── Current playlist membership (marker in the grid) ──
IN_PLAYLIST=()
for (( i=0; i<NUM; i++ )); do IN_PLAYLIST[$i]=""; done
if [[ -f "$PLAYLIST_FILE" ]]; then
    while IFS= read -r pname; do
        for (( i=0; i<NUM; i++ )); do
            [[ "${NAMES[$i]}" == "$pname" ]] && IN_PLAYLIST[$i]="*"
        done
    done < "$PLAYLIST_FILE"
fi

# ── 144-step gradient (same palette as the statusline) ──
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

# ── Grid geometry ──
TERM_COLS=$(tput cols 2>/dev/null || echo 100)
TERM_ROWS=$(tput lines 2>/dev/null || echo 30)
FRAME_W=12                      # frame display area (widest animation is 12)
CELL_W=$(( 3 + 1 + 1 + 16 + 1 + FRAME_W + 2 ))   # " 95 *name............ frame........  "
GRID_COLS=$(( TERM_COLS / CELL_W ))
[[ $GRID_COLS -lt 1 ]] && GRID_COLS=1
PAGE_ROWS=$(( TERM_ROWS - 6 ))
[[ $PAGE_ROWS -lt 4 ]] && PAGE_ROWS=4
PER_PAGE=$(( GRID_COLS * PAGE_ROWS ))
PAGES=$(( (NUM + PER_PAGE - 1) / PER_PAGE ))

# Key polling: bash 3.2 has no fractional `read -t`, so on a tty we use
# `stty min 0 time 3` + dd as a combined 0.3s frame delay and key poll.
IS_TTY=0
SAVED_STTY=""
if [ -t 0 ]; then
    IS_TTY=1
    SAVED_STTY=$(stty -g)
fi

cleanup() {
    printf '\033[?25h\033[0m\n'
    [[ -n "$SAVED_STTY" ]] && stty "$SAVED_STTY" 2>/dev/null
}
trap cleanup EXIT INT TERM

poll_key() {
    # prints the pressed key (if any) within ~0.3-1s; empty if none
    local k
    if [[ $IS_TTY -eq 1 ]]; then
        k=$(dd bs=1 count=1 2>/dev/null; echo x)   # sentinel keeps whitespace keys
        printf '%s' "${k%x}"
    else
        k=""
        read -t 1 -n1 k 2>/dev/null
        printf '%s' "$k"
    fi
}

draw_page() {
    local page=$1 start=$(( page * PER_PAGE ))
    printf '\033[2J\033[H'
    printf '\033[1mAnimation gallery — page %d/%d  (%d animations, * = in current playlist)\033[0m\n' \
        "$((page+1))" "$PAGES" "$NUM"
    printf 'Any key: next page   q: stop and choose\n\n'
    local i row col
    for (( i=start; i<start+PER_PAGE && i<NUM; i++ )); do
        row=$(( 4 + (i - start) % PAGE_ROWS ))
        col=$(( 1 + ((i - start) / PAGE_ROWS) * CELL_W ))
        printf '\033[%d;%dH\033[2m%3d\033[0m %1s%-16s' \
            "$row" "$col" "$((i+1))" "${IN_PLAYLIST[$i]}" "${NAMES[$i]:0:16}"
    done
}

animate_page() {
    local page=$1 start=$(( page * PER_PAGE )) tick=0
    local i row col fc frame pad key
    while :; do
        for (( i=start; i<start+PER_PAGE && i<NUM; i++ )); do
            IFS='|' read -ra P <<< "${ENTRIES[$i]}"
            fc=${#P[@]}
            frame="${P[$(( tick % fc ))]}"
            pad=$(( FRAME_W - ${#frame} ))
            [[ $pad -lt 0 ]] && pad=0
            row=$(( 4 + (i - start) % PAGE_ROWS ))
            col=$(( 1 + ((i - start) / PAGE_ROWS) * CELL_W + 22 ))
            read -ra rgb <<< "${COLORS[$(( (tick * 2 + i * 9) % 144 ))]}"
            printf '\033[%d;%dH\033[38;2;%d;%d;%dm%s\033[0m%*s' \
                "$row" "$col" "${rgb[0]}" "${rgb[1]}" "${rgb[2]}" "$frame" "$pad" ""
        done
        tick=$(( tick + 1 ))
        key=$(poll_key)
        if [[ -n "$key" ]]; then
            [[ "$key" == "q" || "$key" == "Q" ]] && return 1
            return 0
        fi
    done
}

printf '\033[?25l'
[[ $IS_TTY -eq 1 ]] && stty -echo -icanon min 0 time 3 2>/dev/null
page=0
while [[ $page -lt $PAGES ]]; do
    draw_page "$page"
    animate_page "$page" || break
    page=$(( page + 1 ))
done
printf '\033[?25h\033[2J\033[H'
[[ -n "$SAVED_STTY" ]] && stty "$SAVED_STTY" 2>/dev/null

# ── Selection ──
echo "Pick animations for the playlist."
echo "Enter numbers and/or ranges to KEEP, e.g.:  1 4 7-12 30"
echo "  all          keep everything"
echo "  same         keep current playlist unchanged"
printf "> "
read -r sel

expand_selection() {
    local tok lo hi n
    for tok in $1; do
        if [[ "$tok" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            lo=${BASH_REMATCH[1]}; hi=${BASH_REMATCH[2]}
            for (( n=lo; n<=hi; n++ )); do echo "$n"; done
        elif [[ "$tok" =~ ^[0-9]+$ ]]; then
            echo "$tok"
        fi
    done
}

case "$sel" in
    same|"")
        echo "Playlist unchanged."
        exit 0 ;;
    all)
        KEEP=("${NAMES[@]}") ;;
    *)
        KEEP=()
        for n in $(expand_selection "$sel" | sort -nu); do
            idx=$(( n - 1 ))
            [[ $idx -ge 0 && $idx -lt $NUM ]] && KEEP+=("${NAMES[$idx]}")
        done
        if [[ ${#KEEP[@]} -eq 0 ]]; then
            echo "No valid selections — playlist unchanged."
            exit 0
        fi ;;
esac

printf '%s\n' "${KEEP[@]}" > "$PLAYLIST_FILE"
echo "Saved ${#KEEP[@]} animation(s) to $PLAYLIST_FILE"
echo "Takes effect on the next statusline render — no restart needed."
