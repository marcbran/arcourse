package jsonnet

import (
	"bytes"
	"io/fs"

	"github.com/marcbran/jpoet/pkg/jpoet"
)

type Evaluator struct {
	lib     fs.FS
	jpaths  []string
	plugins []*jpoet.Plugin
}

func NewEvaluator(lib fs.FS, jpaths []string, plugins []*jpoet.Plugin) *Evaluator {
	return &Evaluator{lib: lib, jpaths: jpaths, plugins: plugins}
}

func (e *Evaluator) EvaluateSnippet(snippet string) (string, error) {
	var out bytes.Buffer
	eval := jpoet.NewEval().
		FileImport(e.jpaths).
		FSImport(e.lib).
		SnippetInput("arcourse.jsonnet", snippet).
		WriterOutput(&out)
	for _, p := range e.plugins {
		eval = eval.Plugin(p)
	}
	err := eval.Eval()
	if err != nil {
		return "", err
	}
	return out.String(), nil
}
