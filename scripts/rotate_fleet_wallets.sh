#!/usr/bin/env bash
set -euo pipefail

# Rotate all fleet wallets: create new treasury wallets, archive old mining
# wallets on each node, generate fresh addresses, and collect backups.
# Old wallets are archived (not deleted) for later sweeping via sweep_to_treasury.sh.
#
# rBTC: external cpuminer with --coinbase-addr, wallet "rbtc" under
#       <datadir>/rbitcoin/wallets/rbtc/ (chain subdir layout)
# RNG:  built-in daemon mining via mineaddress= in rng.conf, wallet "miner"
#       under <datadir>/wallets/miner/

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY_PATH="${FLEET_SSH_KEY:-$HOME/.ssh/contabo-mining-fleet}"
SSH_USER="${FLEET_SSH_USER:-root}"
TIMESTAMP="$(date -u +%Y%m%d-%H%M%S)"
BACKUP_BASE="${BACKUP_DIR:-$HOME/.backups}"
TREASURY_DIR="$BACKUP_BASE/treasury-$TIMESTAMP"
WALLET_DIR="$BACKUP_BASE/rotated-wallets-$TIMESTAMP"
MANIFEST="$BACKUP_BASE/new-addresses-$TIMESTAMP"

FLEET_CONF="${FLEET_CONF:-$ROOT_DIR/scripts/fleet.conf}"
if [[ ! -f "$FLEET_CONF" ]]; then
  echo "FAIL: fleet config not found at $FLEET_CONF (copy fleet.conf.example)" >&2
  exit 1
fi
source "$FLEET_CONF"

