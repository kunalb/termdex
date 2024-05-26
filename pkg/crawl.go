package pkg

import (
    "io/ioutil"
    "os"
    "path/filepath"
    "strings"

    "github.com/BurntSushi/toml"
)

type Card struct {
    Path        string
    Frontmatter map[string]interface{}
    Content     string
}

func Crawl(root string) ([]*Card, error) {
    var cards []*Card

    err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
	if err != nil {
	    return err
	}

	if !info.IsDir() && strings.HasSuffix(info.Name(), ".md") {
	    data, err := ioutil.ReadFile(path)
	    if err != nil {
		return err
	    }

	    content := string(data)
	    parts := strings.SplitN(content, "+++", 3)

	    if len(parts) == 3 {
		var frontmatter map[string]interface{}
		_, err := toml.Decode(parts[1], &frontmatter)
		if err != nil {
		    return err
		}

		card := &Card{
		    Path:        path,
		    Frontmatter: frontmatter,
		    Content:     strings.TrimSpace(parts[2]),
		}
		cards = append(cards, card)
	    }
	}

	return nil
    })

    if err != nil {
	return nil, err
    }

    return cards, nil
}
