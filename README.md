# timeout.sh - Portable Timeout Implementation

A fully POSIX-compliant, portable implementation of the `timeout` command that works across sh, bash, zsh, and other Unix shells. This implementation provides robust process timeout management with retry functionality, making it ideal for unreliable network operations, system administration tasks, and CI/CD pipelines.

## Features

- **Universal Compatibility**: Works on sh, bash, zsh, dash, and other POSIX shells
- **Flexible Duration Parsing**: Supports seconds (30), minutes (5m), hours (2h), days (1d)
- **Retry Functionality**: Built-in retry logic with configurable attempts and intervals
- **Signal Management**: Customizable termination signals with kill-after escalation
- **Dual Operation Modes**: Use as standalone script or source as shell function
- **Verbose Output**: Optional progress reporting for debugging and monitoring
- **Robust Error Handling**: Proper exit codes and cleanup mechanisms
- **Zero Dependencies**: Pure POSIX shell implementation

## Installation

### Quick Start

```bash
# Download and make executable
curl -O https://raw.githubusercontent.com/user/repo/main/timeout.sh
chmod +x timeout.sh

# Use immediately
./timeout.sh 30 long-running-command
```

### System-wide Installation

```bash
# Install to system PATH
sudo cp timeout.sh /usr/local/bin/timeout-portable
sudo chmod +x /usr/local/bin/timeout-portable

# Create alias (optional)
echo 'alias timeout="timeout-portable"' >> ~/.bashrc
```

### Shell Function Integration

```bash
# Source into current shell
source timeout.sh

# Add to shell profile for permanent availability
echo 'source /path/to/timeout.sh' >> ~/.bashrc  # bash
echo 'source /path/to/timeout.sh' >> ~/.zshrc   # zsh
```

## Basic Usage

### Syntax

```bash
timeout [OPTIONS] DURATION COMMAND [ARGS...]
```

### Simple Examples

```bash
# Kill command after 30 seconds
timeout 30 sleep 60

# Network request with 10-second timeout
timeout 10 curl https://api.example.com

# Database backup with 1-hour limit
timeout 1h pg_dump mydb > backup.sql

# Process monitoring with 5-minute timeout
timeout 5m tail -f /var/log/application.log
```

## Advanced Usage

### Retry Operations

```bash
# Retry failing network requests
timeout --retry 3 --retry-interval 5s 30 curl https://unreliable-api.com

# Database connection with exponential backoff
timeout -r 5 -i 2s 15 psql -h remote-server -c "SELECT 1"

# Health check with verbose output
timeout --retry 10 --retry-interval 30s --verbose 5 health-check.sh
```

### Signal Handling

```bash
# Use KILL signal immediately (no graceful shutdown)
timeout --signal KILL 10 stubborn-process

# Graceful shutdown with KILL fallback
timeout --signal TERM --kill-after 5s 30 application-server

# Custom signal handling
timeout -s USR1 -k 3s 60 signal-aware-daemon
```

### Complex Scenarios

```bash
# CI/CD pipeline with retries and logging
timeout --retry 3 --retry-interval 10s --verbose 300 \
  docker build -t myapp:latest .

# Network file transfer with multiple fallbacks
timeout -r 5 -i 30s -v 600 \
  rsync -av /local/data/ user@remote:/backup/

# Distributed system health monitoring
timeout --signal TERM --kill-after 10s --retry 2 --verbose 45 \
  kubectl exec -it pod-name -- health-check

# Load testing with timeout and retries
timeout -r 3 -i 5s -v 120 \
  ab -n 1000 -c 10 http://localhost:8080/api/test
```

## Configuration Options

### Duration Formats

| Format | Description | Example |
|--------|-------------|---------|
| `N` | Seconds | `30` |
| `Ns` | Seconds | `30s` |
| `Nm` | Minutes | `5m` |
| `Nh` | Hours | `2h` |
| `Nd` | Days | `1d` |

### Command-line Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--help` | `-h` | Show help and exit | |
| `--signal` | `-s` | Signal to send to process | `TERM` |
| `--kill-after` | `-k` | Send KILL after duration if still alive | |
| `--retry` | `-r` | Number of retry attempts | `0` |
| `--retry-interval` | `-i` | Wait time between retries | `1s` |
| `--verbose` | `-v` | Show retry messages and progress | off |

### Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Command completed successfully |
| `1-123` | Command's original exit code |
| `124` | Command timed out |
| `125` | timeout utility error |
| `126` | Command found but not executable |
| `127` | Command not found |
| `130` | Terminated by signal (Ctrl+C) |

## Real-world Use Cases

### System Administration

```bash
# Service startup with timeout
timeout 60 systemctl start heavy-service

# Log rotation with retry on failure
timeout --retry 2 --retry-interval 30s 300 logrotate /etc/logrotate.conf

# Disk space monitoring
timeout 10 df -h | grep -E '9[0-9]%|100%' && alert-admin.sh

# Network connectivity test
timeout --retry 5 --retry-interval 10s 5 ping -c 1 8.8.8.8
```

### Development and Testing

```bash
# Integration test with retries
timeout --retry 3 --verbose 120 npm test

# Database migration with timeout
timeout 1800 python manage.py migrate

# Docker build with retry on registry issues
timeout -r 2 -i 30s -v 600 docker push myregistry/myapp:latest

# Selenium test with retry
timeout --retry 3 --retry-interval 5s 300 python test_suite.py
```

