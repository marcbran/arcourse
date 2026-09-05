package jsonnet

import (
	"bytes"
	"fmt"
	"io/fs"
	"sync"

	"github.com/marcbran/jpoet/pkg/jpoet"
	"github.com/marcbran/jpoet/pkg/watch"
)

type Evaluator struct {
	lib     fs.FS
	jpaths  []string
	plugins []*jpoet.Plugin

	warmOnce sync.Once
	env      *watch.Environment
}

func NewEvaluator(lib fs.FS, jpaths []string, plugins []*jpoet.Plugin) *Evaluator {
	return &Evaluator{lib: lib, jpaths: jpaths, plugins: plugins}
}

func (e *Evaluator) Warm(stringImports map[string]string) error {
	e.warmOnce.Do(func() {
		e.env = e.buildEnv(stringImports)
	})
	return nil
}

func (e *Evaluator) Evaluate(snippet string) (string, error) {
	if e.env == nil {
		return "", fmt.Errorf("evaluator not warmed")
	}
	return evaluate(e.env, snippet)
}

func (e *Evaluator) Watch(key string, snippet string) (string, <-chan string, func(), error) {
	if e.env == nil {
		return "", nil, nil, fmt.Errorf("evaluator not warmed")
	}
	return e.env.Watch(watch.WatchSnippetInput("arcourse.jsonnet", snippet), watch.WatchWithKey(watch.WatchKey(key)))
}

func (e *Evaluator) EvaluateOnce(stringImports map[string]string, snippet string) (string, error) {
	we := e.buildEnv(stringImports)
	defer func() { _ = we.Close() }()
	return evaluate(we, snippet)
}

func (e *Evaluator) buildEnv(stringImports map[string]string) *watch.Environment {
	opts := []jpoet.EnvOption{
		jpoet.EnvFileImport(e.jpaths),
		jpoet.EnvFSImport(e.lib),
		jpoet.EnvWithPluginSet(e.plugins...),
	}
	for name, content := range stringImports {
		opts = append(opts, jpoet.EnvStringImport(name, content))
	}
	env := jpoet.Env(opts...)
	return watch.New(env)
}

func evaluate(we *watch.Environment, snippet string) (string, error) {
	var out bytes.Buffer
	err := we.Eval(jpoet.EvalSnippetInput("arcourse.jsonnet", snippet), jpoet.EvalWriterOutput(&out))
	if err != nil {
		return "", err
	}
	return out.String(), nil
}
