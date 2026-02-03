#!/usr/bin/env bash
set -euo pipefail

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

GNUPGHOME="$TMPDIR/gnupg"
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"

# Generate test key
cat <<'KEY' > "$TMPDIR/keyparams"
Key-Type: RSA
Key-Length: 2048
Name-Real: Test Key
Name-Email: test@example.com
Expire-Date: 0
%no-protection
%commit
KEY

gpg --homedir "$GNUPGHOME" --batch --gen-key "$TMPDIR/keyparams" >/dev/null 2>&1

# Export public key
KEYID=$(gpg --homedir "$GNUPGHOME" --list-keys --with-colons | awk -F: '/^pub/ {print $5; exit}')
gpg --homedir "$GNUPGHOME" --armor --export "$KEYID" > "$TMPDIR/keys.asc"

# Create dummy artifact + checksums
ARTIFACT="bitcoin-core-0.0.0-test.tar.gz"
ARTIFACT_PATH="$TMPDIR/$ARTIFACT"

echo "hello" > "$ARTIFACT_PATH"

if command -v sha256sum >/dev/null 2>&1; then
  HASH=$(sha256sum "$ARTIFACT_PATH" | awk '{print $1}')
else
  HASH=$(shasum -a 256 "$ARTIFACT_PATH" | awk '{print $1}')
fi

echo "$HASH  $ARTIFACT" > "$TMPDIR/SHA256SUMS"

gpg --homedir "$GNUPGHOME" --armor --detach-sign "$TMPDIR/SHA256SUMS"

# Run verification in fixture mode
FIXTURES_DIR="$TMPDIR" \
GNUPGHOME_DIR="$TMPDIR/gnupg_verify" \
ARTIFACTS="$ARTIFACT" \
./scripts/verify_upstream_release.sh v0.0.0-test >/dev/null

# Tamper artifact and expect failure

echo "tamper" >> "$ARTIFACT_PATH"
if FIXTURES_DIR="$TMPDIR" GNUPGHOME_DIR="$TMPDIR/gnupg_verify2" ARTIFACTS="$ARTIFACT" ./scripts/verify_upstream_release.sh v0.0.0-test >/dev/null 2>&1; then
  echo "FAIL: verification should fail on tampered artifact"
  exit 1
fi

echo "PASS: verify_upstream_release.sh fixture test"
