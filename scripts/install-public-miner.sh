#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -x "$SCRIPT_DIR/rbtc-ensure-cpu-miner" ]]; then
  HELPER_ROOT="$SCRIPT_DIR"
else
  HELPER_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

SERVICE_NAME="${RBTC_MINER_SERVICE_NAME:-rbtc-cpuminer.service}"
NODE_SERVICE_NAME="${RBTC_NODE_SERVICE_NAME:-rbtc-bitcoind.service}"
SERVICE_DIR="${RBTC_SYSTEMD_DIR:-/etc/systemd/system}"
INSTALL_BIN_DIR="${RBTC_SYSTEM_BIN_DIR:-/usr/local/bin}"
CONFIG_DIR="${RBTC_SYSTEM_CONFIG_DIR:-/etc/rbitcoin}"
DATA_DIR="${RBTC_SYSTEM_DATA_DIR:-/var/lib/rbitcoin}"
SERVICE_USER="${RBTC_SERVICE_USER:-rbtc}"
SERVICE_GROUP="${RBTC_SERVICE_GROUP:-$SERVICE_USER}"
MINE_ADDRESS="${RBTC_MINEADDRESS:-}"
THREADS="${RBTC_MINER_THREADS:-}"
CPU_PERCENT="${RBTC_MINER_CPU_PERCENT:-25}"
MAX_THREADS="${RBTC_MINER_MAX_THREADS:-20}"
ENABLE_NOW=0
REMOVE_SERVICE=0

usage() {
  cat <<'EOF'
Install or remove a persistent rBTC CPU-miner systemd service.

Usage:
  sudo ./scripts/install-public-miner.sh --address RBTC_ADDRESS [--threads N] [--enable-now]
  sudo rbtc-install-public-miner --address RBTC_ADDRESS [--threads N] [--enable-now]
  sudo rbtc-install-public-miner --remove
EOF
}

info() { printf '[INFO] %s\n' "$1"; }
error() { printf '[ERROR] %s\n' "$1" >&2; exit 1; }

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --address)
        [[ $# -ge 2 ]] || error "--address requires a value"
        MINE_ADDRESS="$2"
        shift 2
        ;;
      --threads)
        [[ $# -ge 2 ]] || error "--threads requires a value"
        THREADS="$2"
        shift 2
        ;;
      --enable-now)
        ENABLE_NOW=1
        shift
        ;;
      --remove)
        REMOVE_SERVICE=1
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

require_root() {
  [[ "$(id -u)" -eq 0 ]] || error "Run this script as root"
}

cpu_count() {
  nproc 2>/dev/null || sysctl -n hw.logicalcpu 2>/dev/null || echo 1
}

default_threads() {
  local cores threads
  cores="$(cpu_count)"
  threads=$(( (cores * CPU_PERCENT + 99) / 100 ))
  if (( threads < 1 )); then
    threads=1
  fi
  if (( threads > MAX_THREADS )); then
    threads=$MAX_THREADS
  fi
  printf '%s\n' "$threads"
}

config_value() {
  local key="$1"
  sed -n "s/^[[:space:]]*$key[[:space:]]*=[[:space:]]*//p" "$CONFIG_DIR/bitcoin.conf" | tail -1
}

install_service() {
  local ensure_helper rpc_user rpc_pass rpc_port env_file unit_file cpuminer_path

  [[ -f "$SERVICE_DIR/$NODE_SERVICE_NAME" ]] || error "Base node service $NODE_SERVICE_NAME not found"
  [[ -f "$CONFIG_DIR/bitcoin.conf" ]] || error "Missing $CONFIG_DIR/bitcoin.conf"
  [[ -n "$MINE_ADDRESS" ]] || error "A payout address is required (--address RBTC_ADDRESS)"

  if [[ -z "$THREADS" ]]; then
    THREADS="$(default_threads)"
  fi

  ensure_helper="$HELPER_ROOT/rbtc-ensure-cpu-miner"
  if [[ ! -x "$ensure_helper" ]]; then
    ensure_helper="$HELPER_ROOT/scripts/ensure_cpu_miner.sh"
  fi
  [[ -x "$ensure_helper" ]] || error "Could not locate ensure_cpu_miner helper"

  INSTALL_DIR="$INSTALL_BIN_DIR" "$ensure_helper"

  cpuminer_path="$INSTALL_BIN_DIR/cpuminer"
  [[ -x "$cpuminer_path" ]] || error "cpuminer not found at $cpuminer_path after install"

  rpc_user="$(config_value rpcuser)"
  rpc_pass="$(config_value rpcpassword)"
  rpc_port="$(config_value rpcport)"
  [[ -n "$rpc_user" && -n "$rpc_pass" ]] || error "rpcuser/rpcpassword missing from $CONFIG_DIR/bitcoin.conf"
  [[ -n "$rpc_port" ]] || rpc_port="19332"

  env_file="$CONFIG_DIR/rbtc-cpuminer.env"
  unit_file="$SERVICE_DIR/$SERVICE_NAME"

  cat > "$env_file" <<EOF
RPC_USER=$rpc_user
RPC_PASS=$rpc_pass
RPC_PORT=$rpc_port
RBTC_MINE_ADDRESS=$MINE_ADDRESS
RBTC_MINER_THREADS=$THREADS
EOF
  chmod 640 "$env_file"
  chown root:"$SERVICE_GROUP" "$env_file"

  cat > "$unit_file" <<EOF
[Unit]
Description=rBTC cpuminer-opt CPU miner
After=$NODE_SERVICE_NAME network-online.target
Requires=$NODE_SERVICE_NAME

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_GROUP
Environment=HOME=$DATA_DIR
EnvironmentFile=$env_file
ExecStart=$cpuminer_path -a sha256d -t \${RBTC_MINER_THREADS} -o http://127.0.0.1:\${RPC_PORT} -u \${RPC_USER} -p \${RPC_PASS} --coinbase-addr \${RBTC_MINE_ADDRESS} --no-getwork --no-stratum --scantime 30
Restart=always
RestartSec=5
Nice=19
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

  chmod 644 "$unit_file"
  systemctl daemon-reload
  if [[ "$ENABLE_NOW" -eq 1 ]]; then
    systemctl enable --now "$SERVICE_NAME"
  fi
  info "Installed $SERVICE_NAME"
}

remove_service() {
  find "$SERVICE_DIR" -maxdepth 1 -name "$SERVICE_NAME" -delete
  find "$CONFIG_DIR" -maxdepth 1 -name 'rbtc-cpuminer.env' -delete
  systemctl daemon-reload
  if [[ "$ENABLE_NOW" -eq 1 ]]; then
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
  fi
  info "Removed $SERVICE_NAME"
}

main() {
  parse_args "$@"
  require_root

  if [[ "$REMOVE_SERVICE" -eq 1 ]]; then
    remove_service
    exit 0
  fi

  install_service
}

main "$@"
