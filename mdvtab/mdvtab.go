// Implements a Virtual Table extension for SQLite that allows querying
// markdown documents through SQL, with special handling for frontmatter.
//
// TODO:
//   - Make the table structure static and use JSONB to store metadata; makes
//     the table be significantly more "live" to react to changing/new files.
package main

// #cgo CFLAGS: -g -Wall
// #cgo LDFLAGS: -lsqlite3
// #include "sqlite3ext.h"
//
// int sqlite3_mdvtab_init_impl(
//   sqlite3 *db,
//   char **pzErrMsg,
//   const sqlite3_api_routines *pApi
// );
import "C"
import (
	"bufio"
	"fmt"
	"io/fs"
	"log"
	"os"
	"path/filepath"
	"sort"

	"github.com/adrg/frontmatter"
)

type MdFile struct {
	Path    string
	Size    int64
	ModTime int64
	// FirstCreated int64
	FrontMatter map[string]interface{}
}

type Table struct {
	Dir   string
	Files []MdFile
	Cols  []string
}

const FIXED_COLS int = 3
var tableCounter int64 = 0
var tables = make(map[int64]Table)

// Walk over the directory and fill in the table details
// This is done up front to make sure the table schema can be created correctly
func (cur *Table) Init() {
	filepath.WalkDir(cur.Dir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			log.Printf("Skipping indexing %s because of %s", path, err)
			return nil
		}

		if !d.IsDir() && filepath.Ext(path) == ".md" {
			info, infoErr := d.Info()
			if infoErr != nil {
				log.Printf("Couldn't get file info of %s because of %s; skipping file", path, infoErr)
				return nil
			}

			var matter map[string]interface{}

			fileReader, openErr := os.Open(path)
			if openErr != nil {
				log.Printf("Couldn't open %s because of %s; skipping file.", path, openErr)
				return nil
			}

			_, matterErr := frontmatter.Parse(bufio.NewReader(fileReader), &matter)
			if matterErr != nil {
				log.Printf("Couldn't parse the front matter of %s because of %s; skipping parsing.", path, matterErr)
			}

			cur.Files = append(cur.Files, MdFile{path, info.Size(), info.ModTime().Unix(), matter})
		}
		return nil
	})

	allMatter := make(map[string]bool)
	for _, file := range cur.Files {
		for key := range file.FrontMatter {
			allMatter[key] = true
		}
	}
	for key := range allMatter {
		cur.Cols = append(cur.Cols, key)
	}
	sort.Strings(cur.Cols)
}

func MakeTable(dir string) Table {
	table := Table{dir, nil, nil}
	table.Init()
	return table
}

//export sqlite3_mdvtab_init
func sqlite3_mdvtab_init(db *C.sqlite3, pzErrMsg **C.char, pApi *C.sqlite3_api_routines) C.int {
	return C.sqlite3_mdvtab_init_impl(db, pzErrMsg, pApi)
}

//export CreateTable
func CreateTable(dir *C.char) int64 {
	tables[tableCounter] = MakeTable(C.GoString(dir))
	tableCounter++

	return tableCounter - 1
}

//export TableDeclaration
func TableDeclaration(tableId int64) *C.char {
	decl := "CREATE TABLE x(file_name, mod_time, size_bytes"
	for _, col := range tables[tableId].Cols {
		decl += ", frontmatter_" + col
	}
	decl += ")"
	return C.CString(decl)
}

//export DeleteTable
func DeleteTable(id int64) {
	delete(tables, id)
}

//export CursorFileName
func CursorFileName(tableId int64, rowId int64) *C.char {
	return C.CString(tables[tableId].Files[rowId].Path)
}

//export CursorFileLength
func CursorFileLength(tableId int64, rowId int64) int {
	return int(tables[tableId].Files[rowId].Size)
}

//export CursorModTime
func CursorModTime(tableId int64, rowId int64) int {
	return int(tables[tableId].Files[rowId].ModTime)
}

//export CursorFrontMatter
func CursorFrontMatter(tableId int64, rowId int64, colId int) *C.char {
	file := &tables[tableId].Files[rowId]
	val := file.FrontMatter[tables[tableId].Cols[colId-FIXED_COLS]]
	if val == nil {
		return nil
	} else {
		return C.CString(fmt.Sprint(val))
	}
}

//export TableLength
func TableLength(tableId int64) int64 {
	return int64(len(tables[tableId].Files))
}

func main() {}
