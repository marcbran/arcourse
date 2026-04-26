//go:build e2e

package tests

import (
	"bytes"
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type CLIStage struct {
	t require.TestingT

	binaryPath string
	tempDir    string

	LastOutput string
	LastError  string
}

func cli_scenario(t *testing.T) (*CLIStage, *CLIStage, *CLIStage) {
	tempDir := t.TempDir()
	binaryPath := os.Getenv("ARCO_BINARY")
	require.NotEmpty(t, binaryPath, "ARCO_BINARY is required")
	_, err := os.Stat(binaryPath)
	require.NoError(t, err, "unable to access ARCO_BINARY %q", binaryPath)

	config := "mode: local\nevaluate: {}\n"
	err = os.WriteFile(filepath.Join(tempDir, "config.yaml"), []byte(config), 0o600)
	require.NoError(t, err)

	s := &CLIStage{
		t:          t,
		binaryPath: binaryPath,
		tempDir:    tempDir,
	}
	return s, s, s
}

func (s *CLIStage) and() *CLIStage {
	return s
}

func (s *CLIStage) a_graph_root(jsonnet string) *CLIStage {
	err := os.WriteFile(filepath.Join(s.tempDir, "root.jsonnet"), []byte(jsonnet), 0o600)
	require.NoError(s.t, err)
	return s
}

func (s *CLIStage) a_path_is_rendered_to_output_file(path []string, format pkg.Format, outputPath string) *CLIStage {
	cmd := exec.CommandContext(
		context.Background(),
		s.binaryPath,
		"render",
		strings.Join(path, "."),
		"--format",
		string(format),
		"--output",
		outputPath,
	)
	cmd.Env = append(os.Environ(), "ARCOURSE_HOME="+s.tempDir)

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	if err != nil {
		s.LastOutput = ""
		if stderr.String() != "" {
			s.LastError = stderr.String()
		} else {
			s.LastError = err.Error()
		}
		return s
	}

	s.LastOutput = strings.TrimSuffix(stdout.String(), "\n")
	s.LastError = ""
	return s
}

func (s *CLIStage) the_raw_output_is(expected string) *CLIStage {
	assert.Equal(s.t, expected, strings.TrimSpace(s.LastOutput))
	return s
}

func (s *CLIStage) the_file_contains(path string, expected string) *CLIStage {
	content, err := os.ReadFile(path)
	require.NoError(s.t, err, "expected file %q to exist", path)
	assert.Equal(s.t, expected, string(content))
	return s
}
