#!/usr/bin/env bash
set -euo pipefail

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Create dummy upstream report
mkdir -p ./reports ./manifests
cat <<JSON > ./reports/verification-v0.0.0-test.json
{ "tag": "v0.0.0-test", "status": "PASS" }
JSON

# Create minimal manifest
cat <<JSON > ./manifests/manifest-v0.0.0-test.json
{
  "upstream_tag": "v0.0.0-test",
  "patch_hash": "$(cat ./patch/immutable.patch.sha256 | tr -d ' \n')",
  "verification_report": "./reports/verification-v0.0.0-test.json",
  "timestamp": "2026-01-01T00:00:00Z",
  "artifacts": [ { "path": "./build/bitcoind", "sha256": "deadbeef" } ]
}
JSON

# Mock upstream verification to avoid network
WRAP="$TMPDIR/verify_ok.sh"
cat <<'WRAP' > "$WRAP"
#!/usr/bin/env bash
exit 0
WRAP
chmod +x "$WRAP"

VERIFY_CMD="$WRAP" ./scripts/agent_verify.sh v0.0.0-test >/tmp/rbtc_agent_verify.txt

if ! grep -q "PASS" /tmp/rbtc_agent_verify.txt; then
  echo "FAIL: agent_verify did not pass"
  exit 1
fi

echo "PASS: agent_verify.sh"
