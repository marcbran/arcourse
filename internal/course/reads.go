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
	ID        SessionID
	FirstSeen time.Time
	LastSeen  time.Time
	Visits    []VisitSummary
	Edges     []SessionEdge
}

type VisitSummary struct {
	VisitID   VisitID
	Address   Address
	Timestamp time.Time
}

type SessionEdge struct {
	From VisitID
	To   VisitID
}

type Visit struct {
	VisitID     VisitID
	SessionID   SessionID
	Address     Address
	From        EvaluationID
	Evaluations []Evaluation
}

type Evaluation struct {
	EvaluationID EvaluationID
	Timestamp    time.Time
	ContentIDs   map[Projection]ContentID
}

type ListSessions struct {
	repo Repo
}

func NewListSessions(repo Repo) *ListSessions {
	return &ListSessions{repo: repo}
}

func (uc *ListSessions) Exec(ctx context.Context) ([]SessionSummary, error) {
	events, err := uc.repo.List(ctx)
	if err != nil {
		return nil, err
	}
	index := map[SessionID]int{}
	visits := map[SessionID]map[VisitID]bool{}
	sessions := make([]SessionSummary, 0)
	for _, event := range events {
		at, ok := index[event.SessionID]
		if !ok {
			at = len(sessions)
			index[event.SessionID] = at
			visits[event.SessionID] = map[VisitID]bool{}
			sessions = append(sessions, SessionSummary{ID: event.SessionID, FirstSeen: event.Timestamp})
		}
		sessions[at].LastSeen = event.Timestamp
		visits[event.SessionID][event.VisitID] = true
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
	events, err := uc.repo.ListSession(ctx, sessionID)
	if err != nil {
		return Session{}, err
	}
	result := Session{ID: sessionID, Visits: []VisitSummary{}, Edges: []SessionEdge{}}
	seen := map[VisitID]bool{}
	visitOfEvaluation := map[EvaluationID]VisitID{}
	type pending struct {
		from EvaluationID
		to   VisitID
	}
	var edges []pending
	for _, event := range events {
		visitOfEvaluation[event.EvaluationID] = event.VisitID
		if result.FirstSeen.IsZero() {
			result.FirstSeen = event.Timestamp
		}
		result.LastSeen = event.Timestamp
		if seen[event.VisitID] {
			continue
		}
		seen[event.VisitID] = true
		result.Visits = append(result.Visits, VisitSummary{
			VisitID:   event.VisitID,
			Address:   event.Address,
			Timestamp: event.Timestamp,
		})
		if event.From != "" {
			edges = append(edges, pending{from: event.From, to: event.VisitID})
		}
	}
	for _, edge := range edges {
		result.Edges = append(result.Edges, SessionEdge{From: visitOfEvaluation[edge.from], To: edge.to})
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
	events, err := uc.repo.ListVisit(ctx, visitID)
	if err != nil {
		return Visit{}, err
	}
	if len(events) == 0 {
		return Visit{}, fmt.Errorf("%w: %s", ErrVisitNotRecorded, visitID)
	}
	head := events[0]
	visit := Visit{
		VisitID:     head.VisitID,
		SessionID:   head.SessionID,
		Address:     head.Address,
		From:        head.From,
		Evaluations: make([]Evaluation, 0, len(events)),
	}
	for _, event := range events {
		visit.Evaluations = append(visit.Evaluations, Evaluation{
			EvaluationID: event.EvaluationID,
			Timestamp:    event.Timestamp,
			ContentIDs:   event.ContentIDs,
		})
	}
	return visit, nil
}
