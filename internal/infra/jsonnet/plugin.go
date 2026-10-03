package jsonnet

import (
	"context"
	"fmt"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/google/go-jsonnet"
	"github.com/google/uuid"
	"github.com/marcbran/jpoet/pkg/jpoet"
	jpoetwatch "github.com/marcbran/jpoet/pkg/watch"

	"github.com/marcbran/arcourse/internal/arcourse"
)

const (
	sessionsKey   = "arcourse://sessions"
	sessionPrefix = "arcourse://session/"
	visitPrefix   = "arcourse://visit/"
	inertKey      = "arcourse://inert"
)

type CourseReader interface {
	List(ctx context.Context) ([]arcourse.Event, error)
}

type CourseSource struct {
	reader CourseReader

	mu      sync.Mutex
	changes func(keys []jpoetwatch.InvocationKey)
}

func NewCourseSource(reader CourseReader) *CourseSource {
	return &CourseSource{reader: reader}
}

func (s *CourseSource) InvocationKey(funcName string, args []any) jpoetwatch.InvocationKey {
	switch funcName {
	case "sessions":
		return sessionsKey
	case "course":
		return jpoetwatch.InvocationKey(sessionPrefix + stringArg(args, 0))
	case "visit":
		return jpoetwatch.InvocationKey(visitPrefix + stringArg(args, 0))
	default:
		return inertKey
	}
}

func (s *CourseSource) Acquire(key jpoetwatch.InvocationKey) (func(), error) {
	return func() {}, nil
}

func (s *CourseSource) SetChanges(changes func(keys []jpoetwatch.InvocationKey)) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.changes = changes
}

func (s *CourseSource) Appended(event arcourse.Event) {
	s.mu.Lock()
	changes := s.changes
	s.mu.Unlock()
	if changes == nil {
		return
	}
	changes([]jpoetwatch.InvocationKey{
		sessionsKey,
		jpoetwatch.InvocationKey(sessionPrefix + event.SessionID),
		jpoetwatch.InvocationKey(visitPrefix + event.VisitID),
	})
}

func stringArg(args []any, index int) string {
	if len(args) <= index {
		return ""
	}
	value, _ := args[index].(string)
	return value
}

func newPlugin(source *CourseSource) *jpoet.Plugin {
	natives := []jsonnet.NativeFunction{
		{
			Name: "uuid",
			Func: func(args []any) (any, error) {
				return uuid.Must(uuid.NewV7()).String(), nil
			},
		},
		{
			Name: "sessions",
			Func: func(args []any) (any, error) {
				return source.sessions()
			},
		},
		{
			Name: "course",
			Func: func(args []any) (any, error) {
				return source.course(stringArg(args, 0))
			},
		},
		{
			Name: "visit",
			Func: func(args []any) (any, error) {
				return source.visit(stringArg(args, 0))
			},
		},
	}
	return jpoet.NewPlugin("arcourse", natives, jpoet.WithWatchSource(source))
}

func (s *CourseSource) events() ([]arcourse.Event, error) {
	if s.reader == nil {
		return nil, nil
	}
	return s.reader.List(context.Background())
}

func (s *CourseSource) sessions() (any, error) {
	events, err := s.events()
	if err != nil {
		return nil, err
	}
	order := []string{}
	byID := map[string]map[string]any{}
	visits := map[string]map[string]bool{}
	for _, event := range events {
		entry, ok := byID[event.SessionID]
		if !ok {
			entry = map[string]any{
				"id":    event.SessionID,
				"first": event.Timestamp.Format(time.RFC3339),
			}
			byID[event.SessionID] = entry
			visits[event.SessionID] = map[string]bool{}
			order = append(order, event.SessionID)
		}
		entry["last"] = event.Timestamp.Format(time.RFC3339)
		visits[event.SessionID][event.VisitID] = true
	}
	items := make([]any, 0, len(order))
	for _, id := range order {
		entry := byID[id]
		entry["visits"] = len(visits[id])
		entry["_queryPath"] = "/root/arcourse/session/" + id
		items = append(items, entry)
	}
	sort.Slice(items, func(i, j int) bool {
		left := items[i].(map[string]any)["last"].(string)
		right := items[j].(map[string]any)["last"].(string)
		return left > right
	})
	return items, nil
}

func (s *CourseSource) course(session string) (any, error) {
	events, err := s.events()
	if err != nil {
		return nil, err
	}
	seen := map[string]bool{}
	visitByQueryID := map[string]string{}
	var vertices []any
	var edges []any
	for _, event := range events {
		if event.SessionID != session {
			continue
		}
		visitByQueryID[event.QueryID] = event.VisitID
		if seen[event.VisitID] {
			continue
		}
		seen[event.VisitID] = true
		vertices = append(vertices, map[string]any{
			"visitId":    event.VisitID,
			"path":       event.Path,
			"edgeClass":  event.EdgeClass,
			"timestamp":  event.Timestamp.Format(time.RFC3339),
			"_queryPath": "/root/arcourse/session/" + session + "/visit/" + event.VisitID,
		})
		if event.From == "" {
			continue
		}
		edges = append(edges, map[string]any{
			"from":      event.From,
			"to":        event.VisitID,
			"edgeClass": event.EdgeClass,
		})
	}
	for _, edge := range edges {
		entry := edge.(map[string]any)
		from, _ := entry["from"].(string)
		entry["from"] = visitByQueryID[from]
	}
	if vertices == nil {
		vertices = []any{}
	}
	if edges == nil {
		edges = []any{}
	}
	return map[string]any{"session": session, "vertices": vertices, "edges": edges}, nil
}

func (s *CourseSource) visit(visitID string) (any, error) {
	events, err := s.events()
	if err != nil {
		return nil, err
	}
	var evaluations []any
	var head *arcourse.Event
	for i := range events {
		if events[i].VisitID != visitID {
			continue
		}
		if head == nil {
			head = &events[i]
		}
		evaluations = append(evaluations, map[string]any{
			"queryId":       events[i].QueryID,
			"timestamp":     events[i].Timestamp.Format(time.RFC3339),
			"jsonContentId": events[i].JSONContentID,
			"htmlContentId": events[i].HTMLContentID,
		})
	}
	if head == nil {
		return nil, fmt.Errorf("visit not recorded: %s", visitID)
	}
	return map[string]any{
		"visitId":     head.VisitID,
		"sessionId":   head.SessionID,
		"path":        head.Path,
		"from":        head.From,
		"edgeClass":   head.EdgeClass,
		"versions":    len(evaluations),
		"evaluations": evaluations,
		"node":        map[string]any{"_node": true, "_queryPath": "/" + strings.TrimPrefix(head.Path, "/")},
	}, nil
}
