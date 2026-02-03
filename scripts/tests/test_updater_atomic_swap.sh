#!/usr/bin/env bash
set -euo pipefail

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

ROOT="$TMPDIR/runtime"
mkdir -p "$ROOT/versions"

# Create a previous version
PREV="$ROOT/versions/v0.0.0-prev"
mkdir -p "$PREV"
ln -s "$PREV" "$ROOT/current"

# Mock verify and build
export MOCK_BUILD=1

# Wrapper verify command writes a dummy report
WRAP="$TMPDIR/verify_ok.sh"
cat <<'WRAP' > "$WRAP"
#!/usr/bin/env bash
set -euo pipefail
TAG="$1"
mkdir -p "${REPORTS_DIR:-./reports}"
cat <<JSON > "${REPORTS_DIR:-./reports}/verification-$TAG.json"
{ "tag": "$TAG", "status": "PASS" }
JSON
exit 0
WRAP
chmod +x "$WRAP"

# Run updater with failing smoke test to force rollback
SMOKE_TEST_CMD="false" VERIFY_CMD="$WRAP" UPDATER_ROOT="$ROOT" ./scripts/updater.sh v0.0.1-test >/dev/null 2>&1 || true

CUR=$(readlink "$ROOT/current")
if [[ "$CUR" != "$PREV" ]]; then
  echo "FAIL: rollback did not restore previous version"
  exit 1
fi

# Now run with passing smoke test
SMOKE_TEST_CMD="true" VERIFY_CMD="$WRAP" UPDATER_ROOT="$ROOT" ./scripts/updater.sh v0.0.2-test >/dev/null

CUR=$(readlink "$ROOT/current")
if [[ "$CUR" != "$ROOT/versions/v0.0.2-test" ]]; then
  echo "FAIL: atomic swap did not update to new version"
  exit 1
fi

echo "PASS: updater atomic swap + rollback"
