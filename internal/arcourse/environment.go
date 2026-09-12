package arcourse

import (
	"context"
	"fmt"
)

type Evaluator interface {
	Warm(rootPath string) error
	Evaluate(snippet string) (string, error)
	EvaluateOnceRaw(snippet string) (string, error)
	Watch(key string, snippet string) (string, <-chan string, func(), error)
	WatchFile(key string, snippet string, path string) (func(), error)
}

type environment struct {
	root      *root
	evaluator Evaluator
}

func newEnvironment(root *root, evaluator Evaluator) *environment {
	return &environment{root: root, evaluator: evaluator}
}

func (e *environment) Warm(ctx context.Context) error {
	return e.root.Warm(ctx)
}

func (e *environment) Evaluate(ctx context.Context, expression string) (string, error) {
	err := e.root.Warm(ctx)
	if err != nil {
		return "", err
	}
	return e.evaluator.Evaluate(queryExpression(expression))
}

func (e *environment) Watch(ctx context.Context, key string, expression string) (string, <-chan string, func(), error) {
	err := e.root.Warm(ctx)
	if err != nil {
		return "", nil, nil, err
	}
	return e.evaluator.Watch(key, queryExpression(expression))
}

func queryExpression(expression string) string {
	return fmt.Sprintf(`local root = import 'root'; %s`, expression)
}
