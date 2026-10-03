package cmd

import (
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

			cfg, err := loadConfig()
			if err != nil {
				return err
			}
			facade := buildFacade(cfg, plugins)

			result, err := facade.Exec(c.Context(), pkg.QueryID(args[0]))
			if err != nil {
				return err
			}
			_, err = fmt.Fprintln(c.OutOrStdout(), result.Output)
			return err
		},
	}
	return cmd
}
