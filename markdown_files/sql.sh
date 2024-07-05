#!/bin/bash -eu

pushd ~/dev/termdex/markdown_files/ >/dev/null
zig build
popd 2>/dev/null

sqlite3 ":memory:" -column -cmd ".load ./zig-out/lib/libmarkdown_files.so sqlite3_markdown_files_init" "$@"
