#!/bin/sh
# test_11_upload_certs.sh — Certificate upload (General tab, Bug 3 regression test)
# Tests: upload trust/key/crt via /api/basicstation/upload, verify files + UCI
#
# IMPORTANT: This test backs up and restores real certificates and UCI values.
# Previous versions destroyed production certs connected to TTN.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -z "$TOKEN" ]; then . "$SCRIPT_DIR/test_00_login.sh"; fi

PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); printf "  \033[32mPASS\033[0m %s\n" "$1"; }
fail() { FAIL=$((FAIL + 1)); printf "  \033[31mFAIL\033[0m %s\n" "$1"; }
info() { printf "  \033[36mINFO\033[0m %s\n" "$1"; }

api() { curl -sk -H "Authorization: Bearer ${TOKEN}" "$@" 2>/dev/null; }
ssh_cmd() { sshpass -p "$DEVICE_PASS" ssh -o StrictHostKeyChecking=no "${DEVICE_USER}@${DEVICE_IP}" "$@" 2>/dev/null; }

printf "\n=== test_11_upload_certs: Certificate Upload (Bug 3 regression) ===\n"

# ===== BACKUP PHASE =====
info "Backing up production certificates and UCI values..."
ssh_cmd "cp /etc/basicstation/tc.trust /tmp/_backup_tc.trust 2>/dev/null"
ssh_cmd "cp /etc/basicstation/tc.key /tmp/_backup_tc.key 2>/dev/null"
ssh_cmd "cp /etc/basicstation/tc.crt /tmp/_backup_tc.crt 2>/dev/null"
ORIG_TRUST=$(ssh_cmd "uci get basicstation.auth.trust 2>/dev/null")
ORIG_KEY=$(ssh_cmd "uci get basicstation.auth.key 2>/dev/null")
ORIG_CRT=$(ssh_cmd "uci get basicstation.auth.crt 2>/dev/null")
info "Backed up: trust=${ORIG_TRUST} key=${ORIG_KEY} crt=${ORIG_CRT}"

# Create local temp files for curl upload
TMPDIR=$(mktemp -d)
echo "TEST_TRUST_CONTENT_abc123" > "${TMPDIR}/test_trust.pem"
echo "TEST_KEY_CONTENT_def456" > "${TMPDIR}/test_key.pem"
echo "TEST_CRT_CONTENT_ghi789" > "${TMPDIR}/test_crt.pem"

# ===== CLEANUP FUNCTION =====
cleanup() {
    info "Restoring production certificates..."
    ssh_cmd "cp /tmp/_backup_tc.trust /etc/basicstation/tc.trust 2>/dev/null"
    ssh_cmd "cp /tmp/_backup_tc.key /etc/basicstation/tc.key 2>/dev/null"
    ssh_cmd "cp /tmp/_backup_tc.crt /etc/basicstation/tc.crt 2>/dev/null"
    ssh_cmd "chmod 0644 /etc/basicstation/tc.trust 2>/dev/null"
    ssh_cmd "chmod 0600 /etc/basicstation/tc.key 2>/dev/null"
    ssh_cmd "chmod 0644 /etc/basicstation/tc.crt 2>/dev/null"
    # Restore UCI values
    ssh_cmd "uci set basicstation.auth.trust='${ORIG_TRUST}'; uci set basicstation.auth.key='${ORIG_KEY}'; uci set basicstation.auth.crt='${ORIG_CRT}'; uci commit basicstation" 2>/dev/null
    # Clean up backups
    ssh_cmd "rm -f /tmp/_backup_tc.trust /tmp/_backup_tc.key /tmp/_backup_tc.crt" 2>/dev/null
    rm -rf "$TMPDIR"
    info "Restore complete."
}
trap cleanup EXIT

# ===== UPLOAD TESTS =====

# --- Test: upload trust certificate ---
RESP=$(curl -sk -H "Authorization: Bearer ${TOKEN}" \
    -F "file=@${TMPDIR}/test_trust.pem" \
    -F "option=trust" \
    "${BASE_URL}/api/basicstation/upload" 2>/dev/null)
if echo "$RESP" | grep -q '"success":true'; then
    pass "Upload trust cert returns success"
else
    fail "Upload trust cert failed"
    info "$RESP"
fi

if echo "$RESP" | grep -q '"type":"trust"'; then
    pass "Upload response identifies type as trust"
else
    fail "Upload response wrong type"
    info "$RESP"
fi

if echo "$RESP" | grep -q 'tc.trust'; then
    pass "Upload response references tc.trust"
else
    fail "Upload response missing tc.trust path"
fi

# Verify file content on device
CONTENT=$(ssh_cmd "cat /etc/basicstation/tc.trust 2>/dev/null")
if echo "$CONTENT" | grep -q "TEST_TRUST_CONTENT_abc123"; then
    pass "Trust cert content correct on device"
else
    fail "Trust cert content mismatch"
    info "Got: ${CONTENT}"
fi

