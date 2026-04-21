//go:build e2e

package tests

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type CLIFacade struct {
	binaryPath string
	homeDir    string
}

func NewCLIFacade(homeDir string) (*CLIFacade, error) {
	binaryPath := os.Getenv("ARCO_BINARY")
	if binaryPath == "" {
		return nil, fmt.Errorf("ARCO_BINARY is required")
	}
	return NewCLIFacadeWithPath(binaryPath, homeDir)
}

func NewCLIFacadeWithPath(binaryPath, homeDir string) (*CLIFacade, error) {
	_, err := os.Stat(binaryPath)
	if err != nil {
		return nil, fmt.Errorf("unable to access ARCO_BINARY %q: %w", binaryPath, err)
	}
	config := "mode: local\nevaluate: {}\n"
	err = os.WriteFile(filepath.Join(homeDir, "config.yaml"), []byte(config), 0o600)
	if err != nil {
		return nil, err
	}
	return &CLIFacade{binaryPath: binaryPath, homeDir: homeDir}, nil
}

type commandOutput struct {
	Output string `json:"output"`
}

func (f *CLIFacade) Evaluate(ctx context.Context, expression string) (pkg.Result, error) {
	cmd := exec.CommandContext(ctx, f.binaryPath, "eval", expression, "--format", "json")
	cmd.Env = append(os.Environ(), "ARCOURSE_HOME="+f.homeDir)

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	if err != nil {
		if stderr.String() != "" {
			return pkg.Result{}, errors.New(stderr.String())
		}
		return pkg.Result{}, err
	}

	var output commandOutput
	err = json.Unmarshal(stdout.Bytes(), &output)
	if err != nil {
		return pkg.Result{}, err
	}

	return pkg.Result{Output: output.Output}, nil
}

func (f *CLIFacade) Render(ctx context.Context, path []string, format pkg.Format) (pkg.Result, error) {
	cmd := exec.CommandContext(ctx, f.binaryPath, "render", strings.Join(path, "."), "--format", string(format))
	cmd.Env = append(os.Environ(), "ARCOURSE_HOME="+f.homeDir)

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	if err != nil {
		if stderr.String() != "" {
			return pkg.Result{}, errors.New(stderr.String())
		}
		return pkg.Result{}, err
	}

	return pkg.Result{Output: strings.TrimSuffix(stdout.String(), "\n")}, nil
}
