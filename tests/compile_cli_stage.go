//go:build e2e

package tests

import (
	"bytes"
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/stretchr/testify/require"
)

func (s *CLIStage) the_root_is_compiled_to(outputPath string) *CLIStage {
	cmd := exec.CommandContext(context.Background(), s.binaryPath, "compile", "--output", outputPath)
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

func (s *CLIStage) the_config_uses_dir(dir string) *CLIStage {
	config := "mode: local\nroot:\n  dir: " + dir + "\n  mode: immediateRoot\n"
	err := os.WriteFile(filepath.Join(s.tempDir, "config.yaml"), []byte(config), 0o600)
	require.NoError(s.t, err)
	return s
}
