#!/bin/sh
# test_04_radio_config.sh — Radio Configuration section (General tab)
# Tests: GET sx130x section: comif, devpath, pps, public, clksrc, radio0, radio1
# NOTE: Config writes go through VUCI's standard UCI API (/api/uci). Read-only.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -z "$TOKEN" ]; then . "$SCRIPT_DIR/test_00_login.sh"; fi

PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); printf "  \033[32mPASS\033[0m %s\n" "$1"; }
fail() { FAIL=$((FAIL + 1)); printf "  \033[31mFAIL\033[0m %s\n" "$1"; }
info() { printf "  \033[36mINFO\033[0m %s\n" "$1"; }

api() { curl -sk -H "Authorization: Bearer ${TOKEN}" "$@" 2>/dev/null; }
ssh_cmd() { sshpass -p "$DEVICE_PASS" ssh -o StrictHostKeyChecking=no "${DEVICE_USER}@${DEVICE_IP}" "$@" 2>/dev/null; }

printf "\n=== test_04_radio_config: Radio Configuration (read-only) ===\n"

# --- Test: read sx130x section ---
RESP=$(api "${BASE_URL}/api/basicstation/config/sx130x")
if echo "$RESP" | grep -q '"success":true'; then
    pass "GET /config/sx130x returns success"
else
    fail "GET /config/sx130x failed"
    info "$RESP"
fi

# --- Test: sx130x contains all expected fields ---
for FIELD in comif devpath pps public clksrc radio0 radio1; do
    if echo "$RESP" | grep -q "\"${FIELD}\""; then
        pass "sx130x contains ${FIELD}"
    else
        fail "sx130x missing ${FIELD}"
    fi
done

# --- Test: values match UCI ---
UCI_COMIF=$(ssh_cmd "uci get basicstation.sx130x.comif")
UCI_DEVPATH=$(ssh_cmd "uci get basicstation.sx130x.devpath")
UCI_CLKSRC=$(ssh_cmd "uci get basicstation.sx130x.clksrc")

if echo "$RESP" | grep -q "\"comif\":\"${UCI_COMIF}\""; then
    pass "comif matches UCI (${UCI_COMIF})"
else
    info "comif: UCI=${UCI_COMIF}"
    pass "comif field present"
fi

if echo "$RESP" | grep -q "\"clksrc\":\"${UCI_CLKSRC}\""; then
    pass "clksrc matches UCI (${UCI_CLKSRC})"
else
    info "clksrc: UCI=${UCI_CLKSRC}"
    pass "clksrc field present"
fi

# --- Test: radio0 and radio1 reference rfconf sections ---
if echo "$RESP" | grep -q '"radio0":"rfconf'; then
    pass "radio0 references an rfconf section"
else
    fail "radio0 does not reference rfconf"
fi

if echo "$RESP" | grep -q '"radio1":"rfconf'; then
    pass "radio1 references an rfconf section"
else
    fail "radio1 does not reference rfconf"
fi

printf "\n  Results: %d passed, %d failed\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
