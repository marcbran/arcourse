package cmd

import (
	"encoding/json"
	"fmt"
	"os"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
	"github.com/spf13/cobra"
)

func newEvalCmd(facade pkg.Facade) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "eval [expression]",
		Short: "Evaluate a Jsonnet expression against the configured root",
		Args:  cobra.ExactArgs(1),
		RunE: func(c *cobra.Command, args []string) error {
			c.SilenceUsage = true
			c.SilenceErrors = true

			format, err := c.Flags().GetString("format")
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
	cmd.Flags().StringP("format", "f", "text", "Output format: text, json")
	return cmd
}
