//go:build e2e

package tests

import (
	"context"
	"time"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
	"github.com/stretchr/testify/require"
)

func (s *Stage) the_path_was_queried(path string) *Stage {
	result, err := s.facade.Query(context.Background(), pkg.NewQueryPath(path), nil, pkg.FormatJSON, s.origin)
	require.NoError(s.t, err)
	s.evaluationID = evaluationIDOf(s.t, result.Output)
	s.recordedOutput = result.Output
	return s
}

func (s *Stage) the_recorded_evaluation_is_reviewed_at(path string, format pkg.Format) *Stage {
	return s.an_evaluation_is_reviewed_at(path, s.evaluationID, format)
}

func (s *Stage) an_evaluation_is_reviewed_at(path string, id pkg.EvaluationID, format pkg.Format) *Stage {
	result, err := s.facade.Review(context.Background(), pkg.NewQueryPath(path), id, format)
	if err != nil {
		s.LastOutput = ""
		s.LastError = err.Error()
		return s
	}
	s.LastOutput = result.Output
	s.LastError = ""
	return s
}

func (s *Stage) the_output_is_the_recorded_query_output() *Stage {
	require.JSONEq(s.t, s.recordedOutput, s.LastOutput)
	return s
}

func (s *Stage) the_watch_has_ended() *Stage {
	select {
	case result, ok := <-s.watchCh:
		require.False(s.t, ok, "expected the watch to end, got another event: %s", result.Output)
	case <-time.After(2 * time.Second):
		require.Fail(s.t, "timed out waiting for the watch to end")
	}
	return s
}
