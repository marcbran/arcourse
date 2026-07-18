package server

import (
	"errors"
	"html/template"
	"log/slog"
	"net/http"
	"time"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

var auditListTemplate = template.Must(template.New("auditList").Parse(`<!doctype html>
<h1>Audit</h1>
<ul>
{{range .}}  <li><a href="/audit/{{.ID}}">{{.Timestamp}}</a> {{.Path}}</li>
{{end}}</ul>
`))

var auditEntryTemplate = template.Must(template.New("auditEntry").Parse(`<!doctype html>
<h1>Audit Entry</h1>
<p>Path: {{.Path}}</p>
<p>Timestamp: {{.Timestamp}}</p>
{{if .HTML}}<div>{{.HTML}}</div>{{else if .JSON}}<pre>{{.JSON}}</pre>{{else}}<p>No captured view for this entry.</p>{{end}}
`))

type auditListItem struct {
	ID        string
	Path      string
	Timestamp string
}

type auditEntryView struct {
	Path      string
	Timestamp string
	HTML      template.HTML
	JSON      string
}

func (s *Server) handleAuditPage(w http.ResponseWriter, r *http.Request) {
	entries, err := s.facade.ListAudit(r.Context())
	if err != nil {
		returnError(w, err)
		return
	}
	items := make([]auditListItem, 0, len(entries))
	for _, entry := range entries {
		items = append(items, auditListItem{
			ID:        entry.ID,
			Path:      entry.Path,
			Timestamp: entry.Timestamp.Format(time.RFC3339),
		})
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	err = auditListTemplate.Execute(w, items)
	if err != nil {
		slog.Warn("write audit list response", "err", err)
	}
}

func (s *Server) handleAuditEntryPage(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if id == "" {
		returnBadRequest(w, errors.New("id is required"))
		return
	}
	entry, err := s.facade.GetAudit(r.Context(), id)
	if err != nil {
		returnError(w, err)
		return
	}
	view := auditEntryView{
		Path:      entry.Path,
		Timestamp: entry.Timestamp.Format(time.RFC3339),
	}
	if html, ok := entry.Results[pkg.FormatHTML]; ok {
		view.HTML = template.HTML(html.Output)
	} else if j, ok := entry.Results[pkg.FormatJSON]; ok {
		view.JSON = j.Output
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	err = auditEntryTemplate.Execute(w, view)
	if err != nil {
		slog.Warn("write audit entry response", "err", err)
	}
}
