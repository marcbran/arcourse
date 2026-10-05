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
	ErrExecutionNotRecorded  = errors.New("execution not recorded")
	ErrContentNotRecorded    = errors.New("evaluation has no content recorded")
	ErrOutputNotRecorded     = errors.New("execution has no output recorded")
	ErrAlreadyExecuted       = errors.New("evaluation already executed")
)

type SessionID string

type VisitID string

type EvaluationID string

type ExecutionID string

type EntryID string

type ContentID string

type Projection string

type Address string

func (a Address) String() string {
	return string(a)
}

type Origin struct {
	SessionID   SessionID
	From        EntryID
	FromAddress Address
}

type From struct {
	Evaluation EvaluationID
	Execution  ExecutionID
}

func (f From) IsZero() bool {
	return f.Evaluation == "" && f.Execution == ""
}

type Evaluation struct {
	EvaluationID EvaluationID
	VisitID      VisitID
	SessionID    SessionID
	Address      Address
	From         From
	Implicit     bool
	Timestamp    time.Time
	ContentIDs   map[Projection]ContentID
}

type ExecutionStatus string

const (
	ExecutionUnknown   ExecutionStatus = "unknown"
	ExecutionSucceeded ExecutionStatus = "succeeded"
	ExecutionFailed    ExecutionStatus = "failed"
)

type Execution struct {
	ExecutionID ExecutionID
	From        EvaluationID
	SessionID   SessionID
	Implicit    bool
	Timestamp   time.Time
	Outcome     *Outcome
}

func (e Execution) Status() ExecutionStatus {
	if e.Outcome == nil {
		return ExecutionUnknown
	}
	if e.Outcome.Error != "" {
		return ExecutionFailed
	}
	return ExecutionSucceeded
}

type Outcome struct {
	Timestamp time.Time
	OutputID  ContentID
	Error     string
}

type Log struct {
	Evaluations []Evaluation
	Executions  []Execution
}

type VisitRef struct {
	VisitID    VisitID
	SessionID  SessionID
	Implicit   bool
	ContentIDs map[Projection]ContentID
}

type Change struct {
	SessionID   SessionID
	VisitID     VisitID
	ExecutionID ExecutionID
}

type Repo interface {
	AppendEvaluation(ctx context.Context, evaluation Evaluation) error
	AppendExecution(ctx context.Context, execution Execution) error
	AppendOutcome(ctx context.Context, executionID ExecutionID, outcome Outcome) error
	List(ctx context.Context) (Log, error)
	Evaluation(ctx context.Context, evaluationID EvaluationID) (Evaluation, error)
	Execution(ctx context.Context, executionID ExecutionID) (Execution, error)
	ListSession(ctx context.Context, sessionID SessionID) (Log, error)
	ListVisit(ctx context.Context, visitID VisitID) (Log, error)
	LatestAtAddress(ctx context.Context, sessionID SessionID, address Address) (Evaluation, bool, error)
	LatestImplicitActivity(ctx context.Context) (SessionID, time.Time, bool, error)
}

