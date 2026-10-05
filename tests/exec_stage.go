//go:build e2e

package tests

import (
	"context"
)

func (s *Stage) the_action_recorded_for_the_query_is_executed() *Stage {
	result, err := s.facade.Exec(context.Background(), evaluationIDOf(s.t, s.LastOutput))
	if err != nil {
		s.LastError = err.Error()
		s.LastOutput = ""
		return s
	}
	s.LastError = ""
	s.LastOutput = result.Output
	return s
}

func (s *Stage) an_unknown_action_is_executed() *Stage {
	result, err := s.facade.Exec(context.Background(), "01a00000-0000-7000-8000-000000000000")
	if err != nil {
		s.LastError = err.Error()
		s.LastOutput = ""
		return s
	}
	s.LastError = ""
	s.LastOutput = result.Output
	return s
}
