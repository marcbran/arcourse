package arcourse

import (
	"context"
	"errors"
	"fmt"
	"strings"
)

var (
	ErrGraphEntryNotFound = errors.New("root.jsonnet not found in evaluate dir")
	ErrEvaluateDirNotSet  = errors.New("evaluate dir not set")
	ErrQueryNotRecorded   = errors.New("query not recorded")
	ErrContentNotRecorded = errors.New("query has no json content recorded")
	ErrActionNotFound     = errors.New("node has no action")
	ErrShapeNotSupported  = errors.New("compiling a root shape requires immediateGraph or compiledGraph mode (root.jsonnet must be a node-spec list, not a finished value)")
)

const EvaluationIDField = "_evaluationId"

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

type QueryPath string

func NewQueryPath(raw string) QueryPath {
	return QueryPath(strings.Trim(raw, "/"))
}

func (p QueryPath) String() string {
	return string(p)
}

type EvaluationID string

type SessionID string

type Origin struct {
	Session  SessionID
	From     EvaluationID
	FromPath QueryPath
}

type Result struct {
	Output string
}

type ExecResult struct {
	Output   string
	Redirect QueryPath
}

type Facade interface {
	Evaluate(ctx context.Context, expression string) (Result, error)
	Query(ctx context.Context, path QueryPath, params map[string]any, format Format, origin Origin) (Result, error)
	Watch(ctx context.Context, path QueryPath, params map[string]any, format Format, origin Origin) (<-chan Result, func(), error)
	Exec(ctx context.Context, id EvaluationID) (ExecResult, error)
	Compile(ctx context.Context) (Result, error)
	Warm(ctx context.Context) error
	Close() error
}