type Observer interface {
	Changed(change Change)
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

func newRecordVisit(repo Repo, blobs BlobStore) *recordVisit {
	return &recordVisit{repo: repo, blobs: blobs}
}

func (uc *recordVisit) Exec(ctx context.Context, ref VisitRef, evaluationID EvaluationID, address Address, contents map[Projection]string, origin Origin) VisitRef {
	evaluation := Evaluation{EvaluationID: evaluationID, Address: address, Timestamp: time.Now()}
	first := ref.VisitID == ""
	if first {
		sessionID, from, implicit := uc.resolveOrigin(ctx, origin)
		ref = VisitRef{VisitID: VisitID(uuid.Must(uuid.NewV7()).String()), SessionID: sessionID, Implicit: implicit}
		evaluation.From = from
	}
	evaluation.VisitID = ref.VisitID
	evaluation.SessionID = ref.SessionID
	evaluation.Implicit = ref.Implicit
	evaluation.ContentIDs = uc.put(ctx, contents, address)
	if !first && sameContentIDs(evaluation.ContentIDs, ref.ContentIDs) {
		return ref
	}
	ref.ContentIDs = evaluation.ContentIDs
	err := uc.repo.AppendEvaluation(ctx, evaluation)
	if err != nil {
		slog.Warn("append course evaluation", "err", err, "address", address)
		return ref
	}
	notify(uc.observer, Change{SessionID: evaluation.SessionID, VisitID: evaluation.VisitID})
	return ref
}

func (uc *recordVisit) resolveOrigin(ctx context.Context, origin Origin) (SessionID, From, bool) {
	from, fromSession, fromImplicit := uc.resolveFrom(ctx, origin.From)
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
	if from.IsZero() && origin.FromAddress != "" {
		from = From{Evaluation: uc.resolveFromAddress(ctx, sessionID, origin.FromAddress)}
	}
	return sessionID, from, implicit
}

func (uc *recordVisit) resolveFrom(ctx context.Context, id EntryID) (From, SessionID, bool) {
	if id == "" {
		return From{}, "", false
	}
	evaluation, err := uc.repo.Evaluation(ctx, EvaluationID(id))
	if err == nil {
		return From{Evaluation: evaluation.EvaluationID}, evaluation.SessionID, evaluation.Implicit
	}
	execution, err := uc.repo.Execution(ctx, ExecutionID(id))
	if err == nil {
		return From{Execution: execution.ExecutionID}, execution.SessionID, execution.Implicit
	}
	slog.Warn("from names no recorded evaluation or execution", "from", id)
	return From{}, "", false
}

func (uc *recordVisit) resolveFromAddress(ctx context.Context, sessionID SessionID, address Address) EvaluationID {
	evaluation, found, err := uc.repo.LatestAtAddress(ctx, sessionID, address)
	if err != nil || !found {
		return ""
	}
	return evaluation.EvaluationID
}

func (uc *recordVisit) implicitSession(ctx context.Context) SessionID {
	sessionID, at, found, err := uc.repo.LatestImplicitActivity(ctx)
	if err == nil && found && time.Since(at) < implicitSessionIdleGap {
		return sessionID
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

type startExecution struct {
	repo     Repo
	observer Observer
}

func newStartExecution(repo Repo) *startExecution {
	return &startExecution{repo: repo}
}

func (uc *startExecution) Exec(ctx context.Context, from Evaluation) (Execution, error) {
	execution := Execution{
		ExecutionID: ExecutionID(uuid.Must(uuid.NewV7()).String()),
		From:        from.EvaluationID,
		SessionID:   from.SessionID,
		Implicit:    from.Implicit,
		Timestamp:   time.Now(),
	}
	err := uc.repo.AppendExecution(ctx, execution)
	if err != nil {
		return Execution{}, err
	}
	notify(uc.observer, Change{SessionID: execution.SessionID, VisitID: from.VisitID, ExecutionID: execution.ExecutionID})
	return execution, nil
}

type finishExecution struct {
	repo     Repo
	blobs    BlobStore
	observer Observer
}

func newFinishExecution(repo Repo, blobs BlobStore) *finishExecution {
	return &finishExecution{repo: repo, blobs: blobs}
}

func (uc *finishExecution) Exec(ctx context.Context, execution Execution, output string, failure error) error {
	outcome := Outcome{Timestamp: time.Now()}
	if output != "" {
		id, err := uc.blobs.Put(ctx, output)
		if err != nil {
			return err
		}
		outcome.OutputID = id
	}
	if failure != nil {
		outcome.Error = failure.Error()
	}
	err := uc.repo.AppendOutcome(ctx, execution.ExecutionID, outcome)
	if err != nil {
		return err
	}
	change := Change{SessionID: execution.SessionID, ExecutionID: execution.ExecutionID}
	from, err := uc.repo.Evaluation(ctx, execution.From)
	if err == nil {
		change.VisitID = from.VisitID
	}
	notify(uc.observer, change)
	return nil
}

func notify(observer Observer, change Change) {
	if observer == nil {
		return
	}
	observer.Changed(change)
}

type getEvaluationContent struct {
	blobs BlobStore
}

func newGetEvaluationContent(blobs BlobStore) *getEvaluationContent {
	return &getEvaluationContent{blobs: blobs}
}

func (uc *getEvaluationContent) Exec(ctx context.Context, evaluation Evaluation, projection Projection) (string, error) {
	id, ok := evaluation.ContentIDs[projection]
	if !ok {
		return "", fmt.Errorf("%w: %s %s", ErrContentNotRecorded, evaluation.Address, projection)
	}
	return uc.blobs.Get(ctx, id)
}

type getExecutionOutput struct {
	blobs BlobStore
}

func newGetExecutionOutput(blobs BlobStore) *getExecutionOutput {
	return &getExecutionOutput{blobs: blobs}
}

func (uc *getExecutionOutput) Exec(ctx context.Context, execution Execution) (string, error) {
	if execution.Outcome == nil || execution.Outcome.OutputID == "" {
		return "", fmt.Errorf("%w: %s", ErrOutputNotRecorded, execution.ExecutionID)
	}
	return uc.blobs.Get(ctx, execution.Outcome.OutputID)
}
