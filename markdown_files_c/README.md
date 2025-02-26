# Markdown Files SQLite Extension

This SQLite extension provides functionality to work with Markdown files within SQLite queries.

## Features

- Virtual table `md_files` to list and query markdown files in a directory
- Function `md_contents(path)` to get the raw content of a markdown file
- Function `md_front_matter(path, field)` to extract YAML front matter fields from markdown files
- Function `md_html(path)` to convert markdown content to HTML

## Building

```bash
make
```

This will produce `libmd_files.so` which can be loaded into SQLite.

## Requirements

- SQLite3 development libraries
- LibYAML for front matter parsing
- cmark-gfm for markdown to HTML conversion

## Usage

### In SQLite

```sql
-- Load the extension
.load ./libmd_files.so

-- Create a virtual table on a directory of markdown files
CREATE VIRTUAL TABLE notes USING md_files('/path/to/markdown/files');

-- Query all markdown files in the directory
SELECT path, basename, size_bytes, mtime_s FROM notes;

-- Get the content of a markdown file
SELECT md_contents(path) FROM notes WHERE basename = 'example.md';

-- Extract front matter field from a markdown file
SELECT md_front_matter(path, 'title') FROM notes WHERE basename = 'example.md';

-- Convert markdown to HTML
SELECT md_html(path) FROM notes WHERE basename = 'example.md';
```

### Front Matter Format

The extension expects front matter in YAML format at the beginning of markdown files, delimited by `---` lines:

```markdown
---
title: Example Document
author: John Doe
date: 2023-01-01
---

# Content starts here
```

## License

Same as the termdex project.