package cmd

import (
	"encoding/json"
	"errors"
	"os"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
	"github.com/marcbran/jpoet/pkg/jpoet"
	"github.com/spf13/cobra"
)

func newObserveCmd(plugins []*jpoet.Plugin) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "observe",
		Short: "Stream the most recently queried node",
		Args:  cobra.NoArgs,
		RunE: func(c *cobra.Command, args []string) error {
			c.SilenceUsage = true
			c.SilenceErrors = true

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
			if cfg.Mode != ModeClient {
				return errors.New("observe requires mode: client to connect to a running arco serve; local mode has no queries to observe")
			}
			facade := buildFacade(cfg, plugins)

			ch, unsubscribe := facade.Observe(c.Context(), format)
			defer unsubscribe()

			encoder := json.NewEncoder(os.Stdout)
			for result := range ch {
				err := encoder.Encode(struct {
					Output string `json:"output"`
				}{Output: result.Output})
				if err != nil {
					return err
				}
			}
			return nil
		},
	}
	cmd.Flags().StringP("format", "f", "json", "Observed format: json, html, jsonnet")
	return cmd
}
