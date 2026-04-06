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

func returnBadRequest(w http.ResponseWriter, err error) {
	slog.Warn("bad request", "err", err)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusBadRequest)
	returnJSON(w, ErrorResponse{Message: err.Error()})
}

func returnInternalServerError(w http.ResponseWriter, err error) {
	slog.Error("internal server error", "err", err)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusInternalServerError)
	returnJSON(w, ErrorResponse{Message: err.Error()})
}

func returnError(w http.ResponseWriter, err error) {
	if errors.Is(err, pkg.ErrRootConfigNotConfigured) {
		returnBadRequest(w, err)
		return
	}
	returnInternalServerError(w, err)
}

func returnJSON(w http.ResponseWriter, data any) {
	encodeErr := json.NewEncoder(w).Encode(data)
	if encodeErr != nil {
		slog.Warn("encode response", "err", encodeErr)
	}
}
