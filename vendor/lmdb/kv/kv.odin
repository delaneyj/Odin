package lmdb_kv

import "core:c"
import "base:runtime"
import cbor "core:encoding/cbor"
import json "core:encoding/json"
import "core:slice"
import "vendor:lmdb"

DB :: struct {
	env: ^lmdb.MDB_env,
}

Txn :: struct {
	txn: ^lmdb.MDB_txn,
	dbi: lmdb.MDB_dbi,
}

Cursor :: struct {
	cur: ^lmdb.MDB_cursor,
}

val_from_bytes :: proc(b: []u8) -> lmdb.MDB_val {
	if len(b) == 0 {
		return lmdb.MDB_val{mv_size = 0, mv_data = nil}
	}
	return lmdb.MDB_val{mv_size = len(b), mv_data = rawptr(&b[0])}
}

val_from_string :: proc(s: string) -> lmdb.MDB_val {
	return val_from_bytes(transmute([]u8)s)
}

bytes_from_string :: proc(s: string) -> []u8 {
	return transmute([]u8)s
}

encode_cbor :: proc(v: any, allocator := context.temp_allocator) -> (data: []u8, err: cbor.Marshal_Error) {
	data, err = cbor.marshal(v, allocator=allocator)
	return
}

decode_cbor :: proc(data: []u8, ptr: ^$T, allocator := context.allocator) -> (err: cbor.Unmarshal_Error) {
	return cbor.unmarshal_from_bytes(data, ptr, allocator=allocator)
}

encode_json :: proc(v: any, allocator := context.temp_allocator) -> (data: []u8, err: json.Marshal_Error) {
	return json.marshal(v, allocator=allocator)
}

decode_json :: proc(data: []u8, ptr: ^$T, allocator := context.allocator) -> (err: json.Unmarshal_Error) {
	return json.unmarshal(data, ptr, allocator=allocator)
}

open :: proc(path: cstring, mapsize: u64, maxdbs: u32 = 1, env_flags: u32 = 0, mode: lmdb.mdb_mode_t = lmdb.mdb_mode_t(0o775)) -> (db: DB, rc: i32) {
	env: ^lmdb.MDB_env
	rc = lmdb.mdb_env_create(&env)
	if rc != lmdb.MDB_SUCCESS {
		return
	}

	rc = lmdb.mdb_env_set_maxdbs(env, maxdbs)
	if rc != lmdb.MDB_SUCCESS {
		lmdb.mdb_env_close(env)
		return
	}

	if mapsize != 0 {
		rc = lmdb.mdb_env_set_mapsize(env, c.size_t(mapsize))
		if rc != lmdb.MDB_SUCCESS {
			lmdb.mdb_env_close(env)
			return
		}
	}

	rc = lmdb.mdb_env_open(env, path, env_flags, mode)
	if rc != lmdb.MDB_SUCCESS {
		lmdb.mdb_env_close(env)
		return
	}

	db.env = env
	return
}

close :: proc(db: ^DB) {
	if db.env != nil {
		lmdb.mdb_env_close(db.env)
		db.env = nil
	}
}

update :: proc(db: ^DB, fn: proc(tx: ^Txn) -> i32) -> i32 {
	txn: ^lmdb.MDB_txn
	rc := lmdb.mdb_txn_begin(db.env, nil, 0, &txn)
	if rc != lmdb.MDB_SUCCESS {
		return rc
	}
	defer if txn != nil {
		lmdb.mdb_txn_abort(txn)
	}

	dbi: lmdb.MDB_dbi
	rc = lmdb.mdb_dbi_open(txn, nil, 0, &dbi)
	if rc != lmdb.MDB_SUCCESS {
		return rc
	}
	defer lmdb.mdb_dbi_close(db.env, dbi)

	t := Txn{txn, dbi}
	rc = fn(&t)
	if rc != lmdb.MDB_SUCCESS {
		return rc
	}

	rc = lmdb.mdb_txn_commit(txn)
	if rc == lmdb.MDB_SUCCESS {
		txn = nil
	}
	return rc
}

