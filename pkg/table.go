package pkg

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"text/tabwriter"
)

func GenerateTable() error {
	currentDir, err := os.Getwd()
	if err != nil {
		return err
	}

	cards, err := Crawl(currentDir)
	if err != nil {
		return err
	}

	// Create a new tabwriter to format the table
	tw := new(tabwriter.Writer)
	tw.Init(os.Stdout, 0, 8, 2, ' ', 0)

	// Extract the unique keys from the frontmatter of all cards
	keys := make(map[string]bool)
	for _, card := range cards {
		for key := range card.Frontmatter {
			keys[key] = true
		}
	}
	keyList := mapKeys(keys)

	// Write the table header
	fmt.Fprintln(tw, "Title\t"+strings.Join(keyList, "\t"))

	// Write the table rows
	for _, card := range cards {
		title, ok := card.Frontmatter["title"].(string)
		if !ok {
			title = filepath.Base(card.Path)
		}
		row := fmt.Sprintf("%s", title, )

		for _, key := range keyList {
			value, ok := card.Frontmatter[key]
			if !ok {
				row += "\t"
			} else {
				row += fmt.Sprintf("\t%v", value)
			}
		}
		fmt.Fprintln(tw, row)
	}

	// Flush the tabwriter to output the formatted table
	tw.Flush()
	return nil
}

// Helper function to convert map keys to a slice of strings
func mapKeys(m map[string]bool) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	return keys
}
