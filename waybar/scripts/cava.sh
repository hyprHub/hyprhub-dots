# ==================================
# Project: hyprhub
# Author: grid
# Description: Hyprland configuration
# ==================================

# !/bin/bash

trap 'exit 0' SIGPIPE SIGTERM SIGINT

config_file="/tmp/waybar_cava_config"

cat > "$config_file" <<EOF
[general]
bars = 18

[input]
method = pipewire

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
EOF

cava -p "$config_file" | while read -r line; do
    text=""

    for n in $(echo "$line" | grep -o '[0-7]'); do
        case $n in
            0) text+="▁" ;;
            1) text+="▂" ;;
            2) text+="▃" ;;
            3) text+="▄" ;;
            4) text+="▅" ;;
            5) text+="▆" ;;
            6) text+="▇" ;;
            7) text+="█" ;;
        esac
    done

    printf '{"text":"%s"}\n' "$text" || exit 0
done

