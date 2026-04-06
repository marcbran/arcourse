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
		http.Redirect(w, r, "/root/", http.StatusFound)
		return
	}
	segments := strings.Split(path, "/")
	for _, segment := range segments {
		if strings.Contains(segment, ".") {
			http.NotFound(w, r)
			return
		}
	}
	if len(segments) > 0 && segments[0] == "api" {
		http.NotFound(w, r)
		return
	}
	result, err := s.facade.Render(r.Context(), segments, pkg.FormatHTML)
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
