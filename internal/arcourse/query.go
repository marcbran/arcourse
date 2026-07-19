package arcourse

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type QueryConfig struct {
	AuditFormats []pkg.Format `json:"auditFormats"`
}

type Query struct {
	cfg         QueryConfig
	evaluate    *Evaluate
	lastQuery   LastQuery
	appendAudit *AppendAudit
}

func NewQuery(cfg QueryConfig, evaluate *Evaluate, lastQuery LastQuery, appendAudit *AppendAudit) *Query {
	return &Query{cfg: cfg, evaluate: evaluate, lastQuery: lastQuery, appendAudit: appendAudit}
}

func (uc *Query) Exec(ctx context.Context, path string, params map[string]any, format pkg.Format) (pkg.Result, error) {
	err := ctx.Err()
	if err != nil {
		return pkg.Result{}, err
	}

	observed := uc.lastQuery.ObservedFormats()
	formats := mergeFormats(format, observed, uc.cfg.AuditFormats)

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
	formatsJSON, err := json.Marshal(formats)
	if err != nil {
		return pkg.Result{}, err
	}
	expression := fmt.Sprintf(
		"(import 'lib/query.libsonnet')(root, %s, %s, %s)",
		string(pathJSON),
		string(paramsJSON),
		string(formatsJSON),
	)

	result, err := uc.evaluate.exec(ctx, expression)
	if err != nil {
		return pkg.Result{}, err
	}

	var raw map[string]json.RawMessage
	err = json.Unmarshal([]byte(result.Output), &raw)
	if err != nil {
		return pkg.Result{}, err
	}

	decoded := make(map[pkg.Format]string, len(raw))
	for _, f := range formats {
		rawValue, ok := raw[string(f)]
		if !ok {
			if f == format {
				return pkg.Result{}, fmt.Errorf("node has no %s view", f)
			}
			continue
		}
		value, err := decodeField(f, rawValue)
		if err != nil {
			return pkg.Result{}, err
		}
		decoded[f] = value
	}

	for _, f := range observed {
		value, ok := decoded[f]
		if !ok {
			continue
		}
		uc.lastQuery.Publish(f, pkg.Result{Output: value})
	}

	if len(uc.cfg.AuditFormats) > 0 {
		results := make(map[pkg.Format]pkg.Result, len(uc.cfg.AuditFormats))
		for _, f := range uc.cfg.AuditFormats {
			value, ok := decoded[f]
			if !ok {
				continue
			}
			results[f] = pkg.Result{Output: value}
		}
		uc.appendAudit.Exec(ctx, path, results)
	}

	return pkg.Result{Output: decoded[format]}, nil
}

func mergeFormats(primary pkg.Format, sets ...[]pkg.Format) []pkg.Format {
	seen := map[pkg.Format]bool{primary: true}
	formats := []pkg.Format{primary}
	for _, set := range sets {
		for _, f := range set {
			if seen[f] {
				continue
			}
			seen[f] = true
			formats = append(formats, f)
		}
	}
	return formats
}

func normalizeParams(params map[string]any) map[string]any {
	if params == nil {
		return map[string]any{}
	}
	return params
}

func decodeField(format pkg.Format, raw json.RawMessage) (string, error) {
	if format == pkg.FormatJSON {
		return string(raw), nil
	}
	var s string
	err := json.Unmarshal(raw, &s)
	if err != nil {
		return "", err
	}
	return s, nil
}
