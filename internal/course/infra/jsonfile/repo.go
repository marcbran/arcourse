package jsonfile

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/marcbran/arcourse/internal/course"
)

const (
	kindEvaluation = "evaluation"
	kindExecution  = "execution"
	kindOutcome    = "outcome"
	kindRemark     = "remark"
)

type line struct {
	Kind            string                                 `json:"kind"`
	EvaluationID    course.EvaluationID                    `json:"evaluationId,omitempty"`
	ExecutionID     course.ExecutionID                     `json:"executionId,omitempty"`
	RemarkID        course.RemarkID                        `json:"remarkId,omitempty"`
	VisitID         course.VisitID                         `json:"visitId,omitempty"`
	SessionID       course.SessionID                       `json:"sessionId,omitempty"`
	Address         course.Address                         `json:"address,omitempty"`
	From            course.EvaluationID                    `json:"from,omitempty"`
	FromExecution   course.ExecutionID                     `json:"fromExecution,omitempty"`
	Implicit        bool                                   `json:"implicit,omitempty"`
	Timestamp       time.Time                              `json:"timestamp"`
	ContentIDs      map[course.Projection]course.ContentID `json:"contentIds,omitempty"`
	OutputContentID course.ContentID                       `json:"outputContentId,omitempty"`
	Error           string                                 `json:"error,omitempty"`
	Text            string                                 `json:"text,omitempty"`
}

type CourseRepo struct {
	dir string
	mu  sync.Mutex
}

func NewCourseRepo(dir string) *CourseRepo {
	return &CourseRepo{dir: dir}
}

