package server

import (
	"log/slog"
	"net/http"
	"strings"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

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
	result, err := s.facade.Render(r.Context(), path, params, pkg.FormatHTML)
	if err != nil {
		returnError(w, err)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, err = w.Write([]byte(result.Output))
	if err != nil {
		slog.Warn("write browse response", "err", err)
	}
}
