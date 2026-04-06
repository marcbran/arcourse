package server

import (
	"context"
	"errors"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
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
	port := cfg.Port
	if port == "" {
		port = "8080"
	}
	addr := net.JoinHostPort(cfg.Hostname, port)

	srv := NewServer(facade)
	httpServer := &http.Server{
		Addr:    addr,
		Handler: srv.mux,
	}

	go func() {
		slog.Info("http server listening", "addr", addr)
		err := httpServer.ListenAndServe()
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			slog.Error("http server", "err", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	select {
	case <-quit:
		slog.Info("shutting down http server")
	case <-ctx.Done():
		slog.Info("context done, shutting down http server")
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	return httpServer.Shutdown(shutdownCtx)
}
