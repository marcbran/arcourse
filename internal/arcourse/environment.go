package arcourse

import (
	"context"
	"fmt"
)

type Evaluator interface {
	Warm(stringImports map[string]string) error
	Evaluate(snippet string) (string, error)
	EvaluateOnce(stringImports map[string]string, snippet string) (string, error)
}

type environment struct {
	cfg       RootConfig
	root      *root
	evaluator Evaluator
}

func newEnvironment(cfg RootConfig, root *root, evaluator Evaluator) *environment {
	return &environment{cfg: cfg, root: root, evaluator: evaluator}
}

func (e *environment) Evaluate(ctx context.Context, expression string) (string, error) {
	err := ctx.Err()
	if err != nil {
		return "", err
	}
	rootSnippet, err := e.root.Snippet(ctx)
	if err != nil {
		return "", err
	}
	stringImports := map[string]string{"root": rootSnippet}
	snippet := fmt.Sprintf(`local root = import 'root'; %s`, expression)

	if e.cfg.Mode != ModeCompiledGraph {
		return e.evaluator.EvaluateOnce(stringImports, snippet)
	}
	err = e.evaluator.Warm(stringImports)
	if err != nil {
		return "", err
	}
	return e.evaluator.Evaluate(snippet)
}

func (e *environment) Warm(ctx context.Context) error {
	rootSnippet, err := e.root.Snippet(ctx)
	if err != nil {
		return err
	}
	if e.cfg.Mode != ModeCompiledGraph {
		return nil
	}
	return e.evaluator.Warm(map[string]string{"root": rootSnippet})
}
