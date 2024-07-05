#!/bin/bash -eu

cd ~/dev/termdex/markdown_files/

zig build
./sqlite/sqlite3 \
    -column :memory: -cmd \
    ".load ./zig-out/lib/libmarkdown_files.so sqlite3_markdown_files_init" \
    "CREATE VIRTUAL TABLE dex USING markdown_files(/home/knl/dex)" \
    "SELECT * FROM dex WHERE path LIKE '%.md' AND path NOT LIKE '.git%'"
