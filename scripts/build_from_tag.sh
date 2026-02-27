#!/usr/bin/env bash
set -euo pipefail

TAG="${1:-}"
if [[ -z "$TAG" ]]; then
  echo "Usage: $0 <tag>" >&2
  exit 1
fi

ROOT_DIR="$(pwd)"
UPSTREAM_REPO="${UPSTREAM_REPO:-https://github.com/bitcoin/bitcoin.git}"
WORKDIR="${WORKDIR:-$ROOT_DIR/.cache/build}"
PATCH_FILE="${PATCH_FILE:-$ROOT_DIR/patch/immutable.patch}"
PATCH_HASH_FILE="${PATCH_HASH_FILE:-$ROOT_DIR/patch/immutable.patch.sha256}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"
LOG_FILE="${LOG_FILE:-$BUILD_DIR/build.log}"
UPSTREAM_CLONE_DEPTH="${UPSTREAM_CLONE_DEPTH:-1}"
CMAKE_BUILD_DIR="${CMAKE_BUILD_DIR:-}"

MOCK_BUILD="${MOCK_BUILD:-0}"

mkdir -p "$WORKDIR" "$BUILD_DIR"

install_binary_atomic() {
  local src="$1"
  local dest="$2"
  local tmp

  tmp="$(mktemp "${dest}.tmp.XXXXXX")"
  cp -f "$src" "$tmp"
  chmod +x "$tmp"
  mv -f "$tmp" "$dest"
}

write_mock_binary() {
  local dest="$1"
  local name="$2"
  local tmp

  tmp="$(mktemp "${dest}.tmp.XXXXXX")"
  cat > "$tmp" <<EOF
#!/usr/bin/env bash
echo "FAIL: $name is a mock binary (set MOCK_BUILD=0 for real build)" >&2
exit 1
EOF
  chmod +x "$tmp"
  mv -f "$tmp" "$dest"
}

# Ensure patch hash matches pinned file
PATCH_HASH=""
if [[ -f "$PATCH_HASH_FILE" ]]; then
  expected=$(cat "$PATCH_HASH_FILE" | tr -d ' \n')
  if [[ -z "$expected" ]]; then
    echo "FAIL: empty patch hash file" >&2
    exit 1
  fi
  actual=$(./scripts/compute_patch_hash.sh "$PATCH_FILE" | tr -d ' \n')
  if [[ "$expected" != "$actual" ]]; then
    echo "FAIL: patch hash mismatch" >&2
    exit 1
  fi
  PATCH_HASH="$expected"
fi

if [[ "$MOCK_BUILD" == "1" ]]; then
  echo "MOCK BUILD for $TAG" > "$LOG_FILE"
  echo "patch_hash=$(cat "$PATCH_HASH_FILE" 2>/dev/null || echo none)" >> "$LOG_FILE"
  write_mock_binary "$BUILD_DIR/bitcoind" "bitcoind"
  write_mock_binary "$BUILD_DIR/bitcoin-cli" "bitcoin-cli"
  echo "PASS: mock build complete"
  exit 0
fi

# Clone or update upstream (shallow clone by default)
if [[ -n "$PATCH_HASH" ]]; then
  PATCH_SUFFIX="${PATCH_HASH:0:12}"
else
  PATCH_SUFFIX="nopatch"
fi
UPSTREAM_DIR="$WORKDIR/bitcoin-$TAG-$PATCH_SUFFIX"
if [[ ! -d "$UPSTREAM_DIR/.git" ]]; then
  git clone --depth "$UPSTREAM_CLONE_DEPTH" --branch "$TAG" "$UPSTREAM_REPO" "$UPSTREAM_DIR"
else
  git -C "$UPSTREAM_DIR" fetch --depth "$UPSTREAM_CLONE_DEPTH" origin "$TAG"
fi

pushd "$UPSTREAM_DIR" >/dev/null

if [[ -z "$CMAKE_BUILD_DIR" ]]; then
  CMAKE_BUILD_DIR="build-cmake"
fi
if [[ "$CMAKE_BUILD_DIR" != /* ]]; then
  CMAKE_BUILD_DIR="$PWD/$CMAKE_BUILD_DIR"
fi

# If the cmake cache was created on a different path/host, clear it to avoid
# "source does not match" errors (common when sharing a repo across hosts).
if [[ -f "$CMAKE_BUILD_DIR/CMakeCache.txt" ]]; then
  cached_src=$(grep -E '^CMAKE_HOME_DIRECTORY:INTERNAL=' "$CMAKE_BUILD_DIR/CMakeCache.txt" | cut -d'=' -f2- || true)
  if [[ -n "$cached_src" && "$cached_src" != "$PWD" ]]; then
    rm -rf "$CMAKE_BUILD_DIR"
  fi
fi

git checkout "$TAG"

# Apply patch if non-empty
if [[ -s "$PATCH_FILE" ]]; then
  if git apply --reverse --check "$PATCH_FILE" >/dev/null 2>&1; then
    echo "INFO: patch already applied"
  else
    git apply "$PATCH_FILE"
  fi
fi

# Build (best effort)
if [[ -x "./autogen.sh" ]]; then
  ./autogen.sh
  ./configure
  make -j"${BUILD_JOBS:-2}"
else
  if ! command -v cmake >/dev/null 2>&1; then
    echo "FAIL: cmake is required to build this release" >&2
    exit 1
  fi
  cmake -S . -B "$CMAKE_BUILD_DIR" \
    -DBUILD_GUI=OFF \
    -DBUILD_TESTS=OFF \
    -DBUILD_BENCH=OFF \
    -DBUILD_FUZZ_BINARY=OFF \
    -DBUILD_TX=OFF \
    -DBUILD_UTIL=OFF \
    -DBUILD_UTIL_CHAINSTATE=OFF \
    -DBUILD_KERNEL_LIB=OFF \
    -DBUILD_WALLET_TOOL=OFF \
    -DENABLE_IPC=OFF \
    -DENABLE_WALLET=ON \
    -DWERROR=OFF
  cmake --build "$CMAKE_BUILD_DIR" -j"${BUILD_JOBS:-2}"
fi

# Copy binaries
if [[ -f "src/bitcoind" ]]; then
  install_binary_atomic src/bitcoind "$BUILD_DIR/bitcoind"
  install_binary_atomic src/bitcoin-cli "$BUILD_DIR/bitcoin-cli"
elif [[ -n "$CMAKE_BUILD_DIR" && -f "$CMAKE_BUILD_DIR/bin/bitcoind" ]]; then
  install_binary_atomic "$CMAKE_BUILD_DIR/bin/bitcoind" "$BUILD_DIR/bitcoind"
  install_binary_atomic "$CMAKE_BUILD_DIR/bin/bitcoin-cli" "$BUILD_DIR/bitcoin-cli"
else
  echo "FAIL: build did not produce bitcoind/bitcoin-cli" >&2
  exit 1
fi

# macOS: ad-hoc sign binaries to avoid dyld startup hangs
if [[ "$(uname -s)" == "Darwin" ]] && command -v codesign >/dev/null 2>&1; then
  codesign -s - "$BUILD_DIR/bitcoind" "$BUILD_DIR/bitcoin-cli" >/dev/null 2>&1 || true
fi

popd >/dev/null

{
  echo "tag=$TAG"
  echo "patch_hash=$(cat "$PATCH_HASH_FILE" 2>/dev/null || echo none)"
  date -u
} > "$LOG_FILE"

echo "PASS: build complete"
