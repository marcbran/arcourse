package arcourse

import (
	"context"
	"fmt"
)

type Evaluator interface {
	Warm(stringImports map[string]string) error
	Evaluate(snippet string) (string, error)
	Watch(key string, snippet string) (string, <-chan string, func(), error)
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

func (e *environment) Evaluate(ctx context.Context, expression string) (string, error) {
	snippet, stringImports, err := e.buildSnippet(ctx, expression)
	if err != nil {
		return "", err
	}
	if e.cfg.Mode != ModeCompiledGraph {
		return e.evaluator.EvaluateOnce(stringImports, snippet)
	}
	err = e.evaluator.Warm(stringImports)
	if err != nil {
		return "", err
	}
	return e.evaluator.Evaluate(snippet)
}

func (e *environment) Watch(ctx context.Context, key string, expression string) (string, <-chan string, func(), error) {
	snippet, stringImports, err := e.buildSnippet(ctx, expression)
	if err != nil {
		return "", nil, nil, err
	}
	if e.cfg.Mode != ModeCompiledGraph {
		out, err := e.evaluator.EvaluateOnce(stringImports, snippet)
		if err != nil {
			return "", nil, nil, err
		}
		closed := make(chan string)
		close(closed)
		return out, closed, func() {}, nil
	}
	err = e.evaluator.Warm(stringImports)
	if err != nil {
		return "", nil, nil, err
	}
	return e.evaluator.Watch(key, snippet)
}

func (e *environment) buildSnippet(ctx context.Context, expression string) (string, map[string]string, error) {
	err := ctx.Err()
	if err != nil {
		return "", nil, err
	}
	rootSnippet, err := e.root.Snippet(ctx)
	if err != nil {
		return "", nil, err
	}
	stringImports := map[string]string{"root": rootSnippet}
	snippet := fmt.Sprintf(`local root = import 'root'; %s`, expression)
	return snippet, stringImports, nil
}
