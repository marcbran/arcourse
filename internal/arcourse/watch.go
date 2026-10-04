package arcourse

import (
	"context"
	"fmt"

	"github.com/marcbran/arcourse/internal/course"
	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type watch struct {
	environment *environment
	course      *course.Facade
}

func newWatch(environment *environment, courseFacade *course.Facade) *watch {
	return &watch{environment: environment, course: courseFacade}
}

func (uc *watch) Exec(ctx context.Context, path pkg.QueryPath, params map[string]any, format pkg.Format, origin pkg.Origin) (<-chan pkg.Result, func(), error) {
	err := ctx.Err()
	if err != nil {
		return nil, nil, err
	}

	formats := mergeFormats(format, recordedFormats)

	queryPath, segments, paramsJSON, key, err := queryParts(path, params, formats)
	if err != nil {
		return nil, nil, err
	}

	expression, err := buildExpression(segments, paramsJSON, formats)
	if err != nil {
		return nil, nil, err
	}

	initial, updates, unregister, err := uc.environment.Watch(ctx, key, expression)
	if err != nil {
		return nil, nil, err
	}

	var ref course.VisitRef

	value, ok := uc.decodeAndRecord(ctx, &ref, initial, formats, format, queryPath, origin)
	if !ok {
		unregister()
		return nil, nil, fmt.Errorf("node has no %s view", format)
	}

	results := make(chan pkg.Result, 1)
	results <- pkg.Result{Output: value}
	go func() {
		defer close(results)

		for {
			select {
			case out, ok := <-updates:
				if !ok {
					return
				}
				value, ok := uc.decodeAndRecord(ctx, &ref, out, formats, format, queryPath, origin)
				if !ok {
					continue
				}
				select {
				case results <- pkg.Result{Output: value}:
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

func (uc *watch) decodeAndRecord(ctx context.Context, ref *course.VisitRef, out string, formats []pkg.Format, format pkg.Format, queryPath pkg.QueryPath, origin pkg.Origin) (string, bool) {
	decoded, evaluationID, err := decodeOutput(out, formats, format)
	if err != nil {
		return "", false
	}
	value, ok := decoded[format]
	if !ok {
		return "", false
	}
	if recordable(decoded) {
		*ref = uc.course.Record(ctx, *ref, course.EvaluationID(evaluationID), course.Address(queryPath), recordableContents(decoded), courseOrigin(origin))
	}
	return value, true
}
