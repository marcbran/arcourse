package arcourse

import (
	"encoding/json"
	"fmt"
	"net/url"
	"slices"
	"strings"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type request struct {
	queryPath  pkg.QueryPath
	segments   []string
	paramsJSON string
	formats    []pkg.Format
	format     pkg.Format
	key        string
	expression string
	origin     pkg.Origin
}

func newRequest(path pkg.QueryPath, params map[string]any, format pkg.Format, origin pkg.Origin) (request, error) {
	formats := mergeFormats(format, recordedFormats)
	queryPath, segments, paramsJSON, key, err := queryParts(path, params, formats)
	if err != nil {
		return request{}, err
	}
	expression, err := buildExpression(segments, paramsJSON, formats)
	if err != nil {
		return request{}, err
	}
	return request{
		queryPath:  queryPath,
		segments:   segments,
		paramsJSON: paramsJSON,
		formats:    formats,
		format:     format,
		key:        key,
		expression: expression,
		origin:     origin,
	}, nil
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
	slices.Sort(formats)
	return formats
}

func queryParts(path pkg.QueryPath, params map[string]any, formats []pkg.Format) (queryPath pkg.QueryPath, segments []string, paramsJSON string, key string, err error) {
	queryPath, queryParams, err := splitPathAndQuery(path)
	if err != nil {
		return "", nil, "", "", err
	}
	queryPath = pkg.NewQueryPath(queryPath.String())
	parts := strings.Split(queryPath.String(), "/")
	segments = make([]string, 0, len(parts)-1)
	for _, part := range parts[1:] {
		segment, err := url.PathUnescape(part)
		if err != nil {
			return "", nil, "", "", err
		}
		segments = append(segments, segment)
	}
	paramsBytes, err := json.Marshal(mergeParams(queryParams, params))
	if err != nil {
		return "", nil, "", "", err
	}
	paramsJSON = string(paramsBytes)
	key = queryPath.String() + "|" + paramsJSON + "|" + formatsKey(formats)
	return queryPath, segments, paramsJSON, key, nil
}

func splitPathAndQuery(path pkg.QueryPath) (pkg.QueryPath, map[string]any, error) {
	base, query, found := strings.Cut(path.String(), "?")
	if !found {
		return pkg.QueryPath(base), map[string]any{}, nil
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
	return pkg.QueryPath(base), params, nil
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

func formatsKey(formats []pkg.Format) string {
	parts := make([]string, len(formats))
	for i, f := range formats {
		parts[i] = string(f)
	}
	return strings.Join(parts, ",")
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
