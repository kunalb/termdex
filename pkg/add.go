package pkg

import (
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"time"
	"log"
)


func NewCard() {
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

	cmdErr := cmd.Wait()
	if cmdErr != nil {
		log.Fatal("Failed to run vim: ", cmdErr)
	}
}
