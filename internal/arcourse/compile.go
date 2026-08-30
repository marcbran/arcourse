package arcourse

import (
	"context"
	"fmt"
	"os"
	"path/filepath"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type compile struct {
	cfg       RootConfig
	evaluator Evaluator
}

func newCompile(cfg RootConfig, evaluator Evaluator) *compile {
	return &compile{cfg: cfg, evaluator: evaluator}
}

func (c *compile) Exec(ctx context.Context) (pkg.Result, error) {
	err := ctx.Err()
	if err != nil {
		return pkg.Result{}, err
	}
	if c.cfg.Dir == "" {
		return pkg.Result{}, pkg.ErrEvaluateDirNotSet
	}
	if c.cfg.Mode != ModeImmediateGraph && c.cfg.Mode != ModeCompiledGraph {
		return pkg.Result{}, pkg.ErrShapeNotSupported
	}
	entryPath := filepath.Join(c.cfg.Dir, "root.jsonnet")
	fi, err := os.Stat(entryPath)
	if err != nil {
		if os.IsNotExist(err) {
			return pkg.Result{}, fmt.Errorf("%w: %s", pkg.ErrGraphEntryNotFound, c.cfg.Dir)
		}
		return pkg.Result{}, err
	}
	if !fi.Mode().IsRegular() {
		return pkg.Result{}, fmt.Errorf("%w: %s", pkg.ErrGraphEntryNotFound, entryPath)
	}

	slash := filepath.ToSlash(entryPath)
	shapeSnippet := fmt.Sprintf(`local root = import 'root'; (import 'lib/compile_graph.libsonnet')(import %q)`, slash)
	shapeJSON, err := c.evaluator.EvaluateOnce(map[string]string{"root": immediateGraphSnippet(entryPath)}, shapeSnippet)
	if err != nil {
		return pkg.Result{}, err
	}

	artifact := fmt.Sprintf(`local construct_compiled_graph_root = import 'lib/construct_compiled_graph_root.libsonnet';
construct_compiled_graph_root(import %q, %s)`, slash, shapeJSON)
	return pkg.Result{Output: artifact}, nil
}

func immediateGraphSnippet(entryPath string) string {
	slash := filepath.ToSlash(entryPath)
	return fmt.Sprintf(`local construct_immediate_graph_root = import 'lib/construct_immediate_graph_root.libsonnet';
construct_immediate_graph_root(import %q)`, slash)
}
