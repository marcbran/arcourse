package arcourse

import (
	"context"
	"fmt"
	"path/filepath"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type Evaluator interface {
	EvaluateSnippet(snippet string) (string, error)
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

func (uc *Evaluate) Exec(ctx context.Context, expression string) (pkg.Result, error) {
	err := ctx.Err()
	if err != nil {
		return pkg.Result{}, err
	}
	if uc.cfg.Root == "" {
		return pkg.Result{}, pkg.ErrRootConfigNotConfigured
	}
	snippet := fmt.Sprintf(
		"local truncateNode = import 'lib/truncate_node.libsonnet';\nlocal root = import %q;\ntruncateNode(%s)",
		filepath.ToSlash(uc.cfg.Root),
		expression,
	)
	out, err := uc.evaluator.EvaluateSnippet(snippet)
	if err != nil {
		return pkg.Result{}, err
	}
	return pkg.Result{Output: out}, nil
}
