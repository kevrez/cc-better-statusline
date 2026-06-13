#!/bin/bash
# anim-widget.sh - Stateless animation widget for ccstatusline.
#
# The displayed frame is a pure function of wall-clock time:
#   cycle = epoch / total_ticks   -> seeds a Fisher-Yates shuffle of the
#                                    animation order (LCG PRNG, pure arithmetic)
#   pos   = epoch % total_ticks   -> position within the shuffled cycle
#   color = epoch % 144           -> gradient step
#
# Every cycle plays each playlist animation exactly once, in a pseudo-random
# order that changes every cycle. No state file, no daemon, no inter-instance
# coordination: every Claude Code instance computes the same permutation from
# the same clock, so all windows stay in sync, and a missed repaint can only
# land on a later frame — never jump back.
#
# Schedule cache format (/tmp/ccstatusline-anim-schedule):
#   line 1: signature header (magic + input-file mtimes)
#   line 2: "seg <len> <len> ..." — ticks per animation, playlist order
#   line 3+: one display string per tick, segments in playlist order
# Rebuilt whenever the header doesn't exactly match the current mtimes of
# anim-frames.txt, anim-playlist, and this script — covering edits, restores
# to older versions, and missing/corrupt/truncated cache files alike.
#
# Test hook: ANIM_EPOCH=<n> overrides the clock for deterministic output.

export LANG=en_US.UTF-8

cat > /dev/null  # consume stdin (required by ccstatusline)

CONFIG_DIR="$HOME/.config/ccstatusline"
FRAMES_FILE="$CONFIG_DIR/anim-frames.txt"
PLAYLIST_FILE="$CONFIG_DIR/anim-playlist"
CACHE="/tmp/ccstatusline-anim-schedule"

# Cache validity signature: magic + input-file mtimes. Stored as the cache's
# first line; any mismatch (edited inputs, foreign/corrupt content) -> rebuild.
SIG="ccanim2 $(stat -f %m "$HOME/.config/ccstatusline/anim-frames.txt" "$HOME/.config/ccstatusline/anim-playlist" "$0" 2>/dev/null | tr '\n' ' ')"

# ── 144-step gradient: navy→teal→yellow→orange→red-orange→dark red→navy ──
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

now=${ANIM_EPOCH:-$(date +%s)}

# Last-resort render when no schedule can be built (e.g. frames file missing):
# a static frame that still color-cycles, so the line never goes blank.
render_static_fallback() {
    local rgb
    read -ra rgb <<< "${COLORS[$(( now % 144 ))]}"
    printf '\033[38;2;%d;%d;%dm⠋\033[0m' "${rgb[0]}" "${rgb[1]}" "${rgb[2]}"
    exit 0
}

