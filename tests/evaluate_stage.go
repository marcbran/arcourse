//go:build e2e

package tests

import (
	"os"
	"path/filepath"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func (s *Stage) a_graph(jsonnet string) *Stage {
	rootFile := filepath.Join(s.tempDir, "root.jsonnet")
	err := os.WriteFile(rootFile, []byte(jsonnet), 0o600)
	require.NoError(s.t, err)
	s.rootFile = rootFile
	return s
}

func (s *Stage) an_expression_is_evaluated(expression string) *Stage {
	result, err := s.facade.Evaluate(s.rootFile, expression)
	if err != nil {
		s.LastOutput = ""
		s.LastError = err.Error()
		return s
	}

	s.LastOutput = result
	s.LastError = ""
	return s
}

func (s *Stage) the_output_is(expected string) *Stage {
	assert.JSONEq(s.t, expected, s.LastOutput)
	return s
}
