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

func (uc *Query) Exec(ctx context.Context, path string) (pkg.Result, error) {
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
	expression := fmt.Sprintf(
		"(import 'lib/traverse_path.libsonnet')(root, %s)",
		string(pathJSON),
	)
	return uc.evaluate.Exec(ctx, expression)
}
