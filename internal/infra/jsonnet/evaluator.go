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
	opts := []jpoet.Option{
		jpoet.FileImport(e.jpaths),
		jpoet.FSImport(e.lib),
		jpoet.SnippetInput("arcourse.jsonnet", snippet),
		jpoet.WriterOutput(&out),
		jpoet.WithPluginSet(e.plugins...),
	}
	err := jpoet.Eval(opts...)
	if err != nil {
		return "", err
	}
	return out.String(), nil
}
