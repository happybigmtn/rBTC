#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -x "$SCRIPT_DIR/bitcoind" || -x "$SCRIPT_DIR/bitcoin-cli" ]]; then
  ASSET_ROOT="$SCRIPT_DIR"
else
  ASSET_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

SERVICE_USER="${RBTC_SERVICE_USER:-rbtc}"
SERVICE_GROUP="${RBTC_SERVICE_GROUP:-$SERVICE_USER}"
INSTALL_BIN_DIR="${RBTC_SYSTEM_BIN_DIR:-/usr/local/bin}"
INSTALL_LIB_DIR="${RBTC_SYSTEM_LIB_DIR:-/usr/local/lib/rbtc}"
CONFIG_DIR="${RBTC_SYSTEM_CONFIG_DIR:-/etc/rbitcoin}"
DATA_DIR="${RBTC_SYSTEM_DATA_DIR:-/var/lib/rbitcoin}"
SERVICE_DIR="${RBTC_SYSTEMD_DIR:-/etc/systemd/system}"
BITCOIND_PATH="${RBTC_BITCOIND_PATH:-}"
BITCOIN_CLI_PATH="${RBTC_BITCOIN_CLI_PATH:-}"
ENABLE_NOW=0

usage() {
  cat <<'EOF'
Install rBTC as a long-running public systemd node on this host.

Usage:
  sudo ./scripts/install-public-node.sh [--enable-now]
  sudo rbtc-install-public-node [--enable-now]
EOF
}

info() { printf '[INFO] %s\n' "$1"; }
warn() { printf '[WARN] %s\n' "$1" >&2; }
error() { printf '[ERROR] %s\n' "$1" >&2; exit 1; }

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --enable-now)
        ENABLE_NOW=1
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

resolve_asset() {
  local explicit="$1"
  local rel_repo="$2"
  local rel_package="$3"
  local command_name="$4"
  local resolved=""

  if [[ -n "$explicit" ]]; then
    [[ -x "$explicit" ]] || error "Not executable: $explicit"
    printf '%s\n' "$explicit"
    return
  fi

  if [[ -x "$ASSET_ROOT/$rel_package" ]]; then
    printf '%s\n' "$ASSET_ROOT/$rel_package"
    return
  fi

  if [[ -x "$ASSET_ROOT/$rel_repo" ]]; then
    printf '%s\n' "$ASSET_ROOT/$rel_repo"
    return
  fi

  resolved="$(command -v "$command_name" 2>/dev/null || true)"
  [[ -n "$resolved" ]] || error "Could not locate $command_name"
  printf '%s\n' "$resolved"
}

resolve_file() {
  local rel_repo="$1"
  local rel_package="$2"

  if [[ -f "$ASSET_ROOT/$rel_package" ]]; then
    printf '%s\n' "$ASSET_ROOT/$rel_package"
    return
  fi

  if [[ -f "$ASSET_ROOT/$rel_repo" ]]; then
    printf '%s\n' "$ASSET_ROOT/$rel_repo"
    return
  fi

  error "Could not locate required file $rel_repo"
}

ensure_service_user() {
  if ! getent group "$SERVICE_GROUP" >/dev/null 2>&1; then
    groupadd --system "$SERVICE_GROUP"
  fi

  if ! id "$SERVICE_USER" >/dev/null 2>&1; then
    useradd --system --home-dir "$DATA_DIR" --create-home --gid "$SERVICE_GROUP" \
      --shell /usr/sbin/nologin "$SERVICE_USER"
  fi
}

write_wrapper() {
  local path="$1"
  shift
  local target="$1"
  shift
  local rendered_args=""
  local arg

  for arg in "$@"; do
    rendered_args+=" $(printf '%q' "$arg")"
  done

  cat > "$path" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec $(printf '%q' "$target")$rendered_args "\$@"
EOF
  chmod 755 "$path"
}

write_default_config() {
  local template_path="$1"
  local config_path="$CONFIG_DIR/bitcoin.conf"
  local rpcpass

  if [[ -f "$config_path" ]]; then
    warn "Config already exists at $config_path; leaving it unchanged"
    return
  fi

  rpcpass="$(openssl rand -hex 16 2>/dev/null || head -c 32 /dev/urandom | xxd -p | head -c 32)"
  sed "s#replace-this-password#$rpcpass#g" "$template_path" > "$config_path"
  chmod 640 "$config_path"
  chown root:"$SERVICE_GROUP" "$config_path"
  info "Wrote $config_path"
}

