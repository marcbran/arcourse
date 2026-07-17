package cmd

import (
	"fmt"
	"os"
	"path/filepath"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
	"github.com/marcbran/jpoet/pkg/jpoet"
	"github.com/spf13/cobra"
)

func newQueryCmd(plugins []*jpoet.Plugin) *cobra.Command {
	var paramFlags []string
	cmd := &cobra.Command{
		Use:   "query [path]",
		Short: "Query a node by path (slash-separated)",
		Args:  cobra.ExactArgs(1),
		RunE: func(c *cobra.Command, args []string) error {
			c.SilenceUsage = true
			c.SilenceErrors = true

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

			result, err := facade.Query(c.Context(), args[0], params, format)
			if err != nil {
				return err
			}

			outputPath, err := c.Flags().GetString("output")
			if err != nil {
				return err
			}
			if outputPath != "" {
				return writeQueryOutput(outputPath, result.Output)
			}

			_, err = fmt.Fprint(os.Stdout, result.Output)
			return err
		},
	}
	cmd.Flags().StringP("format", "f", "json", "Output format: json, html, jsonnet")
	cmd.Flags().StringP("output", "o", "", "Write output to a file")
	cmd.Flags().StringArrayVar(&paramFlags, "param", nil, "Parameter as key=value (repeatable)")
	return cmd
}

func writeQueryOutput(path string, output string) error {
	dir := filepath.Dir(path)
	if dir != "." {
		err := os.MkdirAll(dir, 0o755)
		if err != nil {
			return err
		}
	}
	return os.WriteFile(path, []byte(output), 0o644)
}
