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
	observe  *Observe
}

func NewFacade(cfg Config, evaluator Evaluator, lastQuery LastQuery) pkg.Facade {
	evaluate := NewEvaluate(cfg.Evaluate, evaluator)
	query := NewQuery(evaluate, lastQuery)
	observe := NewObserve(lastQuery)
	return &facade{evaluate: evaluate, query: query, observe: observe}
}

func (f *facade) Evaluate(ctx context.Context, expression string) (pkg.Result, error) {
	return f.evaluate.Exec(ctx, expression)
}

func (f *facade) Query(ctx context.Context, path string, params map[string]any, format pkg.Format) (pkg.Result, error) {
	return f.query.Exec(ctx, path, params, format)
}

func (f *facade) Observe(ctx context.Context, format pkg.Format) (<-chan pkg.Result, func()) {
	return f.observe.Exec(ctx, format)
}
