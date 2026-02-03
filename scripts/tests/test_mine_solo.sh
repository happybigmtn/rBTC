#!/usr/bin/env bash
set -euo pipefail

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Mock bitcoin-cli
CLI="$TMPDIR/bitcoin-cli"
cat <<'CLI' > "$CLI"
#!/usr/bin/env bash
for arg in "$@"; do
  case "$arg" in
    getnewaddress)
      echo "rbtc_test_addr"; exit 0;;
    generatetoaddress)
      echo "[\"dummyblockhash\"]"; exit 0;;
    getblockcount)
      echo "1"; exit 0;;
  esac
  done

echo "1"
CLI
chmod +x "$CLI"

BTC_CLI="$CLI" ./scripts/mine_solo.sh --network regtest >/tmp/rbtc_mine_out.txt

if ! grep -q "Mined block at height" /tmp/rbtc_mine_out.txt; then
  echo "FAIL: mine_solo output missing height"
  exit 1
fi

if ! grep -q "rbtc_test_addr" /tmp/rbtc_mine_out.txt; then
  echo "FAIL: mine_solo output missing address"
  exit 1
fi

echo "PASS: mine_solo.sh"
