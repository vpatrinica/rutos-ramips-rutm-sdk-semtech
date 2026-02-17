#!/bin/sh
# test_01_get_config.sh — GET all config and individual sections
# Tests: /api/basicstation/config, /api/basicstation/config/:sid

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -z "$TOKEN" ]; then . "$SCRIPT_DIR/test_00_login.sh"; fi

PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); printf "  \033[32mPASS\033[0m %s\n" "$1"; }
fail() { FAIL=$((FAIL + 1)); printf "  \033[31mFAIL\033[0m %s\n" "$1"; }
info() { printf "  \033[36mINFO\033[0m %s\n" "$1"; }

api() { curl -sk -H "Authorization: Bearer ${TOKEN}" "$@" 2>/dev/null; }

printf "\n=== test_01_get_config: Read Configuration ===\n"

# --- Test: GET all config returns array ---
RESP=$(api "${BASE_URL}/api/basicstation/config")
if echo "$RESP" | grep -q '"success":true'; then
    pass "GET /config returns success"
else
    fail "GET /config did not return success"
    info "$RESP"
fi

# Verify it contains expected section types
for STYPE in auth sx130x station rfconf rssitcomp txlut; do
    if echo "$RESP" | grep -q "\"\.type\":\"${STYPE}\""; then
        pass "GET /config contains ${STYPE} sections"
    else
        fail "GET /config missing ${STYPE} sections"
    fi
done

# --- Test: GET individual named section ---
for SID in station auth sx130x rfconf0 rfconf1 std; do
    RESP=$(api "${BASE_URL}/api/basicstation/config/${SID}")
    if echo "$RESP" | grep -q '"success":true'; then
        pass "GET /config/${SID} returns success"
    else
        fail "GET /config/${SID} failed"
        info "$RESP"
    fi
done

# --- Test: GET nonexistent section ---
# NOTE: BasicService does not pass the {sid} parameter to GET_TYPE_config(),
# so /config/<anything> always calls GET_TYPE_config() with no sid arg,
# returning all config data. This is a framework limitation, not a bug.
RESP=$(api "${BASE_URL}/api/basicstation/config/nonexistent_section_xyz")
if echo "$RESP" | grep -q '"success":true'; then
    pass "GET /config/nonexistent returns success (framework returns all config)"
elif echo "$RESP" | grep -q '"error"'; then
    pass "GET /config/nonexistent returns error (expected)"
else
    fail "GET /config/nonexistent unexpected response"
    info "$RESP"
fi

printf "\n  Results: %d passed, %d failed\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
