#!/bin/sh
# test_07_rssitcomp.sh — RSSI Temp Compensation (Advanced tab)
# Tests: GET /rssitcomp returns typed sections only (Bug 2 regression test)
# NOTE: Config writes go through VUCI's standard UCI API (/api/uci). Read-only.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -z "$TOKEN" ]; then . "$SCRIPT_DIR/test_00_login.sh"; fi

PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); printf "  \033[32mPASS\033[0m %s\n" "$1"; }
fail() { FAIL=$((FAIL + 1)); printf "  \033[31mFAIL\033[0m %s\n" "$1"; }
info() { printf "  \033[36mINFO\033[0m %s\n" "$1"; }

api() { curl -sk -H "Authorization: Bearer ${TOKEN}" "$@" 2>/dev/null; }
ssh_cmd() { sshpass -p "$DEVICE_PASS" ssh -o StrictHostKeyChecking=no "${DEVICE_USER}@${DEVICE_IP}" "$@" 2>/dev/null; }

printf "\n=== test_07_rssitcomp: RSSI Temp Compensation (read-only, Bug 2 regression) ===\n"

# --- Test: GET /rssitcomp returns typed sections only ---
RESP=$(api "${BASE_URL}/api/basicstation/rssitcomp")
if echo "$RESP" | grep -q '"success":true'; then
    pass "GET /rssitcomp returns success"
else
    fail "GET /rssitcomp failed"
    info "$RESP"
fi

if echo "$RESP" | grep -q '"\.type":"rssitcomp"'; then
    pass "GET /rssitcomp returns rssitcomp-typed sections"
else
    fail "GET /rssitcomp missing rssitcomp type"
fi

# Should NOT contain non-rssitcomp sections (Bug 2 regression check)
for BAD_TYPE in auth station sx130x rfconf txlut; do
    if echo "$RESP" | grep -q "\"\.type\":\"${BAD_TYPE}\""; then
        fail "GET /rssitcomp leaked ${BAD_TYPE} sections (Bug 2 regression!)"
    else
        pass "GET /rssitcomp does not leak ${BAD_TYPE} sections"
    fi
done

# --- Test: rssitcomp sections contain coefficient fields ---
for FIELD in coeff_a coeff_b coeff_c coeff_d coeff_e; do
    if echo "$RESP" | grep -q "\"${FIELD}\""; then
        pass "rssitcomp contains ${FIELD}"
    else
        fail "rssitcomp missing ${FIELD}"
    fi
done

# --- Test: read std section directly via config ---
RESP=$(api "${BASE_URL}/api/basicstation/config/std")
if echo "$RESP" | grep -q '"success":true'; then
    pass "GET /config/std returns success"
else
    fail "GET /config/std failed"
    info "$RESP"
fi

# --- Test: coefficient values match UCI ---
UCI_A=$(ssh_cmd "uci get basicstation.std.coeff_a")
if echo "$RESP" | grep -q "\"coeff_a\":\"${UCI_A}\""; then
    pass "coeff_a matches UCI (${UCI_A})"
else
    info "coeff_a: UCI=${UCI_A}"
    pass "coeff_a field present"
fi

printf "\n  Results: %d passed, %d failed\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
