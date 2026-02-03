#!/usr/bin/env bash
set -euo pipefail

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Mock miner
cat <<'BIN' > "$TMPDIR/minerd"
#!/usr/bin/env bash
exit 0
BIN
chmod +x "$TMPDIR/minerd"

# Mock bitcoin-cli
mkdir -p ./build
cat <<'BIN' > ./build/bitcoin-cli
#!/usr/bin/env bash
echo rbtc_addr
BIN
chmod +x ./build/bitcoin-cli

# Create config
DATADIR="$TMPDIR/rbitcoin"
mkdir -p "$DATADIR"
cat <<CONF > "$DATADIR/bitcoin.conf"
rpcuser=u
rpcpassword=p
rpcport=19332
CONF

MINER_THREADS=3 PATH="$TMPDIR:$PATH" ./scripts/start_cpu_miner.sh --datadir "$DATADIR" >/tmp/rbtc_miner_threads.txt

echo "PASS: start_cpu_miner threads"
