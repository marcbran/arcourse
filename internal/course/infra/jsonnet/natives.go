package jsonnet

import (
	"context"
	"fmt"
	"time"

	"github.com/marcbran/arcourse/internal/course"
)

type Repo interface {
	Sessions(ctx context.Context) ([]course.SessionSummary, error)
	Session(ctx context.Context, sessionID course.SessionID) (course.Session, error)
	Visit(ctx context.Context, visitID course.VisitID) (course.Visit, error)
	Evaluation(ctx context.Context, evaluationID course.EvaluationID) (course.Evaluation, error)
	Execution(ctx context.Context, executionID course.ExecutionID) (course.Execution, error)
	Content(ctx context.Context, evaluation course.Evaluation, projection course.Projection) (string, error)
	Output(ctx context.Context, execution course.Execution) (string, error)
}

type natives struct {
	repo Repo
}

func newNatives(repo Repo) *natives {
	return &natives{repo: repo}
}

func (n *natives) sessions() (any, error) {
	if n.repo == nil {
		return []any{}, nil
	}
	sessions, err := n.repo.Sessions(context.Background())
	if err != nil {
		return nil, err
	}
	items := make([]any, 0, len(sessions))
	for _, session := range sessions {
		items = append(items, map[string]any{
			"id":     string(session.ID),
			"visits": session.Visits,
			"first":  session.FirstSeen.Format(time.RFC3339),
			"last":   session.LastSeen.Format(time.RFC3339),
		})
	}
	return items, nil
}

func (n *natives) session(sessionID course.SessionID) (any, error) {
	if n.repo == nil {
		return nil, fmt.Errorf("course repo not configured")
	}
	result, err := n.repo.Session(context.Background(), sessionID)
	if err != nil {
		return nil, err
	}
	visits := make([]any, 0, len(result.Visits))
	for _, visit := range result.Visits {
		visits = append(visits, map[string]any{
			"visitId":   string(visit.VisitID),
			"address":   visit.Address.String(),
			"timestamp": visit.Timestamp.Format(time.RFC3339),
			"parent": map[string]any{
				"visit":     string(visit.Parent.Visit),
				"execution": string(visit.Parent.Execution),
			},
			"remarks": visit.Remarks,
		})
	}
	executions := make([]any, 0, len(result.Executions))
	for _, execution := range result.Executions {
		executions = append(executions, map[string]any{
			"executionId": string(execution.ExecutionID),
			"visitId":     string(execution.Visit),
			"timestamp":   execution.Timestamp.Format(time.RFC3339),
			"status":      string(execution.Status),
		})
	}
	return map[string]any{
		"id":         string(result.ID),
		"first":      result.FirstSeen.Format(time.RFC3339),
		"last":       result.LastSeen.Format(time.RFC3339),
		"visits":     visits,
		"executions": executions,
	}, nil
}

func (n *natives) visit(visitID course.VisitID) (any, error) {
	if n.repo == nil {
		return nil, fmt.Errorf("course repo not configured")
	}
	visit, err := n.repo.Visit(context.Background(), visitID)
	if err != nil {
		return nil, err
	}
	evaluations := make([]any, 0, len(visit.Evaluations))
	for _, evaluation := range visit.Evaluations {
		evaluations = append(evaluations, map[string]any{
			"evaluationId": string(evaluation.EvaluationID),
			"timestamp":    evaluation.Timestamp.Format(time.RFC3339),
			"contentIds":   contentIDs(evaluation.ContentIDs),
		})
	}
	executions := make([]any, 0, len(visit.Executions))
	for _, execution := range visit.Executions {
		executions = append(executions, map[string]any{
			"executionId": string(execution.ExecutionID),
			"from":        string(execution.From),
			"timestamp":   execution.Timestamp.Format(time.RFC3339),
			"status":      string(execution.Status()),
		})
	}
	remarks := make([]any, 0, len(visit.Remarks))
	for _, remark := range visit.Remarks {
		remarks = append(remarks, map[string]any{
			"remarkId":  string(remark.RemarkID),
			"from":      string(remark.From),
			"timestamp": remark.Timestamp.Format(time.RFC3339),
			"text":      remark.Text,
		})
	}
	return map[string]any{
		"visitId":     string(visit.VisitID),
		"sessionId":   string(visit.SessionID),
		"address":     visit.Address.String(),
		"from":        from(visit.From),
		"versions":    len(visit.Evaluations),
		"evaluations": evaluations,
		"executions":  executions,
		"remarks":     remarks,
	}, nil
}

func (n *natives) evaluation(evaluationID course.EvaluationID) (any, error) {
	if n.repo == nil {
		return nil, fmt.Errorf("course repo not configured")
	}
	evaluation, err := n.repo.Evaluation(context.Background(), evaluationID)
	if err != nil {
		return nil, err
	}
	return map[string]any{
		"evaluationId": string(evaluation.EvaluationID),
		"visitId":      string(evaluation.VisitID),
		"sessionId":    string(evaluation.SessionID),
		"address":      evaluation.Address.String(),
		"from":         from(evaluation.From),
		"timestamp":    evaluation.Timestamp.Format(time.RFC3339),
		"contentIds":   contentIDs(evaluation.ContentIDs),
	}, nil
}

func (n *natives) execution(executionID course.ExecutionID) (any, error) {
	if n.repo == nil {
		return nil, fmt.Errorf("course repo not configured")
	}
	execution, err := n.repo.Execution(context.Background(), executionID)
	if err != nil {
		return nil, err
	}
	evaluation, err := n.repo.Evaluation(context.Background(), execution.From)
	if err != nil {
		return nil, err
	}
	result := map[string]any{
		"executionId": string(execution.ExecutionID),
		"from":        string(execution.From),
		"visitId":     string(evaluation.VisitID),
		"sessionId":   string(execution.SessionID),
		"address":     evaluation.Address.String(),
		"timestamp":   execution.Timestamp.Format(time.RFC3339),
		"status":      string(execution.Status()),
		"finished":    "",
		"error":       "",
		"hasOutput":   false,
	}
	if execution.Outcome != nil {
		result["finished"] = execution.Outcome.Timestamp.Format(time.RFC3339)
		result["error"] = execution.Outcome.Error
		result["hasOutput"] = execution.Outcome.OutputID != ""
	}
	return result, nil
}

func (n *natives) content(evaluationID course.EvaluationID, projection course.Projection) (any, error) {
	if n.repo == nil {
		return nil, fmt.Errorf("course repo not configured")
	}
	evaluation, err := n.repo.Evaluation(context.Background(), evaluationID)
	if err != nil {
		return nil, err
	}
	return n.repo.Content(context.Background(), evaluation, projection)
}

func (n *natives) output(executionID course.ExecutionID) (any, error) {
	if n.repo == nil {
		return nil, fmt.Errorf("course repo not configured")
	}
	execution, err := n.repo.Execution(context.Background(), executionID)
	if err != nil {
		return nil, err
	}
	return n.repo.Output(context.Background(), execution)
}

func from(from course.From) map[string]any {
	return map[string]any{
		"evaluation": string(from.Evaluation),
		"execution":  string(from.Execution),
	}
}

func contentIDs(contentIDs map[course.Projection]course.ContentID) map[string]any {
	out := make(map[string]any, len(contentIDs))
	for projection, id := range contentIDs {
		out[string(projection)] = string(id)
	}
	return out
}
