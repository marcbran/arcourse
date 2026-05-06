package server

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	archttp "github.com/marcbran/arcourse/internal/http"
	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type Server struct {
	facade pkg.Facade
	mux    *http.ServeMux
}

func NewServer(facade pkg.Facade) *Server {
	s := &Server{facade: facade, mux: http.NewServeMux()}
	s.mux.HandleFunc("POST /api/evaluate", s.handleEvaluate)
	s.mux.HandleFunc("POST /api/render", s.handleRender)
	s.mux.HandleFunc("GET /{path...}", s.handleBrowse)
	return s
}

func Serve(ctx context.Context, facade pkg.Facade, cfg archttp.Config) error {
	listeners, err := listen(cfg)
	if err != nil {
		return err
	}
	defer func() {
		for _, listener := range listeners {
			_ = listener.Close()
			if listener.Addr().Network() == "unix" {
				_ = os.Remove(listener.Addr().String())
			}
		}
	}()

	srv := NewServer(facade)
	httpServer := &http.Server{
		Handler: srv.mux,
	}

	errs := make(chan error, len(listeners))
	for _, listener := range listeners {
		go func() {
			slog.Info("http server listening", "network", listener.Addr().Network(), "addr", listener.Addr().String())
			err := httpServer.Serve(listener)
			if err != nil && !errors.Is(err, http.ErrServerClosed) {
				errs <- err
			}
		}()
	}

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	defer signal.Stop(quit)

	select {
	case <-quit:
		slog.Info("shutting down http server")
	case <-ctx.Done():
		slog.Info("context done, shutting down http server")
	case err := <-errs:
		return err
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	return httpServer.Shutdown(shutdownCtx)
}

func listen(cfg archttp.Config) ([]net.Listener, error) {
	port := cfg.Port
	if port == "" {
		port = "8080"
	}
	addr := net.JoinHostPort(cfg.Hostname, port)

	tcpListener, err := net.Listen("tcp", addr)
	if err != nil {
		return nil, err
	}
	listeners := []net.Listener{tcpListener}

	if cfg.UnixSocket != "" {
		unixListener, err := listenUnix(cfg.UnixSocket)
		if err != nil {
			for _, listener := range listeners {
				_ = listener.Close()
			}
			return nil, err
		}
		listeners = append(listeners, unixListener)
	}

	return listeners, nil
}

func listenUnix(path string) (net.Listener, error) {
	err := prepareUnixSocket(path)
	if err != nil {
		return nil, err
	}
	listener, err := net.Listen("unix", path)
	if err != nil {
		return nil, err
	}
	return listener, nil
}

func prepareUnixSocket(path string) error {
	info, err := os.Lstat(path)
	if err != nil {
		if os.IsNotExist(err) {
			return os.MkdirAll(filepath.Dir(path), 0o755)
		}
		return err
	}
	if info.Mode()&os.ModeSocket == 0 {
		return fmt.Errorf("unix socket path exists and is not a socket: %s", path)
	}

	conn, err := net.DialTimeout("unix", path, 100*time.Millisecond)
	if err == nil {
		_ = conn.Close()
		return fmt.Errorf("unix socket is already in use: %s", path)
	}
	if !errors.Is(err, syscall.ECONNREFUSED) {
		return fmt.Errorf("unix socket exists but could not be checked: %w", err)
	}
	return os.Remove(path)
}
