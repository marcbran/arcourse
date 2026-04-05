package arcourse

import (
	"encoding/json"
	"strings"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type Render struct {
	evaluate *Evaluate
}

func NewRender(evaluate *Evaluate) *Render {
	return &Render{evaluate: evaluate}
}

func (uc *Render) Exec(path []string, format pkg.Format) (pkg.Result, error) {
	expression := strings.Join(path, ".") + "._view." + string(format)
	result, err := uc.evaluate.Exec(expression)
	if err != nil {
		return pkg.Result{}, err
	}
	var output string
	err = json.Unmarshal([]byte(result.Output), &output)
	if err != nil {
		return pkg.Result{}, err
	}
	return pkg.Result{Output: output}, nil
}
