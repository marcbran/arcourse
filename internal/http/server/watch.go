package server

import (
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

func (s *Server) handleWatch(w http.ResponseWriter, r *http.Request) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		returnError(w, errors.New("streaming unsupported"))
		return
	}

	path := r.URL.Query().Get("path")
	if path == "" {
		returnBadRequest(w, errors.New("path is required"))
		return
	}
	format, err := pkg.ParseFormat(r.URL.Query().Get("format"))
	if err != nil {
		returnBadRequest(w, err)
		return
	}
	params := map[string]any{}
	rawParams := r.URL.Query().Get("params")
	if rawParams != "" {
		err = json.Unmarshal([]byte(rawParams), &params)
		if err != nil {
			returnBadRequest(w, err)
			return
		}
	}

	ch, unsubscribe, err := s.facade.Watch(r.Context(), path, params, format)
	if err != nil {
		returnError(w, err)
		return
	}
	defer unsubscribe()

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.WriteHeader(http.StatusOK)

	for {
		select {
		case <-r.Context().Done():
			return
		case result, ok := <-ch:
			if !ok {
				return
			}
			data, err := json.Marshal(outputResponse{Output: result.Output})
			if err != nil {
				slog.Warn("marshal watch event", "err", err)
				continue
			}
			_, err = fmt.Fprintf(w, "data: %s\n\n", data)
			if err != nil {
				slog.Warn("write watch stream", "err", err)
				return
			}
			flusher.Flush()
		}
	}
}
