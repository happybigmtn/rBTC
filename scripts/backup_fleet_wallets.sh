#!/usr/bin/env bash
set -euo pipefail

# Consolidated wallet backup: SSH into each fleet node, call backupwallet
# RPC for both rBTC and RNG chains, download locally, generate checksums.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY_PATH="${FLEET_SSH_KEY:-$HOME/.ssh/contabo-mining-fleet}"
SSH_USER="${FLEET_SSH_USER:-root}"
BACKUP_BASE="${BACKUP_DIR:-$HOME/.backups/wallet-backups-consolidated}"
TIMESTAMP="$(date -u +%Y%m%d-%H%M%S)"

FLEET_CONF="${FLEET_CONF:-$ROOT_DIR/scripts/fleet.conf}"
if [[ ! -f "$FLEET_CONF" ]]; then
  echo "FAIL: fleet config not found at $FLEET_CONF (copy fleet.conf.example)" >&2
  exit 1
fi
source "$FLEET_CONF"

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

RBTC_DIR="$BACKUP_BASE/rBTC/rbtc-wallets-$TIMESTAMP"
RNG_DIR="$BACKUP_BASE/RNG/rng-wallets-$TIMESTAMP"
mkdir -p "$RBTC_DIR" "$RNG_DIR"

backup_one() {
  local ip="$1"

  ssh "${SSH_OPTS[@]}" "$SSH_USER@$ip" bash -s <<'REMOTE'
set -euo pipefail

backup_chain() {
  local label="$1"
  local cli="$2"
  local datadir="$3"
  local wallet_name="$4"
  local dest="/tmp/${label}-wallet-backup.dat"

  if ! $cli getblockcount >/dev/null 2>&1; then
    echo "  [$label] SKIP: daemon unreachable"
    return 1
  fi

  # Ensure wallet is loaded
  if ! $cli listwallets | grep -q "\"$wallet_name\""; then
    if $cli listwalletdir | grep -q "\"$wallet_name\""; then
      $cli loadwallet "$wallet_name" >/dev/null
    else
      echo "  [$label] SKIP: wallet '$wallet_name' not found"
      return 1
    fi
  fi

  rm -f "$dest"
  $cli -rpcwallet="$wallet_name" backupwallet "$dest"
  echo "  [$label] BACKUP_OK $dest"
}

backup_chain "rBTC" "/opt/rbitcoin/build/bitcoin-cli -rpcwait -datadir=/root/.rbitcoin" "/root/.rbitcoin" "rbtc"
backup_chain "RNG"  "/root/rng-cli -rpcwait -datadir=/root/.rng" "/root/.rng" "rbtc"
REMOTE

  # Download backup files
  local rbtc_local="$RBTC_DIR/${ip}-rbtc-wallet.dat"
  local rng_local="$RNG_DIR/${ip}-rng-wallet.dat"

  if scp "${SSH_OPTS[@]}" "$SSH_USER@$ip:/tmp/rBTC-wallet-backup.dat" "$rbtc_local" 2>/dev/null; then
    echo "  [$ip] rBTC downloaded"
  else
    echo "  [$ip] rBTC download FAILED (daemon may have been unreachable)"
  fi

  if scp "${SSH_OPTS[@]}" "$SSH_USER@$ip:/tmp/RNG-wallet-backup.dat" "$rng_local" 2>/dev/null; then
    echo "  [$ip] RNG downloaded"
  else
    echo "  [$ip] RNG download FAILED (daemon may have been unreachable)"
  fi

  # Clean up remote temp files
  ssh "${SSH_OPTS[@]}" "$SSH_USER@$ip" "rm -f /tmp/rBTC-wallet-backup.dat /tmp/RNG-wallet-backup.dat" 2>/dev/null || true
}

failed=0

for ip in "${FLEET_IPS[@]}"; do
  echo "[$ip]"
  if backup_one "$ip"; then
    echo "  done"
  else
    echo "  PARTIAL (check output above)"
    failed=1
  fi
  echo
done

# Generate checksums and source manifest
for dir in "$RBTC_DIR" "$RNG_DIR"; do
  if ls "$dir"/*.dat >/dev/null 2>&1; then
    (cd "$dir" && sha256sum *.dat > SHA256SUMS)

    {
      echo "Backup timestamp: $TIMESTAMP"
      echo "Source nodes:"
      for ip in "${FLEET_IPS[@]}"; do
        echo "  $ip"
      done
    } > "$dir/SOURCES.txt"

    echo "Checksums written: $dir/SHA256SUMS"
  fi
done

echo
echo "Backup location:"
echo "  rBTC: $RBTC_DIR"
echo "  RNG:  $RNG_DIR"

rbtc_count=$(find "$RBTC_DIR" -name '*.dat' 2>/dev/null | wc -l)
rng_count=$(find "$RNG_DIR" -name '*.dat' 2>/dev/null | wc -l)
echo "  rBTC wallets: $rbtc_count / ${#FLEET_IPS[@]}"
echo "  RNG wallets:  $rng_count / ${#FLEET_IPS[@]}"

if [[ "$failed" -ne 0 ]]; then
  echo
  echo "WARN: some backups failed (see output above)" >&2
  exit 1
fi

echo
echo "PASS: all wallet backups consolidated"
