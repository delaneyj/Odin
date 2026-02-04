# LMDB

This folder vendors LMDB from the GitHub mirror of the OpenLDAP repository.

## Fetch/update sources

Latest:

```sh
./fetch.sh latest
```

Specific tag:

```sh
./fetch.sh LMDB_0.9.35
```

The selected tag is recorded in `VERSION`.

`fetch.sh` will also rebuild the static library after fetching and regenerate bindings if `bindgen` is available.

## Build (static library)

Linux/macOS:

```sh
./build.sh
```

Windows (Developer Command Prompt):

```bat
build.bat
```

This produces `lib/liblmdb.a` (Unix) or `lib/lmdb.lib` (Windows).

## Bindings

Bindings are generated with `odin-c-bindgen` and live in `lmdb/lmdb.odin`.
