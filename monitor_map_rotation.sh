#!/bin/bash
# Script to monitor mohz.exe log files and shift maplist.txt when a map rotation occurs
# Usage: ./monitor_map_rotation.sh

LOG_DIR="/var/log/mohh-uhs"
MAPLIST="/var/www/mohh-uhs/maplist.txt"

# Ensure UHS_PORT is set to default if not provided
export UHS_PORT=${UHS_PORT:-3668}

# Function to get the maplist.txt line for a given port
get_maplist_line_for_port() {
    local port="$1"
    local idx=$((port - UHS_PORT))
    grep -v '^#' "$MAPLIST" | grep -v '^$' | sed -n "$((idx+1))p"
}

# Function to shift the mapList in a maplist.txt line
shift_maplist() {
    local line="$1"
    local cycled_map="$2"
    # Extract the mapList
    local maplist=$(echo "$line" | grep -oP '(?<=-mapList:)[^ ]+')
    IFS=',' read -ra maps <<< "$maplist"
    idx=-1
    for i in "${!maps[@]}"; do
        map_trimmed=$(echo "${maps[$i]}" | xargs)
        if [[ "$map_trimmed" == "$cycled_map" ]]; then
            idx=$i
            break
        fi
    done
    if [[ $idx -ge 0 ]]; then
        new_maps=()
        for ((j=idx; j<${#maps[@]}; j++)); do
            new_maps+=("${maps[$j]}")
        done
        for ((j=0; j<idx; j++)); do
            new_maps+=("${maps[$j]}")
        done
        new_maplist=$(IFS=, ; echo "${new_maps[*]}")
        new_line=$(echo "$line" | sed "s/-mapList:[^ ]*/-mapList:$new_maplist/")
        echo "$new_line"
    else
        echo "$line"
    fi
}

# Function to check if a port is present in any mapList in maplist.txt
port_in_any_maplist() {
    local port="$1"
    grep -oP '(?<=-mapList:)[^ ]+' "$MAPLIST" | tr ',' '\n' | grep -qx "$port"
}

# Dynamic watcher: monitor new log files as they appear

declare -A tailed_files

echo "[DEBUG] Script started, UHS_PORT=$UHS_PORT, LOG_DIR=$LOG_DIR"

while true; do
    for logfile in "$LOG_DIR"/uhs_instance_*.log; do
        if [ -f "$logfile" ] && [ -z "${tailed_files[$logfile]}" ]; then
            echo "[DEBUG] Launching tail for $logfile"
            tailed_files["$logfile"]=1
            {
                port=$(echo "$logfile" | grep -oE '[0-9]+')
                echo "[DEBUG] [$port] Tail process started for $logfile"
                tail -f "$logfile" 2>/dev/null | while read -r line; do
                    echo "[DEBUG] [$port] Raw line: [$line]"
                    if [[ "$line" == *"Server cycling to map"* ]]; then
                        echo "[DEBUG] [$port] Substring match: $line"
                        mapnum=$(echo "$line" | grep -oE "Server cycling to map '?([0-9]+)'?" | grep -oE "[0-9]+")
                        echo "[DEBUG] [$port] Extracted map number: $mapnum"
                        cycled_map="$mapnum"
                        map_line=$(get_maplist_line_for_port "$port")
                        echo "[DEBUG] [$port] Using maplist line: $map_line"
                        new_map_line=$(shift_maplist "$map_line" "$cycled_map")
                        if [[ "$new_map_line" != "$map_line" ]]; then
                            echo "[DEBUG] [$port] Cycled map found in maplist, updating maplist..."
                            tmpfile=$(mktemp)
                            replaced=0
                            line_num=0
                            while IFS= read -r l; do
                                if [[ $replaced -eq 0 && ! "$l" =~ ^# && ! -z "$l" ]]; then
                                    if [[ $line_num -eq $((port - UHS_PORT)) ]]; then
                                        echo "$new_map_line" >> "$tmpfile"
                                        replaced=1
                                    else
                                        echo "$l" >> "$tmpfile"
                                    fi
                                    ((line_num++))
                                else
                                    echo "$l" >> "$tmpfile"
                                fi
                            done < "$MAPLIST"
                            mv "$tmpfile" "$MAPLIST"
                            echo "[DEBUG] [$port] maplist.txt updated: $new_map_line"
                        else
                            echo "[DEBUG] [$port] Cycled map $cycled_map not in maplist.txt, no update"
                        fi
                    fi
                done
                echo "[DEBUG] [$port] Tail process for $logfile exiting"
            } &
        fi
    done
    sleep 2
done
wait
