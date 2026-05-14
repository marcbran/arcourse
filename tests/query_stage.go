//go:build e2e

package tests

import "context"

func (s *Stage) a_path_is_queried(path string) *Stage {
	result, err := s.facade.Query(context.Background(), path)
	if err != nil {
		s.LastOutput = ""
		s.LastError = err.Error()
		return s
	}

	s.LastOutput = result.Output
	s.LastError = ""
	return s
}
