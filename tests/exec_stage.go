//go:build e2e

package tests

import (
	"context"
)

func (s *Stage) the_action_recorded_by_the_audit_entry_is_executed() *Stage {
	result, err := s.facade.Exec(context.Background(), s.auditEntry.ID)
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
