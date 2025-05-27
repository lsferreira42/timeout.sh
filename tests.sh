#!/bin/sh

# Comprehensive test suite for timeout.sh
# Tests all options and edge cases

# Colors for output (if terminal supports it)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Timeout script path
TIMEOUT_SCRIPT="./timeout.sh"

# Helper functions
print_header() {
    echo
    echo "${BLUE}=== $1 ===${NC}"
    echo
}

print_test() {
    echo "${YELLOW}Test $((TESTS_RUN + 1)): $1${NC}"
}

print_pass() {
    echo "${GREEN}✓ PASS${NC}: $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_fail() {
    echo "${RED}✗ FAIL${NC}: $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

run_test() {
    TESTS_RUN=$((TESTS_RUN + 1))
}

# Test if timeout script exists
check_timeout_script() {
    if [ ! -f "$TIMEOUT_SCRIPT" ]; then
        echo "${RED}Error: $TIMEOUT_SCRIPT not found${NC}"
        echo "Please ensure timeout.sh is in the current directory"
        exit 1
    fi
    
    if [ ! -x "$TIMEOUT_SCRIPT" ]; then
        echo "Making $TIMEOUT_SCRIPT executable..."
        chmod +x "$TIMEOUT_SCRIPT"
    fi
}

# Test basic functionality
test_basic_functionality() {
    print_header "Basic Functionality Tests"
    
    # Test 1: Help option
    print_test "Help option --help"
    run_test
    if $TIMEOUT_SCRIPT --help >/dev/null 2>&1; then
        print_pass "Help option works"
    else
        print_fail "Help option failed"
    fi
    
    # Test 2: Help option -h
    print_test "Help option -h"
    run_test
    if $TIMEOUT_SCRIPT -h >/dev/null 2>&1; then
        print_pass "Short help option works"
    else
        print_fail "Short help option failed"
    fi
    
    # Test 3: Basic timeout (command should succeed)
    print_test "Basic timeout with successful command"
    run_test
    if $TIMEOUT_SCRIPT 5 echo "hello" >/dev/null 2>&1; then
        print_pass "Basic successful command works"
    else
        print_fail "Basic successful command failed"
    fi
    
    # Test 4: Basic timeout (command should timeout)
    print_test "Basic timeout with slow command"
    run_test
    start_time=$(date +%s)
    $TIMEOUT_SCRIPT 2 sleep 10 >/dev/null 2>&1
    exit_code=$?
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    if [ $exit_code -eq 124 ] && [ $duration -ge 2 ] && [ $duration -le 4 ]; then
        print_pass "Timeout works correctly (exit code 124, ~2s duration)"
    else
        print_fail "Timeout failed (exit code: $exit_code, duration: ${duration}s)"
    fi
}

# Test duration parsing
test_duration_parsing() {
    print_header "Duration Parsing Tests"
    
    # Test seconds
    print_test "Duration parsing - seconds"
    run_test
    if $TIMEOUT_SCRIPT 1 echo "test" >/dev/null 2>&1; then
        print_pass "Plain seconds work"
    else
        print_fail "Plain seconds failed"
    fi
    
    print_test "Duration parsing - seconds with 's' suffix"
    run_test
    if $TIMEOUT_SCRIPT 1s echo "test" >/dev/null 2>&1; then
        print_pass "Seconds with 's' suffix work"
    else
        print_fail "Seconds with 's' suffix failed"
    fi
    
    # Test minutes (quick test - 1m = 60s, test with very short sleep)
    print_test "Duration parsing - minutes"
    run_test
    start_time=$(date +%s)
    $TIMEOUT_SCRIPT 1m sleep 2 >/dev/null 2>&1
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    if [ $duration -ge 2 ] && [ $duration -le 4 ]; then
        print_pass "Minutes parsing works (command completed normally)"
    else
        print_fail "Minutes parsing may have issues"
    fi
    
    # Test invalid duration
    print_test "Duration parsing - invalid duration"
    run_test
    if ! $TIMEOUT_SCRIPT abc echo "test" >/dev/null 2>&1; then
        print_pass "Invalid duration properly rejected"
    else
        print_fail "Invalid duration was accepted"
    fi
    
    # Test invalid suffix
    print_test "Duration parsing - invalid suffix"
    run_test
    if ! $TIMEOUT_SCRIPT 5x echo "test" >/dev/null 2>&1; then
        print_pass "Invalid suffix properly rejected"
    else
        print_fail "Invalid suffix was accepted"
    fi
}

# Test signal options
test_signal_options() {
    print_header "Signal Options Tests"
    
    # Test custom signal
    print_test "Custom signal option --signal KILL"
    run_test
    start_time=$(date +%s)
    $TIMEOUT_SCRIPT --signal KILL 2 sleep 10 >/dev/null 2>&1
    exit_code=$?
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    if [ $exit_code -eq 124 ] && [ $duration -ge 2 ] && [ $duration -le 4 ]; then
        print_pass "Custom signal KILL works"
    else
        print_fail "Custom signal KILL failed (exit: $exit_code, duration: ${duration}s)"
    fi
    
    # Test short signal option
    print_test "Short signal option -s TERM"
    run_test
    $TIMEOUT_SCRIPT -s TERM 2 sleep 10 >/dev/null 2>&1
    exit_code=$?
    
    if [ $exit_code -eq 124 ]; then
        print_pass "Short signal option works"
    else
        print_fail "Short signal option failed"
    fi
}

# Test kill-after option
test_kill_after() {
    print_header "Kill-After Option Tests"
    
    # Test kill-after with TERM that should be ignored
    print_test "Kill-after option with stubborn process"
    run_test
    
    # Create a temporary script that ignores TERM but dies to KILL
    temp_script=$(mktemp)
    cat > "$temp_script" << 'EOF'
#!/bin/sh
trap '' TERM  # Ignore TERM signal
sleep 20
EOF
    chmod +x "$temp_script"
    
    start_time=$(date +%s)
    $TIMEOUT_SCRIPT --kill-after 2s 3 "$temp_script" >/dev/null 2>&1
    exit_code=$?
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    rm -f "$temp_script"
    
    if [ $exit_code -eq 124 ] && [ $duration -ge 3 ] && [ $duration -le 7 ]; then
        print_pass "Kill-after works (process killed after grace period)"
    else
        print_fail "Kill-after failed (exit: $exit_code, duration: ${duration}s)"
    fi
}

# Test retry functionality
test_retry_functionality() {
    print_header "Retry Functionality Tests"
    
    # Test retry with failing command
    print_test "Retry with failing command (should retry)"
    run_test
    
    # Create a unique counter file using timestamp and random number
    counter_file="/tmp/retry_test_$(date +%s)_$"
    echo "0" > "$counter_file"
    
    # Create a script that fails first few times
    temp_script=$(mktemp)
    cat > "$temp_script" << EOF
#!/bin/sh
count_file="$counter_file"
if [ -f "\$count_file" ]; then
    count=\$(cat "\$count_file")
else
    count=0
fi
count=\$((count + 1))
echo \$count > "\$count_file"

echo "Attempt \$count" >&2

if [ \$count -lt 3 ]; then
    exit 1
else
    exit 0
fi
EOF
    chmod +x "$temp_script"
    
    output=$($TIMEOUT_SCRIPT --retry 3 --verbose 5 "$temp_script" 2>&1)
    exit_code=$?
    final_count=$(cat "$counter_file" 2>/dev/null || echo "0")
    
    rm -f "$temp_script"
    rm -f "$counter_file"
    
    if [ $exit_code -eq 0 ] && [ "$final_count" -ge 3 ]; then
        print_pass "Retry functionality works (exit: $exit_code, attempts: $final_count)"
    else
        print_fail "Retry functionality failed (exit: $exit_code, attempts: $final_count)"
        echo "Debug output: $output" >&2
    fi
    
    # Test retry interval
    print_test "Retry interval timing"
    run_test
    
    # Test just that retry intervals are respected
    # Use a shorter interval and fewer retries for more reliable testing
    start_time=$(date +%s)
    $TIMEOUT_SCRIPT --retry 1 --retry-interval 2s 5 sh -c 'exit 1' >/dev/null 2>&1
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    # Should take: immediate fail + 2s interval + immediate fail = ~2s
    # Allow some variance for system overhead
    if [ $duration -ge 2 ] && [ $duration -le 4 ]; then
        print_pass "Retry interval timing works (duration: ${duration}s, expected ~2s)"
    else
        print_fail "Retry interval timing issues (duration: ${duration}s, expected ~2s)"
    fi
    
    # Additional simple test - just verify intervals are working
    print_test "Retry interval basic functionality"
    run_test
    
    output=$($TIMEOUT_SCRIPT --retry 1 --retry-interval 1s --verbose 5 false 2>&1)
    if echo "$output" | grep -q "after 1s"; then
        print_pass "Retry interval message shows correct timing"
    else
        print_fail "Retry interval message incorrect"
        echo "Debug: $output" >&2
    fi
    
    # Test that timeout doesn't retry
    print_test "Timeout doesn't trigger retry"
    run_test
    
    start_time=$(date +%s)
    $TIMEOUT_SCRIPT --retry 3 2 sleep 10 >/dev/null 2>&1
    exit_code=$?
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    if [ $exit_code -eq 124 ] && [ $duration -ge 2 ] && [ $duration -le 4 ]; then
        print_pass "Timeout doesn't trigger retry (exit: 124, duration: ${duration}s)"
    else
        print_fail "Timeout retry behavior wrong (exit: $exit_code, duration: ${duration}s)"
    fi
}

# Test verbose option
test_verbose_option() {
    print_header "Verbose Option Tests"
    
    # Test verbose output
    print_test "Verbose output during retries"
    run_test
    
    output=$($TIMEOUT_SCRIPT --retry 2 --verbose 1 false 2>&1)
    exit_code=$?
    
    if echo "$output" | grep -q "Retry" && [ $exit_code -eq 1 ]; then
        print_pass "Verbose output shows retry messages"
    else
        print_fail "Verbose output not working (exit: $exit_code)"
        echo "Debug: $output" >&2
    fi
    
    # Test silent mode (no verbose)
    print_test "Silent mode (no verbose flag)"
    run_test
    
    output=$($TIMEOUT_SCRIPT --retry 2 1 sh -c 'exit 1' 2>&1)
    
    if ! echo "$output" | grep -q "Retry"; then
        print_pass "Silent mode works (no retry messages)"
    else
        print_fail "Silent mode failed (unexpected retry messages)"
    fi
}

# Test error handling
test_error_handling() {
    print_header "Error Handling Tests"
    
    # Test missing duration
    print_test "Missing duration argument"
    run_test
    if ! $TIMEOUT_SCRIPT echo "test" >/dev/null 2>&1; then
        print_pass "Missing duration properly detected"
    else
        print_fail "Missing duration not detected"
    fi
    
    # Test missing command
    print_test "Missing command argument"
    run_test
    if ! $TIMEOUT_SCRIPT 5 >/dev/null 2>&1; then
        print_pass "Missing command properly detected"
    else
        print_fail "Missing command not detected"
    fi
    
    # Test unknown option
    print_test "Unknown option"
    run_test
    if ! $TIMEOUT_SCRIPT --unknown-option 5 echo "test" >/dev/null 2>&1; then
        print_pass "Unknown option properly rejected"
    else
        print_fail "Unknown option was accepted"
    fi
    
    # Test invalid retry count
    print_test "Invalid retry count"
    run_test
    if ! $TIMEOUT_SCRIPT --retry abc 5 echo "test" >/dev/null 2>&1; then
        print_pass "Invalid retry count properly rejected"
    else
        print_fail "Invalid retry count was accepted"
    fi
}

# Test option combinations
test_option_combinations() {
    print_header "Option Combinations Tests"
    
    # Test multiple options together
    print_test "Multiple options combination"
    run_test
    
    $TIMEOUT_SCRIPT --signal TERM --kill-after 2s --retry 1 --retry-interval 1s --verbose 3 echo "test" >/dev/null 2>&1
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        print_pass "Multiple options work together"
    else
        print_fail "Multiple options combination failed"
    fi
    
    # Test short options
    print_test "Short options combination"
    run_test
    
    $TIMEOUT_SCRIPT -s KILL -k 1s -r 1 -i 1s -v 2 echo "test" >/dev/null 2>&1
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        print_pass "Short options work together"
    else
        print_fail "Short options combination failed"
    fi
}

# Test exit codes
test_exit_codes() {
    print_header "Exit Code Tests"
    
    # Test successful command
    print_test "Exit code 0 for successful command"
    run_test
    $TIMEOUT_SCRIPT 5 true >/dev/null 2>&1
    exit_code=$?
    if [ $exit_code -eq 0 ]; then
        print_pass "Exit code 0 for successful command"
    else
        print_fail "Wrong exit code for successful command: $exit_code"
    fi
    
    # Test failed command
    print_test "Exit code preservation for failed command"
    run_test
    $TIMEOUT_SCRIPT 5 sh -c 'exit 42' >/dev/null 2>&1
    exit_code=$?
    if [ $exit_code -eq 42 ]; then
        print_pass "Exit code properly preserved (42)"
    else
        print_fail "Exit code not preserved: got $exit_code, expected 42"
    fi
    
    # Test timeout exit code
    print_test "Exit code 124 for timeout"
    run_test
    $TIMEOUT_SCRIPT 1 sleep 5 >/dev/null 2>&1
    exit_code=$?
    if [ $exit_code -eq 124 ]; then
        print_pass "Exit code 124 for timeout"
    else
        print_fail "Wrong exit code for timeout: $exit_code"
    fi
    
    # Test command not found
    print_test "Exit code 127 for command not found"
    run_test
    $TIMEOUT_SCRIPT 5 nonexistent_command_12345 >/dev/null 2>&1
    exit_code=$?
    if [ $exit_code -eq 127 ]; then
        print_pass "Exit code 127 for command not found"
    else
        print_fail "Wrong exit code for command not found: $exit_code"
    fi
}

# Test sourcing functionality
test_sourcing() {
    print_header "Sourcing Functionality Tests"
    
    # Test sourcing in different shells
    for shell in sh bash zsh; do
        if command -v "$shell" >/dev/null 2>&1; then
            print_test "Sourcing in $shell"
            run_test
            
            result=$($shell -c ". $TIMEOUT_SCRIPT && timeout 2 echo 'sourced test'" 2>&1)
            if echo "$result" | grep -q "sourced test"; then
                print_pass "Sourcing works in $shell"
            else
                print_fail "Sourcing failed in $shell"
            fi
        fi
    done
}

# Performance stress test
test_performance() {
    print_header "Performance Tests"
    
    # Test rapid successive calls
    print_test "Rapid successive timeout calls"
    run_test
    
    start_time=$(date +%s)
    for i in 1 2 3 4 5; do
        $TIMEOUT_SCRIPT 1 echo "test $i" >/dev/null 2>&1
    done
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    if [ $duration -le 10 ]; then
        print_pass "Rapid calls perform well (${duration}s for 5 calls)"
    else
        print_fail "Performance issues (${duration}s for 5 calls)"
    fi
}

# Main test runner
main() {
    echo "${BLUE}Timeout Script Test Suite${NC}"
    echo "${BLUE}========================${NC}"
    
    check_timeout_script
    
    test_basic_functionality
    test_duration_parsing
    test_signal_options
    test_kill_after
    test_retry_functionality
    test_verbose_option
    test_error_handling
    test_option_combinations
    test_exit_codes
    test_sourcing
    test_performance
    
    # Final summary
    echo
    echo "${BLUE}=== Test Summary ===${NC}"
    echo
    echo "Tests run: $TESTS_RUN"
    echo "${GREEN}Tests passed: $TESTS_PASSED${NC}"
    echo "${RED}Tests failed: $TESTS_FAILED${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo
        echo "${GREEN}🎉 All tests passed!${NC}"
        exit 0
    else
        echo
        echo "${RED}❌ Some tests failed. Please check the implementation.${NC}"
        exit 1
    fi
}

# Run tests
main "$@"