package cmd

import (
	"os"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
	"github.com/spf13/cobra"
)

const sessionEnvVar = "ARCOURSE_SESSION"

func addOriginFlags(cmd *cobra.Command) {
	cmd.Flags().String("session", "", "Record this query into the named session")
	cmd.Flags().String("from", "", "Query id of the response this path was read from")
	cmd.Flags().String("from-path", "", "Path of the node this path was read from, when no query id is known")
}

func originFrom(cmd *cobra.Command) (pkg.Origin, error) {
	session, err := cmd.Flags().GetString("session")
	if err != nil {
		return pkg.Origin{}, err
	}
	if session == "" {
		session = os.Getenv(sessionEnvVar)
	}
	from, err := cmd.Flags().GetString("from")
	if err != nil {
		return pkg.Origin{}, err
	}
	fromPath, err := cmd.Flags().GetString("from-path")
	if err != nil {
		return pkg.Origin{}, err
	}
	suppress := false
	if cmd.Flags().Lookup("output") != nil {
		output, err := cmd.Flags().GetString("output")
		if err != nil {
			return pkg.Origin{}, err
		}
		suppress = output != ""
	}
	return pkg.Origin{Session: pkg.SessionID(session), From: pkg.QueryID(from), FromPath: pkg.NewQueryPath(fromPath), Suppress: suppress}, nil
}
