package cmd

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/marcbran/jpoet/pkg/jpoet"
	"github.com/spf13/cobra"
)

var version = "dev"

func newRootCmd(plugins []*jpoet.Plugin) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "arco [expression]",
		Short: "Evaluate Jsonnet expressions against a configured root",
		Args:  cobra.ExactArgs(1),
		RunE: func(c *cobra.Command, args []string) error {
			c.SilenceUsage = true
			c.SilenceErrors = true

			format, err := c.Flags().GetString("format")
			if err != nil {
				return err
			}

			facade, err := NewFacade(plugins)
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
		Version: version,
	}
	cmd.PersistentFlags().BoolP("quiet", "q", false, "Suppress progress messages on stderr")
	cmd.Flags().StringP("format", "f", "text", "Output format: text, json")
	return cmd
}

func Execute(plugins []*jpoet.Plugin) {
	err := newRootCmd(plugins).Execute()
	if err == nil {
		return
	}
	fmt.Fprintln(os.Stderr, err)
	os.Exit(1)
}
