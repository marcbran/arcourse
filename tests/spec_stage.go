//go:build e2e

package tests

import (
	"testing"

	"github.com/stretchr/testify/require"
)

type Stage struct {
	t require.TestingT

	facade   Facade
	rootFile string
	tempDir  string

	LastOutput string
	LastError  string
}

func scenario(t *testing.T) (*Stage, *Stage, *Stage) {
	tempDir := t.TempDir()
	facade, err := NewCLIFacade()
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
