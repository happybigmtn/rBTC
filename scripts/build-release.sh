#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="${RBTC_RELEASE_TAG:-}"
PLATFORM="${RBTC_RELEASE_PLATFORM:-}"
OUTPUT_DIR="${RBTC_RELEASE_OUTPUT_DIR:-$ROOT_DIR/dist}"
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-}"
SKIP_BUILD=0

usage() {
  cat <<'EOF'
Build and package a verified rBTC release tarball.

Usage:
  ./scripts/build-release.sh [--tag TAG] [--platform PLATFORM] [--output-dir DIR] [--skip-build]
EOF
}

info() { printf '[INFO] %s\n' "$1"; }
error() { printf '[ERROR] %s\n' "$1" >&2; exit 1; }

detect_platform() {
  local os arch
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"

  case "$os" in
    linux*) os="linux" ;;
    darwin*) os="macos" ;;
    *) error "Unsupported OS: $os" ;;
  esac

  case "$arch" in
    x86_64|amd64) arch="x86_64" ;;
    arm64|aarch64) arch="arm64" ;;
    *) error "Unsupported architecture: $arch" ;;
  esac

  printf '%s-%s\n' "$os" "$arch"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tag)
        [[ $# -ge 2 ]] || error "--tag requires a value"
        TAG="$2"
        shift 2
        ;;
      --platform)
        [[ $# -ge 2 ]] || error "--platform requires a value"
        PLATFORM="$2"
        shift 2
        ;;
      --output-dir)
        [[ $# -ge 2 ]] || error "--output-dir requires a path"
        OUTPUT_DIR="$2"
        shift 2
        ;;
      --skip-build)
        SKIP_BUILD=1
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

resolve_source_date_epoch() {
  if [[ -n "$SOURCE_DATE_EPOCH" ]]; then
    return
  fi
  SOURCE_DATE_EPOCH="$(git -C "$ROOT_DIR" log -1 --format=%ct HEAD)"
}

maybe_strip_binary() {
  local file="$1"
  if command -v strip >/dev/null 2>&1; then
    strip "$file" 2>/dev/null || true
  fi
}

default_upstream_artifact() {
  local version="${TAG#v}"

  case "$PLATFORM" in
    linux-x86_64)
      printf 'bitcoin-%s-x86_64-linux-gnu.tar.gz\n' "$version"
      ;;
    linux-arm64)
      printf 'bitcoin-%s-aarch64-linux-gnu.tar.gz\n' "$version"
      ;;
    macos-x86_64)
      printf 'bitcoin-%s-x86_64-apple-darwin.zip\n' "$version"
      ;;
    macos-arm64)
      printf 'bitcoin-%s-arm64-apple-darwin.zip\n' "$version"
      ;;
    *)
      return 1
      ;;
  esac
}

package_release() {
  local patch_hash package_root stage_root tarball

  patch_hash="$(tr -d ' \n' < "$ROOT_DIR/patch/immutable.patch.sha256")"
  mkdir -p "$OUTPUT_DIR"
  package_root="rbtc-${TAG}-${PLATFORM}"
  stage_root="$(mktemp -d)/$package_root"
  mkdir -p "$stage_root"

  cp "$ROOT_DIR/build/bitcoind" "$stage_root/bitcoind"
  cp "$ROOT_DIR/build/bitcoin-cli" "$stage_root/bitcoin-cli"
  cp "$ROOT_DIR/scripts/doctor.sh" "$stage_root/rbtc-doctor"
  cp "$ROOT_DIR/scripts/start_cpu_miner.sh" "$stage_root/rbtc-start-cpu-miner"
  cp "$ROOT_DIR/scripts/ensure_cpu_miner.sh" "$stage_root/rbtc-ensure-cpu-miner"
  cp "$ROOT_DIR/scripts/install-public-node.sh" "$stage_root/rbtc-install-public-node"
  cp "$ROOT_DIR/scripts/install-public-miner.sh" "$stage_root/rbtc-install-public-miner"
  cp "$ROOT_DIR/scripts/public-apply.sh" "$stage_root/rbtc-public-apply"
  cp "$ROOT_DIR/contrib/init/rbtc-bitcoind.service" "$stage_root/rbtc-bitcoind.service"
  cp "$ROOT_DIR/contrib/init/rbitcoin.conf.example" "$stage_root/rbitcoin.conf.example"
  cp "$ROOT_DIR/doc/public-node.md" "$stage_root/PUBLIC-NODE.md"
  cp "$ROOT_DIR/manifests/manifest-$TAG.json" "$stage_root/manifest-$TAG.json"
  cp "$ROOT_DIR/reports/verification-$TAG.json" "$stage_root/verification-$TAG.json"
  cp "$ROOT_DIR/patch/immutable.patch.sha256" "$stage_root/immutable.patch.sha256"

  maybe_strip_binary "$stage_root/bitcoind"
  maybe_strip_binary "$stage_root/bitcoin-cli"
  chmod 755 "$stage_root/bitcoind" "$stage_root/bitcoin-cli" \
    "$stage_root/rbtc-doctor" "$stage_root/rbtc-start-cpu-miner" \
    "$stage_root/rbtc-ensure-cpu-miner" "$stage_root/rbtc-install-public-node" \
    "$stage_root/rbtc-install-public-miner" "$stage_root/rbtc-public-apply"
  chmod 644 "$stage_root/rbtc-bitcoind.service" "$stage_root/rbitcoin.conf.example" \
    "$stage_root/PUBLIC-NODE.md" "$stage_root/manifest-$TAG.json" \
    "$stage_root/verification-$TAG.json" "$stage_root/immutable.patch.sha256"

  python3 - "$stage_root/release-manifest.json" "$TAG" "$PLATFORM" "$patch_hash" "$SOURCE_DATE_EPOCH" "$(git -C "$ROOT_DIR" rev-parse HEAD)" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = {
    "upstream_tag": sys.argv[2],
    "platform": sys.argv[3],
    "patch_hash": sys.argv[4],
    "source_date_epoch": int(sys.argv[5]),
    "git_commit": sys.argv[6],
    "artifacts": [
        "bitcoind",
        "bitcoin-cli",
        "rbtc-doctor",
        "rbtc-start-cpu-miner",
        "rbtc-ensure-cpu-miner",
        "rbtc-install-public-node",
        "rbtc-install-public-miner",
        "rbtc-public-apply",
        "rbtc-bitcoind.service",
        "rbitcoin.conf.example",
        "PUBLIC-NODE.md",
        f"manifest-{sys.argv[2]}.json",
        f"verification-{sys.argv[2]}.json",
        "immutable.patch.sha256",
    ],
}
path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="ascii")
PY

  tarball="$OUTPUT_DIR/${package_root}.tar.gz"
  python3 - "$stage_root" "$tarball" "$SOURCE_DATE_EPOCH" <<'PY'
