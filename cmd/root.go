package cmd

import (
	"fmt"
	"os"

	"github.com/marcbran/jpoet/pkg/jpoet"
	"github.com/spf13/cobra"
)

var version = "dev"

func newRootCmd(plugins []*jpoet.Plugin) *cobra.Command {
	cmd := &cobra.Command{
		Use:     "arco",
		Short:   "Jsonnet graph tools",
		Version: version,
	}
	cmd.PersistentFlags().BoolP("quiet", "q", false, "Suppress progress messages on stderr")
	cmd.AddCommand(newEvalCmd(plugins))
	cmd.AddCommand(newQueryCmd(plugins))
	cmd.AddCommand(newRenderCmd(plugins))
	cmd.AddCommand(newServeCmd(plugins))
	return cmd
}

func Execute(plugins []*jpoet.Plugin) {
	err := newRootCmd(plugins).Execute()
	if err == nil {
		return
	}
	fmt.Fprintln(os.Stderr, err)
	os.Exit(1)
}
