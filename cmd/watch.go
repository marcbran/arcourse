package cmd

import (
	"encoding/json"
	"os"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
	"github.com/marcbran/jpoet/pkg/jpoet"
	"github.com/spf13/cobra"
)

func newWatchCmd(plugins []*jpoet.Plugin) *cobra.Command {
	var paramFlags []string
	cmd := &cobra.Command{
		Use:   "watch [path]",
		Short: "Stream a node by path, re-querying whenever its data changes",
		Args:  cobra.ExactArgs(1),
		RunE: func(c *cobra.Command, args []string) error {
			c.SilenceUsage = true
			c.SilenceErrors = true
			defer closePlugins(plugins)

			params, err := parseParams(paramFlags)
			if err != nil {
				return err
			}

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

			ch, unsubscribe, err := facade.Watch(c.Context(), args[0], params, format)
			if err != nil {
				return err
			}
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
	cmd.Flags().StringP("format", "f", "json", "Output format: json, html, jsonnet")
	cmd.Flags().StringArrayVar(&paramFlags, "param", nil, "Parameter as key=value (repeatable)")
	return cmd
}
