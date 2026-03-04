#!/usr/bin/env bash
set -euo pipefail

# Sweep rBTC from all Contabo fleet wallets into dedicated treasury wallets.
#
# Creates one treasury wallet per Contabo node (10 total) on the sweep node,
# then sends funds from each node's rbtc + rbtc-archived wallets to the
# corresponding treasury address. Miners keep running with their current
# pinned addresses — only accumulated balances are moved.
#
# For active nodes: sends via SSH + RPC on the node itself.
# For decommissioned nodes: loads wallet backups onto the sweep node temporarily.
#
# Treasury wallets persist across runs. Re-running with --sweep after a --test
# reuses the same treasury addresses.
#
# Modes:
#   --test       Send TEST_AMOUNT rBTC per wallet (default: 1)
#   --sweep      Send full balance from each wallet
#   --dry-run    Report balances only, no transactions
#
# Usage:
#   ./sweep_to_treasury.sh                        # test (1 rBTC each)
#   ./sweep_to_treasury.sh --sweep                # full sweep
#   ./sweep_to_treasury.sh --dry-run              # preview only
#   TEST_AMOUNT=5 ./sweep_to_treasury.sh --test   # custom test amount

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLEET_CONF="${FLEET_CONF:-$ROOT_DIR/scripts/fleet.conf}"
KEY_PATH="${FLEET_SSH_KEY:-$HOME/.ssh/contabo-mining-fleet}"
SSH_USER="${FLEET_SSH_USER:-root}"
BACKUP_BASE="${BACKUP_DIR:-$HOME/.backups}"
TIMESTAMP="$(date -u +%Y%m%d-%H%M%S)"

RBTC_CLI="/opt/rbitcoin/build/bitcoin-cli -datadir=/root/.rbitcoin"
WALLETS_PATH="/root/.rbitcoin/rbitcoin/wallets"

declare -a DECOMM_IPS=(
  "161.97.83.147"
  "161.97.97.83"
  "95.111.227.14"
  "95.111.229.108"
)

TEST_AMOUNT="${TEST_AMOUNT:-1}"
FEE_RATE="${FEE_RATE:-10}"
MODE="test"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --test)    MODE="test"; shift ;;
    --sweep)   MODE="sweep"; shift ;;
    --dry-run) MODE="dry-run"; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ ! -f "$FLEET_CONF" ]]; then
  echo "FAIL: fleet config not found at $FLEET_CONF" >&2
  exit 1
fi
source "$FLEET_CONF"

