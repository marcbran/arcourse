//go:build e2e

package tests

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func plugin_scenario(t *testing.T) (*Stage, *Stage, *Stage) {
	tempDir := t.TempDir()
	binaryPath, err := buildPluginBinary(tempDir)
	require.NoError(t, err)
	facade, err := NewCLIFacadeWithPath(binaryPath, tempDir)
	require.NoError(t, err)
	s := &Stage{
		t:       t,
		facade:  facade,
		tempDir: tempDir,
	}
	return s, s, s
}

func buildPluginBinary(outputDir string) (string, error) {
	exampleDir := filepath.Join("..", "examples", "plugin-binary")
	_, err := os.Stat(exampleDir)
	if err != nil {
		return "", err
	}
	binaryPath := filepath.Join(outputDir, "arco-plugin")
	cmd := exec.Command("go", "build", "-o", binaryPath, ".")
	cmd.Dir = exampleDir
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	err = cmd.Run()
	if err != nil {
		if stderr.String() != "" {
			return "", fmt.Errorf("failed to build plugin binary: %s", stderr.String())
		}
		return "", err
	}
	return binaryPath, nil
}
