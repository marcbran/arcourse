//go:build e2e

package tests

import (
	"context"
	"time"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

func (s *Stage) a_path_is_queried(path string) *Stage {
	return s.a_path_is_queried_with_params(path, nil)
}

func (s *Stage) a_path_is_queried_with_params(path string, params map[string]any) *Stage {
	return s.a_path_is_queried_with_params_and_format(path, params, pkg.FormatJSON)
}

func (s *Stage) a_path_is_queried_with_format(path string, format pkg.Format) *Stage {
	return s.a_path_is_queried_with_params_and_format(path, nil, format)
}

func (s *Stage) a_path_is_queried_with_params_and_format(path string, params map[string]any, format pkg.Format) *Stage {
	result, err := s.facade.Query(context.Background(), path, params, format)
	if err != nil {
		s.LastOutput = ""
		s.LastError = err.Error()
		return s
	}

	s.LastOutput = result.Output
	s.LastError = ""
	return s
}

// a_path_is_queried_with_format_promptly queries with a bounded deadline,
// so a query that hangs (e.g. because publishing to an observer blocked)
// fails fast with a clear error instead of hanging the whole test run.
func (s *Stage) a_path_is_queried_with_format_promptly(path string, format pkg.Format) *Stage {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	result, err := s.facade.Query(ctx, path, nil, format)
	if err != nil {
		s.LastOutput = ""
		s.LastError = err.Error()
		return s
	}

	s.LastOutput = result.Output
	s.LastError = ""
	return s
}