import gzip
import os
import tarfile
import sys
from pathlib import Path

source_root = Path(sys.argv[1]).resolve()
tarball = Path(sys.argv[2]).resolve()
mtime = int(sys.argv[3])

def normalized_mode(path: Path) -> int:
    if path.is_dir():
        return 0o755
    if os.access(path, os.X_OK):
        return 0o755
    return 0o644

with tarball.open("wb") as raw:
    with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=mtime) as gz:
        with tarfile.open(fileobj=gz, mode="w", format=tarfile.PAX_FORMAT) as archive:
            for path in [source_root, *sorted(source_root.rglob("*"))]:
                arcname = path.relative_to(source_root.parent).as_posix()
                info = archive.gettarinfo(str(path), arcname)
                info.uid = 0
                info.gid = 0
                info.uname = "root"
                info.gname = "root"
                info.mtime = mtime
                info.mode = normalized_mode(path)
                if path.is_file():
                    with path.open("rb") as handle:
                        archive.addfile(info, handle)
                else:
                    archive.addfile(info)
PY

  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$OUTPUT_DIR" && sha256sum "$(basename "$tarball")" > SHA256SUMS)
  else
    (cd "$OUTPUT_DIR" && shasum -a 256 "$(basename "$tarball")" > SHA256SUMS)
  fi

  info "Built release tarball $tarball"
}

main() {
  parse_args "$@"

  if [[ -z "$TAG" ]]; then
    TAG="$("$ROOT_DIR/scripts/fetch_upstream_release.sh")"
  fi
  if [[ -z "$PLATFORM" ]]; then
    PLATFORM="$(detect_platform)"
  fi
  resolve_source_date_epoch

  if [[ "$SKIP_BUILD" -eq 0 ]]; then
    if [[ -z "${ARTIFACTS:-}" ]]; then
      ARTIFACTS="$(default_upstream_artifact || true)"
      export ARTIFACTS
    fi
    "$ROOT_DIR/scripts/verify_upstream_release.sh" "$TAG"
    "$ROOT_DIR/scripts/enforce_patch_scope.sh" "$ROOT_DIR/patch/immutable.patch"
    "$ROOT_DIR/scripts/build_from_tag.sh" "$TAG"
    "$ROOT_DIR/scripts/make_update_manifest.sh" "$TAG"
    "$ROOT_DIR/scripts/validate_manifest.sh" "$ROOT_DIR/manifests/manifest-$TAG.json"
    "$ROOT_DIR/scripts/verify_local_binary.sh" "$ROOT_DIR/build/bitcoind" "$ROOT_DIR/manifests/manifest-$TAG.json"
  fi

  [[ -x "$ROOT_DIR/build/bitcoind" ]] || error "Missing $ROOT_DIR/build/bitcoind"
  [[ -x "$ROOT_DIR/build/bitcoin-cli" ]] || error "Missing $ROOT_DIR/build/bitcoin-cli"
  [[ -f "$ROOT_DIR/manifests/manifest-$TAG.json" ]] || error "Missing manifest for $TAG"
  [[ -f "$ROOT_DIR/reports/verification-$TAG.json" ]] || error "Missing verification report for $TAG"

  package_release
}

main "$@"
