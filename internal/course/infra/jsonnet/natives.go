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
	Evaluation(ctx context.Context, evaluationID course.EvaluationID) (course.Event, error)
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
		})
	}
	edges := make([]any, 0, len(result.Edges))
	for _, edge := range result.Edges {
		edges = append(edges, map[string]any{
			"from": string(edge.From),
			"to":   string(edge.To),
		})
	}
	return map[string]any{
		"id":     string(result.ID),
		"first":  result.FirstSeen.Format(time.RFC3339),
		"last":   result.LastSeen.Format(time.RFC3339),
		"visits": visits,
		"edges":  edges,
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
	return map[string]any{
		"visitId":     string(visit.VisitID),
		"sessionId":   string(visit.SessionID),
		"address":     visit.Address.String(),
		"from":        string(visit.From),
		"versions":    len(visit.Evaluations),
		"evaluations": evaluations,
	}, nil
}

func (n *natives) evaluation(evaluationID course.EvaluationID) (any, error) {
	if n.repo == nil {
		return nil, fmt.Errorf("course repo not configured")
	}
	event, err := n.repo.Evaluation(context.Background(), evaluationID)
	if err != nil {
		return nil, err
	}
	return map[string]any{
		"evaluationId": string(event.EvaluationID),
		"visitId":      string(event.VisitID),
		"sessionId":    string(event.SessionID),
		"address":      event.Address.String(),
		"from":         string(event.From),
		"timestamp":    event.Timestamp.Format(time.RFC3339),
		"contentIds":   contentIDs(event.ContentIDs),
	}, nil
}

func contentIDs(contentIDs map[course.Projection]course.ContentID) map[string]any {
	out := make(map[string]any, len(contentIDs))
	for projection, id := range contentIDs {
		out[string(projection)] = string(id)
	}
	return out
}
