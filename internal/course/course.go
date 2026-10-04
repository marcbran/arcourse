package course

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"
)

const implicitSessionIdleGap = 30 * time.Minute

var (
	ErrVisitNotRecorded      = errors.New("visit not recorded")
	ErrEvaluationNotRecorded = errors.New("evaluation not recorded")
	ErrContentNotRecorded    = errors.New("evaluation has no content recorded")
)

type SessionID string

type VisitID string

type EvaluationID string

type ContentID string

type Projection string

type Address string

func (a Address) String() string {
	return string(a)
}

type Origin struct {
	SessionID   SessionID
	From        EvaluationID
	FromAddress Address
}

type Event struct {
	EvaluationID EvaluationID             `json:"evaluationId"`
	VisitID      VisitID                  `json:"visitId"`
	SessionID    SessionID                `json:"sessionId"`
	Address      Address                  `json:"address"`
	From         EvaluationID             `json:"from,omitempty"`
	Implicit     bool                     `json:"implicit,omitempty"`
	Timestamp    time.Time                `json:"timestamp"`
	ContentIDs   map[Projection]ContentID `json:"contentIds,omitempty"`
}

type VisitRef struct {
	VisitID    VisitID
	SessionID  SessionID
	Implicit   bool
	ContentIDs map[Projection]ContentID
}

type Repo interface {
	Append(ctx context.Context, event Event) error
	List(ctx context.Context) ([]Event, error)
	Get(ctx context.Context, evaluationID EvaluationID) (Event, error)
	ListSession(ctx context.Context, sessionID SessionID) ([]Event, error)
	ListVisit(ctx context.Context, visitID VisitID) ([]Event, error)
	LatestAtAddress(ctx context.Context, sessionID SessionID, address Address) (Event, bool, error)
	LatestImplicitSession(ctx context.Context) (Event, bool, error)
}

type Observer interface {
	Appended(event Event)
}

type BlobStore interface {
	Put(ctx context.Context, content string) (ContentID, error)
	Get(ctx context.Context, contentID ContentID) (string, error)
}

type recordVisit struct {
	repo     Repo
	blobs    BlobStore
	observer Observer
}

func newRecordVisit(repo Repo, blobs BlobStore, observer Observer) *recordVisit {
	return &recordVisit{repo: repo, blobs: blobs, observer: observer}
}

func (uc *recordVisit) Exec(ctx context.Context, ref VisitRef, evaluationID EvaluationID, address Address, contents map[Projection]string, origin Origin) VisitRef {
	event := Event{EvaluationID: evaluationID, Address: address, Timestamp: time.Now()}
	first := ref.VisitID == ""
	if first {
		sessionID, from, implicit := uc.resolveOrigin(ctx, origin)
		ref = VisitRef{VisitID: VisitID(uuid.Must(uuid.NewV7()).String()), SessionID: sessionID, Implicit: implicit}
		event.From = from
	}
	event.VisitID = ref.VisitID
	event.SessionID = ref.SessionID
	event.Implicit = ref.Implicit
	event.ContentIDs = uc.put(ctx, contents, address)
	if !first && sameContentIDs(event.ContentIDs, ref.ContentIDs) {
		return ref
	}
	ref.ContentIDs = event.ContentIDs
	err := uc.repo.Append(ctx, event)
	if err != nil {
		slog.Warn("append course event", "err", err, "address", address)
		return ref
	}
	if uc.observer != nil {
		uc.observer.Appended(event)
	}
	return ref
}

func (uc *recordVisit) resolveOrigin(ctx context.Context, origin Origin) (SessionID, EvaluationID, bool) {
	from := origin.From
	fromSession := SessionID("")
	fromImplicit := false
	if from != "" {
		event, err := uc.repo.Get(ctx, from)
		if err != nil {
			slog.Warn("from names no recorded evaluation", "from", from)
			from = ""
		} else {
			fromSession = event.SessionID
			fromImplicit = event.Implicit
		}
	}
	sessionID := origin.SessionID
	implicit := false
	if sessionID == "" {
		sessionID = fromSession
		implicit = fromImplicit
	}
	if sessionID == "" {
		sessionID = uc.implicitSession(ctx)
		implicit = true
	}
	if from == "" && origin.FromAddress != "" {
		from = uc.resolveFromAddress(ctx, sessionID, origin.FromAddress)
	}
	return sessionID, from, implicit
}

func (uc *recordVisit) resolveFromAddress(ctx context.Context, sessionID SessionID, address Address) EvaluationID {
	event, found, err := uc.repo.LatestAtAddress(ctx, sessionID, address)
	if err != nil || !found {
		return ""
	}
	return event.EvaluationID
}

func (uc *recordVisit) implicitSession(ctx context.Context) SessionID {
	event, found, err := uc.repo.LatestImplicitSession(ctx)
	if err == nil && found && time.Since(event.Timestamp) < implicitSessionIdleGap {
		return event.SessionID
	}
	return SessionID(uuid.Must(uuid.NewV7()).String())
}

func (uc *recordVisit) put(ctx context.Context, contents map[Projection]string, address Address) map[Projection]ContentID {
	stored := make(map[Projection]ContentID, len(contents))
	for projection, content := range contents {
		id, err := uc.blobs.Put(ctx, content)
		if err != nil {
			slog.Warn("store content", "err", err, "address", address, "projection", projection)
			continue
		}
		stored[projection] = id
	}
	return stored
}

func sameContentIDs(left map[Projection]ContentID, right map[Projection]ContentID) bool {
	if len(left) != len(right) {
		return false
	}
	for projection, id := range left {
		if right[projection] != id {
			return false
		}
	}
	return true
}

type getEvaluationContent struct {
	blobs BlobStore
}

func newGetEvaluationContent(blobs BlobStore) *getEvaluationContent {
	return &getEvaluationContent{blobs: blobs}
}

func (uc *getEvaluationContent) Exec(ctx context.Context, event Event, projection Projection) (string, error) {
	id, ok := event.ContentIDs[projection]
	if !ok {
		return "", fmt.Errorf("%w: %s %s", ErrContentNotRecorded, event.Address, projection)
	}
	return uc.blobs.Get(ctx, id)
}
