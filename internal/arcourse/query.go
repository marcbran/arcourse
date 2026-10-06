package arcourse

import (
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"slices"
	"strings"

	"github.com/marcbran/arcourse/internal/course"
	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type query struct {
	environment *environment
	course      *course.Facade
}

func newQuery(environment *environment, courseFacade *course.Facade) *query {
	return &query{environment: environment, course: courseFacade}
}

func (uc *query) Exec(ctx context.Context, path pkg.QueryPath, params map[string]any, format pkg.Format, origin pkg.Origin) (pkg.Result, error) {
	err := ctx.Err()
	if err != nil {
		return pkg.Result{}, err
	}

	formats := mergeFormats(format, recordedFormats)

	queryPath, segments, paramsJSON, key, err := queryParts(path, params, formats)
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

	decoded, evaluationID, err := decodeOutput(out, formats, format)
	if err != nil {
		return pkg.Result{}, err
	}

	result := pkg.Result{Output: decoded[format]}
	if recordable(decoded) {
		ref := uc.course.Record(ctx, course.VisitRef{}, course.EvaluationID(evaluationID), course.Address(queryPath), recordableContents(decoded), courseOrigin(origin))
		result.EvaluationID = pkg.EvaluationID(ref.EvaluationID)
	}

	return result, nil
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
	segments = parts[1:]
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

func decodeOutput(out string, formats []pkg.Format, primary pkg.Format) (map[pkg.Format]string, pkg.EvaluationID, error) {
	var raw map[string]json.RawMessage
	err := json.Unmarshal([]byte(out), &raw)
	if err != nil {
		return nil, "", err
	}
	rawID, ok := raw[pkg.EvaluationIDField]
	if !ok {
		return nil, "", fmt.Errorf("output has no %s", pkg.EvaluationIDField)
	}
	var rawEvaluationID string
	err = json.Unmarshal(rawID, &rawEvaluationID)
	if err != nil {
		return nil, "", err
	}
	if rawEvaluationID == "" {
		return nil, "", fmt.Errorf("output has an empty %s", pkg.EvaluationIDField)
	}
	evaluationID := pkg.EvaluationID(rawEvaluationID)
	decoded := make(map[pkg.Format]string, len(raw))
	for _, f := range formats {
		rawValue, ok := raw[string(f)]
		if !ok {
			if f == primary {
				return nil, "", fmt.Errorf("node has no %s view", f)
			}
			continue
		}
		value, err := decodeField(f, rawValue)
		if err != nil {
			return nil, "", err
		}
		decoded[f] = value
	}
	return decoded, evaluationID, nil
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
