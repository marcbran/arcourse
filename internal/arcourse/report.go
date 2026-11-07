package arcourse

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"

	"github.com/marcbran/arcourse/internal/course"
	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type report struct {
	evaluator Evaluator
	course    *course.Facade
}

func newReport(evaluator Evaluator, courseFacade *course.Facade) *report {
	return &report{evaluator: evaluator, course: courseFacade}
}

func (uc *report) Exec(ctx context.Context, ref *course.VisitRef, req request, out Evaluation) (pkg.Result, error) {
	if out.Err != nil {
		if !errors.Is(out.Err, pkg.ErrEvaluation) {
			return pkg.Result{}, out.Err
		}
		failure := runtimeFailure(out.Err)
		snippet, err := failurePageSnippet(failure, req.format)
		if err != nil {
			return pkg.Result{Failure: failure}, nil
		}
		page, err := uc.evaluator.EvaluateOnceRaw(ctx, snippet)
		if err != nil {
			return pkg.Result{Failure: failure}, nil
		}
		return pkg.Result{Output: page, Failure: failure}, nil
	}

	ev, err := decodeEvaluation(out.Output, req)
	if err != nil {
		return pkg.Result{}, err
	}
	if !ev.recordable {
		return ev.result, nil
	}
	*ref = uc.course.Record(ctx, *ref, ev.evaluationID, course.Address(req.queryPath), ev.contents, courseOrigin(req.origin))
	result := ev.result
	result.EvaluationID = pkg.EvaluationID(ref.EvaluationID)
	return result, nil
}

func runtimeFailure(err error) *pkg.Failure {
	return &pkg.Failure{
		Code:    http.StatusInternalServerError,
		Reason:  http.StatusText(http.StatusInternalServerError),
		Message: err.Error(),
	}
}

func failurePageSnippet(failure *pkg.Failure, format pkg.Format) (string, error) {
	input, err := json.Marshal(map[string]any{"failure": failure, "format": format})
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("local input = %s; (import 'lib/failure_page.libsonnet')(input.failure, input.format)", input), nil
}

type evaluated struct {
	result       pkg.Result
	evaluationID course.EvaluationID
	contents     map[course.Projection]string
	recordable   bool
}

func decodeEvaluation(out string, req request) (evaluated, error) {
	decoded, evaluationID, err := decodeOutput(out, req.formats, req.format)
	if err != nil {
		return evaluated{}, err
	}
	failure, err := failureOf(decoded)
	if err != nil {
		return evaluated{}, err
	}
	return evaluated{
		result:       pkg.Result{Output: decoded[req.format], Failure: failure},
		evaluationID: course.EvaluationID(evaluationID),
		contents:     recordableContents(decoded),
		recordable:   recordable(decoded),
	}, nil
}

func failureOf(decoded map[pkg.Format]string) (*pkg.Failure, error) {
	raw, ok := decoded[pkg.FormatJSON]
	if !ok {
		return nil, nil
	}
	var doc struct {
		Failure *pkg.Failure `json:"_failure"`
	}
	err := json.Unmarshal([]byte(raw), &doc)
	if err != nil {
		return nil, err
	}
	return doc.Failure, nil
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
