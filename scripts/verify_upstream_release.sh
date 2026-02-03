#!/usr/bin/env bash
set -euo pipefail

TAG="${1:-}"
if [[ -z "$TAG" ]]; then
  echo "Usage: $0 <tag>" >&2
  exit 1
fi

VERSION="${TAG#v}"
UPSTREAM_REPO="${UPSTREAM_REPO:-bitcoin/bitcoin}"
RELEASE_BASE="${RELEASE_BASE:-https://bitcoincore.org/bin/bitcoin-core-$VERSION}"
KEYS_URL="${KEYS_URL:-https://bitcoincore.org/keys/keys.txt}"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-./.cache/releases/$TAG}"
REPORTS_DIR="${REPORTS_DIR:-./reports}"
GNUPGHOME_DIR="${GNUPGHOME_DIR:-./.gnupg}"

ARTIFACTS="${ARTIFACTS:-}"
ALLOW_NO_ARTIFACTS="${ALLOW_NO_ARTIFACTS:-0}"

FIXTURES_DIR="${FIXTURES_DIR:-}"

mkdir -p "$DOWNLOAD_DIR" "$REPORTS_DIR" "$GNUPGHOME_DIR"
chmod 700 "$GNUPGHOME_DIR"

if ! command -v gpg >/dev/null 2>&1; then
  echo "FAIL: gpg is required" >&2
  exit 1
fi

# Acquire SHA256SUMS and signature
if [[ -n "$FIXTURES_DIR" ]]; then
  cp "$FIXTURES_DIR/SHA256SUMS" "$DOWNLOAD_DIR/SHA256SUMS"
  cp "$FIXTURES_DIR/SHA256SUMS.asc" "$DOWNLOAD_DIR/SHA256SUMS.asc"
else
  if ! command -v curl >/dev/null 2>&1; then
    echo "FAIL: curl is required" >&2
    exit 1
  fi
  curl -fsSL "$RELEASE_BASE/SHA256SUMS" -o "$DOWNLOAD_DIR/SHA256SUMS"
  curl -fsSL "$RELEASE_BASE/SHA256SUMS.asc" -o "$DOWNLOAD_DIR/SHA256SUMS.asc"
fi

# Import keys
if [[ -n "$FIXTURES_DIR" && -f "$FIXTURES_DIR/keys.asc" ]]; then
  gpg --homedir "$GNUPGHOME_DIR" --import "$FIXTURES_DIR/keys.asc" >/dev/null 2>&1
else
  if ! command -v curl >/dev/null 2>&1; then
    echo "FAIL: curl is required for keys" >&2
    exit 1
  fi
  curl -fsSL "$KEYS_URL" -o "$DOWNLOAD_DIR/keys.txt"
  gpg --homedir "$GNUPGHOME_DIR" --import "$DOWNLOAD_DIR/keys.txt" >/dev/null 2>&1 || true
fi

# Verify signature
if ! gpg --homedir "$GNUPGHOME_DIR" --verify "$DOWNLOAD_DIR/SHA256SUMS.asc" "$DOWNLOAD_DIR/SHA256SUMS" >/dev/null 2>&1; then
  echo "FAIL: SHA256SUMS signature verification failed" >&2
  status="FAIL"
  gpg_ok=false
else
  gpg_ok=true
  status="PASS"
fi

# Verify artifacts if requested
verified_artifacts=()
if [[ -n "$ARTIFACTS" ]]; then
  IFS=',' read -r -a artifacts_arr <<< "$ARTIFACTS"
  for artifact in "${artifacts_arr[@]}"; do
    artifact=$(echo "$artifact" | xargs)
    [[ -z "$artifact" ]] && continue

    if [[ -n "$FIXTURES_DIR" ]]; then
      cp "$FIXTURES_DIR/$artifact" "$DOWNLOAD_DIR/$artifact"
    else
      curl -fsSL "$RELEASE_BASE/$artifact" -o "$DOWNLOAD_DIR/$artifact"
    fi

    expected=$(grep " $artifact" "$DOWNLOAD_DIR/SHA256SUMS" | awk '{print $1}' | head -n1)
    if [[ -z "$expected" ]]; then
      echo "FAIL: checksum not found for artifact $artifact" >&2
      status="FAIL"
      continue
    fi

    if command -v sha256sum >/dev/null 2>&1; then
      actual=$(sha256sum "$DOWNLOAD_DIR/$artifact" | awk '{print $1}')
    else
      actual=$(shasum -a 256 "$DOWNLOAD_DIR/$artifact" | awk '{print $1}')
    fi

    if [[ "$expected" != "$actual" ]]; then
      echo "FAIL: checksum mismatch for $artifact" >&2
      status="FAIL"
    else
      verified_artifacts+=("$artifact")
    fi
  done
else
  if [[ "$ALLOW_NO_ARTIFACTS" != "1" ]]; then
    echo "WARN: no artifacts specified; only signature verified" >&2
  fi
fi

# Write report
report="$REPORTS_DIR/verification-$TAG.json"

cat <<JSON > "$report"
{
  "tag": "$TAG",
  "release_base": "$RELEASE_BASE",
  "keys_url": "$KEYS_URL",
  "gpg_signature_valid": $gpg_ok,
  "artifacts_verified": [$(printf '"%s"' "${verified_artifacts[@]}" | paste -sd, -)],
  "status": "$status",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
JSON

if [[ "$status" != "PASS" ]]; then
  exit 1
fi

echo "PASS: upstream release verified for $TAG"
