package server

import (
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

const observePage = `<!doctype html>
<div id="observe"><p>Waiting for a query...</p></div>
<script>
  new EventSource('/observe/stream?format=html').onmessage = e => {
    document.getElementById('observe').innerHTML = JSON.parse(e.data).output;
  };
</script>
`

func (s *Server) handleObserve(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, err := fmt.Fprint(w, observePage)
	if err != nil {
		slog.Warn("write observe response", "err", err)
	}
}

func (s *Server) handleObserveStream(w http.ResponseWriter, r *http.Request) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		returnError(w, errors.New("streaming unsupported"))
		return
	}

	format, err := pkg.ParseFormat(r.URL.Query().Get("format"))
	if err != nil {
		returnBadRequest(w, err)
		return
	}

	ch, unsubscribe := s.facade.Observe(r.Context(), format)
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
				slog.Warn("marshal observe event", "err", err)
				continue
			}
			_, err = fmt.Fprintf(w, "data: %s\n\n", data)
			if err != nil {
				slog.Warn("write observe stream", "err", err)
				return
			}
			flusher.Flush()
		}
	}
}
