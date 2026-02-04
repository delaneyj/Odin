#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")"

REQ_VERSION=${1:-latest}
REPO="https://github.com/sqlite/sqlite.git"

require_cmd() {
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "Missing required command: $1" >&2
		exit 1
	fi
}

if [ "$REQ_VERSION" = "latest" ]; then
	TAG=$(git ls-remote --tags "$REPO" "refs/tags/version-*" \
		| awk -F/ '{print $3}' \
		| sed 's/\^{}//' \
		| sort -u \
		| sort -t- -k2,2V \
		| tail -n 1)
	if [ -z "$TAG" ]; then
		echo "Failed to resolve tags from $REPO" >&2
		exit 1
	fi
else
	case "$REQ_VERSION" in
		version-3.*)
			TAG="$REQ_VERSION"
			;;
		3.*)
			TAG="version-$REQ_VERSION"
			;;
		*)
			echo "Usage: $0 latest | 3.X.Y | version-3.X.Y" >&2
			exit 1
			;;
	esac
fi

require_cmd git
require_cmd make
require_cmd tclsh
require_cmd cc

TMP_DIR=$(mktemp -d)

git clone --depth 1 --branch "$TAG" "$REPO" "$TMP_DIR/sqlite"

(
	cd "$TMP_DIR/sqlite"
	./configure
	make sqlite3.c sqlite3.h sqlite3ext.h
)

mkdir -p c
cp "$TMP_DIR/sqlite/sqlite3.c" c/
cp "$TMP_DIR/sqlite/sqlite3.h" c/
cp "$TMP_DIR/sqlite/sqlite3ext.h" c/

printf "%s\n" "$TAG" > VERSION

rm -rf "$TMP_DIR"

echo "Fetched sqlite amalgamation from $TAG"


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
