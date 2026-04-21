package cmd

import (
	"github.com/marcbran/arcourse/internal/http/server"
	"github.com/marcbran/jpoet/pkg/jpoet"
	"github.com/spf13/cobra"
)

func newServeCmd(plugins []*jpoet.Plugin) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "serve",
		Short: "Run the HTTP server",
		RunE: func(c *cobra.Command, args []string) error {
			c.SilenceUsage = true
			c.SilenceErrors = true
			cfg, err := loadConfig()
			if err != nil {
				return err
			}
			facade := buildLocalFacade(cfg, plugins)
			return server.Serve(c.Context(), facade, cfg.HTTP)
		},
	}
	return cmd
}
