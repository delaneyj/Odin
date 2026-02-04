// Bindgen output replacement for mdb_mode_t (avoids missing mode_t in bindings).
// The footer is concatenated by bindgen after generating lmdb.odin.
when ODIN_OS == .Windows {
	mdb_mode_t :: c.int
} else {
	mdb_mode_t :: c.uint
}
