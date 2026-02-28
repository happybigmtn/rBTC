#!/usr/bin/env bash
set -euo pipefail

# Mining reward distribution report for rBTC and RNG chains.
# Runs on each fleet node via cron every 6 hours.
# Outputs to stdout and appends to /root/mining-reports/.

RBTC_CLI="/opt/rbitcoin/build/bitcoin-cli -datadir=/root/.rbitcoin"
RNG_CLI="/root/rng-cli -datadir=/root/.rng"

RBTC_CACHE_DIR="/root/.rbitcoin/stats"
RNG_CACHE_DIR="/root/.rng/stats"

REPORT_DIR="/root/mining-reports"
REPORT_FILE="$REPORT_DIR/$(date -u +%Y-%m-%d-%H%M%S).txt"
SIXHOUR_SECS=21600

if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: jq is required but not installed" >&2
  exit 1
fi

mkdir -p "$REPORT_DIR"

output() {
  echo "$1" | tee -a "$REPORT_FILE"
}

read_cache() {
  local cache_file="$1"
  if [[ -f "$cache_file" ]]; then
    if jq empty "$cache_file" 2>/dev/null; then
      cat "$cache_file"
      return
    fi
    echo "WARN: corrupt cache at $cache_file, reinitializing" >&2
  fi
  echo '{"last_height":0,"addresses":{}}'
}

write_cache() {
  local cache_file="$1"
  local data="$2"
  local cache_dir
  cache_dir="$(dirname "$cache_file")"
  mkdir -p "$cache_dir"
  local tmp
  tmp="$(mktemp "$cache_dir/.cache.XXXXXX")"
  echo "$data" > "$tmp"
  mv "$tmp" "$cache_file"
}

get_coinbase_address() {
  local cli="$1"
  local height="$2"
  local blockhash addr

  blockhash=$($cli getblockhash "$height" 2>/dev/null) || return 1
  # verbosity 2 includes full tx data, avoids separate getrawtransaction call
  addr=$($cli getblock "$blockhash" 2 2>/dev/null \
    | jq -r '.tx[0].vout[0].scriptPubKey.address // empty') || return 1

  if [[ -z "$addr" ]]; then
    echo "unknown"
  else
    echo "$addr"
  fi
}

format_distribution() {
  local json="$1"
  local total="$2"

  if [[ "$total" -eq 0 ]]; then
    output "  (no blocks)"
    return
  fi

  echo "$json" | jq -r 'to_entries | sort_by(-.value) | .[]
    | "\(.key) \(.value)"' | while read -r addr count; do
    pct=$(awk "BEGIN { printf \"%.2f\", ($count / $total) * 100 }")
    output "  $addr  $count blocks  ($pct%)"
  done
}

report_chain() {
  local chain_name="$1"
  local cli="$2"
  local cache_dir="$3"
  local cache_file="$cache_dir/mining_cache.json"

  if ! $cli getblockcount >/dev/null 2>&1; then
    output "[$chain_name] WARN: daemon unreachable, skipping"
    output ""
    return
  fi

  local tip_height
  tip_height=$($cli getblockcount)

  local cache
  cache=$(read_cache "$cache_file")
  local cached_height
  cached_height=$(echo "$cache" | jq -r '.last_height')
  local addresses
  addresses=$(echo "$cache" | jq -r '.addresses')

  # Cumulative update: process blocks since last cache
  local h=$((cached_height + 1))
  local new_blocks=0
  while [[ $h -le $tip_height ]]; do
    local addr
    addr=$(get_coinbase_address "$cli" "$h") || { addr="unknown"; }
    local cur_count
    cur_count=$(echo "$addresses" | jq -r --arg a "$addr" '.[$a] // 0')
    addresses=$(echo "$addresses" | jq --arg a "$addr" --argjson c $((cur_count + 1)) '.[$a] = $c')
    h=$((h + 1))
    new_blocks=$((new_blocks + 1))

    # Progress indicator every 500 blocks for large syncs
    if [[ $((new_blocks % 500)) -eq 0 ]]; then
      echo "  [$chain_name] processed $new_blocks new blocks..." >&2
    fi
  done

  local total_blocks
  total_blocks=$(echo "$addresses" | jq '[.[]] | add // 0')

  # Save updated cache
  local new_cache
  new_cache=$(jq -n --argjson h "$tip_height" --argjson a "$addresses" \
    '{"last_height": $h, "addresses": $a}')
  write_cache "$cache_file" "$new_cache"

  # Last 6 hours: walk backwards from tip
  local now
  now=$(date +%s)
  local cutoff=$((now - SIXHOUR_SECS))
  local recent_addrs='{}'
  local recent_count=0
  local scan_h=$tip_height

  while [[ $scan_h -ge 0 ]]; do
    local blockhash block_json block_time addr
    blockhash=$($cli getblockhash "$scan_h" 2>/dev/null) || break
    block_json=$($cli getblock "$blockhash" 2 2>/dev/null) || break
    block_time=$(echo "$block_json" | jq -r '.time')

    if [[ "$block_time" -lt "$cutoff" ]]; then
      break
    fi

    addr=$(echo "$block_json" | jq -r '.tx[0].vout[0].scriptPubKey.address // empty')
    if [[ -z "$addr" ]]; then addr="unknown"; fi
    local cur
    cur=$(echo "$recent_addrs" | jq -r --arg a "$addr" '.[$a] // 0')
    recent_addrs=$(echo "$recent_addrs" | jq --arg a "$addr" --argjson c $((cur + 1)) '.[$a] = $c')
    recent_count=$((recent_count + 1))
    scan_h=$((scan_h - 1))
  done

  output "=== $chain_name ==="
  output "  Height: $tip_height"
  output "  New blocks since last run: $new_blocks"
  output ""
  output "  --- Cumulative (all $total_blocks blocks) ---"
  format_distribution "$addresses" "$total_blocks"
  output ""
  output "  --- Last 6 hours ($recent_count blocks) ---"
  format_distribution "$recent_addrs" "$recent_count"
  output ""
}

output "========================================"
output "  Mining Report — $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
output "  Node: $(hostname) / $(hostname -I 2>/dev/null | awk '{print $1}')"
output "========================================"
output ""

report_chain "rBTC" "$RBTC_CLI" "$RBTC_CACHE_DIR"
report_chain "RNG"  "$RNG_CLI"  "$RNG_CACHE_DIR"

output "========================================"
output "  Report complete"
output "========================================"
