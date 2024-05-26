package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"

	"github.com/BurntSushi/toml"
	_ "github.com/mattn/go-sqlite3"
	"gopkg.in/yaml.v2"
)

type MarkdownTable struct {
	path string
}

func (m *MarkdownTable) Create(c *sqlite3.SQLiteConn, args []string) (sqlite3.VTab, error) {
	// Placeholder for the dynamic schema
	schema := `
		CREATE TABLE %s (
			path TEXT,
			content TEXT
		)
	`

	// Iterate over the markdown files to determine the frontmatter keys
	var frontmatterKeys []string
	err := filepath.Walk(args[1], func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() && strings.HasSuffix(info.Name(), ".md") {
			content, err := ioutil.ReadFile(path)
			if err != nil {
				return err
			}

			parts := strings.SplitN(string(content), "---", 3)
			if len(parts) < 3 {
				return nil
			}

			frontmatter := strings.TrimSpace(parts[1])

			var data map[string]interface{}
			if strings.HasPrefix(frontmatter, "{") {
				err = json.Unmarshal([]byte(frontmatter), &data)
			} else if strings.Contains(frontmatter, "=") {
				_, err = toml.Decode(frontmatter, &data)
			} else {
				err = yaml.Unmarshal([]byte(frontmatter), &data)
			}

			if err != nil {
				return err
			}

			for key := range data {
				if !contains(frontmatterKeys, key) {
					frontmatterKeys = append(frontmatterKeys, key)
				}
			}
		}
		return nil
	})

	if err != nil {
		return nil, err
	}

	// Update the schema with the frontmatter keys as columns
	for _, key := range frontmatterKeys {
		schema += fmt.Sprintf(",\n\t\t%s TEXT", key)
	}

	err = c.DeclareVTab(fmt.Sprintf(schema, args[0]))
	if err != nil {
		return nil, err
	}

	return &MarkdownTable{path: args[1]}, nil
}

func contains(slice []string, item string) bool {
	for _, s := range slice {
		if s == item {
			return true
		}
	}
	return false
}

func (m *MarkdownTable) Open() (sqlite3.VTabCursor, error) {
	return &MarkdownCursor{path: m.path}, nil
}

type MarkdownCursor struct {
	path        string
	files       []string
	index       int
	frontmatter map[string]interface{}
}

func (m *MarkdownCursor) Column(c *sqlite3.SQLiteContext, col int) error {
	file := m.files[m.index]

	if col == 0 {
		c.ResultText(file)
		return nil
	}

	if col == 1 {
		content, err := ioutil.ReadFile(filepath.Join(m.path, file))
		if err != nil {
			return err
		}

		parts := strings.SplitN(string(content), "---", 3)
		if len(parts) < 3 {
			return nil
		}

		markdownContent := strings.TrimSpace(parts[2])
		c.ResultText(markdownContent)
		return nil
	}

	colName := c.ColumnName(col)
	value, ok := m.frontmatter[colName]
	if ok {
		c.ResultText(fmt.Sprint(value))
	} else {
		c.ResultNull()
	}

	return nil
}

func (m *MarkdownCursor) Filter(idxNum int, idxStr string, vals []interface{}) error {
	m.files = nil
	m.index = 0

	err := filepath.Walk(m.path, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() && strings.HasSuffix(info.Name(), ".md") {
			m.files = append(m.files, path)
		}
		return nil
	})

	if err != nil {
		return err
	}

	return nil
}

func (m *MarkdownCursor) Next() error {
	m.index++

	if m.index < len(m.files) {
		content, err := ioutil.ReadFile(filepath.Join(m.path, m.files[m.index]))
		if err != nil {
			return err
		}

		parts := strings.SplitN(string(content), "---", 3)
		if len(parts) < 3 {
			return nil
		}

		frontmatter := strings.TrimSpace(parts[1])

		if strings.HasPrefix(frontmatter, "{") {
			err = json.Unmarshal([]byte(frontmatter), &m.frontmatter)
		} else if strings.Contains(frontmatter, "=") {
			_, err = toml.Decode(frontmatter, &m.frontmatter)
		} else {
			err = yaml.Unmarshal([]byte(frontmatter), &m.frontmatter)
		}

		if err != nil {
			return err
		}
	}

	return nil
}

func (m *MarkdownCursor) EOF() bool {
	return m.index >= len(m.files)
}

func (m *MarkdownCursor) Rowid() (int64, error) {
	return int64(m.index), nil
}

func (m *MarkdownCursor) Close() error {
	return nil
}

func main() {
	sql.Register("markdowntable", &sqlite3.SQLiteDriver{
		ConnectHook: func(conn *sqlite3.SQLiteConn) error {
			return conn.CreateModule("markdowntable", &MarkdownTable{})
		},
	})
}
