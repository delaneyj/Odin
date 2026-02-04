# SQLite3 (amalgamation)

This folder vendors the SQLite amalgamation (`sqlite3.c`, `sqlite3.h`, `sqlite3ext.h`) built from the
GitHub mirror of SQLite.

## Fetch/update sources

Latest:

```sh
./fetch.sh latest
```

Specific version (tag or version string):

```sh
./fetch.sh version-3.51.2
./fetch.sh 3.51.2
```

The selected tag is recorded in `VERSION`.

Note: `fetch.sh` builds the amalgamation from the GitHub source tree and requires `git`, `tclsh`, `make`, and a C compiler (`cc`).

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

This produces `lib/libsqlite3.a` (Unix) or `lib/sqlite3.lib` (Windows).

## Bindings

Bindings are generated with `odin-c-bindgen` and live in `sqlite3.odin`.
