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
	query    *Query
	render   *Render
}

func NewFacade(cfg Config, evaluator Evaluator) pkg.Facade {
	evaluate := NewEvaluate(cfg.Evaluate, evaluator)
	query := NewQuery(evaluate)
	render := NewRender(evaluate)
	return &facade{evaluate: evaluate, query: query, render: render}
}

func (f *facade) Evaluate(ctx context.Context, expression string) (pkg.Result, error) {
	return f.evaluate.Exec(ctx, expression)
}

func (f *facade) Query(ctx context.Context, path string) (pkg.Result, error) {
	return f.query.Exec(ctx, path)
}

func (f *facade) Render(ctx context.Context, path string, format pkg.Format) (pkg.Result, error) {
	return f.render.Exec(ctx, path, format)
}