### DevOps and CI/CD

```bash
# Deployment with rollback on timeout
timeout 600 kubectl rollout status deployment/myapp || kubectl rollout undo deployment/myapp

# Load balancer health check
timeout --retry 10 --retry-interval 30s 10 curl -f http://lb/health

# Infrastructure provisioning
timeout --verbose 1800 terraform apply -auto-approve

# Backup verification
timeout -r 2 -i 60s 300 backup-verify.sh /backups/latest
```

### Network Operations

```bash
# API endpoint monitoring
timeout --retry 5 --retry-interval 60s 30 \
  curl -f -H "Authorization: Bearer $TOKEN" https://api.service.com/health

# File synchronization with retry
timeout -r 3 -i 10s -v 1800 \
  rsync -avz --progress /local/ user@remote:/backup/

# DNS propagation check
timeout --retry 20 --retry-interval 30s 5 \
  nslookup newdomain.com 8.8.8.8

# VPN connection with fallback
timeout -r 2 -i 5s 30 openvpn --config primary.ovpn || \
timeout -r 2 -i 5s 30 openvpn --config backup.ovpn
```

## Testing

The project includes a comprehensive test suite (`test.sh`) that validates all functionality across different shells and scenarios.

### Running Tests

```bash
# Run complete test suite
./test.sh

# Quick smoke test
./test.sh | grep -E "(PASS|FAIL|Summary)"

# Test specific functionality
./test.sh | grep -A 5 "Retry Functionality"
```

### Test Categories

The test suite covers:

- **Basic Functionality**: Help, timeouts, successful commands
- **Duration Parsing**: All time formats and validation
- **Signal Handling**: Custom signals and kill-after behavior
- **Retry Logic**: Multiple attempts, intervals, success scenarios
- **Verbose Output**: Message formatting and silent mode
- **Error Handling**: Invalid inputs and edge cases
- **Option Combinations**: Multiple flags working together
- **Exit Codes**: All standard timeout exit codes
- **Shell Compatibility**: sh, bash, zsh sourcing
- **Performance**: Rapid successive calls and overhead

### Example Test Output

```
Timeout Script Test Suite
========================

=== Basic Functionality Tests ===
Test 1: Help option --help
✓ PASS: Help option works

Test 2: Basic timeout with slow command
✓ PASS: Timeout works correctly (exit code 124, ~2s duration)

=== Retry Functionality Tests ===
Test 13: Retry with failing command (should retry)
✓ PASS: Retry functionality works (exit: 0, attempts: 3)

=== Test Summary ===
Tests run: 45
Tests passed: 45
Tests failed: 0

🎉 All tests passed!
```

### Continuous Integration

Include in your CI/CD pipeline:

```yaml
# GitHub Actions example
- name: Test timeout.sh
  run: |
    chmod +x timeout.sh test.sh
    ./test.sh
    
# GitLab CI example
test_timeout:
  script:
    - chmod +x timeout.sh test.sh
    - ./test.sh
  only:
    - main
    - develop
```

## Compatibility

### Tested Environments

- **Operating Systems**: Linux, macOS, FreeBSD, OpenBSD
- **Shells**: sh, bash (3.2+), zsh, dash
- **Architectures**: x86_64, ARM64, RISC-V
- **Containers**: Docker, Podman, LXC

### Requirements

- POSIX-compliant shell
- Standard utilities: `sleep`, `kill`, `wait`, `trap`, `date`
- `/tmp` directory for temporary files

### Known Limitations

- Sub-second timeouts not supported (minimum 1 second)
- Process groups not fully isolated (child processes may survive)
- Signal handling may vary slightly between shells
- Performance scales with retry count and intervals

## Troubleshooting

### Common Issues

**Command not found**
```bash
# Ensure script is executable and in PATH
chmod +x timeout.sh
which timeout.sh
```

**Sourcing errors**
```bash
# Check shell compatibility
echo $0
bash --version
zsh --version
```

**Timeouts not working**
```bash
# Verify with simple test
./timeout.sh 2 sleep 5
echo $?  # Should be 124
```

**Retries not happening**
```bash
# Use verbose mode to debug
./timeout.sh --retry 2 --verbose 5 false
```

### Debug Mode

Enable debug output for troubleshooting:

```bash
# Shell debug mode
sh -x timeout.sh 10 command

# Add debug to script temporarily
sed 's/#!/#!\/bin\/sh -x/' timeout.sh > debug_timeout.sh
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with tests
4. Run the test suite: `./test.sh`
5. Submit a pull request

### Development Guidelines

- Maintain POSIX compliance
- Add tests for new features
- Update documentation
- Preserve backward compatibility
- Follow shell scripting best practices

## License

This project is released under the MIT License. See LICENSE file for details.

## Related Projects

- [GNU coreutils timeout](https://www.gnu.org/software/coreutils/manual/html_node/timeout-invocation.html)
- [BusyBox timeout](https://busybox.net/downloads/BusyBox.html)
- [macOS gtimeout](https://formulae.brew.sh/formula/coreutils)

## Support

- **Issues**: Report bugs and feature requests via GitHub Issues
- **Discussions**: Join the community discussions for help and ideas
- **Documentation**: Check the wiki for additional examples and guides

---

**timeout.sh** - Making reliable timeouts available everywhere.