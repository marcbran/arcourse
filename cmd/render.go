package cmd

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
	"github.com/marcbran/jpoet/pkg/jpoet"
	"github.com/spf13/cobra"
)

func newRenderCmd(plugins []*jpoet.Plugin) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "render [path]",
		Short: "Render a path into the graph (dot-separated)",
		Args:  cobra.ExactArgs(1),
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
			facade := buildFacade(cfg, plugins)

			path := strings.Split(args[0], ".")
			result, err := facade.Render(c.Context(), path, format)
			if err != nil {
				return err
			}

			outputPath, err := c.Flags().GetString("output")
			if err != nil {
				return err
			}
			if outputPath != "" {
				return writeRenderOutput(outputPath, result.Output)
			}

			_, err = fmt.Fprint(os.Stdout, result.Output)
			return err
		},
	}
	cmd.Flags().StringP("format", "f", "html", "Output format: html")
	cmd.Flags().StringP("output", "o", "", "Write output to a file")
	return cmd
}

func writeRenderOutput(path string, output string) error {
	dir := filepath.Dir(path)
	if dir != "." {
		err := os.MkdirAll(dir, 0o755)
		if err != nil {
			return err
		}
	}
	return os.WriteFile(path, []byte(output), 0o644)
}
