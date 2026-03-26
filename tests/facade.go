//go:build e2e

package tests

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
)

type Facade interface {
	Evaluate(root string, expression string) (string, error)
}

type CLIFacade struct {
	binaryPath string
}

func NewCLIFacade() (*CLIFacade, error) {
	binaryPath := os.Getenv("ARCO_BINARY")
	if binaryPath == "" {
		return nil, fmt.Errorf("ARCO_BINARY is required")
	}
	return NewCLIFacadeWithPath(binaryPath)
}

func NewCLIFacadeWithPath(binaryPath string) (*CLIFacade, error) {
	_, err := os.Stat(binaryPath)
	if err != nil {
		return nil, fmt.Errorf("unable to access ARCO_BINARY %q: %w", binaryPath, err)
	}
	return &CLIFacade{binaryPath: binaryPath}, nil
}

type commandOutput struct {
	Output string `json:"output"`
}

func (f *CLIFacade) Evaluate(root string, expression string) (string, error) {
	tempDir, err := os.MkdirTemp("", "arcourse-e2e-*")
	if err != nil {
		return "", err
	}
	defer os.RemoveAll(tempDir)

	config := "evaluate:\n  root: " + root + "\n"
	err = os.WriteFile(tempDir+"/config.yaml", []byte(config), 0o600)
	if err != nil {
		return "", err
	}

	cmd := exec.Command(f.binaryPath, expression, "--format", "json")
	cmd.Env = append(os.Environ(), "ARCOURSE_HOME="+tempDir)

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err = cmd.Run()
	if err != nil {
		if stderr.String() != "" {
			return "", errors.New(stderr.String())
		}
		return "", err
	}

	var output commandOutput
	err = json.Unmarshal(stdout.Bytes(), &output)
	if err != nil {
		return "", err
	}

	return output.Output, nil
}
