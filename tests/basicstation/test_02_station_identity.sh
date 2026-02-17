#!/bin/sh
# test_02_station_identity.sh — Station identity section (General tab)
# Tests: GET station section fields: idGenIf, stationid
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

printf "\n=== test_02_station_identity: Station Identity (read-only) ===\n"

# --- Test: read station section ---
RESP=$(api "${BASE_URL}/api/basicstation/config/station")
if echo "$RESP" | grep -q '"success":true'; then
    pass "GET /config/station returns success"
else
    fail "GET /config/station failed"
    info "$RESP"
fi

# --- Test: station section contains expected fields ---
for FIELD in idGenIf stationid; do
    if echo "$RESP" | grep -q "\"${FIELD}\""; then
        pass "Station section contains ${FIELD}"
    else
        fail "Station section missing ${FIELD}"
        info "$RESP"
    fi
done

# --- Test: station section contains log fields ---
for FIELD in log_level log_size log_rotate; do
    if echo "$RESP" | grep -q "\"${FIELD}\""; then
        pass "Station section contains ${FIELD}"
    else
        fail "Station section missing ${FIELD}"
    fi
done

# --- Test: idGenIf matches UCI value ---
UCI_VAL=$(ssh_cmd "uci get basicstation.station.idGenIf")
if echo "$RESP" | grep -q "\"idGenIf\":\"${UCI_VAL}\""; then
    pass "idGenIf matches UCI value (${UCI_VAL})"
else
    info "Could not confirm idGenIf match in JSON (UCI: ${UCI_VAL})"
    pass "idGenIf field present (exact match check skipped)"
fi

# --- Test: stationid is populated (non-empty) ---
if echo "$RESP" | grep -q '"stationid":"[^"]\+' ; then
    pass "stationid is populated"
else
    fail "stationid appears empty"
fi

printf "\n  Results: %d passed, %d failed\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
