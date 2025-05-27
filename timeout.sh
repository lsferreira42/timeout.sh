#!/bin/sh

# Portable timeout command implementation
# Works with sh, bash, zsh
# Can be executed as script or sourced as function
# Usage: timeout DURATION COMMAND [args...]

# Show help function
show_help() {
    cat << EOF
Usage: timeout DURATION COMMAND [ARG...]
   or: timeout [OPTION]

Run COMMAND with time limit DURATION.

DURATION can be:
  - A number (seconds): 30
  - With time suffix: 30s, 5m, 2h, 1d
    s = seconds, m = minutes, h = hours, d = days

Options:
  -h, --help         show this help and exit
  -s, --signal       signal to send to command (default: TERM)
  -k, --kill-after   kill process with KILL after this time if still running
  -r, --retry        retry command up to N times on failure (default: 0)
  -i, --retry-interval  wait time between retries (default: 1s)
  -v, --verbose      show retry messages and progress

Exit codes:
  124 if COMMAND timed out
  125 if timeout failed
  126 if COMMAND was found but could not be invoked
  127 if COMMAND was not found
  otherwise, the exit status of COMMAND

Examples:
  timeout 10 sleep 20                    # kill sleep after 10 seconds
  timeout 5m ping google.com             # kill ping after 5 minutes
  timeout --retry 3 30 flaky-command           # retry up to 3 times if fails
  timeout -r 5 -i 2s -v 10 network-test      # retry 5 times with 2s interval, verbose

When sourced into shell:
  source timeout.sh    # makes 'timeout' function available
  timeout 30 command   # use as function
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
        return 1
    fi
    
    # Convert based on suffix
    if [ -z "$suffix" ] || [ "$suffix" = "s" ]; then
        echo "$num"
    elif [ "$suffix" = "m" ]; then
        echo $((num * 60))
    elif [ "$suffix" = "h" ]; then
        echo $((num * 3600))
    elif [ "$suffix" = "d" ]; then
        echo $((num * 86400))
    else
        echo "Error: invalid time suffix '$suffix'" >&2
        return 1
    fi
}

# Cleanup on exit
cleanup_timeout() {
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
    
    # Kill timeout process if running
    if [ -n "$timeout_pid" ] && kill -0 "$timeout_pid" 2>/dev/null; then
        kill "$timeout_pid" 2>/dev/null
    fi
    
    # Remove temp file if exists
    [ -n "$tmp_file" ] && rm -f "$tmp_file" 2>/dev/null
}

# Handle signals
handle_signal() {
    received_signal=1
    cleanup_timeout
    exit 130
}

# Execute single command attempt with timeout
execute_with_timeout() {
    timeout_duration="$1"
    signal="$2"
    kill_after="$3"
    local_received_signal=0
    shift 3
    
    # Create temp file for inter-process communication
    tmp_file=$(mktemp 2>/dev/null || echo "/tmp/timeout_$$_$(date +%s)")
    
    # Local signal handler
    local_handle_signal() {
        local_received_signal=1
        cleanup_timeout
        return 130
    }
    
    # Setup signal handlers
    trap 'local_handle_signal' TERM INT
    
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
        rm -f "$tmp_file" 2>/dev/null
        trap - TERM INT
        return 124
    fi
    
    # If received signal, propagate it
    if [ "$local_received_signal" = "1" ]; then
        rm -f "$tmp_file" 2>/dev/null
        trap - TERM INT
        return 130
    fi
    
    # Cleanup temp file
    rm -f "$tmp_file" 2>/dev/null
    trap - TERM INT
    
    # Return command exit code
    return "$cmd_exit_code"
}

