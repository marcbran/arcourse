package cmd

import (
	"encoding/json"
	"fmt"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
	"github.com/marcbran/jpoet/pkg/jpoet"
	"github.com/spf13/cobra"
)

func newExecCmd(plugins []*jpoet.Plugin) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "exec [id]",
		Short: "Execute the action recorded for a query",
		Args:  cobra.ExactArgs(1),
		RunE: func(c *cobra.Command, args []string) error {
			c.SilenceUsage = true
			c.SilenceErrors = true
			defer closePlugins(plugins)

			format, err := c.Flags().GetString("format")
			if err != nil {
				return err
			}
			if format != execFormatText && format != execFormatJSON {
				return fmt.Errorf("unknown format: %s", format)
			}

			cfg, err := loadConfig()
			if err != nil {
				return err
			}
			facade := buildFacade(cfg, plugins)

			result, err := facade.Exec(c.Context(), pkg.EvaluationID(args[0]))
			if err != nil {
				return err
			}
			if format == execFormatJSON {
				return json.NewEncoder(c.OutOrStdout()).Encode(execOutput{
					ExecutionID: string(result.ExecutionID),
					Output:      result.Output,
					Redirect:    result.Redirect.String(),
				})
			}
			_, err = fmt.Fprintln(c.OutOrStdout(), result.Output)
			return err
		},
	}
	cmd.Flags().StringP("format", "f", execFormatText, "Output format: text, json")
	return cmd
}

const (
	execFormatText = "text"
	execFormatJSON = "json"
)

type execOutput struct {
	ExecutionID string `json:"executionId"`
	Output      string `json:"output"`
	Redirect    string `json:"redirect"`
}
