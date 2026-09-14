package server

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

const browseTemplate = `<div id="node">%s</div>
<script>
  new EventSource(%s).onmessage = e => {
    document.getElementById('node').innerHTML = JSON.parse(e.data).output;
  };
</script>
`

func (s *Server) handleBrowse(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimRight(r.PathValue("path"), "/")
	if path == "" {
		http.Redirect(w, r, "/root", http.StatusFound)
		return
	}
	params := map[string]any{}
	for key, values := range r.URL.Query() {
		if len(values) == 1 {
			params[key] = values[0]
		} else if len(values) > 1 {
			params[key] = values
		}
	}
	watchCtx, cancel := context.WithCancel(context.Background())
	ch, unregister, err := s.facade.Watch(watchCtx, path, params, pkg.FormatHTML)
	if err != nil {
		cancel()
		returnError(w, err)
		return
	}
	result := <-ch
	token := s.pendingWatches.store(ch, func() {
		unregister()
		cancel()
	})
	watchURL := browseWatchURL(token)
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, err = fmt.Fprintf(w, browseTemplate, result.Output, watchURL)
	if err != nil {
		slog.Warn("write browse response", "err", err)
	}
}

func browseWatchURL(token string) []byte {
	values := url.Values{"token": {token}}
	out, _ := json.Marshal("/watch?" + values.Encode())
	return out
}

func (s *Server) handleBrowseWatch(w http.ResponseWriter, r *http.Request) {
	token := r.URL.Query().Get("token")
	if token == "" {
		returnBadRequest(w, errors.New("token is required"))
		return
	}
	pw, ok := s.pendingWatches.claim(token)
	if !ok {
		returnBadRequest(w, errors.New("watch token not found or expired"))
		return
	}
	defer pw.release()

	s.streamWatch(w, r, pw.ch)
}

const pendingWatchTTL = 30 * time.Second

type pendingWatch struct {
	ch        <-chan pkg.Result
	release   func()
	createdAt time.Time
}

type pendingWatches struct {
	mu      sync.Mutex
	entries map[string]*pendingWatch
}

func newPendingWatches() *pendingWatches {
	return &pendingWatches{entries: map[string]*pendingWatch{}}
}

func (p *pendingWatches) store(ch <-chan pkg.Result, release func()) string {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.sweepLocked()
	token := uuid.Must(uuid.NewV7()).String()
	p.entries[token] = &pendingWatch{ch: ch, release: release, createdAt: time.Now()}
	return token
}

func (p *pendingWatches) claim(token string) (*pendingWatch, bool) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.sweepLocked()
	pw, ok := p.entries[token]
	if !ok {
		return nil, false
	}
	delete(p.entries, token)
	return pw, true
}

func (p *pendingWatches) sweepLocked() {
	now := time.Now()
	for token, pw := range p.entries {
		if now.Sub(pw.createdAt) <= pendingWatchTTL {
			continue
		}
		pw.release()
		delete(p.entries, token)
	}
}
