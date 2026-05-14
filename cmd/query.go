package cmd

import (
	"fmt"
	"os"

	"github.com/marcbran/jpoet/pkg/jpoet"
	"github.com/spf13/cobra"
)

func newQueryCmd(plugins []*jpoet.Plugin) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "query [path]",
		Short: "Query a node by path and return its JSON value (slash-separated)",
		Args:  cobra.ExactArgs(1),
		RunE: func(c *cobra.Command, args []string) error {
			c.SilenceUsage = true
			c.SilenceErrors = true

			cfg, err := loadConfig()
			if err != nil {
				return err
			}
			facade := buildFacade(cfg, plugins)

			result, err := facade.Query(c.Context(), args[0])
			if err != nil {
				return err
			}

			_, err = fmt.Fprint(os.Stdout, result.Output)
			return err
		},
	}
	return cmd
}
