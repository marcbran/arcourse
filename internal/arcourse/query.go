package arcourse

import (
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"strings"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type QueryConfig struct {
	AuditFormats []pkg.Format `json:"auditFormats"`
}

type query struct {
	cfg         QueryConfig
	environment *environment
	lastQuery   LastQuery
	appendAudit *appendAudit
}

func newQuery(cfg QueryConfig, environment *environment, lastQuery LastQuery, appendAudit *appendAudit) *query {
	return &query{cfg: cfg, environment: environment, lastQuery: lastQuery, appendAudit: appendAudit}
}

func (uc *query) Exec(ctx context.Context, path string, params map[string]any, format pkg.Format) (pkg.Result, error) {
	err := ctx.Err()
	if err != nil {
		return pkg.Result{}, err
	}

	observed := uc.lastQuery.ObservedFormats()
	formats := mergeFormats(format, observed, uc.cfg.AuditFormats)

	queryPath, segments, paramsJSON, key, err := queryParts(path, params, format)
	if err != nil {
		return pkg.Result{}, err
	}

	expression, err := buildExpression(segments, paramsJSON, formats)
	if err != nil {
		return pkg.Result{}, err
	}

	out, _, unregister, err := uc.environment.Watch(ctx, key, expression)
	if err != nil {
		return pkg.Result{}, err
	}
	unregister()

	decoded, err := decodeOutput(out, formats, format)
	if err != nil {
		return pkg.Result{}, err
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
		uc.appendAudit.Exec(ctx, queryPath, results)
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

func splitPathAndQuery(path string) (string, map[string]any, error) {
	base, query, found := strings.Cut(path, "?")
	if !found {
		return base, map[string]any{}, nil
	}
	values, err := url.ParseQuery(query)
	if err != nil {
		return "", nil, err
	}
	params := map[string]any{}
	for key, vs := range values {
		if len(vs) == 1 {
			params[key] = vs[0]
		} else if len(vs) > 1 {
			params[key] = vs
		}
	}
	return base, params, nil
}

func queryParts(path string, params map[string]any, format pkg.Format) (queryPath string, segments []string, paramsJSON string, key string, err error) {
	queryPath, queryParams, err := splitPathAndQuery(path)
	if err != nil {
		return "", nil, "", "", err
	}
	parts := strings.Split(strings.Trim(queryPath, "/"), "/")
	segments = parts[1:]
	paramsBytes, err := json.Marshal(mergeParams(queryParams, params))
	if err != nil {
		return "", nil, "", "", err
	}
	paramsJSON = string(paramsBytes)
	key = queryPath + "|" + paramsJSON + "|" + string(format)
	return queryPath, segments, paramsJSON, key, nil
}

func buildExpression(segments []string, paramsJSON string, formats []pkg.Format) (string, error) {
	pathJSON, err := json.Marshal(segments)
	if err != nil {
		return "", err
	}
	formatsJSON, err := json.Marshal(formats)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf(
		"(import 'lib/query.libsonnet')(root, %s, %s, %s)",
		string(pathJSON),
		paramsJSON,
		string(formatsJSON),
	), nil
}

func mergeParams(base map[string]any, overrides map[string]any) map[string]any {
	merged := make(map[string]any, len(base)+len(overrides))
	for k, v := range base {
		merged[k] = v
	}
	for k, v := range overrides {
		merged[k] = v
	}
	return merged
}

func decodeOutput(out string, formats []pkg.Format, primary pkg.Format) (map[pkg.Format]string, error) {
	var raw map[string]json.RawMessage
	err := json.Unmarshal([]byte(out), &raw)
	if err != nil {
		return nil, err
	}
	decoded := make(map[pkg.Format]string, len(raw))
	for _, f := range formats {
		rawValue, ok := raw[string(f)]
		if !ok {
			if f == primary {
				return nil, fmt.Errorf("node has no %s view", f)
			}
			continue
		}
		value, err := decodeField(f, rawValue)
		if err != nil {
			return nil, err
		}
		decoded[f] = value
	}
	return decoded, nil
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
