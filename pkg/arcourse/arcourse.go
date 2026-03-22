package arcourse

import "errors"

var (
	ErrRootConfigNotConfigured = errors.New("root config not configured")
)

type Result struct {
	Output string
}

type Facade interface {
	Evaluate(expression string) (Result, error)
}
