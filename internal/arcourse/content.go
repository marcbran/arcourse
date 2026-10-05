package arcourse

import (
	"bytes"
	"encoding/json"
	"log/slog"
	"strings"

	"github.com/marcbran/arcourse/internal/course"
	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

var recordedFormats = []pkg.Format{pkg.FormatHTML, pkg.FormatJSON}

const recordField = "_record"

func recordable(decoded map[pkg.Format]string) bool {
	raw, ok := decoded[pkg.FormatJSON]
	if !ok {
		return true
	}
	var node map[string]any
	err := json.Unmarshal([]byte(raw), &node)
	if err != nil {
		return true
	}
	value, ok := node[recordField]
	if !ok {
		return true
	}
	record, ok := value.(bool)
	if !ok {
		return true
	}
	return record
}

func recordableContents(decoded map[pkg.Format]string) map[course.Projection]string {
	contents := make(map[course.Projection]string, len(decoded))
	for _, format := range recordedFormats {
		raw, ok := decoded[format]
		if !ok {
			continue
		}
		if format != pkg.FormatJSON {
			contents[course.Projection(format)] = raw
			continue
		}
		body, err := canonicalJSON(raw)
		if err != nil {
			slog.Warn("canonicalise content", "err", err, "format", format)
			continue
		}
		contents[course.Projection(format)] = body
	}
	return contents
}

func canonicalJSON(raw string) (string, error) {
	value, err := decodeJSONValue(raw)
	if err != nil {
		return "", err
	}
	object, ok := value.(map[string]any)
	if ok {
		delete(object, pkg.EvaluationIDField)
	}
	return marshalCanonical(value)
}

func withEvaluationID(raw string, evaluationID course.EvaluationID) (string, error) {
	value, err := decodeJSONValue(raw)
	if err != nil {
		return "", err
	}
	object, ok := value.(map[string]any)
	if !ok {
		return raw, nil
	}
	object[pkg.EvaluationIDField] = string(evaluationID)
	return marshalCanonical(object)
}

func decodeJSONValue(raw string) (any, error) {
	decoder := json.NewDecoder(strings.NewReader(raw))
	decoder.UseNumber()
	var value any
	err := decoder.Decode(&value)
	if err != nil {
		return nil, err
	}
	return value, nil
}

func marshalCanonical(value any) (string, error) {
	var buf bytes.Buffer
	encoder := json.NewEncoder(&buf)
	encoder.SetEscapeHTML(false)
	err := encoder.Encode(value)
	if err != nil {
		return "", err
	}
	return strings.TrimRight(buf.String(), "\n"), nil
}
