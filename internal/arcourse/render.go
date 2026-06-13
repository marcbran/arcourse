package arcourse

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type Render struct {
	evaluate *Evaluate
}

func NewRender(evaluate *Evaluate) *Render {
	return &Render{evaluate: evaluate}
}

func (uc *Render) Exec(ctx context.Context, path string, params map[string]any, format pkg.Format) (pkg.Result, error) {
	err := ctx.Err()
	if err != nil {
		return pkg.Result{}, err
	}
	parts := strings.Split(strings.Trim(path, "/"), "/")
	segments := parts[1:]
	pathJSON, err := json.Marshal(segments)
	if err != nil {
		return pkg.Result{}, err
	}
	paramsJSON, err := json.Marshal(normalizeParams(params))
	if err != nil {
		return pkg.Result{}, err
	}
	expression := fmt.Sprintf(
		"(import 'lib/render.libsonnet')(root, %s, %s, %q)",
		string(pathJSON),
		string(paramsJSON),
		string(format),
	)
	result, err := uc.evaluate.Exec(ctx, expression)
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
