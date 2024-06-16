package cmd

import (
	"github.com/kunalb/termdex/pkg"
	"github.com/spf13/cobra"
)

var templateFile string

// newCmd represents the new command
var newCmd = &cobra.Command{
	Use:   "new",
	Short: "Add a new index card",
	Long:  "Create a new time based card",
	Args:  cobra.NoArgs,
	Run: func(cmd *cobra.Command, args []string) {
		pkg.NewCard(templateFile)
	},
}

func init() {
	rootCmd.AddCommand(newCmd)
	newCmd.Flags().StringVarP(&templateFile, "templateFile", "t", "", "Template file for new card")
}
