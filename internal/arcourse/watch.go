package arcourse

import (
	"context"
	"fmt"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type watch struct {
	cfg         QueryConfig
	environment *environment
	appendAudit *appendAudit
}

func newWatch(cfg QueryConfig, environment *environment, appendAudit *appendAudit) *watch {
	return &watch{cfg: cfg, environment: environment, appendAudit: appendAudit}
}

func (uc *watch) Exec(ctx context.Context, path string, params map[string]any, format pkg.Format) (<-chan pkg.Result, func(), error) {
	err := ctx.Err()
	if err != nil {
		return nil, nil, err
	}

	formats := mergeFormats(format, uc.cfg.AuditFormats)

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

	value, ok := uc.decodeAndAudit(ctx, initial, formats, format, queryPath)
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
				value, ok := uc.decodeAndAudit(ctx, out, formats, format, queryPath)
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

func (uc *watch) decodeAndAudit(ctx context.Context, out string, formats []pkg.Format, format pkg.Format, queryPath string) (string, bool) {
	decoded, queryID, err := decodeOutput(out, formats, format)
	if err != nil {
		return "", false
	}
	value, ok := decoded[format]
	if !ok {
		return "", false
	}
	if len(uc.cfg.AuditFormats) > 0 {
		uc.appendAudit.Exec(ctx, queryID, queryPath, auditResults(decoded, uc.cfg.AuditFormats))
	}
	return value, true
}
