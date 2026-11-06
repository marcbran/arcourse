package arcourse

import (
	"context"

	"github.com/marcbran/arcourse/internal/course"
	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type watch struct {
	environment *environment
	report      *report
}

func newWatch(environment *environment, report *report) *watch {
	return &watch{environment: environment, report: report}
}

func (uc *watch) Exec(ctx context.Context, path pkg.QueryPath, params map[string]any, format pkg.Format, origin pkg.Origin) (<-chan pkg.Result, func(), error) {
	err := ctx.Err()
	if err != nil {
		return nil, nil, err
	}

	req, err := newRequest(path, params, format, origin)
	if err != nil {
		return nil, nil, err
	}

	var ref course.VisitRef

	initial, updates, unregister, err := uc.environment.Watch(ctx, req.key, req.expression)
	if err != nil {
		result, err := uc.report.Exec(ctx, &ref, req, Evaluation{Err: err})
		if err != nil {
			return nil, nil, err
		}
		results := make(chan pkg.Result, 1)
		results <- result
		close(results)
		return results, func() {}, nil
	}

	result, err := uc.report.Exec(ctx, &ref, req, initial)
	if err != nil {
		unregister()
		return nil, nil, err
	}

	results := make(chan pkg.Result, 1)
	results <- result
	go func() {
		defer close(results)

		for {
			select {
			case out, ok := <-updates:
				if !ok {
					return
				}
				result, err := uc.report.Exec(ctx, &ref, req, out)
				if err != nil {
					continue
				}
				select {
				case results <- result:
				case <-ctx.Done():
					return
				}
			case <-ctx.Done():
				return
			}
		}
	}()

	return results, unregister, nil
}
