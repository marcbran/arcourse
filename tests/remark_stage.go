//go:build e2e

package tests

import (
	"context"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

func (s *Stage) a_remark_is_made_on_the_query(text string) *Stage {
	s.evaluationID = evaluationIDOf(s.t, s.LastOutput)
	return s.a_remark_is_made(s.evaluationID, text)
}

func (s *Stage) a_remark_is_made_on_an_unknown_query(text string) *Stage {
	return s.a_remark_is_made("01a00000-0000-7000-8000-000000000000", text)
}

func (s *Stage) a_remark_is_made(id pkg.EvaluationID, text string) *Stage {
	remarkID, err := s.facade.Remark(context.Background(), id, text)
	if err != nil {
		s.LastError = err.Error()
		s.LastOutput = ""
		return s
	}
	s.LastError = ""
	s.LastOutput = string(remarkID)
	return s
}
