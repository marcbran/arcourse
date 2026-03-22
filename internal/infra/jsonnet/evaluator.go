package jsonnet

import (
	"fmt"
	"path/filepath"

	gojsonnet "github.com/google/go-jsonnet"
)

type Evaluator struct{}

func NewEvaluator() *Evaluator {
	return &Evaluator{}
}

func (e *Evaluator) Evaluate(root string, expression string) (string, error) {
	vm := gojsonnet.MakeVM()
	snippet := fmt.Sprintf("local root = import %q;\n%s", filepath.ToSlash(root), expression)
	out, err := vm.EvaluateAnonymousSnippet("arcourse.jsonnet", snippet)
	if err != nil {
		return "", err
	}
	return out, nil
}
