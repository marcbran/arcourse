package arcourse

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type Query struct {
	evaluate *Evaluate
}

func NewQuery(evaluate *Evaluate) *Query {
	return &Query{evaluate: evaluate}
}

func (uc *Query) Exec(ctx context.Context, path string, params map[string]any) (pkg.Result, error) {
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
		"(import 'lib/query.libsonnet')(root, %s, %s)",
		string(pathJSON),
		string(paramsJSON),
	)
	return uc.evaluate.exec(ctx, expression)
}