if [[ ${#FLEET_IPS[@]} -eq 0 ]]; then
  echo "FAIL: FLEET_IPS is empty in $FLEET_CONF" >&2
  exit 1
fi

if [[ ! -f "$KEY_PATH" ]]; then
  echo "FAIL: fleet SSH key not found at $KEY_PATH" >&2
  exit 1
fi

SSH_OPTS=(
  -i "$KEY_PATH"
  -o BatchMode=yes
  -o ConnectTimeout=15
  -o StrictHostKeyChecking=no
)

mkdir -p "$TREASURY_DIR" "$WALLET_DIR" "$MANIFEST"

TREASURY_RBTC=""
TREASURY_RNG=""

declare -A NEW_RBTC_ADDRS=()
declare -A NEW_RNG_ADDRS=()

##############################################################################
# Phase 1: Create treasury wallets on first fleet node
##############################################################################

echo "=== Phase 1: Create treasury wallets ==="
TREASURY_NODE="${FLEET_IPS[0]}"
echo "Using node $TREASURY_NODE for treasury wallet creation"

TREASURY_RBTC=$(ssh "${SSH_OPTS[@]}" "$SSH_USER@$TREASURY_NODE" bash -s <<'REMOTE'
set -euo pipefail
CLI="/opt/rbitcoin/build/bitcoin-cli -rpcwait -datadir=/root/.rbitcoin"

$CLI unloadwallet "treasury" 2>/dev/null || true

if $CLI listwalletdir | grep -q '"treasury"'; then
  echo "WARN: treasury wallet dir already exists, loading it" >&2
  $CLI loadwallet "treasury" >/dev/null
else
  $CLI -named createwallet wallet_name="treasury" disable_private_keys=false blank=false passphrase="" >/dev/null
fi

ADDR=$($CLI -rpcwallet=treasury getnewaddress "" legacy)
$CLI -rpcwallet=treasury backupwallet "/tmp/treasury-rbtc-backup.dat"
$CLI unloadwallet "treasury" >/dev/null

echo "$ADDR"
REMOTE
)

echo "  rBTC treasury: $TREASURY_RBTC"

scp "${SSH_OPTS[@]}" "$SSH_USER@$TREASURY_NODE:/tmp/treasury-rbtc-backup.dat" \
  "$TREASURY_DIR/treasury-rbtc-wallet.dat"
ssh "${SSH_OPTS[@]}" "$SSH_USER@$TREASURY_NODE" "rm -f /tmp/treasury-rbtc-backup.dat"

TREASURY_RNG=$(ssh "${SSH_OPTS[@]}" "$SSH_USER@$TREASURY_NODE" bash -s <<'REMOTE'
set -euo pipefail
CLI="/root/rng-cli -rpcwait -datadir=/root/.rng"

$CLI unloadwallet "treasury" 2>/dev/null || true

if $CLI listwalletdir | grep -q '"treasury"'; then
  echo "WARN: treasury wallet dir already exists, loading it" >&2
  $CLI loadwallet "treasury" >/dev/null
else
  $CLI -named createwallet wallet_name="treasury" disable_private_keys=false blank=false passphrase="" >/dev/null
fi

ADDR=$($CLI -rpcwallet=treasury getnewaddress "" legacy)
$CLI -rpcwallet=treasury backupwallet "/tmp/treasury-rng-backup.dat"
$CLI unloadwallet "treasury" >/dev/null

echo "$ADDR"
REMOTE
)

echo "  RNG treasury:  $TREASURY_RNG"

scp "${SSH_OPTS[@]}" "$SSH_USER@$TREASURY_NODE:/tmp/treasury-rng-backup.dat" \
  "$TREASURY_DIR/treasury-rng-wallet.dat"
ssh "${SSH_OPTS[@]}" "$SSH_USER@$TREASURY_NODE" "rm -f /tmp/treasury-rng-backup.dat"

echo "  Treasury backups saved to $TREASURY_DIR"
echo

##############################################################################
# Phase 2: Rotate each node (sequential)
##############################################################################

echo "=== Phase 2: Rotate fleet wallets ==="

rotate_rbtc() {
  local ip="$1"
  echo "  [rBTC] Rotating..." >&2

  ssh "${SSH_OPTS[@]}" "$SSH_USER@$ip" bash -s <<'REMOTE'
set -euo pipefail
CLI="/opt/rbitcoin/build/bitcoin-cli -rpcwait -datadir=/root/.rbitcoin"
DATADIR="/root/.rbitcoin"

# Detect chain subdir (rbitcoin uses <datadir>/rbitcoin/wallets/)
CHAIN_DIR=""
for candidate in "$DATADIR/rbitcoin/wallets" "$DATADIR/wallets"; do
  if [[ -d "$candidate" ]]; then
    CHAIN_DIR="$candidate"
    break
  fi
done

# 1. Kill ALL rBTC miners (any minerd/cpuminer targeting port 19332)
for pid in $(pgrep -f 'minerd|cpuminer-opt|cpuminer' || true); do
  if ps -p "$pid" -o args= 2>/dev/null | grep -q '19332'; then
    kill "$pid" 2>/dev/null || true
    echo "KILLED: miner pid $pid" >&2
  fi
done
sleep 2

# 2. Unload old wallet
$CLI unloadwallet "rbtc" 2>/dev/null || true

# 3. Archive old wallet on disk (idempotent: skip if already archived)
if [[ -n "$CHAIN_DIR" && -d "$CHAIN_DIR/rbtc" ]]; then
  mv "$CHAIN_DIR/rbtc" "$CHAIN_DIR/rbtc-archived"
  echo "ARCHIVED: $CHAIN_DIR/rbtc -> $CHAIN_DIR/rbtc-archived" >&2
elif [[ -n "$CHAIN_DIR" && -d "$CHAIN_DIR/rbtc-archived" ]]; then
  echo "ALREADY_ARCHIVED: $CHAIN_DIR/rbtc-archived exists" >&2
elif [[ -f "$DATADIR/wallet.dat" ]]; then
  mkdir -p "$DATADIR/wallets"
  mv "$DATADIR/wallet.dat" "$DATADIR/wallets/rbtc-archived-wallet.dat"
  echo "ARCHIVED: legacy wallet.dat" >&2
else
  echo "WARN: no wallet found to archive at $DATADIR" >&2
fi

# 4. Remove old pin
rm -f "$DATADIR/mining_address"

# 5. Create fresh wallet + generate address directly (don't rely on start_cpu_miner.sh)
if ! $CLI listwallets | grep -q '"rbtc"'; then
  if $CLI listwalletdir | grep -q '"rbtc"'; then
    $CLI loadwallet "rbtc" >/dev/null
  else
    $CLI -named createwallet wallet_name="rbtc" disable_private_keys=false blank=false passphrase="" >/dev/null
  fi
fi
NEW_ADDR=$($CLI -rpcwallet=rbtc getnewaddress "" legacy)
echo "$NEW_ADDR" > "$DATADIR/mining_address"
echo "PINNED: $NEW_ADDR" >&2

# 6. Start miner with explicit --address (skips wallet logic in start_cpu_miner.sh)
cd /opt/rbitcoin
AUTO_INSTALL=0 MINER_BACKGROUND=1 PEER_BOOTSTRAP=0 \
  ./scripts/start_cpu_miner.sh --datadir "$DATADIR" --address "$NEW_ADDR"

# 7. Verify miner running
sleep 3
if ! pgrep -f 'minerd|cpuminer-opt|cpuminer' >/dev/null; then
  echo "FAIL: miner not running after restart" >&2
  exit 1
fi

# 8. Output new address (only stdout — captured by caller)
echo "$NEW_ADDR"
REMOTE
}

rotate_rng() {
  local ip="$1"
  echo "  [RNG]  Rotating..." >&2

  ssh "${SSH_OPTS[@]}" "$SSH_USER@$ip" bash -s <<'REMOTE'
set -euo pipefail
CLI="/root/rng-cli -rpcwait -datadir=/root/.rng"
DATADIR="/root/.rng"
CONF="$DATADIR/rng.conf"

# 1. Stop the RNG daemon (it does built-in mining via mine=1 / mineaddress=)
/root/rng-cli -datadir="$DATADIR" stop 2>/dev/null || true
# Wait for clean shutdown
for i in {1..15}; do
  if ! pgrep -f 'rngd.*datadir=/root/.rng' >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

# 2. Unload happens implicitly when daemon stops, but archive wallet on disk
if [[ -d "$DATADIR/wallets/miner" ]]; then
  mv "$DATADIR/wallets/miner" "$DATADIR/wallets/miner-archived"
  echo "ARCHIVED: $DATADIR/wallets/miner -> $DATADIR/wallets/miner-archived" >&2
else
  echo "WARN: no miner wallet dir found to archive" >&2
fi

# 3. Remove old pin
rm -f "$DATADIR/mining_address"

# 4. Restart daemon (without mining initially, so we can create wallet first)
OLD_MINEADDR=$(grep '^mineaddress=' "$CONF" | cut -d= -f2)
# Temporarily disable mining so daemon starts without needing the wallet
sed -i 's/^mine=1/mine=0/' "$CONF"
nohup /root/rngd -datadir="$DATADIR" -conf="$CONF" -walletcrosschain=1 >/dev/null 2>&1 &

# Wait for RPC to become available
for i in {1..30}; do
  if $CLI getblockcount >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! $CLI getblockcount >/dev/null 2>&1; then
  echo "FAIL: RNG daemon did not start" >&2
  # Restore mining config before exiting
  sed -i 's/^mine=0/mine=1/' "$CONF"
  exit 1
fi

# 5. Create new wallet
$CLI -named createwallet wallet_name="miner" disable_private_keys=false blank=false passphrase="" >/dev/null

# 6. Generate + pin new address (bech32 to match existing mineaddress format)
NEW_ADDR=$($CLI -rpcwallet=miner getnewaddress "" bech32)
echo "$NEW_ADDR" > "$DATADIR/mining_address"

# 7. Update mineaddress in config and re-enable mining
sed -i "s/^mineaddress=.*/mineaddress=$NEW_ADDR/" "$CONF"
sed -i 's/^mine=0/mine=1/' "$CONF"

# 8. Restart daemon with mining enabled and new address
$CLI stop 2>/dev/null || true
for i in {1..15}; do
  if ! pgrep -f 'rngd.*datadir=/root/.rng' >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

nohup /root/rngd -datadir="$DATADIR" -conf="$CONF" -walletcrosschain=1 -wallet=miner >/dev/null 2>&1 &

# Wait for daemon to come up and start mining
for i in {1..30}; do
  if $CLI getblockcount >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

# 9. Verify daemon running
if ! $CLI getblockcount >/dev/null 2>&1; then
  echo "FAIL: RNG daemon not running after restart" >&2
  exit 1
fi

# 10. Output new address
cat "$DATADIR/mining_address"
REMOTE
}

for ip in "${FLEET_IPS[@]}"; do
  echo "[$ip] Starting rotation..."

  RBTC_ADDR=$(rotate_rbtc "$ip")
  echo "  [rBTC] New address: $RBTC_ADDR"

  RNG_ADDR=$(rotate_rng "$ip")
  echo "  [RNG]  New address: $RNG_ADDR"

  NEW_RBTC_ADDRS["$ip"]="$RBTC_ADDR"
  NEW_RNG_ADDRS["$ip"]="$RNG_ADDR"

  # Verify both miners producing work
  echo "  Verifying miners..."
  ssh "${SSH_OPTS[@]}" "$SSH_USER@$ip" bash -s <<'VERIFY'
set -euo pipefail
RBTC_MINERS=$(pgrep -fc 'coinbase-addr.*127\.0\.0\.1:19332' || echo 0)
RNG_RUNNING=0
if /root/rng-cli -datadir=/root/.rng getblockcount >/dev/null 2>&1; then
  RNG_RUNNING=1
fi
RNG_MINING=$(grep '^mine=' /root/.rng/rng.conf | cut -d= -f2)
echo "  rBTC miners: $RBTC_MINERS, RNG daemon: $RNG_RUNNING (mine=$RNG_MINING)"
if [[ "$RBTC_MINERS" -eq 0 ]]; then
  echo "  WARN: rBTC miner not running" >&2
fi
if [[ "$RNG_RUNNING" -eq 0 ]]; then
  echo "  WARN: RNG daemon not reachable" >&2
fi
VERIFY

  echo "  [$ip] Rotation complete"
  echo
done

##############################################################################
# Phase 3: Collect addresses + backup new wallets
##############################################################################

echo "=== Phase 3: Collect addresses and backup new wallets ==="

ADDR_FILE="$MANIFEST/ADDRESSES.txt"
{
  echo "=== Treasury ==="
  echo "rBTC: $TREASURY_RBTC"
  echo "RNG:  $TREASURY_RNG"
  echo ""
  echo "=== Mining (node -> rBTC, RNG) ==="
} > "$ADDR_FILE"

RBTC_WALLET_DIR="$WALLET_DIR/rBTC"
RNG_WALLET_DIR="$WALLET_DIR/RNG"
mkdir -p "$RBTC_WALLET_DIR" "$RNG_WALLET_DIR"

for ip in "${FLEET_IPS[@]}"; do
  echo "[$ip] Collecting..."

  RBTC_ADDR=$(ssh "${SSH_OPTS[@]}" "$SSH_USER@$ip" "cat /root/.rbitcoin/mining_address")
  RNG_ADDR=$(ssh "${SSH_OPTS[@]}" "$SSH_USER@$ip" "cat /root/.rng/mining_address")

  echo "$ip: $RBTC_ADDR, $RNG_ADDR" >> "$ADDR_FILE"

  # Backup new rBTC wallet
  ssh "${SSH_OPTS[@]}" "$SSH_USER@$ip" bash -s <<'REMOTE'
set -euo pipefail
/opt/rbitcoin/build/bitcoin-cli -rpcwait -datadir=/root/.rbitcoin -rpcwallet=rbtc backupwallet "/tmp/rbtc-new-wallet-backup.dat"
REMOTE
  scp "${SSH_OPTS[@]}" "$SSH_USER@$ip:/tmp/rbtc-new-wallet-backup.dat" \
    "$RBTC_WALLET_DIR/${ip}-rbtc-wallet.dat"
  ssh "${SSH_OPTS[@]}" "$SSH_USER@$ip" "rm -f /tmp/rbtc-new-wallet-backup.dat"

  # Backup new RNG wallet
  ssh "${SSH_OPTS[@]}" "$SSH_USER@$ip" bash -s <<'REMOTE'
set -euo pipefail
/root/rng-cli -rpcwait -datadir=/root/.rng -rpcwallet=miner backupwallet "/tmp/rng-new-wallet-backup.dat"
REMOTE
  scp "${SSH_OPTS[@]}" "$SSH_USER@$ip:/tmp/rng-new-wallet-backup.dat" \
    "$RNG_WALLET_DIR/${ip}-rng-wallet.dat"
  ssh "${SSH_OPTS[@]}" "$SSH_USER@$ip" "rm -f /tmp/rng-new-wallet-backup.dat"

  echo "  done"
done

# Generate checksums
for dir in "$TREASURY_DIR" "$RBTC_WALLET_DIR" "$RNG_WALLET_DIR"; do
  if ls "$dir"/*.dat >/dev/null 2>&1; then
    (cd "$dir" && sha256sum *.dat > SHA256SUMS)
  fi
done

echo
echo "=== Rotation Complete ==="
echo "  Treasury addresses:"
echo "    rBTC: $TREASURY_RBTC"
echo "    RNG:  $TREASURY_RNG"
echo "  Address manifest: $ADDR_FILE"
echo "  Treasury backups: $TREASURY_DIR"
echo "  Wallet backups:   $WALLET_DIR"
echo "  Nodes rotated:    ${#FLEET_IPS[@]}"

rbtc_count=$(find "$RBTC_WALLET_DIR" -name '*.dat' 2>/dev/null | wc -l)
rng_count=$(find "$RNG_WALLET_DIR" -name '*.dat' 2>/dev/null | wc -l)
treasury_count=$(find "$TREASURY_DIR" -name '*.dat' 2>/dev/null | wc -l)
total=$((rbtc_count + rng_count + treasury_count))
echo "  Total wallet backups: $total (expected 22)"

echo
cat "$ADDR_FILE"
echo
echo "PASS: fleet wallet rotation completed"
