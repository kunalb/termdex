/*
Copyright © 2024 NAME HERE <EMAIL ADDRESS>

*/
package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

// initCmd represents the init command
var initCmd = &cobra.Command{
	Use:   "init",
	Short: "Mark current directory as the root of an index.",
	Long: `
Explicitly mark the directory as a terminal index.

This lets you run termdex in any sub folder and consider the
full directory by default, as well as sharing configuration
files within the directory.`,
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("init called -- create a .termdex folder")
	},
}

func init() {
	rootCmd.AddCommand(initCmd)
}
