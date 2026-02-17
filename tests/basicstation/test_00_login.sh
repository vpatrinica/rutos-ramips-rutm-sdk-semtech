#!/bin/sh
# test_00_login.sh — Obtain auth token from VUCI
# Usage: . ./test_00_login.sh   (sources TOKEN into caller)
#        ./test_00_login.sh     (prints token)
#
# Env: DEVICE_IP, DEVICE_USER, DEVICE_PASS, WEB_PASS

DEVICE_IP="${DEVICE_IP:-192.168.1.1}"
DEVICE_USER="${DEVICE_USER:-root}"
DEVICE_PASS="${DEVICE_PASS:-}"
WEB_PASS="${WEB_PASS:-}"
BASE_URL="https://${DEVICE_IP}"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf "  \033[32mPASS\033[0m %s\n" "$1"; }
fail() { FAIL=$((FAIL + 1)); printf "  \033[31mFAIL\033[0m %s\n" "$1"; }
info() { printf "  \033[36mINFO\033[0m %s\n" "$1"; }

printf "\n=== test_00_login: Authentication ===\n"

# --- Test: obtain bearer token ---
LOGIN_RESP=$(curl -sk -X POST "${BASE_URL}/api/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"admin\",\"password\":\"${WEB_PASS}\"}" 2>/dev/null)

TOKEN=$(echo "$LOGIN_RESP" | jsonfilter -e '@.data.token' 2>/dev/null)
if [ -z "$TOKEN" ]; then
    # Fallback: try python3 or jq on the build host
    TOKEN=$(echo "$LOGIN_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['token'])" 2>/dev/null)
fi
if [ -z "$TOKEN" ]; then
    TOKEN=$(echo "$LOGIN_RESP" | jq -r '.data.token' 2>/dev/null)
fi

if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
    pass "Login successful, got token"
    info "Token: ${TOKEN}"
    export TOKEN
    export BASE_URL
    export DEVICE_IP
    export DEVICE_USER
    export DEVICE_PASS
else
    fail "Login failed — no token in response"
    info "Response: ${LOGIN_RESP}"
    exit 1
fi

# --- Test: token works for authenticated request ---
AUTH_CHECK=$(curl -sk -H "Authorization: Bearer ${TOKEN}" \
    "${BASE_URL}/api/basicstation/status" 2>/dev/null)

if echo "$AUTH_CHECK" | grep -q '"success":true'; then
    pass "Token authenticates successfully"
else
    fail "Token authentication failed"
    info "Response: ${AUTH_CHECK}"
fi

printf "\n  Results: %d passed, %d failed\n" "$PASS" "$FAIL"
# When sourced, return instead of exit (so caller is not killed)
if [ -n "$_SOURCED_LOGIN" ]; then
    [ "$FAIL" -eq 0 ] && return 0 || return 1
fi
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
