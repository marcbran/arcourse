package arcourse

import pkg "github.com/marcbran/arcourse/pkg/arcourse"

type Evaluator interface {
	Evaluate(root string, expression string) (string, error)
}

type EvaluateConfig struct {
	Root string `json:"root"`
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

func (uc *Evaluate) Exec(expression string) (pkg.Result, error) {
	if uc.cfg.Root == "" {
		return pkg.Result{}, pkg.ErrRootConfigNotConfigured
	}
	out, err := uc.evaluator.Evaluate(uc.cfg.Root, expression)
	if err != nil {
		return pkg.Result{}, err
	}
	return pkg.Result{Output: out}, nil
}
