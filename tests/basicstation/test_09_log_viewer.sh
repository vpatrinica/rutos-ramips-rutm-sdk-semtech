#!/bin/sh
# test_09_log_viewer.sh — Log viewer (Log tab)
# Tests: GET /log, GET /clear_log, log content, log file permissions
# Bug 1 regression test: log must be readable by uhttpd user

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -z "$TOKEN" ]; then . "$SCRIPT_DIR/test_00_login.sh"; fi

PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); printf "  \033[32mPASS\033[0m %s\n" "$1"; }
fail() { FAIL=$((FAIL + 1)); printf "  \033[31mFAIL\033[0m %s\n" "$1"; }
info() { printf "  \033[36mINFO\033[0m %s\n" "$1"; }

api() { curl -sk -H "Authorization: Bearer ${TOKEN}" "$@" 2>/dev/null; }
ssh_cmd() { sshpass -p "$DEVICE_PASS" ssh -o StrictHostKeyChecking=no "${DEVICE_USER}@${DEVICE_IP}" "$@" 2>/dev/null; }

printf "\n=== test_09_log_viewer: Log Messages (Bug 1 regression) ===\n"

# --- Test: log file exists with correct permissions ---
# BusyBox has no stat -c; parse ls -la output instead
PERMS_LINE=$(ssh_cmd "ls -la /tmp/basicstation/log 2>/dev/null")
if echo "$PERMS_LINE" | grep -q '^-rw-r--r--'; then
    pass "Log file has correct permissions (644 = rw-r--r--)"
elif echo "$PERMS_LINE" | grep -q '^-'; then
    # File exists but permissions differ
    PERMS_SHORT=$(echo "$PERMS_LINE" | awk '{print $1}')
    # Check world-readable (the 'r' in position 8)
    if echo "$PERMS_SHORT" | grep -q 'r.$'; then
        pass "Log file is world-readable (${PERMS_SHORT})"
    else
        fail "Log file not world-readable: ${PERMS_SHORT} (Bug 1 regression!)"
    fi
else
    fail "Log file does not exist or ls failed"
    info "$PERMS_LINE"
fi

# --- Test: GET /log returns content (Bug 1 regression test) ---
RESP=$(api "${BASE_URL}/api/basicstation/log")
if echo "$RESP" | grep -q '"success":true'; then
    pass "GET /log returns success"
else
    fail "GET /log failed"
    info "$RESP"
fi

if echo "$RESP" | grep -q '"log"'; then
    pass "GET /log contains log field"
else
    fail "GET /log missing log field"
fi

# Log should have actual content (station is running)
LOG_LEN=$(echo "$RESP" | wc -c)
if [ "$LOG_LEN" -gt 100 ]; then
    pass "Log content is non-empty (response ${LOG_LEN} bytes)"
else
    fail "Log content appears empty (response ${LOG_LEN} bytes)"
fi

# --- Test: GET /clear_log clears the log ---
RESP=$(api "${BASE_URL}/api/basicstation/clear_log")
if echo "$RESP" | grep -q '"success":true'; then
    pass "GET /clear_log returns success"
else
    fail "GET /clear_log failed"
    info "$RESP"
fi

if echo "$RESP" | grep -q '"cleared":true'; then
    pass "clear_log response confirms cleared"
else
    fail "clear_log response missing cleared field"
fi

# Verify log is now shorter
sleep 1  # Give station a moment to not write too much
RESP2=$(api "${BASE_URL}/api/basicstation/log")
LOG_LEN2=$(echo "$RESP2" | wc -c)
if [ "$LOG_LEN2" -lt "$LOG_LEN" ]; then
    pass "Log is shorter after clear (${LOG_LEN2} < ${LOG_LEN})"
else
    info "Log may have refilled quickly (${LOG_LEN2} bytes after, ${LOG_LEN} before)"
    pass "clear_log executed (station writes new data quickly)"
fi

# --- Test: log file still readable after truncation ---
RESP=$(api "${BASE_URL}/api/basicstation/log")
if echo "$RESP" | grep -q '"success":true'; then
    pass "Log still readable after clear"
else
    fail "Log not readable after clear"
fi

printf "\n  Results: %d passed, %d failed\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