update_ctx :: proc(db: ^DB, ctx: rawptr, fn: proc(ctx: rawptr, tx: ^Txn) -> i32) -> i32 {
	txn: ^lmdb.MDB_txn
	rc := lmdb.mdb_txn_begin(db.env, nil, 0, &txn)
	if rc != lmdb.MDB_SUCCESS {
		return rc
	}
	defer if txn != nil {
		lmdb.mdb_txn_abort(txn)
	}

	dbi: lmdb.MDB_dbi
	rc = lmdb.mdb_dbi_open(txn, nil, 0, &dbi)
	if rc != lmdb.MDB_SUCCESS {
		return rc
	}
	defer lmdb.mdb_dbi_close(db.env, dbi)

	t := Txn{txn, dbi}
	rc = fn(ctx, &t)
	if rc != lmdb.MDB_SUCCESS {
		return rc
	}

	rc = lmdb.mdb_txn_commit(txn)
	if rc == lmdb.MDB_SUCCESS {
		txn = nil
	}
	return rc
}

view :: proc(db: ^DB, fn: proc(tx: ^Txn) -> i32) -> i32 {
	txn: ^lmdb.MDB_txn
	rc := lmdb.mdb_txn_begin(db.env, nil, lmdb.MDB_RDONLY, &txn)
	if rc != lmdb.MDB_SUCCESS {
		return rc
	}
	defer if txn != nil {
		lmdb.mdb_txn_abort(txn)
	}

	dbi: lmdb.MDB_dbi
	rc = lmdb.mdb_dbi_open(txn, nil, 0, &dbi)
	if rc != lmdb.MDB_SUCCESS {
		return rc
	}
	defer lmdb.mdb_dbi_close(db.env, dbi)

	t := Txn{txn, dbi}
	rc = fn(&t)
	if rc != lmdb.MDB_SUCCESS {
		return rc
	}

	rc = lmdb.mdb_txn_commit(txn)
	if rc == lmdb.MDB_SUCCESS {
		txn = nil
	}
	return rc
}

view_ctx :: proc(db: ^DB, ctx: rawptr, fn: proc(ctx: rawptr, tx: ^Txn) -> i32) -> i32 {
	txn: ^lmdb.MDB_txn
	rc := lmdb.mdb_txn_begin(db.env, nil, lmdb.MDB_RDONLY, &txn)
	if rc != lmdb.MDB_SUCCESS {
		return rc
	}
	defer if txn != nil {
		lmdb.mdb_txn_abort(txn)
	}

	dbi: lmdb.MDB_dbi
	rc = lmdb.mdb_dbi_open(txn, nil, 0, &dbi)
	if rc != lmdb.MDB_SUCCESS {
		return rc
	}
	defer lmdb.mdb_dbi_close(db.env, dbi)

	t := Txn{txn, dbi}
	rc = fn(ctx, &t)
	if rc != lmdb.MDB_SUCCESS {
		return rc
	}

	rc = lmdb.mdb_txn_commit(txn)
	if rc == lmdb.MDB_SUCCESS {
		txn = nil
	}
	return rc
}

cursor_open :: proc(tx: ^Txn, c: ^Cursor) -> i32 {
	return lmdb.mdb_cursor_open(tx.txn, tx.dbi, &c.cur)
}

cursor_close :: proc(c: ^Cursor) {
	if c.cur != nil {
		lmdb.mdb_cursor_close(c.cur)
		c.cur = nil
	}
}

cursor_get :: proc(c: ^Cursor, op: lmdb.MDB_cursor_op) -> (key, val: []u8, rc: i32) {
	k: lmdb.MDB_val
	v: lmdb.MDB_val
	rc = lmdb.mdb_cursor_get(c.cur, &k, &v, op)
	if rc != lmdb.MDB_SUCCESS {
		return nil, nil, rc
	}
	key = slice.bytes_from_ptr(k.mv_data, int(k.mv_size))
	val = slice.bytes_from_ptr(v.mv_data, int(v.mv_size))
	return
}

cursor_seek :: proc(c: ^Cursor, key: []u8, op: lmdb.MDB_cursor_op) -> (found_key, val: []u8, rc: i32) {
	k := val_from_bytes(key)
	v: lmdb.MDB_val
	rc = lmdb.mdb_cursor_get(c.cur, &k, &v, op)
	if rc != lmdb.MDB_SUCCESS {
		return nil, nil, rc
	}
	found_key = slice.bytes_from_ptr(k.mv_data, int(k.mv_size))
	val = slice.bytes_from_ptr(v.mv_data, int(v.mv_size))
	return
}

