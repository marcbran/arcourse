package server

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type ErrorResponse struct {
	Message string `json:"message"`
}

func returnSuccess(w http.ResponseWriter, data any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	returnJSON(w, data)
}

func returnError(w http.ResponseWriter, err error) {
	if errors.Is(err, pkg.ErrGraphEntryNotFound) || errors.Is(err, pkg.ErrEvaluateDirNotSet) ||
		errors.Is(err, pkg.ErrActionNotFound) {
		returnBadRequest(w, err)
		return
	}
	if errors.Is(err, pkg.ErrQueryNotRecorded) {
		returnNotFound(w, err)
		return
	}
	if errors.Is(err, pkg.ErrAlreadyExecuted) {
		returnConflict(w, err)
		return
	}
	returnInternalServerError(w, err)
}

func returnBadRequest(w http.ResponseWriter, err error) {
	slog.Warn("bad request", "err", err)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusBadRequest)
	returnJSON(w, ErrorResponse{Message: err.Error()})
}

func returnNotFound(w http.ResponseWriter, err error) {
	slog.Warn("not found", "err", err)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusNotFound)
	returnJSON(w, ErrorResponse{Message: err.Error()})
}

func returnConflict(w http.ResponseWriter, err error) {
	slog.Warn("conflict", "err", err)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusConflict)
	returnJSON(w, ErrorResponse{Message: err.Error()})
}

func returnInternalServerError(w http.ResponseWriter, err error) {
	slog.Error("internal server error", "err", err)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusInternalServerError)
	returnJSON(w, ErrorResponse{Message: err.Error()})
}

func returnJSON(w http.ResponseWriter, data any) {
	encodeErr := json.NewEncoder(w).Encode(data)
	if encodeErr != nil {
		slog.Warn("encode response", "err", encodeErr)
	}
}
