#!/usr/bin/env bash
set -euo pipefail

# Deploy mining_report.sh and install 6-hourly cron on all fleet nodes.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY_PATH="${FLEET_SSH_KEY:-$HOME/.ssh/contabo-mining-fleet}"
SSH_USER="${FLEET_SSH_USER:-root}"
REMOTE_SCRIPTS="/opt/rbitcoin/scripts"
SCRIPT_SRC="$ROOT_DIR/scripts/mining_report.sh"
CRON_SCHEDULE="0 */6 * * *"
CRON_CMD="$REMOTE_SCRIPTS/mining_report.sh >> /root/mining-reports/cron.log 2>&1"

declare -a FLEET_IPS=(
  "95.111.227.14"
  "95.111.229.108"
  "95.111.239.142"
  "161.97.83.147"
  "161.97.97.83"
  "161.97.114.192"
  "161.97.117.0"
  "194.163.144.177"
  "185.218.126.23"
  "185.239.209.227"
)

if [[ ! -f "$KEY_PATH" ]]; then
  echo "FAIL: fleet SSH key not found at $KEY_PATH" >&2
  exit 1
fi

if [[ ! -f "$SCRIPT_SRC" ]]; then
  echo "FAIL: mining_report.sh not found at $SCRIPT_SRC" >&2
  exit 1
fi

SSH_OPTS=(
  -i "$KEY_PATH"
  -o BatchMode=yes
  -o ConnectTimeout=15
  -o StrictHostKeyChecking=no
)

deploy_one() {
  local ip="$1"

  echo "[$ip] copying mining_report.sh..."
  ssh "${SSH_OPTS[@]}" "$SSH_USER@$ip" "mkdir -p '$REMOTE_SCRIPTS' /root/mining-reports"
  scp "${SSH_OPTS[@]}" "$SCRIPT_SRC" "$SSH_USER@$ip:$REMOTE_SCRIPTS/mining_report.sh"
  ssh "${SSH_OPTS[@]}" "$SSH_USER@$ip" "chmod +x '$REMOTE_SCRIPTS/mining_report.sh'"

  echo "[$ip] installing cron..."
  ssh "${SSH_OPTS[@]}" "$SSH_USER@$ip" bash -s -- "$CRON_SCHEDULE" "$CRON_CMD" <<'REMOTE'
set -euo pipefail
SCHEDULE="$1"
CMD="$2"
CRON_LINE="$SCHEDULE $CMD"

# Ensure jq is available
if ! command -v jq >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y >/dev/null && apt-get install -y jq >/dev/null
fi

CURRENT_CRON=$(crontab -l 2>/dev/null || true)

# Remove any existing mining_report cron entry
FILTERED=$(echo "$CURRENT_CRON" | grep -v 'mining_report\.sh' || true)

# Append new cron line
echo "$FILTERED
$CRON_LINE" | crontab -

echo "CRON_OK"
REMOTE

  echo "[$ip] verifying..."
  ssh "${SSH_OPTS[@]}" "$SSH_USER@$ip" "crontab -l | grep 'mining_report'"
}

failed=0

for ip in "${FLEET_IPS[@]}"; do
  if deploy_one "$ip"; then
    echo "  $ip  OK"
  else
    echo "  $ip  FAIL"
    failed=1
  fi
  echo
done

if [[ "$failed" -ne 0 ]]; then
  echo "FAIL: some nodes failed deployment" >&2
  exit 1
fi

echo "PASS: mining cron deployed to all ${#FLEET_IPS[@]} nodes"