cursor_put :: proc(c: ^Cursor, key, val: []u8, flags: u32 = 0) -> i32 {
	k := val_from_bytes(key)
	v := val_from_bytes(val)
	return lmdb.mdb_cursor_put(c.cur, &k, &v, flags)
}

cursor_del :: proc(c: ^Cursor, flags: u32 = 0) -> i32 {
	return lmdb.mdb_cursor_del(c.cur, flags)
}

put :: proc(tx: ^Txn, key, val: []u8, flags: u32 = 0) -> i32 {
	k := val_from_bytes(key)
	v := val_from_bytes(val)
	return lmdb.mdb_put(tx.txn, tx.dbi, &k, &v, flags)
}

get :: proc(tx: ^Txn, key: []u8) -> (val: []u8, rc: i32) {
	k := val_from_bytes(key)
	v: lmdb.MDB_val
	rc = lmdb.mdb_get(tx.txn, tx.dbi, &k, &v)
	if rc != lmdb.MDB_SUCCESS {
		return nil, rc
	}
	return slice.bytes_from_ptr(v.mv_data, int(v.mv_size)), rc
}

del :: proc(tx: ^Txn, key: []u8) -> i32 {
	k := val_from_bytes(key)
	return lmdb.mdb_del(tx.txn, tx.dbi, &k, nil)
}

put_cbor :: proc(tx: ^Txn, key: []u8, v: any, flags: u32 = 0, allocator := context.temp_allocator) -> (rc: i32, err: cbor.Marshal_Error) {
	data, e := encode_cbor(v, allocator)
	if e != nil {
		return lmdb.MDB_BAD_VALSIZE, e
	}
	return put(tx, key, data, flags), nil
}

get_cbor :: proc(tx: ^Txn, key: []u8, ptr: ^$T, allocator := context.allocator) -> (rc: i32, err: cbor.Unmarshal_Error) {
	data, r := get(tx, key)
	if r != lmdb.MDB_SUCCESS {
		return r, nil
	}
	err = decode_cbor(data, ptr, allocator)
	return r, err
}

put_json :: proc(tx: ^Txn, key: []u8, v: any, flags: u32 = 0, allocator := context.temp_allocator) -> (rc: i32, err: json.Marshal_Error) {
	data, e := encode_json(v, allocator)
	if e != nil {
		return lmdb.MDB_BAD_VALSIZE, e
	}
	return put(tx, key, data, flags), nil
}

get_json :: proc(tx: ^Txn, key: []u8, ptr: ^$T, allocator := context.allocator) -> (rc: i32, err: json.Unmarshal_Error) {
	data, r := get(tx, key)
	if r != lmdb.MDB_SUCCESS {
		return r, nil
	}
	err = decode_json(data, ptr, allocator)
	return r, err
}

cursor_put_cbor :: proc(c: ^Cursor, key: []u8, v: any, flags: u32 = 0, allocator := context.temp_allocator) -> (rc: i32, err: cbor.Marshal_Error) {
	data, e := encode_cbor(v, allocator)
	if e != nil {
		return lmdb.MDB_BAD_VALSIZE, e
	}
	return cursor_put(c, key, data, flags), nil
}

cursor_get_cbor :: proc(c: ^Cursor, op: lmdb.MDB_cursor_op, ptr: ^$T, allocator := context.allocator) -> (key: []u8, rc: i32, err: cbor.Unmarshal_Error) {
	val: []u8
	key, val, rc = cursor_get(c, op)
	if rc != lmdb.MDB_SUCCESS {
		return nil, rc, nil
	}
	err = decode_cbor(val, ptr, allocator)
	return key, rc, err
}

cursor_put_json :: proc(c: ^Cursor, key: []u8, v: any, flags: u32 = 0, allocator := context.temp_allocator) -> (rc: i32, err: json.Marshal_Error) {
	data, e := encode_json(v, allocator)
	if e != nil {
		return lmdb.MDB_BAD_VALSIZE, e
	}
	return cursor_put(c, key, data, flags), nil
}

cursor_get_json :: proc(c: ^Cursor, op: lmdb.MDB_cursor_op, ptr: ^$T, allocator := context.allocator) -> (key: []u8, rc: i32, err: json.Unmarshal_Error) {
	val: []u8
	key, val, rc = cursor_get(c, op)
	if rc != lmdb.MDB_SUCCESS {
		return nil, rc, nil
	}
	err = decode_json(val, ptr, allocator)
	return key, rc, err
}
