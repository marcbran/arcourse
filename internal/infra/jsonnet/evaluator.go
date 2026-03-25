package jsonnet

import (
	"bytes"
	"io/fs"

	"github.com/marcbran/jpoet/pkg/jpoet"
)

type Evaluator struct {
	lib fs.FS
}

func NewEvaluator(lib fs.FS) *Evaluator {
	return &Evaluator{lib: lib}
}

func (e *Evaluator) EvaluateSnippet(snippet string) (string, error) {
	var out bytes.Buffer
	err := jpoet.NewEval().
		FileImport([]string{"/"}).
		FSImport(e.lib).
		SnippetInput("arcourse.jsonnet", snippet).
		WriterOutput(&out).
		Eval()
	if err != nil {
		return "", err
	}
	return out.String(), nil
}
