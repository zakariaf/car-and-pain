#!/usr/bin/env bash
# verify_encryption.sh — Car and Pain data-layer encryption guardrails.
#
# Static + optional runtime checks that the encrypted Drift/SQLCipher store is
# wired correctly and can never ship plaintext. Prints findings to stdout and
# exits non-zero if any hard check fails. Safe to run from CI or locally.
#
#   PRAGMA key must be the FIRST statement, the cipher must be asserted, backups
#   must NOT File.copy a live DB, the header CI test must exist, and any built DB
#   file's first 16 bytes must NOT be "SQLite format 3".
#
# Usage: bash scripts/verify_encryption.sh [REPO_ROOT]
set -uo pipefail

ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
DATA="$ROOT/packages/data"
fail=0
pass() { printf 'PASS  %s\n' "$1"; }
warn() { printf 'WARN  %s\n' "$1"; }
bad()  { printf 'FAIL  %s\n' "$1"; fail=1; }

echo "== Car and Pain: encryption guardrails =="
echo "root: $ROOT"

if [ ! -d "$DATA" ]; then
  warn "packages/data not found — repo may not be scaffolded yet; running what checks it can."
fi

# --- 1. open_connection: PRAGMA key present and asserted -----------------------
OPEN=$(grep -rl --include='*.dart' -e "PRAGMA key" "$DATA" 2>/dev/null | head -1)
if [ -z "$OPEN" ]; then
  bad "No 'PRAGMA key' found under packages/data — encrypted open sequence missing."
else
  pass "PRAGMA key present in: ${OPEN#$ROOT/}"
  # key line should appear before the first select/query in the setup callback
  keyln=$(grep -n "PRAGMA key" "$OPEN" | head -1 | cut -d: -f1)
  cipherln=$(grep -n "cipher_version" "$OPEN" | head -1 | cut -d: -f1)
  if [ -n "$cipherln" ]; then
    pass "cipher_version assertion present (line $cipherln)."
    if [ -n "$keyln" ] && [ "$keyln" -lt "$cipherln" ]; then
      pass "PRAGMA key (line $keyln) precedes the cipher assertion — correct order."
    else
      bad "PRAGMA key does not clearly precede the cipher assertion — key must be FIRST."
    fi
  else
    bad "No 'cipher_version' assertion near PRAGMA key — a stock sqlite3 would open plaintext undetected."
  fi
  # WAL should be enabled in the same setup
  if grep -q "journal_mode = WAL\|journal_mode=WAL\|WAL" "$OPEN"; then
    pass "WAL journal_mode configured in open sequence."
  else
    warn "No WAL journal_mode found in the open sequence — WAL is required."
  fi
fi

# --- 2. Backup must NOT File.copy a live DB -----------------------------------
BACKUP_DIR="$DATA/lib/src/backup"
if [ -d "$BACKUP_DIR" ]; then
  # Flag File.copy of anything that looks like the live sqlite file.
  hits=$(grep -rn --include='*.dart' -E "File\(.+sqlite.+\)\.copy|\.copy\(.+\.sqlite" "$BACKUP_DIR" 2>/dev/null)
  if [ -n "$hits" ]; then
    bad "Backup appears to File.copy a live DB — use wal_checkpoint(TRUNCATE) + VACUUM INTO:"
    printf '        %s\n' "$hits"
  else
    pass "No raw File.copy of a live DB in backup/."
  fi
  if grep -rq "VACUUM INTO" "$BACKUP_DIR" 2>/dev/null; then
    pass "VACUUM INTO used for backup serialization."
  else
    warn "No 'VACUUM INTO' found in backup/ — the only correct backup primitive."
  fi
  if grep -rq "wal_checkpoint" "$BACKUP_DIR" 2>/dev/null; then
    pass "wal_checkpoint present before VACUUM INTO."
  else
    warn "No 'wal_checkpoint(TRUNCATE)' found — checkpoint before VACUUM INTO."
  fi
else
  warn "packages/data/lib/src/backup not found — skipping backup checks."
fi

# --- 3. Header CI test must exist ---------------------------------------------
if grep -rlq --include='*.dart' -e "SQLite format 3" "$ROOT" 2>/dev/null; then
  t=$(grep -rl --include='*.dart' -e "SQLite format 3" "$ROOT" 2>/dev/null | head -1)
  pass "Plaintext-header assertion test present: ${t#$ROOT/}"
else
  bad "No test asserts the raw DB header is NOT 'SQLite format 3' — the flagship plaintext guard is missing."
fi

# --- 4. No network dependency in the data package -----------------------------
if [ -f "$DATA/pubspec.yaml" ]; then
  if grep -qiE "^\s*(http|dio|web_socket|grpc|firebase)\b" "$DATA/pubspec.yaml"; then
    bad "packages/data declares a networking dependency — the data package must have ZERO network deps."
  else
    pass "No obvious networking dependency in packages/data/pubspec.yaml."
  fi
fi

# --- 5. Runtime: any built DB file must not be plaintext -----------------------
found_db=0
while IFS= read -r db; do
  [ -f "$db" ] || continue
  found_db=1
  header=$(head -c 16 "$db" | tr -d '\000')
  if printf '%s' "$header" | grep -q "SQLite format 3"; then
    bad "PLAINTEXT DB on disk: ${db#$ROOT/} — first bytes are 'SQLite format 3'."
  else
    pass "On-disk DB header is not plaintext: ${db#$ROOT/}"
  fi
done < <(find "$ROOT" -type f \( -name '*.sqlite' -o -name 'car_and_pain*.db' \) 2>/dev/null)
[ "$found_db" -eq 0 ] && warn "No built .sqlite file found to header-check (expected in CI/dev, fine locally)."

echo
if [ "$fail" -ne 0 ]; then
  echo "RESULT: FAIL — encryption guardrail(s) violated."
  exit 1
fi
echo "RESULT: OK — encryption guardrails satisfied (review any WARN lines)."
exit 0