if [[ ${#FLEET_IPS[@]} -eq 0 ]]; then
  echo "FAIL: FLEET_IPS empty in $FLEET_CONF" >&2
  exit 1
fi

if [[ ! -f "$KEY_PATH" ]]; then
  echo "FAIL: SSH key not found at $KEY_PATH" >&2
  exit 1
fi

ALL_IPS=("${FLEET_IPS[@]}" "${DECOMM_IPS[@]}")
SWEEP_NODE="${FLEET_IPS[0]}"

SSH_OPTS=(
  -i "$KEY_PATH"
  -o BatchMode=yes
  -o ConnectTimeout=15
  -o StrictHostKeyChecking=no
)

# Treasury state persists across runs (test -> sweep reuses same addresses)
TREASURY_DIR="$BACKUP_BASE/treasury-sweep"
MANIFEST="$TREASURY_DIR/MANIFEST.txt"
REPORT_FILE="$BACKUP_BASE/reports/sweep-$TIMESTAMP.log"

mkdir -p "$TREASURY_DIR" "$(dirname "$REPORT_FILE")"

log() {
  local msg="[$(date -u '+%H:%M:%S')] $*"
  echo "$msg"
  echo "$msg" >> "$REPORT_FILE"
}

remote() {
  local ip="$1"; shift
  ssh "${SSH_OPTS[@]}" "$SSH_USER@$ip" "$@"
}

is_decomm() {
  local ip="$1"
  for d in "${DECOMM_IPS[@]}"; do
    [[ "$d" == "$ip" ]] && return 0
  done
  return 1
}

# Map IP to index (001-010) for treasury wallet naming
wallet_index() {
  local ip="$1"
  for i in "${!ALL_IPS[@]}"; do
    if [[ "${ALL_IPS[$i]}" == "$ip" ]]; then
      printf "%03d" $((i + 1))
      return
    fi
  done
  echo "FAIL: IP $ip not in ALL_IPS" >&2
  return 1
}

declare -A TREASURY_ADDRS=()
declare -A TX_LOG=()
SEND_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0

##############################################################################
# Phase 1: Create or reuse treasury wallets
##############################################################################

log "========================================"
log "  Sweep to Treasury — $MODE mode"
log "========================================"
log ""

if [[ -f "$MANIFEST" ]]; then
  log "=== Phase 1: Loading existing treasury wallets from $MANIFEST ==="
  while IFS=$'\t' read -r ip addr; do
    TREASURY_ADDRS["$ip"]="$addr"
    idx=$(wallet_index "$ip")
    log "  treasury-$idx ($ip) -> $addr"
  done < "$MANIFEST"

  # Verify all IPs have addresses
  for ip in "${ALL_IPS[@]}"; do
    if [[ -z "${TREASURY_ADDRS[$ip]:-}" ]]; then
      echo "FAIL: missing treasury address for $ip in $MANIFEST" >&2
      exit 1
    fi
  done
else
  log "=== Phase 1: Creating ${#ALL_IPS[@]} treasury wallets on $SWEEP_NODE ==="

  for ip in "${ALL_IPS[@]}"; do
    idx=$(wallet_index "$ip")
    wallet_name="treasury-$idx"

    addr=$(remote "$SWEEP_NODE" bash -s <<REMOTE
set -euo pipefail
CLI="$RBTC_CLI"
\$CLI unloadwallet "$wallet_name" 2>/dev/null || true
if \$CLI listwalletdir | grep -q '"$wallet_name"'; then
  \$CLI loadwallet "$wallet_name" >/dev/null
else
  \$CLI -named createwallet wallet_name="$wallet_name" >/dev/null
fi
ADDR=\$(\$CLI -rpcwallet=$wallet_name getnewaddress "" legacy)
\$CLI -rpcwallet=$wallet_name backupwallet "/tmp/$wallet_name-backup.dat"
\$CLI unloadwallet "$wallet_name" >/dev/null
echo "\$ADDR"
REMOTE
    )

    TREASURY_ADDRS["$ip"]="$addr"

    scp "${SSH_OPTS[@]}" "$SSH_USER@$SWEEP_NODE:/tmp/$wallet_name-backup.dat" \
      "$TREASURY_DIR/$wallet_name.dat"
    remote "$SWEEP_NODE" "rm -f /tmp/$wallet_name-backup.dat"

    log "  $wallet_name ($ip) -> $addr"
  done

  # Write persistent manifest (tab-separated: ip\taddress)
  for ip in "${ALL_IPS[@]}"; do
    printf '%s\t%s\n' "$ip" "${TREASURY_ADDRS[$ip]}"
  done > "$MANIFEST"

  # Checksums for wallet backups
  (cd "$TREASURY_DIR" && sha256sum *.dat > SHA256SUMS)
  log "  Backups saved to $TREASURY_DIR"
fi

[[ "$MODE" == "test" ]] && log "  Test amount: $TEST_AMOUNT rBTC per wallet"
log ""

##############################################################################
# Helpers
##############################################################################

ensure_wallet_loaded() {
  local ip="$1"
  local wallet="$2"
  if ! remote "$ip" "$RBTC_CLI listwallets" 2>/dev/null | grep -q "\"$wallet\""; then
    remote "$ip" "$RBTC_CLI loadwallet \"$wallet\"" >/dev/null 2>&1 || return 1
  fi
  return 0
}

# Load a local .dat backup onto the sweep node as a temporary wallet.
# Descriptor wallets rescan automatically on first load — for rBTC's short
# chain (~18k blocks) this completes in seconds.
load_backup_wallet() {
  local backup_path="$1"
  local temp_name="$2"

  if [[ ! -f "$backup_path" ]]; then
    log "    SKIP: backup not found at $backup_path"
    return 1
  fi

  remote "$SWEEP_NODE" "$RBTC_CLI unloadwallet \"$temp_name\"" 2>/dev/null || true
  remote "$SWEEP_NODE" "rm -rf $WALLETS_PATH/$temp_name" 2>/dev/null || true

  remote "$SWEEP_NODE" "mkdir -p $WALLETS_PATH/$temp_name"
  scp "${SSH_OPTS[@]}" "$backup_path" \
    "$SSH_USER@$SWEEP_NODE:$WALLETS_PATH/$temp_name/wallet.dat"

  if ! remote "$SWEEP_NODE" "$RBTC_CLI loadwallet \"$temp_name\"" >/dev/null 2>&1; then
    log "    FAIL: could not load $temp_name on $SWEEP_NODE"
    remote "$SWEEP_NODE" "rm -rf $WALLETS_PATH/$temp_name" 2>/dev/null || true
    return 1
  fi

  # Brief pause for rescan to settle
  sleep 2
  return 0
}

unload_backup_wallet() {
  local temp_name="$1"
  remote "$SWEEP_NODE" "$RBTC_CLI unloadwallet \"$temp_name\"" 2>/dev/null || true
  remote "$SWEEP_NODE" "rm -rf $WALLETS_PATH/$temp_name" 2>/dev/null || true
}

send_from_wallet() {
  local exec_ip="$1"
  local wallet_name="$2"
  local to_addr="$3"
  local label="$4"

  local balance
  balance=$(remote "$exec_ip" "$RBTC_CLI -rpcwallet=$wallet_name getbalance" 2>/dev/null) || {
    log "    FAIL: could not query balance for $wallet_name on $exec_ip"
    ((FAIL_COUNT++)) || true
    return 1
  }

  log "    $label: $balance rBTC"

  local is_zero
  is_zero=$(awk "BEGIN { print ($balance + 0 == 0) ? 1 : 0 }")
  if [[ "$is_zero" == "1" ]]; then
    log "    SKIP: zero balance"
    ((SKIP_COUNT++)) || true
    return 0
  fi

  if [[ "$MODE" == "dry-run" ]]; then
    return 0
  fi

  if [[ "$MODE" != "sweep" ]]; then
    local sufficient
    sufficient=$(awk "BEGIN { print ($balance + 0 >= $TEST_AMOUNT + 0) ? 1 : 0 }")
    if [[ "$sufficient" != "1" ]]; then
      log "    SKIP: insufficient balance ($balance < $TEST_AMOUNT)"
      ((SKIP_COUNT++)) || true
      return 0
    fi

    local txid
    txid=$(remote "$exec_ip" \
      "$RBTC_CLI -rpcwallet=$wallet_name -named sendtoaddress \
        address=\"$to_addr\" amount=$TEST_AMOUNT fee_rate=$FEE_RATE" \
    ) || {
      log "    FAIL: sendtoaddress failed for $wallet_name"
      ((FAIL_COUNT++)) || true
      return 1
    }

    log "    SENT: $TEST_AMOUNT rBTC -> txid $txid"
    TX_LOG["$label"]="$txid"
    ((SEND_COUNT++)) || true
    return 0
  fi

  # Sweep mode: send in chunks to stay under max transaction weight.
  # ~600 P2PKH inputs fit in one tx, each coinbase UTXO is 50 rBTC.
  # After 2 rapid chunks the mempool descendant limit blocks further
  # sends until a block confirms, so we retry with a wait on that error.
  local CHUNK=30000
  local chunk_num=0

  while true; do
    local remaining
    remaining=$(remote "$exec_ip" "$RBTC_CLI -rpcwallet=$wallet_name getbalance" 2>/dev/null)
    local done_check
    done_check=$(awk "BEGIN { print ($remaining + 0 == 0) ? 1 : 0 }")
    [[ "$done_check" == "1" ]] && break

    local needs_chunk
    needs_chunk=$(awk "BEGIN { print ($remaining + 0 > $CHUNK) ? 1 : 0 }")

    local send_cmd
    if [[ "$needs_chunk" == "1" ]]; then
      send_cmd="$RBTC_CLI -rpcwallet=$wallet_name -named sendtoaddress \
        address=\"$to_addr\" amount=$CHUNK fee_rate=$FEE_RATE"
    else
      send_cmd="$RBTC_CLI -rpcwallet=$wallet_name -named sendtoaddress \
        address=\"$to_addr\" amount=$remaining subtractfeefromamount=true fee_rate=$FEE_RATE"
    fi

    local result
    result=$(remote "$exec_ip" "$send_cmd" 2>&1) || true

    if echo "$result" | grep -q "descendant size limit\|exceeds the maximum weight"; then
      log "    Mempool limit hit — waiting for block confirmation..."
      local start_h
      start_h=$(remote "$exec_ip" "$RBTC_CLI getblockcount")
      while true; do
        sleep 10
        local cur_h
        cur_h=$(remote "$exec_ip" "$RBTC_CLI getblockcount" 2>/dev/null || echo "$start_h")
        if [[ "$cur_h" -gt "$start_h" ]]; then
          log "    Block $cur_h confirmed, resuming..."
          break
        fi
      done
      continue
    fi

    if echo "$result" | grep -q "^error\|FAIL"; then
      log "    FAIL: send failed — $result"
      ((FAIL_COUNT++)) || true
      return 1
    fi

    local txid="$result"
    chunk_num=$((chunk_num + 1))
    if [[ "$needs_chunk" == "1" ]]; then
      log "    SENT: $CHUNK rBTC (chunk $chunk_num) -> txid $txid"
    else
      log "    SENT: $remaining rBTC (final) -> txid $txid"
    fi

    TX_LOG["${label}#${chunk_num}"]="$txid"
    ((SEND_COUNT++)) || true

    [[ "$needs_chunk" != "1" ]] && break
  done
}

##############################################################################
# Phase 2: Sweep active nodes
##############################################################################

log "=== Phase 2: Sweep active nodes ==="

for ip in "${FLEET_IPS[@]}"; do
  idx=$(wallet_index "$ip")
  treasury_addr="${TREASURY_ADDRS[$ip]}"
  log "  [$ip] -> treasury-$idx ($treasury_addr)"

  # Current mining wallet
  if ensure_wallet_loaded "$ip" "rbtc"; then
    send_from_wallet "$ip" "rbtc" "$treasury_addr" "$ip/rbtc"
  else
    log "    SKIP: could not load rbtc on $ip"
    ((SKIP_COUNT++)) || true
  fi

  # Archived (pre-rotation) wallet
  if ensure_wallet_loaded "$ip" "rbtc-archived"; then
    send_from_wallet "$ip" "rbtc-archived" "$treasury_addr" "$ip/rbtc-archived"
  else
    log "    SKIP: rbtc-archived not available on $ip"
    ((SKIP_COUNT++)) || true
  fi

  log ""
done

##############################################################################
# Phase 3: Sweep decommissioned nodes (via backup loading on sweep node)
##############################################################################

log "=== Phase 3: Sweep decommissioned nodes (via $SWEEP_NODE) ==="

for ip in "${DECOMM_IPS[@]}"; do
  idx=$(wallet_index "$ip")
  treasury_addr="${TREASURY_ADDRS[$ip]}"
  log "  [$ip] -> treasury-$idx ($treasury_addr)"

  # Current wallet backup
  current_backup="$BACKUP_BASE/rBTC/current/${ip}-rbtc.dat"
  temp_current="sweep-${ip}-rbtc"
  if load_backup_wallet "$current_backup" "$temp_current"; then
    send_from_wallet "$SWEEP_NODE" "$temp_current" "$treasury_addr" "$ip/rbtc"
    unload_backup_wallet "$temp_current"
  else
    ((SKIP_COUNT++)) || true
  fi

  # Archived wallet backup
  archived_backup="$BACKUP_BASE/rBTC/archived/${ip}-rbtc-archived.dat"
  temp_archived="sweep-${ip}-rbtc-archived"
  if load_backup_wallet "$archived_backup" "$temp_archived"; then
    send_from_wallet "$SWEEP_NODE" "$temp_archived" "$treasury_addr" "$ip/rbtc-archived"
    unload_backup_wallet "$temp_archived"
  else
    ((SKIP_COUNT++)) || true
  fi

  log ""
done

##############################################################################
# Phase 4: Summary
##############################################################################

log "========================================"
log "  Summary"
log "========================================"
log "  Mode:         $MODE"
log "  Sent:         $SEND_COUNT"
log "  Skipped:      $SKIP_COUNT"
log "  Failed:       $FAIL_COUNT"
log "  Treasury dir: $TREASURY_DIR"
log "  Report:       $REPORT_FILE"

if [[ $SEND_COUNT -gt 0 ]]; then
  log ""
  log "  Transactions:"
  for label in $(echo "${!TX_LOG[@]}" | tr ' ' '\n' | sort); do
    log "    $label: ${TX_LOG[$label]}"
  done
fi

log ""
if [[ $FAIL_COUNT -gt 0 ]]; then
  log "  WARNING: $FAIL_COUNT operations failed — review log above"
  log "========================================"
  exit 1
fi

if [[ "$MODE" == "dry-run" ]]; then
  log "  DRY RUN — no transactions executed"
elif [[ "$MODE" == "test" ]]; then
  log "  Test transfers complete. Verify txids above, then run:"
  log "    $0 --sweep"
fi

log "========================================"
