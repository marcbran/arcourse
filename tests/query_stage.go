//go:build e2e

package tests

import (
	"context"
	"encoding/json"
	"time"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
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
	result, err := s.facade.Query(context.Background(), path, params, format, s.origin)
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
// so a query that hangs fails fast with a clear error instead of hanging the whole test run.
func (s *Stage) a_path_is_queried_with_format_promptly(path string, format pkg.Format) *Stage {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	result, err := s.facade.Query(ctx, path, nil, format, s.origin)
	if err != nil {
		s.LastOutput = ""
		s.LastError = err.Error()
		return s
	}

	s.LastOutput = result.Output
	s.LastError = ""
	return s
}

func (s *Stage) the_queried_output_has_a_query_id() *Stage {
	s.queryID = queryIDOf(s.t, s.LastOutput)
	assert.NotEmpty(s.t, s.queryID)
	return s
}

func queryIDOf(t require.TestingT, out string) string {
	var doc map[string]json.RawMessage
	err := json.Unmarshal([]byte(out), &doc)
	require.NoError(t, err)
	raw, ok := doc[pkg.QueryIDField]
	require.True(t, ok, "output has no %s", pkg.QueryIDField)
	var id string
	err = json.Unmarshal(raw, &id)
	require.NoError(t, err)
	return id
}
