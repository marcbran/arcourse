//go:build e2e

package tests

import "context"

func (s *Stage) an_expression_is_evaluated(expression string) *Stage {
	result, err := s.facade.Evaluate(context.Background(), expression)
	if err != nil {
		s.LastOutput = ""
		s.LastError = err.Error()
		return s
	}

	s.LastOutput = result.Output
	s.LastError = ""
	return s
}
