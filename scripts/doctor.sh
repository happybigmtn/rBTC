#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -x "$SCRIPT_DIR/bitcoin-cli" || -x "$SCRIPT_DIR/bitcoind" ]]; then
  ROOT_DIR="$SCRIPT_DIR"
else
  ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi
EXPECTED_GENESIS_HASH="6a934d6728eda510ec92aef31275c40cc7c84f2a7518749c07c347adadad3e45"
RBTC_DAEMON="${RBTC_DAEMON:-}"
RBTC_CLI="${RBTC_CLI:-}"
RBTC_DATADIR="${RBTC_DATADIR:-}"
RBTC_CONF="${RBTC_CONF:-}"
CLI_ARGS=()
HEALTHY=1
CONFIG_PATH=""
OUTPUT_JSON=0
STRICT=0
EXPECT_PUBLIC=0
EXPECT_MINER=0
WARNINGS=()

usage() {
  cat <<'EOF'
Verify that this node is pointed at the live rBTC mainnet and ready to serve peers.

Usage:
  ./scripts/doctor.sh [--datadir DIR] [--conf PATH] [--json] [--strict] [--expect-public] [--expect-miner]
  rbtc-doctor [--datadir DIR] [--conf PATH] [--json] [--strict] [--expect-public] [--expect-miner]

Environment:
  RBTC_DAEMON   bitcoind binary path
  RBTC_CLI      bitcoin-cli binary path
  RBTC_DATADIR  Optional datadir to pass to bitcoin-cli
  RBTC_CONF     Optional config path to pass to bitcoin-cli
EOF
}

info() {
  if [[ "$OUTPUT_JSON" -eq 0 ]]; then
    printf '[INFO] %s\n' "$1"
  fi
}
warn() {
  if [[ "$OUTPUT_JSON" -eq 0 ]]; then
    printf '[WARN] %s\n' "$1"
  fi
  HEALTHY=0
  WARNINGS+=("$1")
}
error() { printf '[ERROR] %s\n' "$1" >&2; exit 1; }

resolve_defaults() {
  if [[ -z "$RBTC_DAEMON" ]]; then
    if [[ -x "$ROOT_DIR/build/bitcoind" ]]; then
      RBTC_DAEMON="$ROOT_DIR/build/bitcoind"
    elif [[ -x "$ROOT_DIR/bitcoind" ]]; then
      RBTC_DAEMON="$ROOT_DIR/bitcoind"
    else
      RBTC_DAEMON="bitcoind"
    fi
  fi

  if [[ -z "$RBTC_CLI" ]]; then
    if [[ -x "$ROOT_DIR/build/bitcoin-cli" ]]; then
      RBTC_CLI="$ROOT_DIR/build/bitcoin-cli"
    elif [[ -x "$ROOT_DIR/bitcoin-cli" ]]; then
      RBTC_CLI="$ROOT_DIR/bitcoin-cli"
    else
      RBTC_CLI="bitcoin-cli"
    fi
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --datadir)
        [[ $# -ge 2 ]] || error "--datadir requires a path"
        RBTC_DATADIR="$2"
        shift 2
        ;;
      --conf)
        [[ $# -ge 2 ]] || error "--conf requires a path"
        RBTC_CONF="$2"
        shift 2
        ;;
      --json)
        OUTPUT_JSON=1
        shift
        ;;
      --strict)
        STRICT=1
        shift
        ;;
      --expect-public)
        EXPECT_PUBLIC=1
        shift
        ;;
      --expect-miner)
        EXPECT_MINER=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        error "Unknown argument: $1"
        ;;
    esac
  done
}

append_common_args() {
  if [[ -n "$RBTC_DATADIR" ]]; then
    CLI_ARGS+=("-datadir=$RBTC_DATADIR")
  fi
  if [[ -n "$RBTC_CONF" ]]; then
    CLI_ARGS+=("-conf=$RBTC_CONF")
  fi
}

cli() {
  "$RBTC_CLI" "${CLI_ARGS[@]}" "$@"
}

extract_json_string() {
  sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p"
}

extract_json_number() {
  sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\\([-0-9][0-9]*\\).*/\\1/p"
}

extract_json_bool() {
  sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\\(true\\|false\\).*/\\1/p"
}

resolve_config_path() {
  CONFIG_PATH="$HOME/.rbitcoin/bitcoin.conf"
  if [[ -n "$RBTC_CONF" ]]; then
    CONFIG_PATH="$RBTC_CONF"
  elif [[ -n "$RBTC_DATADIR" && -f "$RBTC_DATADIR/bitcoin.conf" ]]; then
    CONFIG_PATH="$RBTC_DATADIR/bitcoin.conf"
  fi
}

