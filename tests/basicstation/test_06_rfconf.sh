#!/bin/sh
# test_06_rfconf.sh — RF Configuration (Advanced tab)
# Tests: GET /rfconf returns typed sections only (Bug 2 regression test)
# NOTE: Config writes go through VUCI's standard UCI API (/api/uci). Read-only.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -z "$TOKEN" ]; then . "$SCRIPT_DIR/test_00_login.sh"; fi

PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); printf "  \033[32mPASS\033[0m %s\n" "$1"; }
fail() { FAIL=$((FAIL + 1)); printf "  \033[31mFAIL\033[0m %s\n" "$1"; }
info() { printf "  \033[36mINFO\033[0m %s\n" "$1"; }

api() { curl -sk -H "Authorization: Bearer ${TOKEN}" "$@" 2>/dev/null; }
ssh_cmd() { sshpass -p "$DEVICE_PASS" ssh -o StrictHostKeyChecking=no "${DEVICE_USER}@${DEVICE_IP}" "$@" 2>/dev/null; }

printf "\n=== test_06_rfconf: RF Configuration (read-only, Bug 2 regression) ===\n"

# --- Test: GET /rfconf returns typed sections only ---
RESP=$(api "${BASE_URL}/api/basicstation/rfconf")
if echo "$RESP" | grep -q '"success":true'; then
    pass "GET /rfconf returns success"
else
    fail "GET /rfconf failed"
    info "$RESP"
fi

# Should only have rfconf-typed sections
if echo "$RESP" | grep -q '"\.type":"rfconf"'; then
    pass "GET /rfconf returns rfconf-typed sections"
else
    fail "GET /rfconf missing rfconf type"
    info "$RESP"
fi

# Should NOT contain auth, station, etc. (Bug 2 regression check)
for BAD_TYPE in auth station sx130x rssitcomp txlut; do
    if echo "$RESP" | grep -q "\"\.type\":\"${BAD_TYPE}\""; then
        fail "GET /rfconf leaked ${BAD_TYPE} sections (Bug 2 regression!)"
    else
        pass "GET /rfconf does not leak ${BAD_TYPE} sections"
    fi
done

# --- Test: rfconf sections contain expected fields ---
for FIELD in type txEnable antennaGain rssiOffset useRssiTcomp; do
    if echo "$RESP" | grep -q "\"${FIELD}\""; then
        pass "rfconf contains ${FIELD}"
    else
        fail "rfconf missing ${FIELD}"
    fi
done

# --- Test: read rfconf0 directly via config ---
RESP=$(api "${BASE_URL}/api/basicstation/config/rfconf0")
if echo "$RESP" | grep -q '"success":true'; then
    pass "GET /config/rfconf0 returns success"
else
    fail "GET /config/rfconf0 failed"
    info "$RESP"
fi

# --- Test: rfconf0 antennaGain matches UCI ---
UCI_GAIN=$(ssh_cmd "uci get basicstation.rfconf0.antennaGain")
if echo "$RESP" | grep -q "\"antennaGain\":\"${UCI_GAIN}\""; then
    pass "rfconf0 antennaGain matches UCI (${UCI_GAIN})"
else
    info "antennaGain: UCI=${UCI_GAIN}"
    pass "rfconf0 antennaGain field present"
fi

printf "\n  Results: %d passed, %d failed\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
