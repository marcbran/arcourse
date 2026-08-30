package jsonnet

import (
	"bytes"
	"fmt"
	"io/fs"
	"sync"

	"github.com/marcbran/jpoet/pkg/jpoet"
)

type Evaluator struct {
	lib     fs.FS
	jpaths  []string
	plugins []*jpoet.Plugin

	mu  sync.Mutex
	env *jpoet.Environment
}

func NewEvaluator(lib fs.FS, jpaths []string, plugins []*jpoet.Plugin) *Evaluator {
	return &Evaluator{lib: lib, jpaths: jpaths, plugins: plugins}
}

func (e *Evaluator) Warm(stringImports map[string]string) error {
	e.mu.Lock()
	defer e.mu.Unlock()
	if e.env == nil {
		e.env = e.buildEnv(stringImports)
	}
	return nil
}

func (e *Evaluator) Evaluate(snippet string) (string, error) {
	e.mu.Lock()
	defer e.mu.Unlock()
	if e.env == nil {
		return "", fmt.Errorf("evaluator not warmed")
	}
	return evaluate(e.env, snippet)
}

func (e *Evaluator) EvaluateOnce(stringImports map[string]string, snippet string) (string, error) {
	return evaluate(e.buildEnv(stringImports), snippet)
}

func (e *Evaluator) buildEnv(stringImports map[string]string) *jpoet.Environment {
	opts := []jpoet.EnvOption{
		jpoet.EnvFileImport(e.jpaths),
		jpoet.EnvFSImport(e.lib),
		jpoet.EnvWithPluginSet(e.plugins...),
	}
	for name, content := range stringImports {
		opts = append(opts, jpoet.EnvStringImport(name, content))
	}
	return jpoet.Env(opts...)
}

func evaluate(env *jpoet.Environment, snippet string) (string, error) {
	var out bytes.Buffer
	err := env.Eval(jpoet.EvalSnippetInput("arcourse.jsonnet", snippet), jpoet.EvalWriterOutput(&out))
	if err != nil {
		return "", err
	}
	return out.String(), nil
}