config_value() {
  local key="$1"
  resolve_config_path
  [[ -f "$CONFIG_PATH" ]] || return 1
  sed -n "s/^[[:space:]]*$key[[:space:]]*=[[:space:]]*//p" "$CONFIG_PATH" | tail -1
}

count_localaddresses() {
  awk '
    /"localaddresses"[[:space:]]*:/ {in_local=1; next}
    in_local && /"address"[[:space:]]*:/ {count++}
    in_local && /^[[:space:]]*]/ {in_local=0}
    END {print count + 0}
  '
}

warnings_json() {
  python3 - <<'PY' "${WARNINGS[@]}"
import json
import sys
print(json.dumps(sys.argv[1:]))
PY
}

print_json_status() {
  local chain_ok="$1"
  local rpc_ok="$2"
  local public_reachable="$3"
  local miner_configured="$4"
  local miner_running="$5"
  local ready="$6"
  local warning_json="$7"
  local services_json="$8"

  python3 - "$chain_ok" "$rpc_ok" "$public_reachable" "$miner_configured" \
    "$miner_running" "$ready" "${connection_count:-0}" \
    "${inbound:-0}" "${outbound:-0}" "${localaddresses:-0}" \
    "${blocks:-0}" "${headers:-0}" "${chain_name:-unknown}" \
    "${version_line:-}" "${miner_proc:-}" "$warning_json" "$services_json" <<'PY'
import json
import sys

payload = {
    "chain_ok": sys.argv[1] == "true",
    "rpc_ok": sys.argv[2] == "true",
    "public_reachable": sys.argv[3] == "true",
    "miner_configured": sys.argv[4] == "true",
    "miner_running": sys.argv[5] == "true",
    "ready": sys.argv[6] == "true",
    "peer_count": int(sys.argv[7]),
    "connections_in": int(sys.argv[8]),
    "connections_out": int(sys.argv[9]),
    "advertised_local_addresses": int(sys.argv[10]),
    "blocks": int(sys.argv[11]),
    "headers": int(sys.argv[12]),
    "chain": sys.argv[13],
    "version": sys.argv[14],
    "miner_process": sys.argv[15],
    "warnings": json.loads(sys.argv[16]),
    "services": json.loads(sys.argv[17]),
}
print(json.dumps(payload, indent=2))
PY
}

