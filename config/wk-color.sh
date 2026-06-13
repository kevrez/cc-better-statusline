#!/bin/bash
DATA=$(cat)
PCT=$(echo "$DATA" | jq -r '.rate_limits.seven_day.used_percentage // empty')
[ -z "$PCT" ] && exit 0
awk -v p="$PCT" '
function lerp(a, b, t) { return int(a + (b-a)*t + 0.5) }
BEGIN {
    if      (p <= 25) { t=(p   )/25; r=lerp( 13,  5,t); g=lerp( 43,178,t); b=lerp(158,146,t) }
    else if (p <= 50) { t=(p-25)/25; r=lerp(  5,240,t); g=lerp(178,203,t); b=lerp(146,  8,t) }
    else if (p <= 75) { t=(p-50)/25; r=lerp(240,245,t); g=lerp(203,122,t); b=lerp(  8,  0,t) }
    else if (p <= 90) { t=(p-75)/15; r=lerp(245,234,t); g=lerp(122, 72,t); b=lerp(  0, 32,t) }
    else              { t=(p-90)/10; r=lerp(234,185,t); g=lerp( 72, 27,t); b=lerp( 32, 27,t) }
    printf "\033[38;2;%d;%d;%dmwk %.1f%%\033[0m", r, g, b, p
}'
