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
	FormatHTML Format = "html"
)

func ParseFormat(s string) (Format, error) {
	switch Format(s) {
	case FormatHTML:
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
	Render(ctx context.Context, path []string, format Format) (Result, error)
}
