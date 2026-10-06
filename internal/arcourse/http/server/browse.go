package server

import (
	"context"
	_ "embed"
	"encoding/json"
	"errors"
	"fmt"
	"html"
	"log/slog"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

//go:embed quick-remark.js
var quickRemarkScript []byte

const quickRemarkPath = "/assets/quick-remark.js"

const browseTemplate = `<div id="node">%s</div>
%s<script>
  new EventSource(%s).onmessage = e => {
    const message = JSON.parse(e.data);
    document.getElementById('node').innerHTML = message.output;
    const remark = document.querySelector('quick-remark');
    if (remark && message.evaluationId) remark.setAttribute('from', message.evaluationId);
  };
</script>
`

const quickRemarkTemplate = `<quick-remark from="%s"></quick-remark>
<script src="%s"></script>
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
	ch, unregister, err := s.facade.Watch(watchCtx, pkg.NewQueryPath(path), params, pkg.FormatHTML, browseOrigin(w, r))
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
	_, err = fmt.Fprintf(w, browseTemplate, result.Output, browseRemark(result.EvaluationID), watchURL)
	if err != nil {
		slog.Warn("write browse response", "err", err)
	}
}

func (s *Server) handleBrowseExec(w http.ResponseWriter, r *http.Request) {
	err := r.ParseForm()
	if err != nil {
		returnBadRequest(w, err)
		return
	}
	id := r.PostFormValue("evaluationId")
	if id == "" {
		returnBadRequest(w, errors.New("evaluationId is required"))
		return
	}
	result, err := s.facade.Exec(r.Context(), pkg.EvaluationID(id))
	if err != nil {
		returnError(w, err)
		return
	}
	setFromCookie(w, pkg.EntryID(result.ExecutionID))
	http.Redirect(w, r, "/"+strings.TrimPrefix(result.Redirect.String(), "/"), http.StatusSeeOther)
}

func browseRemark(evaluationID pkg.EvaluationID) string {
	if evaluationID == "" {
		return ""
	}
	return fmt.Sprintf(quickRemarkTemplate, html.EscapeString(string(evaluationID)), quickRemarkPath)
}

func (s *Server) handleQuickRemarkScript(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/javascript; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, err := w.Write(quickRemarkScript)
	if err != nil {
		slog.Warn("write quick remark script", "err", err)
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
