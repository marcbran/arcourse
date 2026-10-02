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
	Close() error
}

type environment struct {
	root      *root
	evaluator Evaluator
	executor  Executor
}

func newEnvironment(root *root, evaluator Evaluator, executor Executor) *environment {
	return &environment{root: root, evaluator: evaluator, executor: executor}
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

func (e *environment) Exec(ctx context.Context, plugin string, action string, data map[string]any) (string, error) {
	err := e.root.Warm(ctx)
	if err != nil {
		return "", err
	}
	return e.executor.Exec(ctx, plugin, action, data)
}

func (e *environment) Close() error {
	return e.evaluator.Close()
}

func queryExpression(expression string) string {
	return fmt.Sprintf(`local root = import 'root'; %s`, expression)
}
