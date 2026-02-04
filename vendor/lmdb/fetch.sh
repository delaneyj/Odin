#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")"

REPO="https://github.com/LMDB/lmdb.git"
REQ_VERSION=${1:-latest}

if [ "$REQ_VERSION" = "latest" ]; then
	TAGS=$(git ls-remote --tags "$REPO" "refs/tags/LMDB_*" | awk -F/ '{print $3}' | sed 's/\^{}//' | sort -u)
	if [ -z "$TAGS" ]; then
		echo "Failed to resolve LMDB tags from $REPO" >&2
		exit 1
	fi
	VERSION=$(printf '%s\n' "$TAGS" | sort -t_ -k2,2V | tail -n1)
else
	case "$REQ_VERSION" in
		LMDB_*) VERSION="$REQ_VERSION" ;;
		[0-9]*.[0-9]*.[0-9]*) VERSION="LMDB_$REQ_VERSION" ;;
		*)
			echo "Usage: $0 latest | LMDB_X.Y.Z | X.Y.Z" >&2
			exit 1
			;;
	esac
fi

TMP_DIR=$(mktemp -d)

git clone --depth 1 --branch "$VERSION" "$REPO" "$TMP_DIR/lmdb"

mkdir -p c
cp "$TMP_DIR/lmdb/libraries/liblmdb/mdb.c" c/
cp "$TMP_DIR/lmdb/libraries/liblmdb/midl.c" c/
cp "$TMP_DIR/lmdb/libraries/liblmdb/lmdb.h" c/
cp "$TMP_DIR/lmdb/libraries/liblmdb/midl.h" c/
cp "$TMP_DIR/lmdb/libraries/liblmdb/LICENSE" LICENSE
printf "%s\n" "$VERSION" > VERSION

rm -rf "$TMP_DIR"

echo "Fetched $VERSION"


echo "Regenerating bindings (if bindgen is available)..."
BINDGEN_BIN=${ODIN_C_BINDGEN:-bindgen}
if [ -x "$BINDGEN_BIN" ]; then
	"$BINDGEN_BIN" "$(pwd)"
elif command -v "$BINDGEN_BIN" >/dev/null 2>&1; then
	"$BINDGEN_BIN" "$(pwd)"
else
	echo "bindgen not found; skipping. Set ODIN_C_BINDGEN or install bindgen." >&2
fi


echo "Building static library..."
./build.sh
