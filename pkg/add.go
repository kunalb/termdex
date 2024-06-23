package pkg

import (
	"io"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"time"
)

func NewCard(templatePath string) {
	// TODO Figure out a reasonable template for this card
	// Based on the other cards in the current dex folder
	editorBinary := os.Getenv("EDITOR")
	if editorBinary == "" {
		log.Println(
			"Couldn't find a configured editor: set the EDITOR environment" +
				"variable to a suitable editor. Falling back to nano.")
		editorBinary = "nano"
	}

	currentTime := time.Now()
	indexCardDir := currentTime.Format("2006/01/02")

	fileName := strconv.FormatInt(currentTime.Unix(), 10) + ".md"

	dirErr := os.MkdirAll(indexCardDir, os.ModePerm)
	if dirErr != nil {
		log.Fatal(dirErr)
	}

	cardPath := filepath.Join(indexCardDir, fileName)

	if templatePath != "" {
		if copyErr := copyFile(cardPath, templatePath); copyErr != nil {
			log.Printf("Couldn't apply template %s to %s because of %s\n", templatePath, cardPath, copyErr)
		}
	} else {
		if defaultErr := makeDefaultCard(cardPath); defaultErr != nil {
			log.Printf("Couldn't apply default template to %s because of %s\n", cardPath, defaultErr)
		}
	}

	cmdPath, cmdPathErr := exec.LookPath(editorBinary)
	if cmdPathErr != nil {
		log.Panic(cmdPathErr)
	}

	cmd := exec.Command(cmdPath, cardPath)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = os.Environ()
	editErr := cmd.Run()
	if editErr != nil {
		log.Fatal(editErr)
	}
}

func copyFile(dstPath, srcPath string) error {
	srcFile, err := os.Open(srcPath)
	if err != nil {
		return err
	}
	defer srcFile.Close()

	dstFile, err := os.Create(dstPath)
	if err != nil {
		return err
	}
	defer dstFile.Close()

	_, err = io.Copy(dstFile, srcFile)
	if err != nil {
		return err
	}

	err = dstFile.Sync()
	if err != nil {
		return err
	}

	return nil
}

func makeDefaultCard(dstPath string) error {
	file, err := os.Create(dstPath)
	if err != nil {
		return err
	}
	defer file.Close()

	file.WriteString(`---
title:                    # Quick summary, can leave body empty
tags:                     # Simple categorization, preferably use more structured
what:                     # Type: meeting, note, event, quote, task
when:                     # Kanban style: today, tomorrow, week, month, quarter
category:                 # Associate with a longer term note, with path (single)
state:                    # Mainly for tasks: active, done, delegated, blocked, etc.
---
`)
	return nil
}
