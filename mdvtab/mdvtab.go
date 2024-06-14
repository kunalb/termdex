package main

/*
#cgo CFLAGS: -g -Wall
#cgo LDFLAGS: -lsqlite3
#include "sqlite3ext.h"

int c_sqlite3_mdvtab_init(
  sqlite3 *db,
  char **pzErrMsg,
  const sqlite3_api_routines *pApi
);
*/
import "C"
import (
	"bufio"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"

	"github.com/adrg/frontmatter"
)

type MdFile struct {
	Path        string
	Size        int64
	FrontMatter map[string]interface{}
}

type Table struct {
	Dir   string
	Files []MdFile
	Cols  []string
}

func (cur *Table) Init() {
	filepath.WalkDir(cur.Dir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			panic(err)
		}

		if !d.IsDir() && filepath.Ext(path) == ".md" {
			info, infoErr := d.Info()
			if infoErr != nil {
				panic(infoErr)
			}

			var matter map[string]interface{}

			fileReader, openErr := os.Open(path)
			if openErr != nil {
				panic(openErr)
			}

			_, matterErr := frontmatter.Parse(bufio.NewReader(fileReader), &matter)
			if matterErr != nil {
				panic(matterErr)
			}

			cur.Files = append(cur.Files, MdFile{path, info.Size(), matter})
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

var cacheId int64 = 0
var cursorCache = make(map[int64]Table)

//export sqlite3_mdvtab_init
func sqlite3_mdvtab_init(db *C.sqlite3, pzErrMsg **C.char, pApi *C.sqlite3_api_routines) C.int {
	return C.c_sqlite3_mdvtab_init(db, pzErrMsg, pApi)
}

//export CreateTable
func CreateTable(dir *C.char) int64 {
	cursorCache[cacheId] = MakeTable(C.GoString(dir))
	cacheId++

	return cacheId - 1
}

//export TableDeclaration
func TableDeclaration(tableId int64) *C.char {
	decl := "CREATE TABLE x(fileName, sizeBytes"
	for _, col := range cursorCache[tableId].Cols {
		decl += ", frontmatter_" + col
	}
	decl += ")"
	return C.CString(decl)
}

//export DeleteTable
func DeleteTable(id int64) {
	delete(cursorCache, id)
}

//export CursorFileName
func CursorFileName(tableId int64, rowId int64) *C.char {
	return C.CString(cursorCache[tableId].Files[rowId].Path)
}

//export CursorFileLength
func CursorFileLength(tableId int64, rowId int64) int {
	return int(cursorCache[tableId].Files[rowId].Size)
}

//export CursorFrontMatter
func CursorFrontMatter(tableId int64, rowId int64, colId int) *C.char {
	file := &cursorCache[tableId].Files[rowId]
	val := file.FrontMatter[cursorCache[tableId].Cols[colId-2]]
	if val == nil {
		return nil
	} else {
		return C.CString(fmt.Sprint(val))
	}
}

//export TableLength
func TableLength(tableId int64) int64 {
	return int64(len(cursorCache[tableId].Files))
}

func main() {}
