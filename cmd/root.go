package cmd

import (
	"fmt"
	"os"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
	"github.com/marcbran/jpoet/pkg/jpoet"
	"github.com/spf13/cobra"
)

var version = "dev"

func newRootCmd(facade pkg.Facade) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "arco",
		Short: "Jsonnet graph tools",
		Version: version,
	}
	cmd.PersistentFlags().BoolP("quiet", "q", false, "Suppress progress messages on stderr")
	cmd.AddCommand(newEvalCmd(facade), newRenderCmd(facade))
	return cmd
}

func Execute(plugins []*jpoet.Plugin) {
	facade, err := NewFacade(plugins)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	err = newRootCmd(facade).Execute()
	if err == nil {
		return
	}
	fmt.Fprintln(os.Stderr, err)
	os.Exit(1)
}
