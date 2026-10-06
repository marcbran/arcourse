package course

import (
	"context"
	"fmt"
	"time"
)

type SessionSummary struct {
	ID        SessionID
	Visits    int
	FirstSeen time.Time
	LastSeen  time.Time
}

type Session struct {
	ID         SessionID
	FirstSeen  time.Time
	LastSeen   time.Time
	Visits     []VisitSummary
	Executions []ExecutionSummary
}

type Parent struct {
	Visit     VisitID
	Execution ExecutionID
}

type VisitSummary struct {
	VisitID   VisitID
	Address   Address
	Timestamp time.Time
	Parent    Parent
	Remarks   int
}

type ExecutionSummary struct {
	ExecutionID ExecutionID
	Visit       VisitID
	Timestamp   time.Time
	Status      ExecutionStatus
}

type Visit struct {
	VisitID     VisitID
	SessionID   SessionID
	Address     Address
	From        From
	Evaluations []Evaluation
	Executions  []Execution
	Remarks     []Remark
}

type ListSessions struct {
	repo Repo
}

func NewListSessions(repo Repo) *ListSessions {
	return &ListSessions{repo: repo}
}

func (uc *ListSessions) Exec(ctx context.Context) ([]SessionSummary, error) {
	log, err := uc.repo.List(ctx)
	if err != nil {
		return nil, err
	}
	index := map[SessionID]int{}
	visits := map[SessionID]map[VisitID]bool{}
	sessions := make([]SessionSummary, 0)
	seen := func(sessionID SessionID, at time.Time) int {
		i, ok := index[sessionID]
		if !ok {
			i = len(sessions)
			index[sessionID] = i
			visits[sessionID] = map[VisitID]bool{}
			sessions = append(sessions, SessionSummary{ID: sessionID, FirstSeen: at, LastSeen: at})
		}
		if at.Before(sessions[i].FirstSeen) {
			sessions[i].FirstSeen = at
		}
		if at.After(sessions[i].LastSeen) {
			sessions[i].LastSeen = at
		}
		return i
	}
	for _, evaluation := range log.Evaluations {
		seen(evaluation.SessionID, evaluation.Timestamp)
		visits[evaluation.SessionID][evaluation.VisitID] = true
	}
	for _, execution := range log.Executions {
		seen(execution.SessionID, execution.Timestamp)
	}
	for _, remark := range log.Remarks {
		seen(remark.SessionID, remark.Timestamp)
	}
	for i := range sessions {
		sessions[i].Visits = len(visits[sessions[i].ID])
	}
	return sessions, nil
}

type GetSession struct {
	repo Repo
}

func NewGetSession(repo Repo) *GetSession {
	return &GetSession{repo: repo}
}

func (uc *GetSession) Exec(ctx context.Context, sessionID SessionID) (Session, error) {
	log, err := uc.repo.ListSession(ctx, sessionID)
	if err != nil {
		return Session{}, err
	}
	result := Session{ID: sessionID, Visits: []VisitSummary{}, Executions: []ExecutionSummary{}}
	observe := func(at time.Time) {
		if result.FirstSeen.IsZero() || at.Before(result.FirstSeen) {
			result.FirstSeen = at
		}
		if at.After(result.LastSeen) {
			result.LastSeen = at
		}
	}
	visitOfEvaluation := map[EvaluationID]VisitID{}
	for _, evaluation := range log.Evaluations {
		visitOfEvaluation[evaluation.EvaluationID] = evaluation.VisitID
	}
	executions := map[ExecutionID]bool{}
	for _, execution := range log.Executions {
		observe(execution.Timestamp)
		executions[execution.ExecutionID] = true
		result.Executions = append(result.Executions, ExecutionSummary{
			ExecutionID: execution.ExecutionID,
			Visit:       visitOfEvaluation[execution.From],
			Timestamp:   execution.Timestamp,
			Status:      execution.Status(),
		})
	}
	remarks := map[VisitID]int{}
	for _, remark := range log.Remarks {
		observe(remark.Timestamp)
		remarks[visitOfEvaluation[remark.From]]++
	}
	seen := map[VisitID]bool{}
	for _, evaluation := range log.Evaluations {
		observe(evaluation.Timestamp)
		if seen[evaluation.VisitID] {
			continue
		}
		seen[evaluation.VisitID] = true
		parent := Parent{Visit: visitOfEvaluation[evaluation.From.Evaluation]}
		if executions[evaluation.From.Execution] {
			parent = Parent{Execution: evaluation.From.Execution}
		}
		result.Visits = append(result.Visits, VisitSummary{
			VisitID:   evaluation.VisitID,
			Address:   evaluation.Address,
			Timestamp: evaluation.Timestamp,
			Parent:    parent,
			Remarks:   remarks[evaluation.VisitID],
		})
	}
	return result, nil
}

type GetVisit struct {
	repo Repo
}

func NewGetVisit(repo Repo) *GetVisit {
	return &GetVisit{repo: repo}
}

func (uc *GetVisit) Exec(ctx context.Context, visitID VisitID) (Visit, error) {
	log, err := uc.repo.ListVisit(ctx, visitID)
	if err != nil {
		return Visit{}, err
	}
	if len(log.Evaluations) == 0 {
		return Visit{}, fmt.Errorf("%w: %s", ErrVisitNotRecorded, visitID)
	}
	head := log.Evaluations[0]
	return Visit{
		VisitID:     head.VisitID,
		SessionID:   head.SessionID,
		Address:     head.Address,
		From:        head.From,
		Evaluations: log.Evaluations,
		Executions:  log.Executions,
		Remarks:     log.Remarks,
	}, nil
}
