package arcourse

import (
	"context"
	"encoding/json"
	"regexp"
	"strings"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

var identifierRe = regexp.MustCompile(`^[a-zA-Z_][a-zA-Z0-9_]*$`)

type Render struct {
	evaluate *Evaluate
}

func NewRender(evaluate *Evaluate) *Render {
	return &Render{evaluate: evaluate}
}

func (uc *Render) Exec(ctx context.Context, path []string, format pkg.Format) (pkg.Result, error) {
	err := ctx.Err()
	if err != nil {
		return pkg.Result{}, err
	}
	var b strings.Builder
	for i, segment := range path {
		if identifierRe.MatchString(segment) {
			if i > 0 {
				b.WriteByte('.')
			}
			b.WriteString(segment)
		} else {
			b.WriteString(`["`)
			b.WriteString(segment)
			b.WriteString(`"]`)
		}
	}
	b.WriteString("._view.")
	b.WriteString(string(format))
	expression := b.String()
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
