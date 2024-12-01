#!/bin/bash

if [ -z "$UHS_NAME" ] || [ -z "$UHS_PWD" ] || [ -z "$UHS_ADM_PWD" ]; then
    echo "One or more mandatory environment variables are not set"
    exit 1
fi

export UHS_PORT=${UHS_PORT:-3658}

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
        "${args[@]}" &
}

check_instance() {
    local port="$1"
    shift
    local expected_args=("$@")

    # Find PIDs of mohz.exe processes with the given port
    local pids
    pids=$(pgrep -f "mohz.exe.*-port:$port")

    if [ -z "$pids" ]; then
        return 1
    fi

    for pid in $pids; do
        # Read the command line arguments from /proc
        if [ -r "/proc/$pid/cmdline" ]; then
            local cmdline
            cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline")

            # Check if all expected arguments are present
            local mismatch=0
            for arg in "${expected_args[@]}"; do
                if ! echo "$cmdline" | grep -Fq -- "$arg"; then
                    mismatch=1
                    break
                fi
            done

            if [ "$mismatch" -eq 0 ]; then
                # Found a matching process
                return 0
            fi
        fi
    done

    # No matching process found, kill any processes with that port
    echo "$(date): Arguments mismatch for port $port, stopping..."
    pkill -f -- "mohz.exe.*-port:$port"
    return 1
}

port="$UHS_PORT"
line_count=0

while IFS= read -r line || [ -n "$line" ]; do
    if [[ -z "$line" || "$line" == \#* ]]; then
        continue
    fi

    # Read the line into an array, handling quoted strings
    eval "args=($line)"

    if ! check_instance "$port" "${args[@]}"; then
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