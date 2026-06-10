package cmd

import (
	"fmt"
	"os"

	"github.com/marcbran/jpoet/pkg/jpoet"
	"github.com/spf13/cobra"
)

func newQueryCmd(plugins []*jpoet.Plugin) *cobra.Command {
	var paramFlags []string
	cmd := &cobra.Command{
		Use:   "query [path]",
		Short: "Query a node by path and return its JSON value (slash-separated)",
		Args:  cobra.ExactArgs(1),
		RunE: func(c *cobra.Command, args []string) error {
			c.SilenceUsage = true
			c.SilenceErrors = true

			params, err := parseParams(paramFlags)
			if err != nil {
				return err
			}

			cfg, err := loadConfig()
			if err != nil {
				return err
			}
			facade := buildFacade(cfg, plugins)

			result, err := facade.Query(c.Context(), args[0], params)
			if err != nil {
				return err
			}

			_, err = fmt.Fprint(os.Stdout, result.Output)
			return err
		},
	}
	cmd.Flags().StringArrayVar(&paramFlags, "param", nil, "Parameter as key=value (repeatable)")
	return cmd
}
