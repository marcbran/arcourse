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

func (w *Watch) Appended(event course.Event) {
	w.mu.Lock()
	changes := w.changes
	w.mu.Unlock()
	if changes == nil {
		return
	}
	changes([]jpoetwatch.InvocationKey{
		sessionsKey,
		sessionKey(event.SessionID),
		visitKey(event.VisitID),
	})
}

func sessionKey(sessionID course.SessionID) jpoetwatch.InvocationKey {
	return jpoetwatch.InvocationKey("course://session/" + string(sessionID))
}

func visitKey(visitID course.VisitID) jpoetwatch.InvocationKey {
	return jpoetwatch.InvocationKey("course://visit/" + string(visitID))
}
