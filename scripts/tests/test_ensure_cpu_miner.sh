#!/usr/bin/env bash
set -euo pipefail

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Mock minerd in PATH to simulate installed miner
cat <<'BIN' > "$TMPDIR/minerd"
#!/usr/bin/env bash
exit 0
BIN
chmod +x "$TMPDIR/minerd"

PATH="$TMPDIR:$PATH" ./scripts/ensure_cpu_miner.sh >/tmp/rbtc_ensure_miner.txt

if ! grep -q "already installed" /tmp/rbtc_ensure_miner.txt; then
  echo "FAIL: ensure_cpu_miner did not detect installed miner"
  exit 1
fi

# Remove miner, mock brew and dry-run
rm -f "$TMPDIR/minerd"
cat <<'BIN' > "$TMPDIR/brew"
#!/usr/bin/env bash
exit 1
BIN
chmod +x "$TMPDIR/brew"

DRY_RUN=1 PATH="$TMPDIR:$PATH" ./scripts/ensure_cpu_miner.sh >/tmp/rbtc_ensure_miner2.txt || true
if ! grep -q "brew install cpuminer" /tmp/rbtc_ensure_miner2.txt; then
  echo "FAIL: ensure_cpu_miner did not choose brew in dry run"
  exit 1
fi

echo "PASS: ensure_cpu_miner.sh"
