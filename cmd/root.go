package cmd

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var version = "dev"

var rootCmd = &cobra.Command{
	Use:   "arco [expression]",
	Short: "Evaluate Jsonnet expressions against a configured root",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		cmd.SilenceUsage = true
		cmd.SilenceErrors = true

		format, err := cmd.Flags().GetString("format")
		if err != nil {
			return err
		}

		facade, err := NewFacade()
		if err != nil {
			return err
		}

		result, err := facade.Evaluate(args[0])
		if err != nil {
			return err
		}

		switch format {
		case "json":
			return json.NewEncoder(os.Stdout).Encode(struct {
				Output string `json:"output"`
			}{Output: result.Output})
		case "text":
			_, err = fmt.Fprint(os.Stdout, result.Output)
			return err
		default:
			return fmt.Errorf("unknown format: %s", format)
		}
	},
}

func init() {
	rootCmd.PersistentFlags().BoolP("quiet", "q", false, "Suppress progress messages on stderr")
	rootCmd.Flags().StringP("format", "f", "text", "Output format: text, json")
	rootCmd.Version = version
}

func Execute() {
	err := rootCmd.Execute()
	if err == nil {
		return
	}
	fmt.Fprintln(os.Stderr, err)
	os.Exit(1)
}
