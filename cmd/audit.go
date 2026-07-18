package cmd

import (
	"encoding/json"
	"os"

	"github.com/marcbran/jpoet/pkg/jpoet"
	"github.com/spf13/cobra"
)

func newAuditCmd(plugins []*jpoet.Plugin) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "audit [id]",
		Short: "List or replay audited queries",
		Args:  cobra.MaximumNArgs(1),
		RunE: func(c *cobra.Command, args []string) error {
			c.SilenceUsage = true
			c.SilenceErrors = true

			cfg, err := loadConfig()
			if err != nil {
				return err
			}
			facade := buildFacade(cfg, plugins)

			encoder := json.NewEncoder(os.Stdout)
			if len(args) == 1 {
				entry, err := facade.GetAudit(c.Context(), args[0])
				if err != nil {
					return err
				}
				return encoder.Encode(entry)
			}

			entries, err := facade.ListAudit(c.Context())
			if err != nil {
				return err
			}
			return encoder.Encode(entries)
		},
	}
	return cmd
}
