package cmd

import (
	"fmt"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
	"github.com/marcbran/jpoet/pkg/jpoet"
	"github.com/spf13/cobra"
)

func newRemarkCmd(plugins []*jpoet.Plugin) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "remark [id] [text]",
		Short: "Attach a remark to the visit of a recorded query",
		Args:  cobra.ExactArgs(2),
		RunE: func(c *cobra.Command, args []string) error {
			c.SilenceUsage = true
			c.SilenceErrors = true
			defer closePlugins(plugins)

			cfg, err := loadConfig()
			if err != nil {
				return err
			}
			facade := buildFacade(cfg, plugins)

			remarkID, err := facade.Remark(c.Context(), pkg.EvaluationID(args[0]), args[1])
			if err != nil {
				return err
			}
			_, err = fmt.Fprintln(c.OutOrStdout(), remarkID)
			return err
		},
	}
	return cmd
}
