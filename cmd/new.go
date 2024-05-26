package cmd

import (
	"github.com/spf13/cobra"
	"github.com/kunalb/termdex/pkg"
)

// newCmd represents the new command
var newCmd = &cobra.Command{
	Use:   "new",
	Short: "Add a new index card",
	Long: `Create a card based on the current date`,
	Run: func(cmd *cobra.Command, args []string) {
		pkg.NewCard()
	},
}

func init() {
	rootCmd.AddCommand(newCmd)

	// todo template support
	// Here you will define your flags and configuration settings.

	// Cobra supports Persistent Flags which will work for this command
	// and all subcommands, e.g.:
	// newCmd.PersistentFlags().String("foo", "", "A help for foo")

	// Cobra supports local flags which will only run when this command
	// is called directly, e.g.:
	// newCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")
}