# Main timeout function
timeout_main() {
    # Default variables
    signal="TERM"
    kill_after=""
    timeout_duration=""
    retry_count=0
    retry_interval=1
    verbose=0
    received_signal=0
    cmd_pid=""
    timeout_pid=""
    tmp_file=""
    
    # Process arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_help
                return 0
                ;;
            -s|--signal)
                shift
                if [ -z "$1" ]; then
                    echo "Error: --signal requires an argument" >&2
                    return 125
                fi
                signal="$1"
                ;;
            -k|--kill-after)
                shift
                if [ -z "$1" ]; then
                    echo "Error: --kill-after requires an argument" >&2
                    return 125
                fi
                kill_after=$(parse_duration "$1") || return 125
                ;;
            -r|--retry)
                shift
                if [ -z "$1" ]; then
                    echo "Error: --retry requires an argument" >&2
                    return 125
                fi
                if ! [ "$1" -eq "$1" ] 2>/dev/null || [ "$1" -lt 0 ]; then
                    echo "Error: retry count must be a non-negative integer" >&2
                    return 125
                fi
                retry_count="$1"
                ;;
            -i|--retry-interval)
                shift
                if [ -z "$1" ]; then
                    echo "Error: --retry-interval requires an argument" >&2
                    return 125
                fi
                retry_interval=$(parse_duration "$1") || return 125
                ;;
            -v|--verbose)
                verbose=1
                ;;
            -*)
                echo "Error: unknown option '$1'" >&2
                echo "Try 'timeout --help' for more information." >&2
                return 125
                ;;
            *)
                # First non-option argument is duration
                if [ -z "$timeout_duration" ]; then
                    timeout_duration=$(parse_duration "$1") || return 125
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
        echo "Try 'timeout --help' for more information." >&2
        return 125
    fi
    
    if [ $# -eq 0 ]; then
        echo "Error: no command specified" >&2
        echo "Try 'timeout --help' for more information." >&2
        return 125
    fi
    
    # Execute command with retries
    attempt=0
    max_attempts=$((retry_count + 1))
    last_exit_code=1
    
    while [ "$attempt" -lt "$max_attempts" ]; do
        if [ "$attempt" -gt 0 ]; then
            if [ "$verbose" -eq 1 ]; then
                echo "Retry $attempt/$retry_count after ${retry_interval}s..." >&2
            fi
            sleep "$retry_interval"
        fi
        
        execute_with_timeout "$timeout_duration" "$signal" "$kill_after" "$@"
        last_exit_code=$?
        
        # If command succeeded or timed out, don't retry
        if [ "$last_exit_code" -eq 0 ] || [ "$last_exit_code" -eq 124 ]; then
            cleanup_timeout
            return "$last_exit_code"
        fi
        
        # If received signal, don't retry
        if [ "$last_exit_code" -eq 130 ]; then
            cleanup_timeout
            return "$last_exit_code"
        fi
        
        attempt=$((attempt + 1))
    done
    
    # All retries exhausted
    cleanup_timeout
    return "$last_exit_code"
}

# Check if script is being sourced or executed
# Use a more portable detection method
_timeout_sourced=0

# Check if we're in bash and being sourced
if [ -n "${BASH_VERSION-}" ] && [ "${BASH_SOURCE[0]}" != "${0}" ] 2>/dev/null; then
    _timeout_sourced=1
fi

# Check if we're in zsh and being sourced  
if [ -n "${ZSH_VERSION-}" ]; then
    # Zsh sets ZSH_EVAL_CONTEXT to values like 'toplevel:file' when a file is sourced.
    # Consider the script sourced if the context ends with ':file'.
    case "${ZSH_EVAL_CONTEXT-}" in
        (*:file*) _timeout_sourced=1 ;;
    esac
fi

# Check generic sourcing indicators
if [ "$0" = "sh" ] || [ "$0" = "bash" ] || [ "$0" = "zsh" ] || [ "$0" = "-bash" ] || [ "$0" = "-zsh" ]; then
    _timeout_sourced=1
fi

if [ "$_timeout_sourced" -eq 0 ]; then
    # Being executed as script
    timeout_main "$@"
    exit $?
else
    # Being sourced - define timeout function
    timeout() {
        timeout_main "$@"
    }
    
    # Export function if in bash
    if [ -n "${BASH_VERSION-}" ]; then
        export -f timeout 2>/dev/null || true
    fi
    
    echo "timeout function loaded. Usage: timeout DURATION COMMAND [args...]"
fi