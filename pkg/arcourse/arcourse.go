package arcourse

import (
	"context"
	"errors"
	"fmt"
	"net/url"
	"strings"
)

var (
	ErrGraphEntryNotFound = errors.New("root.jsonnet not found in evaluate dir")
	ErrEvaluateDirNotSet  = errors.New("evaluate dir not set")
	ErrQueryNotRecorded   = errors.New("query not recorded")
	ErrContentNotRecorded = errors.New("query has no json content recorded")
	ErrActionNotFound     = errors.New("node has no action")
	ErrActionInvalid      = errors.New("action is invalid")
	ErrAlreadyExecuted    = errors.New("query already executed")
	ErrEmptyRemark        = errors.New("remark text is empty")
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
	base, query, hasQuery := strings.Cut(raw, "?")
	segments := strings.Split(strings.Trim(base, "/"), "/")
	for i, segment := range segments {
		decoded, err := url.PathUnescape(segment)
		if err == nil {
			segments[i] = url.PathEscape(decoded)
		}
	}
	path := strings.Join(segments, "/")
	if !hasQuery {
		return QueryPath(path)
	}
	if values, err := url.ParseQuery(query); err == nil {
		query = values.Encode()
	}
	if query == "" {
		return QueryPath(path)
	}
	return QueryPath(path + "?" + query)
}

func (p QueryPath) String() string {
	return string(p)
}

type EvaluationID string

type ExecutionID string

type RemarkID string

type EntryID string

type SessionID string

type Origin struct {
	Session  SessionID
	From     EntryID
	FromPath QueryPath
}

type Result struct {
	Output       string
	EvaluationID EvaluationID
}

type ExecResult struct {
	ExecutionID ExecutionID
	Output      string
	Redirect    QueryPath
}

type Facade interface {
	Evaluate(ctx context.Context, expression string) (Result, error)
	Query(ctx context.Context, path QueryPath, params map[string]any, format Format, origin Origin) (Result, error)
	Watch(ctx context.Context, path QueryPath, params map[string]any, format Format, origin Origin) (<-chan Result, func(), error)
	Exec(ctx context.Context, id EvaluationID) (ExecResult, error)
	Remark(ctx context.Context, id EvaluationID, text string) (RemarkID, error)
	Compile(ctx context.Context) (Result, error)
	Warm(ctx context.Context) error
	Close() error
}
