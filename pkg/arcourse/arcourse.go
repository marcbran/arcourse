package arcourse

import (
	"errors"
	"fmt"
)

var (
	ErrRootConfigNotConfigured = errors.New("root config not configured")
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
	Evaluate(expression string) (Result, error)
	Render(path []string, format Format) (Result, error)
}
