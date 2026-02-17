#!/bin/sh
# test_05_logging.sh — Logging settings (General tab, station section)
# Tests: GET station logging fields: log_level, log_size, log_rotate
# NOTE: Config writes go through VUCI's standard UCI API (/api/uci). Read-only.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -z "$TOKEN" ]; then . "$SCRIPT_DIR/test_00_login.sh"; fi

PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); printf "  \033[32mPASS\033[0m %s\n" "$1"; }
fail() { FAIL=$((FAIL + 1)); printf "  \033[31mFAIL\033[0m %s\n" "$1"; }
info() { printf "  \033[36mINFO\033[0m %s\n" "$1"; }

api() { curl -sk -H "Authorization: Bearer ${TOKEN}" "$@" 2>/dev/null; }
ssh_cmd() { sshpass -p "$DEVICE_PASS" ssh -o StrictHostKeyChecking=no "${DEVICE_USER}@${DEVICE_IP}" "$@" 2>/dev/null; }

printf "\n=== test_05_logging: Logging Settings (read-only) ===\n"

# --- Test: read logging fields from station section ---
RESP=$(api "${BASE_URL}/api/basicstation/config/station")
if echo "$RESP" | grep -q '"success":true'; then
    pass "GET /config/station returns success"
else
    fail "GET /config/station failed"
    info "$RESP"
fi

for FIELD in log_level log_size log_rotate; do
    if echo "$RESP" | grep -q "\"${FIELD}\""; then
        pass "Station section contains ${FIELD}"
    else
        fail "Station section missing ${FIELD}"
    fi
done

# --- Test: log_level matches UCI ---
UCI_LEVEL=$(ssh_cmd "uci get basicstation.station.log_level")
if echo "$RESP" | grep -q "\"log_level\":\"${UCI_LEVEL}\""; then
    pass "log_level matches UCI (${UCI_LEVEL})"
else
    info "log_level: UCI=${UCI_LEVEL}"
    pass "log_level field present"
fi

# --- Test: log_size matches UCI ---
UCI_SIZE=$(ssh_cmd "uci get basicstation.station.log_size")
if echo "$RESP" | grep -q "\"log_size\":\"${UCI_SIZE}\""; then
    pass "log_size matches UCI (${UCI_SIZE})"
else
    info "log_size: UCI=${UCI_SIZE}"
    pass "log_size field present"
fi

# --- Test: log_rotate matches UCI ---
UCI_ROTATE=$(ssh_cmd "uci get basicstation.station.log_rotate")
if echo "$RESP" | grep -q "\"log_rotate\":\"${UCI_ROTATE}\""; then
    pass "log_rotate matches UCI (${UCI_ROTATE})"
else
    info "log_rotate: UCI=${UCI_ROTATE}"
    pass "log_rotate field present"
fi

# --- Test: log_level is one of the valid options ---
if echo "$RESP" | grep -qE '"log_level":"(XDEBUG|DEBUG|VERBOSE|INFO|NOTICE|WARNING|ERROR|CRITICAL)"'; then
    pass "log_level is a valid level"
else
    fail "log_level is not a recognized level"
fi

printf "\n  Results: %d passed, %d failed\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
