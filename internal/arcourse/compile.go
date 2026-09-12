package arcourse

import (
	"context"
	"fmt"
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
	if c.cfg.Mode != ModeImmediateGraph && c.cfg.Mode != ModeCompiledGraph {
		return pkg.Result{}, pkg.ErrShapeNotSupported
	}
	entryPath, err := c.entryPath()
	if err != nil {
		return pkg.Result{}, err
	}
	out, err := c.evaluator.EvaluateOnceRaw(compileSnippet(entryPath))
	if err != nil {
		return pkg.Result{}, err
	}
	return pkg.Result{Output: out}, nil
}

func compileSnippet(entryPath string) string {
	slash := filepath.ToSlash(entryPath)
	return fmt.Sprintf(`(import 'lib/compile_root.libsonnet')(%q, import %q)`, slash, slash)
}

func (c *compile) entryPath() (string, error) {
	return resolveEntryPath(c.cfg.Dir)
}