main() {
  local version_line genesis_hash connection_count blockchaininfo networkinfo
  local chain_name blocks headers ibd inbound outbound localaddresses listen_value
  local miner_proc chain_ok rpc_ok public_reachable miner_configured miner_running
  local ready warning_json services_json

  parse_args "$@"
  resolve_defaults
  append_common_args

  command -v "$RBTC_DAEMON" >/dev/null 2>&1 || error "bitcoind binary not found: $RBTC_DAEMON"
  command -v "$RBTC_CLI" >/dev/null 2>&1 || error "bitcoin-cli binary not found: $RBTC_CLI"

  version_line="$("$RBTC_DAEMON" --version 2>/dev/null | head -1 || true)"
  [[ -n "$version_line" ]] && info "$version_line"

  rpc_ok=true
  if ! cli getblockcount >/dev/null 2>&1; then
    rpc_ok=false
    chain_ok=false
    public_reachable=false
    miner_configured=false
    miner_running=false
    ready=false
    warn "RPC is not reachable. Start the daemon first:"
    if [[ "$OUTPUT_JSON" -eq 0 ]]; then
      printf '       %s -daemon -datadir=%s\n' "$RBTC_DAEMON" "${RBTC_DATADIR:-$HOME/.rbitcoin}"
    fi
    warning_json="$(warnings_json)"
    services_json='{"bitcoind":"unreachable","rbtc-cpuminer":"unknown"}'
    if [[ "$OUTPUT_JSON" -eq 1 ]]; then
      print_json_status "$chain_ok" "$rpc_ok" "$public_reachable" \
        "$miner_configured" "$miner_running" "$ready" \
        "$warning_json" "$services_json"
    fi
    exit 1
  fi

  genesis_hash="$(cli getblockhash 0 2>/dev/null || true)"
  if [[ "$genesis_hash" == "$EXPECTED_GENESIS_HASH" ]]; then
    chain_ok=true
    info "Genesis hash matches live mainnet: $genesis_hash"
  else
    chain_ok=false
    warn "Unexpected genesis hash: ${genesis_hash:-<empty>}"
    printf '       expected: %s\n' "$EXPECTED_GENESIS_HASH"
  fi

  connection_count="$(cli getconnectioncount 2>/dev/null || echo 0)"
  if [[ "${connection_count:-0}" -gt 0 ]]; then
    info "Peer connections: $connection_count"
  else
    warn "No peer connections yet. Check addnode entries or the public seed fleet."
  fi

  blockchaininfo="$(cli getblockchaininfo 2>/dev/null || true)"
  chain_name="$(printf '%s\n' "$blockchaininfo" | extract_json_string chain | head -1)"
  blocks="$(printf '%s\n' "$blockchaininfo" | extract_json_number blocks | head -1)"
  headers="$(printf '%s\n' "$blockchaininfo" | extract_json_number headers | head -1)"
  ibd="$(printf '%s\n' "$blockchaininfo" | extract_json_bool initialblockdownload | head -1)"

  [[ -n "$chain_name" ]] && info "Chain: $chain_name"
  [[ -n "$blocks" ]] && info "Blocks: $blocks"
  [[ -n "$headers" ]] && info "Headers: $headers"
  [[ -n "$ibd" ]] && info "Initial block download: $ibd"

  networkinfo="$(cli getnetworkinfo 2>/dev/null || true)"
  inbound="$(printf '%s\n' "$networkinfo" | extract_json_number connections_in | head -1)"
  outbound="$(printf '%s\n' "$networkinfo" | extract_json_number connections_out | head -1)"
  localaddresses="$(printf '%s\n' "$networkinfo" | count_localaddresses)"
  listen_value="$(config_value listen || true)"

  [[ -n "$inbound" ]] && info "Inbound peers: $inbound"
  [[ -n "$outbound" ]] && info "Outbound peers: $outbound"
  info "Advertised local addresses: ${localaddresses:-0}"

  if [[ "${listen_value:-1}" == "0" ]]; then
    warn "Config sets listen=0. This node can mine, but it will not accept inbound peers."
  elif [[ "${localaddresses:-0}" -eq 0 || "${inbound:-0}" -eq 0 ]]; then
    info "This node is not currently visible as a public peer. If this is a public VPS, keep listen=1 and open TCP/19333."
  fi

  if [[ "${listen_value:-1}" != "0" && "${localaddresses:-0}" -gt 0 && "${inbound:-0}" -gt 0 ]]; then
    public_reachable=true
  else
    public_reachable=false
    if [[ "$EXPECT_PUBLIC" -eq 1 ]]; then
      warn "Expected a public node, but inbound reachability is not yet proven"
    fi
  fi

  miner_proc="$(pgrep -fa 'cpuminer|minerd' | head -n1 || true)"
  if [[ -n "$miner_proc" ]]; then
    miner_configured=true
    miner_running=true
    info "Detected CPU miner process: $miner_proc"
  else
    miner_configured=false
    miner_running=false
    warn "No local CPU miner process detected. Start one with rbtc-start-cpu-miner or install rbtc-cpuminer.service."
  fi

  ready=false
  if [[ "$chain_ok" == true && "$rpc_ok" == true && "${connection_count:-0}" -gt 0 ]] && \
     { [[ "$EXPECT_PUBLIC" -eq 0 ]] || [[ "$public_reachable" == true ]]; } && \
     { [[ "$EXPECT_MINER" -eq 0 ]] || [[ "$miner_running" == true ]]; }; then
    ready=true
  fi

  services_json="$(python3 - <<'PY' "${miner_proc:-}"
import json
import sys
print(json.dumps({"bitcoind": "reachable", "rbtc-cpuminer": {"process": sys.argv[1]}}))
PY
)"
  warning_json="$(warnings_json)"

  if [[ "$OUTPUT_JSON" -eq 1 ]]; then
    print_json_status "$chain_ok" "$rpc_ok" "$public_reachable" \
      "$miner_configured" "$miner_running" "$ready" \
      "$warning_json" "$services_json"
  fi

  if [[ "$ready" == true ]]; then
    info "Node looks healthy for the live rBTC network"
    exit 0
  fi

  if [[ "$STRICT" -eq 1 || "$EXPECT_PUBLIC" -eq 1 || "$EXPECT_MINER" -eq 1 ]]; then
    exit 1
  fi

  warn "Node needs attention before it is fully ready for public mining"
  exit 1
}

main "$@"
