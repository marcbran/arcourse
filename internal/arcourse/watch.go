package arcourse

import (
	"context"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type watch struct {
	environment *environment
}

func newWatch(environment *environment) *watch {
	return &watch{environment: environment}
}

func (uc *watch) Exec(ctx context.Context, path string, params map[string]any, format pkg.Format) (<-chan pkg.Result, func(), error) {
	err := ctx.Err()
	if err != nil {
		return nil, nil, err
	}

	_, segments, paramsJSON, key, err := queryParts(path, params, format)
	if err != nil {
		return nil, nil, err
	}

	formats := []pkg.Format{format}
	expression, err := buildExpression(segments, paramsJSON, formats)
	if err != nil {
		return nil, nil, err
	}

	initial, updates, unregister, err := uc.environment.Watch(ctx, key, expression)
	if err != nil {
		return nil, nil, err
	}

	results := make(chan pkg.Result)
	go func() {
		defer close(results)

		if value, ok := decodeValue(initial, format); ok {
			select {
			case results <- pkg.Result{Output: value}:
			case <-ctx.Done():
				return
			}
		}

		for {
			select {
			case out, ok := <-updates:
				if !ok {
					return
				}
				value, ok := decodeValue(out, format)
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

func decodeValue(out string, format pkg.Format) (string, bool) {
	decoded, err := decodeOutput(out, []pkg.Format{format}, format)
	if err != nil {
		return "", false
	}
	value, ok := decoded[format]
	return value, ok
}
