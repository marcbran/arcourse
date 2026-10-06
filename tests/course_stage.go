//go:build e2e

package tests

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type courseEvaluation struct {
	VisitID   string `json:"visitId"`
	SessionID string `json:"sessionId"`
}

type courseVisit struct {
	Executions []courseVisitExecution `json:"executions"`
	Remarks    []courseVisitRemark    `json:"remarks"`
}

type courseVisitExecution struct {
	ExecutionID string `json:"executionId"`
	From        string `json:"from"`
	Status      string `json:"status"`
}

type courseVisitRemark struct {
	From string `json:"from"`
	Text string `json:"text"`
}

type courseExecution struct {
	SessionID string `json:"sessionId"`
	Status    string `json:"status"`
	Error     string `json:"error"`
	HasOutput bool   `json:"hasOutput"`
}

type courseSession struct {
	Visits []courseSessionVisit `json:"visits"`
}

type courseSessionVisit struct {
	VisitID string `json:"visitId"`
	Remarks int    `json:"remarks"`
}

func (s *Stage) an_execution_is_recorded_for_the_query(status string) *Stage {
	executions := s.executionsOfTheQuery()
	require.Len(s.t, executions, 1)
	assert.Equal(s.t, status, executions[0].Status)
	var execution courseExecution
	s.readCourse(&execution, "execution", executions[0].ExecutionID)
	assert.Equal(s.t, s.evaluationOfTheQuery().SessionID, execution.SessionID)
	s.executionID = executions[0].ExecutionID
	return s
}

func (s *Stage) no_execution_is_recorded_for_the_query() *Stage {
	assert.Empty(s.t, s.executionsOfTheQuery())
	return s
}

func (s *Stage) the_recorded_execution_output_is(expected string) *Stage {
	var output string
	s.readCourse(&output, "output", s.executionID)
	assert.Equal(s.t, expected, output)
	return s
}

func (s *Stage) the_recorded_execution_error_contains(expected string) *Stage {
	var execution courseExecution
	s.readCourse(&execution, "execution", s.executionID)
	assert.Contains(s.t, execution.Error, expected)
	return s
}

func (s *Stage) the_remarks_recorded_for_the_query_are(texts ...string) *Stage {
	evaluation := s.evaluationOfTheQuery()
	var visit courseVisit
	s.readCourse(&visit, "visit", evaluation.VisitID)
	var recorded []string
	for _, remark := range visit.Remarks {
		assert.Equal(s.t, string(s.evaluationID), remark.From)
		recorded = append(recorded, remark.Text)
	}
	assert.ElementsMatch(s.t, texts, recorded)
	var session courseSession
	s.readCourse(&session, "session", evaluation.SessionID)
	for _, summary := range session.Visits {
		if summary.VisitID == evaluation.VisitID {
			assert.Equal(s.t, len(texts), summary.Remarks)
		}
	}
	return s
}

func (s *Stage) executionsOfTheQuery() []courseVisitExecution {
	var visit courseVisit
	s.readCourse(&visit, "visit", s.evaluationOfTheQuery().VisitID)
	executions := []courseVisitExecution{}
	for _, execution := range visit.Executions {
		if execution.From == string(s.evaluationID) {
			executions = append(executions, execution)
		}
	}
	return executions
}

func (s *Stage) evaluationOfTheQuery() courseEvaluation {
	var evaluation courseEvaluation
	s.readCourse(&evaluation, "evaluation", string(s.evaluationID))
	return evaluation
}

func (s *Stage) readCourse(target any, name string, args ...string) {
	encoded, err := json.Marshal(args)
	require.NoError(s.t, err)
	expression := fmt.Sprintf("std.native('invoke:course')(%q, %s)", name, encoded)
	result, err := s.facade.Evaluate(context.Background(), expression)
	require.NoError(s.t, err)
	err = json.Unmarshal([]byte(result.Output), target)
	require.NoError(s.t, err)
}
