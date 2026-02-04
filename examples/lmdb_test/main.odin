package main

import "core:fmt"
import "core:strings"
import "core:path/filepath"
import "core:os"
import "vendor:lmdb/lmdb"
import "vendor:lmdb/kv"

DB_PATH :: ".odin-cache/lmdb_test"
KEY: string = "answer"
VALUE: i64 = 42

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
	if !ensure_dir_all(DB_PATH) {
		fmt.println("make_directory_all failed")
		return
	}

	db, rc := kv.open(cstring(DB_PATH), 1024*1024*1024*1024, 1, 0, lmdb.mdb_mode_t(0o775))
	if rc != lmdb.MDB_SUCCESS {
		fmt.println("kv.open failed:", rc)
		return
	}
	defer kv.close(&db)

	rc = kv.update(&db, proc(tx: ^kv.Txn) -> i32 {
		if rc := lmdb.mdb_drop(tx.txn, tx.dbi, 0); rc != lmdb.MDB_SUCCESS {
			return rc
		}
		key := kv.bytes_from_string(KEY)
		rc, err := kv.put_cbor(tx, key, VALUE, 0)
		if err != nil {
			fmt.println("kv.put_cbor failed:", err)
			return lmdb.MDB_BAD_VALSIZE
		}
		return rc
	})
	if rc != lmdb.MDB_SUCCESS {
		fmt.println("kv.update failed:", rc)
		return
	}

	rc = kv.view(&db, proc(tx: ^kv.Txn) -> i32 {
		cur: kv.Cursor
		if rc := kv.cursor_open(tx, &cur); rc != lmdb.MDB_SUCCESS {
			return rc
		}
		defer kv.cursor_close(&cur)

		seek_key := kv.bytes_from_string(KEY)
		key, _, rc := kv.cursor_seek(&cur, seek_key, lmdb.MDB_cursor_op.SET_RANGE)
		if rc == lmdb.MDB_NOTFOUND {
			return lmdb.MDB_SUCCESS
		}
		if rc != lmdb.MDB_SUCCESS {
			return rc
		}

		for op := lmdb.MDB_cursor_op.GET_CURRENT; ; op = lmdb.MDB_cursor_op.NEXT {
			out: i64
			key, rc, err := kv.cursor_get_cbor(&cur, op, &out)
			if rc == lmdb.MDB_NOTFOUND {
				return lmdb.MDB_SUCCESS
			}
			if rc != lmdb.MDB_SUCCESS {
				return rc
			}
			if err != nil {
				fmt.println("kv.cursor_get_cbor failed:", err)
				return lmdb.MDB_BAD_VALSIZE
			}
			fmt.println("lmdb read:", string(key), out)
		}
		return lmdb.MDB_SUCCESS
	})
	if rc != lmdb.MDB_SUCCESS {
		fmt.println("kv.view failed:", rc)
		return
	}

	fmt.println("lmdb OK")
}
