package cmd

import (
	"fmt"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
	"github.com/marcbran/jpoet/pkg/jpoet"
	"github.com/spf13/cobra"
)

func newReviewCmd(plugins []*jpoet.Plugin) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "review [path] [id]",
		Short: "Review a recorded evaluation of a node without evaluating it again",
		Long:  "Review a recorded evaluation of a node without evaluating it again. The id can also be part of the path, as in a browse URL: review \"<path>?evaluationId=<id>\".",
		Args:  cobra.RangeArgs(1, 2),
		RunE: func(c *cobra.Command, args []string) error {
			c.SilenceUsage = true
			c.SilenceErrors = true
			defer closePlugins(plugins)

			formatStr, err := c.Flags().GetString("format")
			if err != nil {
				return err
			}
			format, err := pkg.ParseFormat(formatStr)
			if err != nil {
				return err
			}

			cfg, err := loadConfig()
			if err != nil {
				return err
			}
			facade := buildFacade(cfg, plugins)

			var id pkg.EvaluationID
			if len(args) == 2 {
				id = pkg.EvaluationID(args[1])
			}
			result, err := facade.Review(c.Context(), pkg.NewQueryPath(args[0]), id, format)
			if err != nil {
				return err
			}
			_, err = fmt.Fprintln(c.OutOrStdout(), result.Output)
			return err
		},
	}
	cmd.Flags().StringP("format", "f", "json", "Output format: json, html")
	return cmd
}
