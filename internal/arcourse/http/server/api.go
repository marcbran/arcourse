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
	Path     string         `json:"path"`
	Params   map[string]any `json:"params"`
	Format   string         `json:"format"`
	Session  string         `json:"session"`
	From     string         `json:"from"`
	FromPath string         `json:"fromPath"`
}

type outputResponse struct {
	Output string `json:"output"`
}

type execResponse struct {
	ExecutionID string `json:"executionId"`
	Output      string `json:"output"`
	Redirect    string `json:"redirect"`
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
	origin := pkg.Origin{Session: pkg.SessionID(req.Session), From: pkg.EntryID(req.From), FromPath: pkg.NewQueryPath(req.FromPath)}
	result, err := s.facade.Query(r.Context(), pkg.NewQueryPath(req.Path), req.Params, format, origin)
	if err != nil {
		returnError(w, err)
		return
	}
	returnSuccess(w, outputResponse{Output: result.Output})
}

func (s *Server) handleExec(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if id == "" {
		returnBadRequest(w, errors.New("id is required"))
		return
	}
	result, err := s.facade.Exec(r.Context(), pkg.EvaluationID(id))
	if err != nil {
		returnError(w, err)
		return
	}
	returnSuccess(w, execResponse{ExecutionID: string(result.ExecutionID), Output: result.Output, Redirect: result.Redirect.String()})
}