# Verify UCI updated
UCI_VAL=$(ssh_cmd "uci get basicstation.auth.trust")
if [ "$UCI_VAL" = "/etc/basicstation/tc.trust" ]; then
    pass "UCI auth.trust points to correct path"
else
    fail "UCI auth.trust wrong: ${UCI_VAL}"
fi

# --- Test: upload key certificate ---
RESP=$(curl -sk -H "Authorization: Bearer ${TOKEN}" \
    -F "file=@${TMPDIR}/test_key.pem" \
    -F "option=key" \
    "${BASE_URL}/api/basicstation/upload" 2>/dev/null)
if echo "$RESP" | grep -q '"success":true'; then
    pass "Upload key cert returns success"
else
    fail "Upload key cert failed"
    info "$RESP"
fi

if echo "$RESP" | grep -q '"type":"key"'; then
    pass "Upload response identifies type as key"
else
    fail "Upload response wrong type for key"
fi

# Verify file content
CONTENT=$(ssh_cmd "cat /etc/basicstation/tc.key 2>/dev/null")
if echo "$CONTENT" | grep -q "TEST_KEY_CONTENT_def456"; then
    pass "Key cert content correct on device"
else
    fail "Key cert content mismatch"
    info "Got: ${CONTENT}"
fi

# Verify key has restrictive permissions (BusyBox: use ls -la)
PERMS_LINE=$(ssh_cmd "ls -la /etc/basicstation/tc.key 2>/dev/null")
if echo "$PERMS_LINE" | grep -q '^-rw-------'; then
    pass "Key file has 0600 permissions"
else
    PERMS_SHORT=$(echo "$PERMS_LINE" | awk '{print $1}')
    fail "Key file permissions wrong: ${PERMS_SHORT} (expected -rw-------)"
fi

UCI_VAL=$(ssh_cmd "uci get basicstation.auth.key")
if [ "$UCI_VAL" = "/etc/basicstation/tc.key" ]; then
    pass "UCI auth.key points to correct path"
else
    fail "UCI auth.key wrong: ${UCI_VAL}"
fi

# --- Test: upload client certificate ---
RESP=$(curl -sk -H "Authorization: Bearer ${TOKEN}" \
    -F "file=@${TMPDIR}/test_crt.pem" \
    -F "option=crt" \
    "${BASE_URL}/api/basicstation/upload" 2>/dev/null)
if echo "$RESP" | grep -q '"success":true'; then
    pass "Upload crt cert returns success"
else
    fail "Upload crt cert failed"
    info "$RESP"
fi

if echo "$RESP" | grep -q '"type":"crt"'; then
    pass "Upload response identifies type as crt"
else
    fail "Upload response wrong type for crt"
fi

CONTENT=$(ssh_cmd "cat /etc/basicstation/tc.crt 2>/dev/null")
if echo "$CONTENT" | grep -q "TEST_CRT_CONTENT_ghi789"; then
    pass "Crt cert content correct on device"
else
    fail "Crt cert content mismatch"
    info "Got: ${CONTENT}"
fi

# Verify crt has 644 permissions (BusyBox: use ls -la)
PERMS_LINE=$(ssh_cmd "ls -la /etc/basicstation/tc.crt 2>/dev/null")
if echo "$PERMS_LINE" | grep -q '^-rw-r--r--'; then
    pass "Crt file has 0644 permissions"
else
    PERMS_SHORT=$(echo "$PERMS_LINE" | awk '{print $1}')
    fail "Crt file permissions wrong: ${PERMS_SHORT} (expected -rw-r--r--)"
fi

UCI_VAL=$(ssh_cmd "uci get basicstation.auth.crt")
if [ "$UCI_VAL" = "/etc/basicstation/tc.crt" ]; then
    pass "UCI auth.crt points to correct path"
else
    fail "UCI auth.crt wrong: ${UCI_VAL}"
fi

# --- Test: all three certs are DIFFERENT files (Bug 3 core issue) ---
TRUST_CONTENT=$(ssh_cmd "cat /etc/basicstation/tc.trust")
KEY_CONTENT=$(ssh_cmd "cat /etc/basicstation/tc.key")
CRT_CONTENT=$(ssh_cmd "cat /etc/basicstation/tc.crt")

if [ "$TRUST_CONTENT" != "$KEY_CONTENT" ] && [ "$KEY_CONTENT" != "$CRT_CONTENT" ] && [ "$TRUST_CONTENT" != "$CRT_CONTENT" ]; then
    pass "All three cert files have distinct content (Bug 3 regression PASS)"
else
    fail "Cert files have duplicate content — Bug 3 regression!"
    info "trust=${TRUST_CONTENT} key=${KEY_CONTENT} crt=${CRT_CONTENT}"
fi

# --- Test: /etc/basicstation/ directory exists and is accessible ---
DIR_EXISTS=$(ssh_cmd "[ -d /etc/basicstation ] && echo yes || echo no")
if [ "$DIR_EXISTS" = "yes" ]; then
    pass "/etc/basicstation directory exists"
else
    fail "/etc/basicstation directory missing"
fi

# Cleanup is handled by trap EXIT above

printf "\n  Results: %d passed, %d failed\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
