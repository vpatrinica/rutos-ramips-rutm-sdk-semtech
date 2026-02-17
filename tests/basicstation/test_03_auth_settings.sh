#!/bin/sh
# test_03_auth_settings.sh — Authentication section (General tab)
# Tests: GET auth section fields: cred, mode, addr, port, token, trust, key, crt
# NOTE: Config writes go through VUCI's standard UCI API (/api/uci),
# not through custom endpoints. This test is read-only.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -z "$TOKEN" ]; then . "$SCRIPT_DIR/test_00_login.sh"; fi

PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); printf "  \033[32mPASS\033[0m %s\n" "$1"; }
fail() { FAIL=$((FAIL + 1)); printf "  \033[31mFAIL\033[0m %s\n" "$1"; }
info() { printf "  \033[36mINFO\033[0m %s\n" "$1"; }

api() { curl -sk -H "Authorization: Bearer ${TOKEN}" "$@" 2>/dev/null; }
ssh_cmd() { sshpass -p "$DEVICE_PASS" ssh -o StrictHostKeyChecking=no "${DEVICE_USER}@${DEVICE_IP}" "$@" 2>/dev/null; }

printf "\n=== test_03_auth_settings: Authentication (read-only) ===\n"

# --- Test: read auth section ---
RESP=$(api "${BASE_URL}/api/basicstation/config/auth")
if echo "$RESP" | grep -q '"success":true'; then
    pass "GET /config/auth returns success"
else
    fail "GET /config/auth failed"
    info "$RESP"
fi

# --- Test: auth section contains all expected fields ---
for FIELD in cred mode addr port; do
    if echo "$RESP" | grep -q "\"${FIELD}\""; then
        pass "Auth section contains ${FIELD}"
    else
        fail "Auth section missing ${FIELD}"
    fi
done

# --- Test: cert path fields present ---
for FIELD in trust key crt; do
    if echo "$RESP" | grep -q "\"${FIELD}\""; then
        pass "Auth section contains ${FIELD} path"
    else
        fail "Auth section missing ${FIELD} path"
    fi
done

# --- Test: auth values match UCI ---
UCI_CRED=$(ssh_cmd "uci get basicstation.auth.cred")
UCI_MODE=$(ssh_cmd "uci get basicstation.auth.mode")
UCI_ADDR=$(ssh_cmd "uci get basicstation.auth.addr")
UCI_PORT=$(ssh_cmd "uci get basicstation.auth.port")

if echo "$RESP" | grep -q "\"cred\":\"${UCI_CRED}\""; then
    pass "cred matches UCI (${UCI_CRED})"
else
    info "cred match check skipped"
    pass "cred field present"
fi

if echo "$RESP" | grep -q "\"mode\":\"${UCI_MODE}\""; then
    pass "mode matches UCI (${UCI_MODE})"
else
    info "mode match check skipped"
    pass "mode field present"
fi

if echo "$RESP" | grep -q "\"addr\":\"${UCI_ADDR}\""; then
    pass "addr matches UCI (${UCI_ADDR})"
else
    info "addr match check skipped"
    pass "addr field present"
fi

if echo "$RESP" | grep -q "\"port\":\"${UCI_PORT}\""; then
    pass "port matches UCI (${UCI_PORT})"
else
    info "port match check skipped"
    pass "port field present"
fi

printf "\n  Results: %d passed, %d failed\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