# ── Schedule builder ──
# Flattens the playlist into one display string per tick:
#   expand: first frame sliced to widths 1..w-1 (only when the first frame is wide)
#   play:   ceil(5/frame_count) full cycles — whole cycles, minimum ~5 ticks,
#           always ending on the last frame
#   narrow: last frame sliced to widths w-1..1 (only when the last frame is wide)
# Pure bash string ops: ${#s} and ${s:0:n} count characters under the UTF-8
# locale, so no awk/cut forks are needed. bash 3.2 compatible (no mapfile,
# no associative arrays).
build_schedule() {
    local line cur=-1
    local SEC_NAMES=() SEC_FRAMES=()

    [[ -f "$FRAMES_FILE" ]] || return
    while IFS= read -r line; do
        if [[ "$line" =~ ^\[([A-Za-z0-9]+)\]$ ]]; then
            SEC_NAMES+=("${BASH_REMATCH[1]}")
            SEC_FRAMES+=("")
            cur=$(( ${#SEC_NAMES[@]} - 1 ))
        elif [[ $cur -ge 0 && -n "$line" && "$line" != '#'* ]]; then
            if [[ -n "${SEC_FRAMES[$cur]}" ]]; then
                SEC_FRAMES[$cur]+="|${line}"
            else
                SEC_FRAMES[$cur]="$line"
            fi
        fi
    done < "$FRAMES_FILE"

    local PLAYLIST=()
    if [[ -f "$PLAYLIST_FILE" ]]; then
        while IFS= read -r line; do
            [[ -n "$line" && "$line" != '#'* ]] && PLAYLIST+=("$line")
        done < "$PLAYLIST_FILE"
    fi
    [[ ${#PLAYLIST[@]} -eq 0 ]] && PLAYLIST=("${SEC_NAMES[@]}")

    local out="" segs="" ticks name entry i j w fc P first last fw lw
    local F=()
    for name in "${PLAYLIST[@]}"; do
        # Linear lookup; playlist names with no frames section are skipped
        entry=""
        for (( i=0; i<${#SEC_NAMES[@]}; i++ )); do
            [[ "${SEC_NAMES[$i]}" == "$name" ]] && { entry="${SEC_FRAMES[$i]}"; break; }
        done
        [[ -z "$entry" ]] && continue

        IFS='|' read -ra F <<< "$entry"
        fc=${#F[@]}
        first="${F[0]}"
        last="${F[fc-1]}"
        fw=${#first}
        lw=${#last}
        ticks=0

        if (( fw > 1 )); then
            for (( w=1; w<fw; w++ )); do
                out+="${first:0:w}"$'\n'
            done
            ticks=$(( ticks + fw - 1 ))
        fi

        P=$(( ( (5 + fc - 1) / fc ) * fc ))
        for (( j=0; j<P; j++ )); do
            out+="${F[j % fc]}"$'\n'
        done
        ticks=$(( ticks + P ))

        if (( lw > 1 )); then
            for (( w=lw-1; w>=1; w-- )); do
                out+="${last:0:w}"$'\n'
            done
            ticks=$(( ticks + lw - 1 ))
        fi

        segs+=" $ticks"
    done

    [[ -z "$out" ]] && return

    # Atomic publish: identical deterministic content regardless of which
    # concurrent builder wins the mv. Stale tmps from killed builds are
    # cleaned up here rather than accumulating.
    rm -f "${CACHE}".*.tmp 2>/dev/null
    local tmp="${CACHE}.${$}.tmp"
    printf '%s\nseg%s\n%s' "$SIG" "$segs" "$out" > "$tmp" && mv "$tmp" "$CACHE" 2>/dev/null
}

# ── Cache metadata: header + segment lengths ──
# Sets LENS (ticks per segment, playlist order) and T (total ticks).
# Returns nonzero if the cache is missing, foreign, or malformed.
read_cache_meta() {
    local hdr="" segline="" L
    [[ -s "$CACHE" ]] || return 1
    { IFS= read -r hdr; IFS= read -r segline; } < "$CACHE"
    [[ "$hdr" == "$SIG" ]] || return 1
    [[ "$segline" =~ ^seg( [0-9]+)+$ ]] || return 1
    LENS=(${segline#seg })
    T=0
    for L in "${LENS[@]}"; do T=$(( T + L )); done
    (( T > 0 )) || return 1
}

# ── Random playback order, derived purely from the clock ──
# cycle = now / T seeds a Fisher-Yates shuffle (LCG PRNG); pos = now % T is
# walked through the shuffled segments to find the cache line for this tick.
# Every cycle plays each animation exactly once in a fresh order, and all
# instances compute the identical permutation for the same moment.
compute_lineno() {
    local n=${#LENS[@]} cycle=$(( now / T )) pos=$(( now % T ))
    local i j x t s L acc=0 off=0 m
    local ORDER=()
    for (( i=0; i<n; i++ )); do ORDER[i]=$i; done
    x=$(( (cycle * 2654435761 + 1013904223) & 0x7FFFFFFF ))
    for (( i=n-1; i>0; i-- )); do
        x=$(( (x * 1103515245 + 12345) & 0x7FFFFFFF ))
        j=$(( x % (i + 1) ))
        t=${ORDER[i]}; ORDER[i]=${ORDER[j]}; ORDER[j]=$t
    done
    for (( i=0; i<n; i++ )); do
        s=${ORDER[i]}
        L=${LENS[s]}
        if (( pos < acc + L )); then
            off=0
            for (( m=0; m<s; m++ )); do off=$(( off + LENS[m] )); done
            lineno=$(( off + pos - acc + 3 ))   # +3: header, seg line, 1-based
            return 0
        fi
        acc=$(( acc + L ))
    done
    return 1
}

# ── Rebuild cache when inputs change or cache is missing/invalid ──
LENS=()
T=0
if ! read_cache_meta; then
    build_schedule
    read_cache_meta || render_static_fallback
fi

compute_lineno || render_static_fallback
frame=$(sed -n "${lineno}p" "$CACHE")
if [[ -z "$frame" ]]; then
    # Truncated cache (e.g. a build killed mid-write survived the header check):
    # rebuild once and retry, else fall back
    build_schedule
    read_cache_meta || render_static_fallback
    compute_lineno || render_static_fallback
    frame=$(sed -n "${lineno}p" "$CACHE")
    [[ -n "$frame" ]] || render_static_fallback
fi

read -ra rgb <<< "${COLORS[$(( now % 144 ))]}"
printf '\033[38;2;%d;%d;%dm%s\033[0m' "${rgb[0]}" "${rgb[1]}" "${rgb[2]}" "$frame"
