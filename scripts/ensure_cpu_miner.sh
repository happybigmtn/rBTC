#!/usr/bin/env bash
set -euo pipefail

if command -v minerd >/dev/null 2>&1 || command -v cpuminer >/dev/null 2>&1; then
  echo "PASS: CPU miner already installed"
  exit 0
fi

DISABLE_SOURCE_BUILD="${DISABLE_SOURCE_BUILD:-0}"

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

run_user() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "DRY_RUN: $*"
    return 0
  fi
  "$@"
}

install_from_source() {
  if [[ "$DISABLE_SOURCE_BUILD" == "1" ]]; then
    return 1
  fi

  local url="https://github.com/pooler/cpuminer/archive/refs/tags/v2.5.1.tar.gz"
  local sha256="eac6bfc4e1924a5743ce5dec79c9502fe15f2181b22d205e320cb8d64d0bd39c"
  local tmpdir
  tmpdir=$(mktemp -d)
  local tarball="$tmpdir/cpuminer.tar.gz"

  if ! command -v curl >/dev/null 2>&1; then
    echo "FAIL: curl required to download cpuminer source" >&2
    return 1
  fi

  curl -L -o "$tarball" "$url"
  if command -v sha256sum >/dev/null 2>&1; then
    echo "$sha256  $tarball" | sha256sum -c -
  else
    echo "$sha256  $tarball" | shasum -a 256 -c -
  fi

  tar -xzf "$tarball" -C "$tmpdir"
  local srcdir
  srcdir=$(find "$tmpdir" -maxdepth 1 -type d -name "cpuminer-*" | head -n 1)

  if [[ -z "$srcdir" ]]; then
    echo "FAIL: cpuminer source not found after extract" >&2
    return 1
  fi

  # Ensure libcurl m4 macro is visible (macOS + brew)
  if command -v brew >/dev/null 2>&1; then
    local curl_prefix
    curl_prefix=$(brew --prefix curl 2>/dev/null || true)
    if [[ -d "$curl_prefix/share/aclocal" ]]; then
      export ACLOCAL_PATH="$curl_prefix/share/aclocal:${ACLOCAL_PATH:-}"
    fi
  fi

  pushd "$srcdir" >/dev/null
  ./autogen.sh
  ./configure --disable-dependency-tracking
  make -j"${BUILD_JOBS:-2}"

  local install_dir="${INSTALL_DIR:-$HOME/.local/bin}"
  mkdir -p "$install_dir"
  if [[ ! -f minerd ]]; then
    echo "FAIL: minerd not built" >&2
    popd >/dev/null
    return 1
  fi
  cp -f minerd "$install_dir/"
  popd >/dev/null

  echo "PASS: installed minerd to $install_dir"
  return 0
}

# macOS (brew)
if command -v brew >/dev/null 2>&1; then
  if run_user brew install cpuminer; then
    exit 0
  fi
  # fallback to source build on macOS
  run_user brew install automake autoconf libtool pkg-config curl openssl
  if install_from_source; then
    exit 0
  fi
  echo "WARN: CPU miner auto-install unavailable on macOS" >&2
  exit 1
fi

# Debian/Ubuntu
if command -v apt-get >/dev/null 2>&1; then
  run_root apt-get update
  if run_root apt-get install -y cpuminer; then
    exit 0
  fi
  if run_root apt-get install -y cpuminer-multi; then
    exit 0
  fi
  # fallback to source build
  run_root apt-get install -y build-essential automake autoconf libtool pkg-config libcurl4-openssl-dev libssl-dev
  install_from_source
  exit 0
fi

# Fedora/CentOS/RHEL
if command -v dnf >/dev/null 2>&1; then
  if run_root dnf install -y cpuminer; then
    exit 0
  fi
  run_root dnf install -y gcc make automake autoconf libtool pkgconfig libcurl-devel openssl-devel
  install_from_source
  exit 0
fi
if command -v yum >/dev/null 2>&1; then
  if run_root yum install -y cpuminer; then
    exit 0
  fi
  run_root yum install -y gcc make automake autoconf libtool pkgconfig libcurl-devel openssl-devel
  install_from_source
  exit 0
fi

# Arch
if command -v pacman >/dev/null 2>&1; then
  if run_root pacman -S --noconfirm cpuminer; then
    exit 0
  fi
  run_root pacman -S --noconfirm base-devel autoconf automake libtool pkgconf curl openssl
  install_from_source
  exit 0
fi

# Alpine
if command -v apk >/dev/null 2>&1; then
  if run_root apk add cpuminer; then
    exit 0
  fi
  run_root apk add build-base autoconf automake libtool pkgconf curl openssl-dev
  install_from_source
  exit 0
fi

# Fallback to source build if no package manager but tools exist
install_from_source

if command -v minerd >/dev/null 2>&1; then
  exit 0
fi

echo "FAIL: could not install CPU miner" >&2
exit 1
