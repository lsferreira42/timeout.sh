#!/bin/sh

# Portable timeout command implementation
# Works with sh, bash, zsh
# Usage: timeout.sh <duration> <command> [args...]

# Show help function
show_help() {
    cat << EOF
Usage: timeout.sh DURATION COMMAND [ARG...]
   or: timeout.sh [OPTION]

Run COMMAND with time limit DURATION.

DURATION can be:
  - A number (seconds): 30
  - With time suffix: 30s, 5m, 2h, 1d
    s = seconds, m = minutes, h = hours, d = days

Options:
  -h, --help     show this help and exit
  -s, --signal   signal to send to command (default: TERM)
  -k, --kill-after  kill process with KILL after this time if still running

Exit codes:
  124 if COMMAND timed out
  125 if timeout failed
  126 if COMMAND was found but could not be invoked
  127 if COMMAND was not found
  otherwise, the exit status of COMMAND

Examples:
  timeout.sh 10 sleep 20          # kill sleep after 10 seconds
  timeout.sh 5m ping google.com   # kill ping after 5 minutes
  timeout.sh 1h backup.sh         # kill backup.sh after 1 hour
EOF
}

# Convert duration to seconds
parse_duration() {
    duration="$1"
    
    # If it's already a number, return as is
    if [ "$duration" -eq "$duration" ] 2>/dev/null; then
        echo "$duration"
        return 0
    fi
    
    # Extract number and suffix
    num=$(echo "$duration" | sed 's/[^0-9]*$//')
    suffix=$(echo "$duration" | sed 's/^[0-9]*//')
    
    # Check if number is valid
    if [ -z "$num" ] || ! [ "$num" -eq "$num" ] 2>/dev/null; then
        echo "Error: invalid duration '$duration'" >&2
        exit 125
    fi
    
    # Convert based on suffix
    case "$suffix" in
        "" | "s") echo "$num" ;;
        "m") echo $((num * 60)) ;;
        "h") echo $((num * 3600)) ;;
        "d") echo $((num * 86400)) ;;
        *) 
            echo "Error: invalid time suffix '$suffix'" >&2
            exit 125
            ;;
    esac
}

# Cleanup on exit
cleanup() {
    # Remove signal handlers
    trap - TERM INT
    
    # If command is still running, kill it
    if [ -n "$cmd_pid" ] && kill -0 "$cmd_pid" 2>/dev/null; then
        kill -"$signal" "$cmd_pid" 2>/dev/null
        
        # If kill-after specified, wait and kill with KILL
        if [ -n "$kill_after" ]; then
            sleep "$kill_after"
            if kill -0 "$cmd_pid" 2>/dev/null; then
                kill -KILL "$cmd_pid" 2>/dev/null
            fi
        fi
    fi
    
    # Remove temp file if exists
    [ -n "$tmp_file" ] && rm -f "$tmp_file" 2>/dev/null
}

# Handle signals
handle_signal() {
    received_signal=1
    cleanup
    exit 130
}

# Default variables
signal="TERM"
kill_after=""
timeout_duration=""
received_signal=0
cmd_pid=""
tmp_file=""

# Process arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -s|--signal)
            shift
            if [ -z "$1" ]; then
                echo "Error: --signal requires an argument" >&2
                exit 125
            fi
            signal="$1"
            ;;
        -k|--kill-after)
            shift
            if [ -z "$1" ]; then
                echo "Error: --kill-after requires an argument" >&2
                exit 125
            fi
            kill_after=$(parse_duration "$1")
            ;;
        -*)
            echo "Error: unknown option '$1'" >&2
            echo "Try 'timeout.sh --help' for more information." >&2
            exit 125
            ;;
        *)
            # First non-option argument is duration
            if [ -z "$timeout_duration" ]; then
                timeout_duration=$(parse_duration "$1")
            else
                # Rest are command and arguments
                break
            fi
            ;;
    esac
    shift
done

# Check if we have duration and command
if [ -z "$timeout_duration" ]; then
    echo "Error: duration not specified" >&2
    echo "Try 'timeout.sh --help' for more information." >&2
    exit 125
fi

if [ $# -eq 0 ]; then
    echo "Error: no command specified" >&2
    echo "Try 'timeout.sh --help' for more information." >&2
    exit 125
fi

# Setup signal handlers
trap 'handle_signal' TERM INT

# Create temp file for inter-process communication
tmp_file=$(mktemp 2>/dev/null || echo "/tmp/timeout_$")

# Run command in background
"$@" &
cmd_pid=$!

# Timeout process in background
(
    sleep "$timeout_duration"
    # If we got here, time ran out
    if kill -0 "$cmd_pid" 2>/dev/null; then
        echo "timeout" > "$tmp_file"
        kill -"$signal" "$cmd_pid" 2>/dev/null
        
        # Kill-after if specified
        if [ -n "$kill_after" ]; then
            sleep "$kill_after"
            if kill -0 "$cmd_pid" 2>/dev/null; then
                kill -KILL "$cmd_pid" 2>/dev/null
            fi
        fi
    fi
) &
timeout_pid=$!

# Wait for command to finish or timeout
wait "$cmd_pid" 2>/dev/null
cmd_exit_code=$?

# Kill timeout process if still running
kill "$timeout_pid" 2>/dev/null
wait "$timeout_pid" 2>/dev/null

# Check if timeout occurred
if [ -f "$tmp_file" ] && [ "$(cat "$tmp_file" 2>/dev/null)" = "timeout" ]; then
    cleanup
    exit 124
fi

# If received signal, propagate it
if [ "$received_signal" = "1" ]; then
    cleanup
    exit 130
fi

# Cleanup
cleanup

# Return original command exit code
exit "$cmd_exit_code"