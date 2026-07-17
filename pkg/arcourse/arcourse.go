package arcourse

import (
	"context"
	"errors"
	"fmt"
)

var (
	ErrGraphEntryNotFound = errors.New("neither graph.jsonnet nor root.jsonnet found in evaluate dir")
	ErrEvaluateDirNotSet  = errors.New("evaluate dir not set")
)

type Format string

const (
	FormatJSON    Format = "json"
	FormatHTML    Format = "html"
	FormatJsonnet Format = "jsonnet"
)

func ParseFormat(s string) (Format, error) {
	if s == "" {
		return FormatJSON, nil
	}
	switch Format(s) {
	case FormatJSON, FormatHTML, FormatJsonnet:
		return Format(s), nil
	default:
		return "", fmt.Errorf("unknown format: %s", s)
	}
}

type Result struct {
	Output string
}

type Facade interface {
	Evaluate(ctx context.Context, expression string) (Result, error)
	Query(ctx context.Context, path string, params map[string]any, format Format) (Result, error)
	Observe(ctx context.Context, format Format) (<-chan Result, func())
}
