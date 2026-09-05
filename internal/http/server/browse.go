package server

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"net/url"
	"strings"

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
	result, err := s.facade.Query(r.Context(), path, params, pkg.FormatHTML)
	if err != nil {
		returnError(w, err)
		return
	}
	watchURL, err := browseWatchURL(path, params)
	if err != nil {
		returnError(w, err)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, err = fmt.Fprintf(w, browseTemplate, result.Output, watchURL)
	if err != nil {
		slog.Warn("write browse response", "err", err)
	}
}

func browseWatchURL(path string, params map[string]any) ([]byte, error) {
	paramsJSON, err := json.Marshal(params)
	if err != nil {
		return nil, err
	}
	values := url.Values{
		"path":   {path},
		"format": {string(pkg.FormatHTML)},
		"params": {string(paramsJSON)},
	}
	return json.Marshal("/api/watch?" + values.Encode())
}
