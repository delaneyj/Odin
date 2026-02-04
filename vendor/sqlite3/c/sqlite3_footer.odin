// Bindgen output replacement for SQLITE_STATIC / SQLITE_TRANSIENT.
SQLITE_STATIC : sqlite3_destructor_type = nil
SQLITE_TRANSIENT : sqlite3_destructor_type = transmute(sqlite3_destructor_type)(rawptr(~uintptr(0)))
