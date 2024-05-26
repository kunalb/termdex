/*
Copyright © 2024 NAME HERE <EMAIL ADDRESS>

*/
package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

var cfgFile string

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "termdex",
	Short: "Index cards in the terminal",
	Long: `
Create and manage markdown files easily in the terminal.

TermDex lets you quickly add, index and explore index cards
-- inspired by FocalBoard, Notion, LogSeq, Obsidian -- but written
as a unix application.

Sub commands:
  init    -- explicitly mark a folder as a termdex collection (useful for saving configuratons)
  new     -- add an index card (markdown file)
  board   -- visualize files as a kanban board
  table   -- visualize files as a nested table
`,
}

func Execute() {
	err := rootCmd.Execute()
	if err != nil {
		os.Exit(1)
	}
}

func init() {
	cobra.OnInitialize(initConfig)
	rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is $HOME/.config/termdex/termdex.toml)")
}

// initConfig reads in config file and ENV variables if set.
func initConfig() {
	if cfgFile != "" {
		// Use config file from the flag.
		viper.SetConfigFile(cfgFile)
	} else {
		home, err := os.UserHomeDir()
		cobra.CheckErr(err)
		// TODO: Replace with XDG_CONFIG_HOME
		// Search config in home directory with name ".termdex" (without extension).
		viper.AddConfigPath(home)
		viper.SetConfigName("termdex.toml")
	}

	viper.AutomaticEnv() // read in environment variables that match
	if err := viper.ReadInConfig(); err == nil {
		fmt.Fprintln(os.Stderr, "Using config file:", viper.ConfigFileUsed())
	}
}
