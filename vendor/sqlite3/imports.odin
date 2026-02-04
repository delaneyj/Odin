@(private)
LIB :: (
	     "../lib/sqlite3.lib"    when ODIN_OS == .Windows
	else "../lib/libsqlite3.a"   when ODIN_OS == .Linux
	else "../lib/libsqlite3.a"   when ODIN_OS == .Darwin
	else ""
)

when LIB != "" {
	when !#exists(LIB) {
		#panic("Could not find the compiled sqlite3 library. Build it by running `sh \"" + ODIN_ROOT + "/vendor/sqlite3/build.sh\"` (or `build.bat` on Windows).")
	}
}

when LIB != "" {
	foreign import lib { LIB }
} else {
	foreign import lib "system:sqlite3"
}
