#!/usr/bin/env bash
set -euo pipefail

if command -v minerd >/dev/null 2>&1 || command -v cpuminer >/dev/null 2>&1; then
  echo "PASS: CPU miner already installed"
  exit 0
fi

run_root() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "DRY_RUN: $*"
    return 0
  fi

  if [[ $(id -u) -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    echo "FAIL: need root privileges to install packages" >&2
    return 1
  fi
}

# macOS
if command -v brew >/dev/null 2>&1; then
  run_root brew install cpuminer
  exit 0
fi

# Debian/Ubuntu
if command -v apt-get >/dev/null 2>&1; then
  run_root apt-get update
  if ! run_root apt-get install -y cpuminer; then
    run_root apt-get install -y cpuminer-multi
  fi
  exit 0
fi

# Fedora/CentOS/RHEL
if command -v dnf >/dev/null 2>&1; then
  run_root dnf install -y cpuminer
  exit 0
fi
if command -v yum >/dev/null 2>&1; then
  run_root yum install -y cpuminer
  exit 0
fi

# Arch
if command -v pacman >/dev/null 2>&1; then
  run_root pacman -S --noconfirm cpuminer
  exit 0
fi

# Alpine
if command -v apk >/dev/null 2>&1; then
  run_root apk add cpuminer
  exit 0
fi

echo "FAIL: could not detect package manager to install CPU miner" >&2
exit 1
