# MDDir: Markdown Directories as a SQLite virtual table

This is a second attempt to implement a SQLite extension as a virtual table.


## TODO
- [ ] Translate the sample markdown table to a Zig extension
- [ ] Update the extension to list files (recursively) in the directory
- [ ] Add support for parsing frontmatter (YAML)
- [ ] Add support for parsing markdown itself (headers, links, wiki links)
- [ ] Add support for creating files by inserting records
- [ ] Add support for updating files by modifying rows
- [ ] Document and publish as a library & zig package
