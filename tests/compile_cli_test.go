//go:build e2e

package tests

import (
	"path/filepath"
	"testing"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

func TestCompiledArtifactMatchesSourceQuery(t *testing.T) {
	given, when, then := cli_scenario(t)
	compiledDir := filepath.Join(given.tempDir, "compiled")
	artifactPath := filepath.Join(compiledDir, "root.jsonnet")

	given.
		a_node_graph(`[[[['kubernetes', '$context', 'pods'], { kind: 'PodList' }]]]`).
		and().
		the_root_is_compiled_to(artifactPath).
		and().
		the_config_uses_dir(compiledDir)

	when.
		a_path_is_queried("root/kubernetes/context/prod/pods", pkg.FormatJSON)

	then.
		the_output_is(`{"_node":true,"context":"prod","kind":"PodList"}`)
}

func TestCompileFailsWithoutGraphMode(t *testing.T) {
	given, when, then := cli_scenario(t)
	artifactPath := filepath.Join(given.tempDir, "compiled.jsonnet")

	given.
		a_graph_root(`{ value: 42 }`)

	when.
		the_root_is_compiled_to(artifactPath)

	then.
		the_error_contains("immediateGraph or compiledGraph mode")
}
