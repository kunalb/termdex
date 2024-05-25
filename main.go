package main

import (
	"github.com/gdamore/tcell/v2"

	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"time"
)

import flag "github.com/spf13/pflag"

func redirectLogs() func() {
	logFile, err := os.OpenFile("/tmp/termdex.log", os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		log.Fatal(err)
	}
	log.SetOutput(logFile)

	return func() {
		logFile.Close()
	}
}

func drawText(s tcell.Screen, x1, y1, x2, y2 int, style tcell.Style, text string) {
	row := y1
	col := x1
	for _, r := range []rune(text) {
		s.SetContent(col, row, r, nil, style)
		col++
		if col >= x2 {
			row++
			col = x1
		}
		if row > y2 {
			break
		}
	}
}

func drawBox(s tcell.Screen, x1, y1, x2, y2 int, style tcell.Style, text string) {
	if y2 < y1 {
		y1, y2 = y2, y1
	}
	if x2 < x1 {
		x1, x2 = x2, x1
	}

	// Fill background
	for row := y1; row <= y2; row++ {
		for col := x1; col <= x2; col++ {
			s.SetContent(col, row, ' ', nil, style)
		}
	}

	// Draw borders
	for col := x1; col <= x2; col++ {
		s.SetContent(col, y1, tcell.RuneHLine, nil, style)
		s.SetContent(col, y2, tcell.RuneHLine, nil, style)
	}
	for row := y1 + 1; row < y2; row++ {
		s.SetContent(x1, row, tcell.RuneVLine, nil, style)
		s.SetContent(x2, row, tcell.RuneVLine, nil, style)
	}

	// Only draw corners if necessary
	if y1 != y2 && x1 != x2 {
		s.SetContent(x1, y1, tcell.RuneULCorner, nil, style)
		s.SetContent(x2, y1, tcell.RuneURCorner, nil, style)
		s.SetContent(x1, y2, tcell.RuneLLCorner, nil, style)
		s.SetContent(x2, y2, tcell.RuneLRCorner, nil, style)
	}

	drawText(s, x1+1, y1+1, x2-1, y2-1, style, text)
}

func help() {
	println("TermDex -- terminal index cards\n")
	println("Subcommands: ")
	println("  board: visualize existing cards")
	println("  browse: browse all notes")
	println("  init: register a directory as a termdex")
	println("  new: create a new card")
	println("  journal: create daily entry")
	println("  lsp: run as an lsp for $EDITOR, useful for linking")
	println()
}

func Init() {

}

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

func Board() {
	CrawlDir(".")

	defStyle := tcell.StyleDefault.Background(tcell.ColorReset).Foreground(tcell.ColorReset)
	boxStyle := tcell.StyleDefault.Foreground(tcell.ColorWhite).Background(tcell.ColorPurple)

	// Initialize screen
	s, err := tcell.NewScreen()
	if err != nil {
		log.Fatalf("%+v", err)
	}
	if err := s.Init(); err != nil {
		log.Fatalf("%+v", err)
	}
	s.SetStyle(defStyle)
	s.EnableMouse()
	s.EnablePaste()
	s.Clear()

	// Draw initial boxes
	drawBox(s, 1, 1, 42, 7, boxStyle, "Click and drag to draw a box")
	drawBox(s, 5, 9, 32, 14, boxStyle, "Press C to reset")

	quit := func() {
		maybePanic := recover()
		s.Fini()
		if maybePanic != nil {
			panic(maybePanic)
		}
	}
	defer quit()

	// Here's how to get the screen size when you need it.
	// xmax, ymax := s.Size()

	// Here's an example of how to inject a keystroke where it will
	// be picked up by the next PollEvent call.  Note that the
	// queue is LIFO, it has a limited length, and PostEvent() can
	// return an error.
	// s.PostEvent(tcell.NewEventKey(tcell.KeyRune, rune('a'), 0))

	// Event loop
	ox, oy := -1, -1
	for {
		// Update screen
		s.Show()

		// Poll event
		ev := s.PollEvent()

		// Process event
		switch ev := ev.(type) {
		case *tcell.EventResize:
			s.Sync()
		case *tcell.EventKey:
			if ev.Key() == tcell.KeyEscape || ev.Key() == tcell.KeyCtrlC {
				return
			} else if ev.Key() == tcell.KeyCtrlL {
				s.Sync()
			} else if ev.Rune() == 'C' || ev.Rune() == 'c' {
				s.Clear()
			}
		case *tcell.EventMouse:
			x, y := ev.Position()

			switch ev.Buttons() {
			case tcell.Button1, tcell.Button2:
				if ox < 0 {
					ox, oy = x, y // record location when click started
				}

			case tcell.ButtonNone:
				if ox >= 0 {
					label := fmt.Sprintf("%d,%d to %d,%d", ox, oy, x, y)
					drawBox(s, ox, oy, x, y, boxStyle, label)
					ox, oy = -1, -1
				}
			}
		}
	}
}


func Journal() {
	editorBinary := os.Getenv("EDITOR")
	if editorBinary == "" {
		log.Println(
			"Couldn't find a configured editor: set the EDITOR environment" +
				"variable to a suitable editor. Falling back to nano.")
		editorBinary = "nano"
	}

	currentTime := time.Now()
	indexCardDir := currentTime.Format("2006/01/02")

	fileName := "journal.md"

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
		log.Fatal("Failed to run nvim: ", cmdErr)
	}
}


func main() {
	// Redirect logs because stdout/stderr are used for rendering
	closeLogFile := redirectLogs()
	defer closeLogFile()

	newCmd := flag.NewFlagSet("new", flag.ExitOnError)

	subCommand := "board"
	if len(os.Args) > 1 {
		subCommand = os.Args[1]
	}

	switch subCommand {
	case "new":
		newCmd.Parse(os.Args[2:])
		NewCard()
	case "board":
		Board()
	case "journal":
		Journal()
	default:
		help()
		os.Exit(1)
	}
}
