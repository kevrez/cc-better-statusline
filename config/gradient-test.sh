#!/bin/bash
# 20-step 256-color gradient — starts at dark navy, ends at bright red
printf "256: "
for c in 17 18 19 20 27 33 39 45 51 49 46 82 118 154 226 220 214 208 202 196; do
    printf "\033[38;5;${c}m███\033[0m"
done

printf "\n rgb: "
# 20-step truecolor gradient — dark blue → teal → green → yellow → orange → red
colors=(
    "13;43;158"
    "20;57;184"
    "29;78;216"
    "22;105;204"
    "15;133;187"
    "8;158;169"
    "5;178;146"
    "13;194;116"
    "49;204;79"
    "118;208;48"
    "184;208;0"
    "240;203;8"
    "245;176;0"
    "245;149;0"
    "245;122;0"
    "240;96;16"
    "234;72;32"
    "224;53;48"
    "220;38;38"
    "185;27;27"
)
for rgb in "${colors[@]}"; do
    printf "\033[38;2;${rgb}m███\033[0m"
done
printf "\n"
