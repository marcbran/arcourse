package arcourse

import pkg "github.com/marcbran/arcourse/pkg/arcourse"

type Config struct {
	Evaluate EvaluateConfig `json:"evaluate"`
}

type facade struct {
	evaluate *Evaluate
}

func NewFacade(cfg Config, evaluator Evaluator) pkg.Facade {
	evaluate := NewEvaluate(cfg.Evaluate, evaluator)
	return &facade{evaluate: evaluate}
}

func (f *facade) Evaluate(expression string) (pkg.Result, error) {
	return f.evaluate.Exec(expression)
}