main() {
  local service_template config_template node_helper miner_helper doctor_helper ensure_helper start_helper
  local public_apply_helper

  parse_args "$@"
  require_root

  BITCOIND_PATH="$(resolve_asset "$BITCOIND_PATH" "build/bitcoind" "bitcoind" bitcoind)"
  BITCOIN_CLI_PATH="$(resolve_asset "$BITCOIN_CLI_PATH" "build/bitcoin-cli" "bitcoin-cli" bitcoin-cli)"
  service_template="$(resolve_file "contrib/init/rbtc-bitcoind.service" "rbtc-bitcoind.service")"
  config_template="$(resolve_file "contrib/init/rbitcoin.conf.example" "rbitcoin.conf.example")"
  node_helper="$(resolve_asset "" "scripts/install-public-node.sh" "rbtc-install-public-node" install-public-node.sh)"
  miner_helper="$(resolve_asset "" "scripts/install-public-miner.sh" "rbtc-install-public-miner" install-public-miner.sh)"
  doctor_helper="$(resolve_asset "" "scripts/doctor.sh" "rbtc-doctor" doctor.sh)"
  public_apply_helper="$(resolve_asset "" "scripts/public-apply.sh" "rbtc-public-apply" public-apply.sh)"
  ensure_helper="$(resolve_asset "" "scripts/ensure_cpu_miner.sh" "rbtc-ensure-cpu-miner" ensure_cpu_miner.sh)"
  start_helper="$(resolve_asset "" "scripts/start_cpu_miner.sh" "rbtc-start-cpu-miner" start_cpu_miner.sh)"

  ensure_service_user

  install -d -m 0755 "$INSTALL_BIN_DIR" "$INSTALL_LIB_DIR" "$SERVICE_DIR"
  install -d -o root -g "$SERVICE_GROUP" -m 0750 "$CONFIG_DIR"
  install -d -o "$SERVICE_USER" -g "$SERVICE_GROUP" -m 0750 "$DATA_DIR"

  install -m 0755 "$BITCOIND_PATH" "$INSTALL_LIB_DIR/bitcoind"
  install -m 0755 "$BITCOIN_CLI_PATH" "$INSTALL_LIB_DIR/bitcoin-cli"
  install -m 0755 "$node_helper" "$INSTALL_LIB_DIR/rbtc-install-public-node"
  install -m 0755 "$miner_helper" "$INSTALL_LIB_DIR/rbtc-install-public-miner"
  install -m 0755 "$doctor_helper" "$INSTALL_LIB_DIR/rbtc-doctor"
  install -m 0755 "$public_apply_helper" "$INSTALL_LIB_DIR/rbtc-public-apply"
  install -m 0755 "$ensure_helper" "$INSTALL_LIB_DIR/rbtc-ensure-cpu-miner"
  install -m 0755 "$start_helper" "$INSTALL_LIB_DIR/rbtc-start-cpu-miner"

  install -m 0644 "$config_template" "$INSTALL_LIB_DIR/rbitcoin.conf.example"
  write_default_config "$INSTALL_LIB_DIR/rbitcoin.conf.example"

  sed \
    -e "s#/usr/local/lib/rbtc#$INSTALL_LIB_DIR#g" \
    -e "s#/etc/rbitcoin#$CONFIG_DIR#g" \
    -e "s#/var/lib/rbitcoin#$DATA_DIR#g" \
    -e "s#User=rbtc#User=$SERVICE_USER#g" \
    -e "s#Group=rbtc#Group=$SERVICE_GROUP#g" \
    -e "s#/run/rbitcoin#/run/rbitcoin#g" \
    "$service_template" > "$SERVICE_DIR/rbtc-bitcoind.service"
  chmod 644 "$SERVICE_DIR/rbtc-bitcoind.service"

  write_wrapper "$INSTALL_BIN_DIR/rbtc-bitcoind" "$INSTALL_LIB_DIR/bitcoind" "-conf=$CONFIG_DIR/bitcoin.conf" "-datadir=$DATA_DIR"
  write_wrapper "$INSTALL_BIN_DIR/rbtc-cli" "$INSTALL_LIB_DIR/bitcoin-cli" "-conf=$CONFIG_DIR/bitcoin.conf" "-datadir=$DATA_DIR"
  write_wrapper "$INSTALL_BIN_DIR/rbtc-doctor" "$INSTALL_LIB_DIR/rbtc-doctor" "--conf" "$CONFIG_DIR/bitcoin.conf" "--datadir" "$DATA_DIR"
  write_wrapper "$INSTALL_BIN_DIR/rbtc-public-apply" "$INSTALL_LIB_DIR/rbtc-public-apply"
  write_wrapper "$INSTALL_BIN_DIR/rbtc-start-cpu-miner" "$INSTALL_LIB_DIR/rbtc-start-cpu-miner" "--datadir" "$DATA_DIR" "--network" "main"
  write_wrapper "$INSTALL_BIN_DIR/rbtc-install-public-node" "$INSTALL_LIB_DIR/rbtc-install-public-node"
  write_wrapper "$INSTALL_BIN_DIR/rbtc-install-public-miner" "$INSTALL_LIB_DIR/rbtc-install-public-miner"

  systemctl daemon-reload
  if [[ "$ENABLE_NOW" -eq 1 ]]; then
    systemctl enable --now rbtc-bitcoind.service
  fi

  info "Public-node assets are installed."
  printf '       sudo systemctl enable --now rbtc-bitcoind.service\n'
  printf '       sudo ufw allow 19333/tcp\n'
  printf '       %s/rbtc-doctor --conf %s/bitcoin.conf --datadir %s\n' \
    "$INSTALL_BIN_DIR" "$CONFIG_DIR" "$DATA_DIR"
}

main "$@"
