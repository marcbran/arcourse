package cmd

import (
	"fmt"
	"os"

	"github.com/marcbran/jpoet/pkg/jpoet"
	"github.com/spf13/cobra"
)

func newCompileCmd(plugins []*jpoet.Plugin) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "compile",
		Short: "Precompile the graph root into a bundled jsonnet artifact",
		RunE: func(c *cobra.Command, args []string) error {
			c.SilenceUsage = true
			c.SilenceErrors = true

			cfg, err := loadConfig()
			if err != nil {
				return err
			}
			facade := buildFacade(cfg, plugins)

			result, err := facade.Compile(c.Context())
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
	cmd.Flags().StringP("output", "o", "", "Write the compiled root artifact to a file")
	return cmd
}
