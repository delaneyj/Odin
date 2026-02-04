@(private)
LIB :: (
	     "../lib/lmdb.lib"     when ODIN_OS == .Windows
	else "../lib/liblmdb.a"    when ODIN_OS == .Linux
	else "../lib/liblmdb.a"    when ODIN_OS == .Darwin
	else ""
)

when LIB != "" {
	when !#exists(LIB) {
		#panic("Could not find the compiled lmdb library. Build it by running `sh \"" + ODIN_ROOT + "/vendor/lmdb/build.sh\"` (or `build.bat` on Windows).")
	}
}

when LIB != "" {
	foreign import lib { LIB }
} else {
	foreign import lib "system:lmdb"
}
