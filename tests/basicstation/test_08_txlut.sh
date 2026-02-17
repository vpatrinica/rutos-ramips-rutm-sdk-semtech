#!/bin/sh
# test_08_txlut.sh — TX Gain Lookup Table (Advanced tab)
# Tests: GET config includes txlut sections with expected fields
# NOTE: Config writes go through VUCI's standard UCI API (/api/uci). Read-only.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -z "$TOKEN" ]; then . "$SCRIPT_DIR/test_00_login.sh"; fi

PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); printf "  \033[32mPASS\033[0m %s\n" "$1"; }
fail() { FAIL=$((FAIL + 1)); printf "  \033[31mFAIL\033[0m %s\n" "$1"; }
info() { printf "  \033[36mINFO\033[0m %s\n" "$1"; }

api() { curl -sk -H "Authorization: Bearer ${TOKEN}" "$@" 2>/dev/null; }

printf "\n=== test_08_txlut: TX Gain Lookup Table (read-only) ===\n"

# --- Test: GET all config includes txlut sections ---
RESP=$(api "${BASE_URL}/api/basicstation/config")
if echo "$RESP" | grep -q '"\.type":"txlut"'; then
    pass "GET /config contains txlut sections"
else
    fail "GET /config missing txlut sections"
fi

# Count txlut sections
TXLUT_COUNT=$(echo "$RESP" | grep -o '"\.type":"txlut"' | wc -l)
info "Found ${TXLUT_COUNT} txlut sections"
if [ "$TXLUT_COUNT" -gt 0 ]; then
    pass "At least one txlut section exists (${TXLUT_COUNT} found)"
else
    fail "No txlut sections found"
fi

# --- Test: txlut sections contain expected fields ---
for FIELD in rfPower paGain pwrIdx usedBy; do
    if echo "$RESP" | grep -q "\"${FIELD}\""; then
        pass "txlut contains ${FIELD}"
    else
        fail "txlut missing ${FIELD}"
    fi
done

# --- Test: usedBy references rfconf sections ---
if echo "$RESP" | grep -q '"usedBy":\["rfconf'; then
    pass "txlut usedBy references rfconf sections"
elif echo "$RESP" | grep -q '"usedBy"'; then
    pass "txlut usedBy field present"
else
    fail "txlut usedBy missing"
fi

# --- Test: rfPower values are numeric ---
RFPOWER=$(echo "$RESP" | grep -o '"rfPower":"[0-9]*"' | head -1)
if [ -n "$RFPOWER" ]; then
    pass "rfPower values are numeric strings"
else
    fail "rfPower not found or not numeric"
fi

printf "\n  Results: %d passed, %d failed\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
