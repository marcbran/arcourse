package arcourse

import pkg "github.com/marcbran/arcourse/pkg/arcourse"

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

func (f *facade) Evaluate(expression string) (pkg.Result, error) {
	return f.evaluate.Exec(expression)
}

func (f *facade) Render(path []string, format pkg.Format) (pkg.Result, error) {
	return f.render.Exec(path, format)
}
