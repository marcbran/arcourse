package server

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type evaluateRequest struct {
	Expression string `json:"expression"`
}

type queryRequest struct {
	Path   string         `json:"path"`
	Params map[string]any `json:"params"`
	Format string         `json:"format"`
}

type outputResponse struct {
	Output string `json:"output"`
}

func (s *Server) handleEvaluate(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(r.Body)
	if err != nil {
		returnBadRequest(w, err)
		return
	}
	var req evaluateRequest
	err = json.Unmarshal(body, &req)
	if err != nil {
		returnBadRequest(w, err)
		return
	}
	if req.Expression == "" {
		returnBadRequest(w, errors.New("expression is required"))
		return
	}
	result, err := s.facade.Evaluate(r.Context(), req.Expression)
	if err != nil {
		returnError(w, err)
		return
	}
	returnSuccess(w, outputResponse{Output: result.Output})
}

func (s *Server) handleQuery(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(r.Body)
	if err != nil {
		returnBadRequest(w, err)
		return
	}
	var req queryRequest
	err = json.Unmarshal(body, &req)
	if err != nil {
		returnBadRequest(w, err)
		return
	}
	if req.Path == "" {
		returnBadRequest(w, errors.New("path is required"))
		return
	}
	format, err := pkg.ParseFormat(req.Format)
	if err != nil {
		returnBadRequest(w, err)
		return
	}
	result, err := s.facade.Query(r.Context(), req.Path, req.Params, format)
	if err != nil {
		returnError(w, err)
		return
	}
	returnSuccess(w, outputResponse{Output: result.Output})
}
