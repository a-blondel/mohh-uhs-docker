#!/bin/bash

if [ -z "$UHS_NAME" ] || [ -z "$UHS_PWD" ] || [ -z "$UHS_ADM_PWD" ] || [ -z "$UHS_LOC" ]; then
    echo "One or more mandatory environment variables are not set"
    exit 1
fi

export UHS_PORT=${UHS_PORT:-3668}

if [ ! -d "/root/.wine" ]; then
   winecfg > /dev/null 2>&1
fi

start_instance() {
    local port="$1"
    shift
    local args=("$@")
    echo "============================================================"
    echo "$(date): Starting instance on port $port with args: ${args[*]}"
    echo "============================================================"

    sleep 5 # wait for the previous instance to start
    wine /var/www/mohh-uhs/mohz.exe \
        -name:"$UHS_NAME" \
        -pwd:"$UHS_PWD" \
        -port:"$port" \
        -adminpwd:"$UHS_ADM_PWD" \
        -logging \
        "${args[@]}" > "/var/log/mohh-uhs/uhs_instance_${port}.log" 2>&1 &
}

port="$UHS_PORT"
line_count=0

while IFS= read -r line || [ -n "$line" ]; do
    if [[ -z "$line" || "$line" == \#* ]]; then
        continue
    fi

    # Replace [LOC] with [$UHS_LOC] in the line if UHS_LOC is set (in memory only)
    localized_line="$line"
    if [ -n "$UHS_LOC" ]; then
        localized_line="${localized_line//\[LOC\]/[${UHS_LOC}]}"
    fi
    # Read the line into an array, handling quoted strings
    eval "args=($localized_line)"

    # Only start instance if not already running for this port
    if ! pgrep -f "mohz.exe.*-port:$port" > /dev/null; then
        start_instance "$port" "${args[@]}"
    fi

    ((port++))
    ((line_count++))
done < "/var/www/mohh-uhs/maplist.txt"

# Calculate the maximum expected port number
max_port=$((UHS_PORT + line_count - 1))

# Stop instances with ports beyond max_port
running_pids=$(pgrep -f "mohz.exe.*-port:")

for pid in $running_pids; do
    if [ -r "/proc/$pid/cmdline" ]; then
        cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline")
        if [[ "$cmdline" =~ -port:([0-9]+) ]]; then
            instance_port="${BASH_REMATCH[1]}"
            if (( instance_port >= UHS_PORT && instance_port > max_port )); then
                echo "$(date): Stopping instance on port $instance_port"
                kill "$pid"
            fi
        fi
    fi
done