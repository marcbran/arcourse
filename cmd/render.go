package cmd

import (
	"fmt"
	"os"
	"strings"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
	"github.com/spf13/cobra"
)

func newRenderCmd(facade pkg.Facade) *cobra.Command {
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

			path := strings.Split(args[0], ".")
			result, err := facade.Render(path, format)
			if err != nil {
				return err
			}

			_, err = fmt.Fprint(os.Stdout, result.Output)
			return err
		},
	}
	cmd.Flags().StringP("format", "f", "html", "Output format: html")
	return cmd
}
