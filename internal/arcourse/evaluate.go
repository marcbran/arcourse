package arcourse

import (
	"context"
	"fmt"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type evaluate struct {
	environment *environment
}

func newEvaluate(environment *environment) *evaluate {
	return &evaluate{environment: environment}
}

func (e *evaluate) Exec(ctx context.Context, expression string) (pkg.Result, error) {
	wrapped := fmt.Sprintf("(import 'lib/eval.libsonnet')(root, %s)", expression)
	out, err := e.environment.Evaluate(ctx, wrapped)
	if err != nil {
		return pkg.Result{}, err
	}
	return pkg.Result{Output: out}, nil
}
