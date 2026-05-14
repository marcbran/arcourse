//go:build e2e

package tests

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"testing"
	"time"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type CLIFacade struct {
	binaryPath string
	homeDir    string
}

func NewE2EFacade(t *testing.T, homeDir string) (pkg.Facade, error) {
	binaryPath := os.Getenv("ARCO_BINARY")
	if binaryPath == "" {
		return nil, fmt.Errorf("ARCO_BINARY is required")
	}
	switch os.Getenv("ARCOURSE_E2E_FACADE") {
	case "", "local-cli":
		return NewLocalCLIFacadeWithPath(binaryPath, homeDir)
	case "tcp-client-cli":
		return NewTCPClientCLIFacade(t, binaryPath, homeDir)
	case "unix-client-cli":
		return NewUnixClientCLIFacade(t, binaryPath, homeDir)
	default:
		return nil, fmt.Errorf("invalid ARCOURSE_E2E_FACADE %q", os.Getenv("ARCOURSE_E2E_FACADE"))
	}
}

func NewLocalCLIFacadeWithPath(binaryPath, homeDir string) (*CLIFacade, error) {
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

func NewTCPClientCLIFacade(t *testing.T, binaryPath, serverHome string) (*ServerBackedCLIFacade, error) {
	port, err := freePort()
	if err != nil {
		return nil, err
	}
	clientHome := t.TempDir()
	err = writeConfig(serverHome, fmt.Sprintf("mode: local\nhttp:\n  hostname: localhost\n  port: %q\nevaluate: {}\n", port))
	if err != nil {
		return nil, err
	}
	err = writeConfig(clientHome, fmt.Sprintf("mode: client\nhttp:\n  hostname: localhost\n  port: %q\n", port))
	if err != nil {
		return nil, err
	}
	return newServerBackedCLIFacade(t, binaryPath, serverHome, clientHome, func(ctx context.Context) error {
		return waitForDial(ctx, "tcp", net.JoinHostPort("localhost", port))
	}), nil
}

func NewUnixClientCLIFacade(t *testing.T, binaryPath, serverHome string) (*ServerBackedCLIFacade, error) {
	socketPath, err := shortSocketPath(t)
	if err != nil {
		return nil, err
	}
	clientHome := t.TempDir()
	err = writeConfig(serverHome, fmt.Sprintf("mode: local\nhttp:\n  hostname: localhost\n  port: %q\n  unixSocket: %q\nevaluate: {}\n", "0", socketPath))
	if err != nil {
		return nil, err
	}
	err = writeConfig(clientHome, fmt.Sprintf("mode: client\nhttp:\n  unixSocket: %q\n", socketPath))
	if err != nil {
		return nil, err
	}
	return newServerBackedCLIFacade(t, binaryPath, serverHome, clientHome, func(ctx context.Context) error {
		return waitForDial(ctx, "unix", socketPath)
	}), nil
}

type ServerBackedCLIFacade struct {
	serverBinaryPath string
	serverHomeDir    string
	client           *CLIFacade
	cmd              *exec.Cmd
	waitReady        func(context.Context) error
	startOnce        sync.Once
	startErr         error
}

func newServerBackedCLIFacade(t *testing.T, binaryPath, serverHome, clientHome string, waitReady func(context.Context) error) *ServerBackedCLIFacade {
	f := &ServerBackedCLIFacade{
		serverBinaryPath: binaryPath,
		serverHomeDir:    serverHome,
		client:           &CLIFacade{binaryPath: binaryPath, homeDir: clientHome},
		waitReady:        waitReady,
	}
	t.Cleanup(func() {
		f.stop()
	})
	return f
}

func (f *ServerBackedCLIFacade) Evaluate(ctx context.Context, expression string) (pkg.Result, error) {
	err := f.start()
	if err != nil {
		return pkg.Result{}, err
	}
	return f.client.Evaluate(ctx, expression)
}

func (f *ServerBackedCLIFacade) Render(ctx context.Context, path string, format pkg.Format) (pkg.Result, error) {
	err := f.start()
	if err != nil {
		return pkg.Result{}, err
	}
	return f.client.Render(ctx, path, format)
}

func (f *ServerBackedCLIFacade) start() error {
	f.startOnce.Do(func() {
		f.startErr = f.startServer()
	})
	return f.startErr
}

func (f *ServerBackedCLIFacade) startServer() error {
	cmd := exec.CommandContext(context.Background(), f.serverBinaryPath, "serve")
	cmd.Env = append(os.Environ(), "ARCOURSE_HOME="+f.serverHomeDir)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	err := cmd.Start()
	if err != nil {
		return err
	}
	f.cmd = cmd

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	err = f.waitReady(ctx)
	if err != nil {
		f.stop()
		if stderr.String() != "" {
			return fmt.Errorf("%w: %s", err, stderr.String())
		}
		return err
	}
	return nil
}

func (f *ServerBackedCLIFacade) stop() {
	if f.cmd == nil || f.cmd.Process == nil {
		return
	}
	_ = f.cmd.Process.Signal(syscall.SIGTERM)
	_ = f.cmd.Wait()
	f.cmd = nil
}

func writeConfig(home string, content string) error {
	return os.WriteFile(filepath.Join(home, "config.yaml"), []byte(content), 0o600)
}

func freePort() (string, error) {
	listener, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		return "", err
	}
	defer func() {
		_ = listener.Close()
	}()
	_, port, err := net.SplitHostPort(listener.Addr().String())
	if err != nil {
		return "", err
	}
	return port, nil
}

func shortSocketPath(t *testing.T) (string, error) {
	dir, err := os.MkdirTemp("/tmp", "arco-*")
	if err != nil {
		return "", err
	}
	t.Cleanup(func() {
		_ = os.RemoveAll(dir)
	})
	return filepath.Join(dir, "a.sock"), nil
}

func waitForDial(ctx context.Context, network string, address string) error {
	var lastErr error
	for {
		var d net.Dialer
		conn, err := d.DialContext(ctx, network, address)
		if err == nil {
			_ = conn.Close()
			return nil
		}
		lastErr = err

		select {
		case <-ctx.Done():
			return fmt.Errorf("server did not become ready: %w", lastErr)
		case <-time.After(25 * time.Millisecond):
		}
	}
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

func (f *CLIFacade) Render(ctx context.Context, path string, format pkg.Format) (pkg.Result, error) {
	cmd := exec.CommandContext(ctx, f.binaryPath, "render", path, "--format", string(format))
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
