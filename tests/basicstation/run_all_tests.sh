#!/bin/sh
# run_all_tests.sh — Run all BasicStation UI API tests
#
# Usage:
#   ./tests/basicstation/run_all_tests.sh              # Run all tests
#   ./tests/basicstation/run_all_tests.sh test_09       # Run one test
#   DEVICE_IP=192.168.1.1 ./tests/basicstation/run_all_tests.sh
#
# Environment variables:
#   DEVICE_IP    — Device IP (default: 192.168.1.1)
#   DEVICE_USER  — SSH user (default: root)
#   DEVICE_PASS  — SSH password (from .env)
#   WEB_PASS     — VUCI login password (from .env)
#
# Prerequisites:
#   - sshpass, curl installed on host
#   - Device reachable and BasicStation packages installed
#   - jsonfilter, jq, or python3 for JSON parsing (at least one)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load .env if present
if [ -f "${PROJECT_ROOT}/.env" ]; then
    set -a
    . "${PROJECT_ROOT}/.env"
    set +a
fi

export DEVICE_IP="${DEVICE_IP:-192.168.1.1}"
export DEVICE_USER="${DEVICE_USER:-root}"
export DEVICE_PASS="${DEVICE_PASS:-}"
export WEB_PASS="${WEB_PASS:-}"

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SCRIPTS=0
FAILED_SCRIPTS=""

printf "\n\033[1m╔══════════════════════════════════════════════════╗\033[0m\n"
printf "\033[1m║  BasicStation VUCI API Test Suite                 ║\033[0m\n"
printf "\033[1m║  Device: %-39s  ║\033[0m\n" "$DEVICE_IP"
printf "\033[1m╚══════════════════════════════════════════════════╝\033[0m\n"

# Check prerequisites
for CMD in sshpass curl; do
    if ! command -v "$CMD" >/dev/null 2>&1; then
        printf "\033[31mERROR: %s not found. Install it first.\033[0m\n" "$CMD"
        exit 1
    fi
done

# Check device connectivity
if ! sshpass -p "$DEVICE_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
    "${DEVICE_USER}@${DEVICE_IP}" "echo ok" >/dev/null 2>&1; then
    printf "\033[31mERROR: Cannot connect to device at %s\033[0m\n" "$DEVICE_IP"
    exit 1
fi
printf "\033[32mDevice connectivity: OK\033[0m\n"

# Login once and export token for all tests
_SOURCED_LOGIN=1
. "$SCRIPT_DIR/test_00_login.sh"
unset _SOURCED_LOGIN
if [ -z "$TOKEN" ]; then
    printf "\033[31mERROR: Failed to obtain auth token\033[0m\n"
    exit 1
fi
printf "\n"

# Determine which tests to run
if [ -n "$1" ]; then
    # Run specific test(s) matching the argument
    TESTS=$(find "$SCRIPT_DIR" -name "${1}*.sh" -not -name "run_all*" -not -name "test_00*" | sort)
    if [ -z "$TESTS" ]; then
        printf "\033[31mNo tests matching '%s' found\033[0m\n" "$1"
        exit 1
    fi
else
    TESTS=$(find "$SCRIPT_DIR" -name "test_*.sh" -not -name "test_00*" | sort)
fi

for TEST in $TESTS; do
    TEST_NAME=$(basename "$TEST" .sh)
    TOTAL_SCRIPTS=$((TOTAL_SCRIPTS + 1))

    if sh "$TEST"; then
        printf "  \033[32m%s: ALL PASSED\033[0m\n\n" "$TEST_NAME"
    else
        printf "  \033[31m%s: SOME FAILURES\033[0m\n\n" "$TEST_NAME"
        FAILED_SCRIPTS="${FAILED_SCRIPTS} ${TEST_NAME}"
    fi
done

# Summary
printf "\033[1m╔══════════════════════════════════════════════════╗\033[0m\n"
printf "\033[1m║  TEST SUITE SUMMARY                              ║\033[0m\n"
printf "\033[1m╚══════════════════════════════════════════════════╝\033[0m\n"
printf "  Scripts run: %d\n" "$TOTAL_SCRIPTS"

if [ -z "$FAILED_SCRIPTS" ]; then
    printf "  \033[32mAll test scripts passed!\033[0m\n"
    exit 0
else
    printf "  \033[31mFailed scripts:%s\033[0m\n" "$FAILED_SCRIPTS"
    exit 1
fi
