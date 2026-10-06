//go:build e2e

package tests

import (
	"context"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

func (s *Stage) the_action_recorded_for_the_query_is_executed() *Stage {
	s.evaluationID = evaluationIDOf(s.t, s.LastOutput)
	return s.the_action_is_executed(s.evaluationID)
}

func (s *Stage) the_action_recorded_for_the_query_is_executed_again() *Stage {
	return s.the_action_is_executed(s.evaluationID)
}

func (s *Stage) an_unknown_action_is_executed() *Stage {
	return s.the_action_is_executed("01a00000-0000-7000-8000-000000000000")
}

func (s *Stage) the_action_is_executed(id pkg.EvaluationID) *Stage {
	result, err := s.facade.Exec(context.Background(), id)
	if err != nil {
		s.LastError = err.Error()
		s.LastOutput = ""
		return s
	}
	s.LastError = ""
	s.LastOutput = result.Output
	return s
}
