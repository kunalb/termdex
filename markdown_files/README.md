# Markdown Files

A SQLite extension that makes it possible to do SQL queries over a collection of markdown files: the extension understands frontmatter and metadata, so you can easily query for specific parts of frontmatter, file contents, headings, links, and craft your own queries.

As a bonus, you can also use it to *render* markdown to html using helper functions.

This is brand new software mainly written to scratch my own itch, please feel free to report bugs and issues -- I expect it will take some time and effort to make it rock solid.


## Getting Started
Download the extension that matches your architecture from the [Releases](https://github.com/kunalb/termdex/releases) tab.

Start your sqlite session in a folder with your markdown files, (or [obsidian](https://obsidian.md/) vault, [logseq](https://logseq.com/) graph, [silverbullet](https://silverbullet.md/) system, [hugo](https://gohugo.io/) site, etc.) --


Currently, it requires `libcmark-gfm` and `libyaml` to be installed to parse and manipulate markdown and yaml respectively.


```
# Launching sqlite
sqlite3

# Load in the extension with
.load libmarkdown_files.so

# See all available files, with file metadata
SELECT * FROM markdown_files

# Extract 'title' and contents from the YAML frontmatter
SELECT path, mdf_front_matter(path, 'title'), mdf_contents(path) FROM markdown_files

# Make a virtual table pointing to a different folder
CREATE VIRTUAL TABLE dex USING markdown_files(/home/knl/dex)

# Make a view with the columns you care about
CREATE TEMP VIEW posts (path, title, tags, content) AS
SELECT
  path,
  mdf_front_matter(path, 'title'),
  mdf_front_matter(path, 'tags'),
  mdf_contents(path)
FROM dex
```

The extension also works in different SQLite UIs like [SQLite browser](https://sqlitebrowser.org/).


## Background
Roughly once a year I build myself a new productivity system, slipbox (Zettelkasten) or static site generation mechanism. One common factor is relying extensively on flat files (used to rely on `.org` but these days I switched to `.md` -- and being able to easily query and manipulate them is really valuable.

`termdex/markdown_files` is a building block that I can apply for all of these, with minimal assumptions on how the markdown files were created, how they're managed or interacted with -- and gives a quick way to query them, and then build second order tools on top.

Check out the bash script at [termdex/tdx](https://github.com/kunalb/termdex/blob/main/tdx) as an example.


## Code Outline
This extension is fairly simple, and carefully broken down with
- `markdown_files.zig` as the main interface to sqlite, written like C
- `markdown.zig` functions to manipulate markdown
- `front_matter.zig` functions to manipulate the yaml front-matter

I'm fairly new to zig, and I'm still learning the idioms. Code reviews appreciated!


## Reference


## Change log and plans

### Future
- [ ] Add support for creating files by inserting records
- [ ] Add support for updating files by modifying rows
- [ ] Document and publish as a library & zig package
- [ ] Statically link all dependencies

### 2024-07-30 Open Sourced
- [x] Translate the sample markdown table to a Zig extension
- [x] Update the extension to list files (recursively) in the directory
- [x] Add support for parsing frontmatter (YAML)
- [ ] Add support for parsing markdown itself (headers, links, wiki links)
- [ ] Use virtual tables for all multiple valued columns
