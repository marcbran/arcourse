//go:build e2e

package tests

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type Stage struct {
	t require.TestingT

	facade  pkg.Facade
	tempDir string

	observeCh          <-chan pkg.Result
	observeUnsubscribe func()

	LastOutput string
	LastError  string
}

func scenario(t *testing.T) (*Stage, *Stage, *Stage) {
	tempDir := t.TempDir()
	facade, err := NewE2EFacade(t, tempDir)
	require.NoError(t, err)
	s := &Stage{
		t:       t,
		facade:  facade,
		tempDir: tempDir,
	}
	return s, s, s
}

func (s *Stage) and() *Stage {
	return s
}

func (s *Stage) a_graph_root(jsonnet string) *Stage {
	err := os.WriteFile(filepath.Join(s.tempDir, "root.jsonnet"), []byte(jsonnet), 0o600)
	require.NoError(s.t, err)
	return s
}

func (s *Stage) a_node_graph(jsonnet string) *Stage {
	err := os.WriteFile(filepath.Join(s.tempDir, "graph.jsonnet"), []byte(jsonnet), 0o600)
	require.NoError(s.t, err)
	return s
}

func (s *Stage) the_output_is(expected string) *Stage {
	assert.JSONEq(s.t, expected, s.LastOutput)
	return s
}

func (s *Stage) the_raw_output_is(expected string) *Stage {
	assert.Equal(s.t, expected, strings.TrimSpace(s.LastOutput))
	return s
}

func (s *Stage) the_error_contains(expected string) *Stage {
	assert.Contains(s.t, s.LastError, expected)
	return s
}
