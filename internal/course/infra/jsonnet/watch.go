package jsonnet

import (
	"sync"

	jpoetwatch "github.com/marcbran/jpoet/pkg/watch"

	"github.com/marcbran/arcourse/internal/course"
)

const (
	sessionsKey = jpoetwatch.InvocationKey("course://sessions")
)

type Watch struct {
	mu      sync.Mutex
	changes func(keys []jpoetwatch.InvocationKey)
}

func newWatch() *Watch {
	return &Watch{}
}

func (w *Watch) InvocationKey(funcName string, args []any) jpoetwatch.InvocationKey {
	switch funcName {
	case "sessions":
		return sessionsKey
	case "session":
		return sessionKey(course.SessionID(stringArg(args, 0)))
	case "visit":
		return visitKey(course.VisitID(stringArg(args, 0)))
	case "execution":
		return executionKey(course.ExecutionID(stringArg(args, 0)))
	default:
		return ""
	}
}

func (w *Watch) Acquire(key jpoetwatch.InvocationKey) (func(), error) {
	return func() {}, nil
}

func (w *Watch) SetChanges(changes func(keys []jpoetwatch.InvocationKey)) {
	w.mu.Lock()
	defer w.mu.Unlock()
	w.changes = changes
}

func (w *Watch) Changed(change course.Change) {
	w.mu.Lock()
	changes := w.changes
	w.mu.Unlock()
	if changes == nil {
		return
	}
	keys := []jpoetwatch.InvocationKey{
		sessionsKey,
		sessionKey(change.SessionID),
	}
	if change.VisitID != "" {
		keys = append(keys, visitKey(change.VisitID))
	}
	if change.ExecutionID != "" {
		keys = append(keys, executionKey(change.ExecutionID))
	}
	changes(keys)
}

func sessionKey(sessionID course.SessionID) jpoetwatch.InvocationKey {
	return jpoetwatch.InvocationKey("course://session/" + string(sessionID))
}

func visitKey(visitID course.VisitID) jpoetwatch.InvocationKey {
	return jpoetwatch.InvocationKey("course://visit/" + string(visitID))
}

func executionKey(executionID course.ExecutionID) jpoetwatch.InvocationKey {
	return jpoetwatch.InvocationKey("course://execution/" + string(executionID))
}
