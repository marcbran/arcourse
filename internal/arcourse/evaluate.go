package arcourse

import (
	"context"
	"fmt"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type Evaluator interface {
	EvaluateSnippet(snippet string, virtualImports map[string]string) (string, error)
}

type evaluate struct {
	evaluator Evaluator
	root      *root
}

func newEvaluate(evaluator Evaluator, root *root) *evaluate {
	return &evaluate{evaluator: evaluator, root: root}
}

func (e *evaluate) Exec(ctx context.Context, expression string) (pkg.Result, error) {
	rootSnippet, err := e.root.Snippet(ctx)
	if err != nil {
		return pkg.Result{}, err
	}
	wrapped := fmt.Sprintf("(import 'lib/eval.libsonnet')(root, %s)", expression)
	return runExpression(ctx, e.evaluator, rootSnippet, wrapped)
}

func runExpression(ctx context.Context, evaluator Evaluator, rootSnippet string, expression string) (pkg.Result, error) {
	err := ctx.Err()
	if err != nil {
		return pkg.Result{}, err
	}
	snippet := fmt.Sprintf(`local root = import 'root'; %s`, expression)
	out, err := evaluator.EvaluateSnippet(snippet, map[string]string{"root": rootSnippet})
	if err != nil {
		return pkg.Result{}, err
	}
	return pkg.Result{Output: out}, nil
}