func (r *CourseRepo) AppendEvaluation(ctx context.Context, evaluation course.Evaluation) error {
	err := ctx.Err()
	if err != nil {
		return err
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.appendLine(line{
		Kind:          kindEvaluation,
		EvaluationID:  evaluation.EvaluationID,
		VisitID:       evaluation.VisitID,
		SessionID:     evaluation.SessionID,
		Address:       evaluation.Address,
		From:          evaluation.From.Evaluation,
		FromExecution: evaluation.From.Execution,
		Implicit:      evaluation.Implicit,
		Timestamp:     evaluation.Timestamp,
		ContentIDs:    evaluation.ContentIDs,
	})
}

func (r *CourseRepo) AppendExecution(ctx context.Context, execution course.Execution) error {
	err := ctx.Err()
	if err != nil {
		return err
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	log, err := r.load()
	if err != nil {
		return err
	}
	for _, existing := range log.Executions {
		if existing.From == execution.From {
			return fmt.Errorf("%w: %s", course.ErrAlreadyExecuted, execution.From)
		}
	}
	return r.appendLine(line{
		Kind:        kindExecution,
		ExecutionID: execution.ExecutionID,
		From:        execution.From,
		SessionID:   execution.SessionID,
		Implicit:    execution.Implicit,
		Timestamp:   execution.Timestamp,
	})
}

func (r *CourseRepo) AppendOutcome(ctx context.Context, executionID course.ExecutionID, outcome course.Outcome) error {
	err := ctx.Err()
	if err != nil {
		return err
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.appendLine(line{
		Kind:            kindOutcome,
		ExecutionID:     executionID,
		Timestamp:       outcome.Timestamp,
		OutputContentID: outcome.OutputID,
		Error:           outcome.Error,
	})
}

func (r *CourseRepo) AppendRemark(ctx context.Context, remark course.Remark) error {
	err := ctx.Err()
	if err != nil {
		return err
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.appendLine(line{
		Kind:      kindRemark,
		RemarkID:  remark.RemarkID,
		From:      remark.From,
		SessionID: remark.SessionID,
		Implicit:  remark.Implicit,
		Timestamp: remark.Timestamp,
		Text:      remark.Text,
	})
}

func (r *CourseRepo) List(ctx context.Context) (course.Log, error) {
	return r.read(ctx)
}

func (r *CourseRepo) Evaluation(ctx context.Context, evaluationID course.EvaluationID) (course.Evaluation, error) {
	log, err := r.read(ctx)
	if err != nil {
		return course.Evaluation{}, err
	}
	for i := len(log.Evaluations) - 1; i >= 0; i-- {
		if log.Evaluations[i].EvaluationID == evaluationID {
			return log.Evaluations[i], nil
		}
	}
	return course.Evaluation{}, course.ErrEvaluationNotRecorded
}

func (r *CourseRepo) Execution(ctx context.Context, executionID course.ExecutionID) (course.Execution, error) {
	log, err := r.read(ctx)
	if err != nil {
		return course.Execution{}, err
	}
	for _, execution := range log.Executions {
		if execution.ExecutionID == executionID {
			return execution, nil
		}
	}
	return course.Execution{}, course.ErrExecutionNotRecorded
}

func (r *CourseRepo) ListSession(ctx context.Context, sessionID course.SessionID) (course.Log, error) {
	log, err := r.read(ctx)
	if err != nil {
		return course.Log{}, err
	}
	var result course.Log
	for _, evaluation := range log.Evaluations {
		if evaluation.SessionID == sessionID {
			result.Evaluations = append(result.Evaluations, evaluation)
		}
	}
	for _, execution := range log.Executions {
		if execution.SessionID == sessionID {
			result.Executions = append(result.Executions, execution)
		}
	}
	for _, remark := range log.Remarks {
		if remark.SessionID == sessionID {
			result.Remarks = append(result.Remarks, remark)
		}
	}
	return result, nil
}

func (r *CourseRepo) ListVisit(ctx context.Context, visitID course.VisitID) (course.Log, error) {
	log, err := r.read(ctx)
	if err != nil {
		return course.Log{}, err
	}
	var result course.Log
	evaluations := map[course.EvaluationID]bool{}
	for _, evaluation := range log.Evaluations {
		if evaluation.VisitID == visitID {
			result.Evaluations = append(result.Evaluations, evaluation)
			evaluations[evaluation.EvaluationID] = true
		}
	}
	for _, execution := range log.Executions {
		if evaluations[execution.From] {
			result.Executions = append(result.Executions, execution)
		}
	}
	for _, remark := range log.Remarks {
		if evaluations[remark.From] {
			result.Remarks = append(result.Remarks, remark)
		}
	}
	return result, nil
}

func (r *CourseRepo) LatestAtAddress(ctx context.Context, sessionID course.SessionID, address course.Address) (course.Evaluation, bool, error) {
	log, err := r.read(ctx)
	if err != nil {
		return course.Evaluation{}, false, err
	}
	for i := len(log.Evaluations) - 1; i >= 0; i-- {
		evaluation := log.Evaluations[i]
		if evaluation.SessionID == sessionID && evaluation.Address == address {
			return evaluation, true, nil
		}
	}
	return course.Evaluation{}, false, nil
}

func (r *CourseRepo) LatestImplicitActivity(ctx context.Context) (course.SessionID, time.Time, bool, error) {
	log, err := r.read(ctx)
	if err != nil {
		return "", time.Time{}, false, err
	}
	var sessionID course.SessionID
	var at time.Time
	found := false
	observe := func(candidate course.SessionID, timestamp time.Time) {
		if !found || timestamp.After(at) {
			sessionID = candidate
			at = timestamp
			found = true
		}
	}
	for _, evaluation := range log.Evaluations {
		if evaluation.Implicit {
			observe(evaluation.SessionID, evaluation.Timestamp)
		}
	}
	for _, execution := range log.Executions {
		if execution.Implicit {
			observe(execution.SessionID, execution.Timestamp)
		}
	}
	for _, remark := range log.Remarks {
		if remark.Implicit {
			observe(remark.SessionID, remark.Timestamp)
		}
	}
	return sessionID, at, found, nil
}

func (r *CourseRepo) read(ctx context.Context) (course.Log, error) {
	err := ctx.Err()
	if err != nil {
		return course.Log{}, err
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.load()
}

func (r *CourseRepo) load() (course.Log, error) {
	lines, err := r.readLines()
	if err != nil {
		return course.Log{}, err
	}
	var log course.Log
	executionIndex := map[course.ExecutionID]int{}
	for _, raw := range lines {
		var entry line
		err = json.Unmarshal(raw, &entry)
		if err != nil {
			return course.Log{}, err
		}
		switch entry.Kind {
		case "", kindEvaluation:
			log.Evaluations = append(log.Evaluations, course.Evaluation{
				EvaluationID: entry.EvaluationID,
				VisitID:      entry.VisitID,
				SessionID:    entry.SessionID,
				Address:      entry.Address,
				From:         course.From{Evaluation: entry.From, Execution: entry.FromExecution},
				Implicit:     entry.Implicit,
				Timestamp:    entry.Timestamp,
				ContentIDs:   entry.ContentIDs,
			})
		case kindExecution:
			executionIndex[entry.ExecutionID] = len(log.Executions)
			log.Executions = append(log.Executions, course.Execution{
				ExecutionID: entry.ExecutionID,
				From:        entry.From,
				SessionID:   entry.SessionID,
				Implicit:    entry.Implicit,
				Timestamp:   entry.Timestamp,
			})
		case kindRemark:
			log.Remarks = append(log.Remarks, course.Remark{
				RemarkID:  entry.RemarkID,
				From:      entry.From,
				SessionID: entry.SessionID,
				Implicit:  entry.Implicit,
				Timestamp: entry.Timestamp,
				Text:      entry.Text,
			})
		case kindOutcome:
			i, ok := executionIndex[entry.ExecutionID]
			if !ok {
				continue
			}
			log.Executions[i].Outcome = &course.Outcome{
				Timestamp: entry.Timestamp,
				OutputID:  entry.OutputContentID,
				Error:     entry.Error,
			}
		}
	}
	return log, nil
}

func (r *CourseRepo) appendLine(entry line) error {
	encoded, err := json.Marshal(entry)
	if err != nil {
		return err
	}
	err = os.MkdirAll(r.dir, 0o755)
	if err != nil {
		return err
	}
	file, err := os.OpenFile(r.eventsPath(), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	defer func() {
		_ = file.Close()
	}()
	_, err = file.Write(append(encoded, '\n'))
	return err
}

func (r *CourseRepo) readLines() ([][]byte, error) {
	file, err := os.Open(r.eventsPath())
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return nil, nil
		}
		return nil, err
	}
	defer func() {
		_ = file.Close()
	}()
	var lines [][]byte
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 0, 64*1024), 4*1024*1024)
	for scanner.Scan() {
		raw := scanner.Bytes()
		if len(raw) == 0 {
			continue
		}
		lines = append(lines, append([]byte(nil), raw...))
	}
	err = scanner.Err()
	if err != nil {
		return nil, err
	}
	return lines, nil
}

func (r *CourseRepo) eventsPath() string {
	return filepath.Join(r.dir, "events.jsonl")
}
