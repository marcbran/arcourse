//go:build e2e

package tests

import (
	"path/filepath"
	"testing"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

func TestRenderCLIWritesOutputFile(t *testing.T) {
	given, when, then := cli_scenario(t)
	outputPath := filepath.Join(given.tempDir, "generated", "pages", "child.html")

	given.
		a_graph_root(`{ child: { _view:: { html: "<span>child</span>" } } }`)

	when.
		a_path_is_rendered_to_output_file("root/child", pkg.FormatHTML, outputPath)

	then.
		the_raw_output_is("").
		and().
		the_file_contains(outputPath, "<span>child</span>")
}
