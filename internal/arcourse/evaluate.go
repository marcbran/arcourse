package arcourse

import (
	"context"
	"fmt"
	"os"
	"path/filepath"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type Evaluator interface {
	EvaluateSnippet(snippet string, virtualImports map[string]string) (string, error)
}

type EvaluateConfig struct {
	Dir string `json:"dir"`
}

type Evaluate struct {
	cfg       EvaluateConfig
	evaluator Evaluator
}

func NewEvaluate(cfg EvaluateConfig, evaluator Evaluator) *Evaluate {
	return &Evaluate{
		cfg:       cfg,
		evaluator: evaluator,
	}
}

func (e *Evaluate) Exec(ctx context.Context, expression string) (pkg.Result, error) {
	wrapped := fmt.Sprintf("(import 'lib/eval.libsonnet')(root, %s)", expression)
	return e.exec(ctx, wrapped)
}

func (e *Evaluate) exec(ctx context.Context, expression string) (pkg.Result, error) {
	err := ctx.Err()
	if err != nil {
		return pkg.Result{}, err
	}
	if e.cfg.Dir == "" {
		return pkg.Result{}, pkg.ErrEvaluateDirNotSet
	}
	entryPath, graphMode, err := e.resolveEntry()
	if err != nil {
		return pkg.Result{}, err
	}
	slash := filepath.ToSlash(entryPath)
	var rootSnippet string
	if graphMode {
		rootSnippet = fmt.Sprintf(`local construct_graph_root = import 'lib/construct_graph_root.libsonnet';
construct_graph_root(import %q)`, slash)
	} else {
		rootSnippet = fmt.Sprintf(`import %q`, slash)
	}
	snippet := fmt.Sprintf(`local root = import 'root'; %s`, expression)
	out, err := e.evaluator.EvaluateSnippet(snippet, map[string]string{"root": rootSnippet})
	if err != nil {
		return pkg.Result{}, err
	}
	return pkg.Result{Output: out}, nil
}

func (e *Evaluate) resolveEntry() (path string, graphMode bool, err error) {
	graphPath := filepath.Join(e.cfg.Dir, "graph.jsonnet")
	fi, err := os.Stat(graphPath)
	if err != nil {
		if !os.IsNotExist(err) {
			return "", false, err
		}
	} else {
		if fi.Mode().IsRegular() {
			return graphPath, true, nil
		}
	}
	rootPath := filepath.Join(e.cfg.Dir, "root.jsonnet")
	fi, err = os.Stat(rootPath)
	if err != nil {
		if os.IsNotExist(err) {
			return "", false, fmt.Errorf("%w: %s", pkg.ErrGraphEntryNotFound, e.cfg.Dir)
		}
		return "", false, err
	}
	if !fi.Mode().IsRegular() {
		return "", false, fmt.Errorf("%w: %s", pkg.ErrGraphEntryNotFound, rootPath)
	}
	return rootPath, false, nil
}
