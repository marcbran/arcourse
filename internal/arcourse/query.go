package arcourse

import (
	"context"

	"github.com/marcbran/arcourse/internal/course"
	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type query struct {
	environment *environment
	report      *report
}

func newQuery(environment *environment, report *report) *query {
	return &query{environment: environment, report: report}
}

func (uc *query) Exec(ctx context.Context, path pkg.QueryPath, params map[string]any, format pkg.Format, origin pkg.Origin) (pkg.Result, error) {
	err := ctx.Err()
	if err != nil {
		return pkg.Result{}, err
	}

	req, err := newRequest(path, params, format, origin)
	if err != nil {
		return pkg.Result{}, err
	}

	out, _, unregister, err := uc.environment.Watch(ctx, req.key, req.expression)
	if err != nil {
		out = Evaluation{Err: err}
	} else {
		unregister()
	}

	return uc.report.Exec(ctx, &course.VisitRef{}, req, out)
}
