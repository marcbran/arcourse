package arcourse

import (
	"context"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type Config struct {
	Evaluate EvaluateConfig `json:"evaluate"`
}

type facade struct {
	evaluate *Evaluate
	render   *Render
}

func NewFacade(cfg Config, evaluator Evaluator) pkg.Facade {
	evaluate := NewEvaluate(cfg.Evaluate, evaluator)
	render := NewRender(evaluate)
	return &facade{evaluate: evaluate, render: render}
}

func (f *facade) Evaluate(ctx context.Context, expression string) (pkg.Result, error) {
	return f.evaluate.Exec(ctx, expression)
}

func (f *facade) Render(ctx context.Context, path string, format pkg.Format) (pkg.Result, error) {
	return f.render.Exec(ctx, path, format)
}
