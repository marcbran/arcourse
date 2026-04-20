package cmd

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/marcbran/jpoet/pkg/jpoet"
	"github.com/spf13/cobra"
)

func newEvalCmd(plugins []*jpoet.Plugin) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "eval [expression]",
		Short: "Evaluate a Jsonnet expression against the configured workspace",
		Args:  cobra.ExactArgs(1),
		RunE: func(c *cobra.Command, args []string) error {
			c.SilenceUsage = true
			c.SilenceErrors = true

			format, err := c.Flags().GetString("format")
			if err != nil {
				return err
			}

			cfg, err := loadConfig()
			if err != nil {
				return err
			}
			facade := buildFacade(cfg, plugins)

			result, err := facade.Evaluate(c.Context(), args[0])
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
