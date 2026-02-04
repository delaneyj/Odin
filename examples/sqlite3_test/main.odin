package main

import "core:fmt"
import "core:strings"
import "core:path/filepath"
import "core:os"
import "vendor:sqlite3"

ensure_dir_all :: proc(path: string) -> (ok: bool) {
	if len(path) == 0 {
		return true
	}

	if err := os.make_directory(path); err == nil || err == os.EEXIST {
		return true
	}

	dir, _ := filepath.split(path)
	dir = strings.trim_right(dir, filepath.SEPARATOR_CHARS)
	if len(dir) == 0 || dir == path {
		return false
	}
	if !ensure_dir_all(dir) {
		return false
	}
	if err := os.make_directory(path); err == nil || err == os.EEXIST {
		return true
	}
	return false
}

main :: proc() {
	if !ensure_dir_all(".odin-cache") {
		fmt.println("make_directory_all failed")
		return
	}

	db: ^sqlite3.sqlite3
	path := cstring(".odin-cache/sqlite3_test.db")
	if sqlite3.sqlite3_open(path, &db) != sqlite3.SQLITE_OK {
		fmt.println("sqlite3_open failed")
		return
	}
	defer sqlite3.sqlite3_close(db)

	sql := cstring("CREATE TABLE IF NOT EXISTS t (k TEXT, v TEXT); DELETE FROM t; INSERT INTO t VALUES ('hello','world');")
	err_msg: cstring
	rc := sqlite3.sqlite3_exec(db, sql, nil, nil, &err_msg)
	if rc != sqlite3.SQLITE_OK {
		fmt.println("sqlite3_exec failed:", rc)
		if err_msg != nil {
			err_str, _ := strings.clone_from_cstring(err_msg)
			fmt.println(err_str)
			sqlite3.sqlite3_free(rawptr(err_msg))
		}
		return
	}

	// Close write connection before opening read-only.
	sqlite3.sqlite3_close(db)
	db = nil

	rc = sqlite3.sqlite3_open_v2(
		path,
		&db,
		sqlite3.SQLITE_OPEN_READONLY,
		nil,
	)
	if rc != sqlite3.SQLITE_OK {
		fmt.println("sqlite3_open_v2 (readonly) failed:", rc)
		return
	}
	defer sqlite3.sqlite3_close(db)

	stmt: ^sqlite3.sqlite3_stmt
	qry := cstring("SELECT k, v FROM t;")
	rc = sqlite3.sqlite3_prepare_v2(db, qry, -1, &stmt, nil)
	if rc != sqlite3.SQLITE_OK {
		fmt.println("sqlite3_prepare_v2 failed:", rc)
		return
	}
	defer sqlite3.sqlite3_finalize(stmt)

	for {
		rc = sqlite3.sqlite3_step(stmt)
		if rc == sqlite3.SQLITE_ROW {
			k := sqlite3.sqlite3_column_text(stmt, 0)
			v := sqlite3.sqlite3_column_text(stmt, 1)
			k_str, _ := strings.clone_from_cstring(cstring(k))
			v_str, _ := strings.clone_from_cstring(cstring(v))
			fmt.println("sqlite3 read:", k_str, v_str)
			continue
		}
		if rc == sqlite3.SQLITE_DONE {
			break
		}
		fmt.println("sqlite3_step failed:", rc)
		return
	}

	fmt.println("sqlite3 OK")
}
