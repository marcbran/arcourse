package arcourse

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/google/uuid"
	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

var recordedFormats = []pkg.Format{pkg.FormatHTML, pkg.FormatJSON}

const (
	defaultSessionPrefix  = "default-"
	defaultSessionIdleGap = 30 * time.Minute
)

const (
	EdgeRoot    = "root"
	EdgeTree    = "tree"
	EdgeBack    = "back"
	EdgeForward = "forward"
	EdgeCross   = "cross"
	EdgeFork    = "fork"
)

type Event struct {
	QueryID       string    `json:"queryId"`
	VisitID       string    `json:"visitId"`
	SessionID     string    `json:"sessionId"`
	Path          string    `json:"path"`
	From          string    `json:"from,omitempty"`
	EdgeClass     string    `json:"edgeClass,omitempty"`
	Timestamp     time.Time `json:"timestamp"`
	JSONContentID string    `json:"jsonContentId,omitempty"`
	HTMLContentID string    `json:"htmlContentId,omitempty"`
}

type VisitRef struct {
	VisitID       string
	SessionID     string
	JSONContentID string
	HTMLContentID string
}

type CourseRepo interface {
	Append(ctx context.Context, event Event) error
	List(ctx context.Context) ([]Event, error)
	Get(ctx context.Context, queryID string) (Event, error)
}

type BlobStore interface {
	Put(ctx context.Context, content string) (string, error)
	Get(ctx context.Context, contentID string) (string, error)
}

type recordVisit struct {
	courseRepo CourseRepo
	blobs      BlobStore
}

func newRecordVisit(courseRepo CourseRepo, blobs BlobStore) *recordVisit {
	return &recordVisit{courseRepo: courseRepo, blobs: blobs}
}

func (uc *recordVisit) Exec(ctx context.Context, ref VisitRef, queryID string, path string, decoded map[pkg.Format]string, format pkg.Format, origin pkg.Origin) VisitRef {
	if origin.Suppress || format == pkg.FormatJsonnet {
		return ref
	}
	event := Event{QueryID: queryID, Path: path, Timestamp: time.Now()}
	first := ref.VisitID == ""
	if first {
		session, from := uc.resolveOrigin(ctx, origin)
		ref = VisitRef{VisitID: uuid.Must(uuid.NewV7()).String(), SessionID: session}
		event.From = from
		event.EdgeClass = uc.classify(ctx, session, from, path)
	}
	event.VisitID = ref.VisitID
	event.SessionID = ref.SessionID
	raw, ok := decoded[pkg.FormatJSON]
	if ok {
		event.JSONContentID = uc.put(ctx, canonicalJSON, raw, path, pkg.FormatJSON)
	}
	raw, ok = decoded[pkg.FormatHTML]
	if ok {
		event.HTMLContentID = uc.put(ctx, verbatim, raw, path, pkg.FormatHTML)
	}
	if !first && event.JSONContentID == ref.JSONContentID && event.HTMLContentID == ref.HTMLContentID {
		return ref
	}
	ref.JSONContentID = event.JSONContentID
	ref.HTMLContentID = event.HTMLContentID
	err := uc.courseRepo.Append(ctx, event)
	if err != nil {
		slog.Warn("append course event", "err", err, "path", path)
	}
	return ref
}

func (uc *recordVisit) classify(ctx context.Context, session string, from string, path string) string {
	if from == "" {
		return EdgeRoot
	}
	events, err := uc.courseRepo.List(ctx)
	if err != nil {
		return EdgeRoot
	}
	source, ok := visitOf(events, from)
	if !ok {
		return EdgeRoot
	}
	if source.SessionID != session {
		return EdgeFork
	}
	visits := visitsOf(events, session)
	visited := false
	for _, visit := range visits {
		if visit.Path == path {
			visited = true
			break
		}
	}
	if !visited {
		return EdgeTree
	}
	parents := parentsOf(visits)
	for id := source.VisitID; id != ""; id = parents[id] {
		if pathOf(visits, id) == path {
			return EdgeBack
		}
	}
	for _, visit := range visits {
		if visit.Path != path {
			continue
		}
		for id := parents[visit.VisitID]; id != ""; id = parents[id] {
			if id == source.VisitID {
				return EdgeForward
			}
		}
	}
	return EdgeCross
}

func visitOf(events []Event, queryID string) (Event, bool) {
	for _, event := range events {
		if event.QueryID == queryID {
			return event, true
		}
	}
	return Event{}, false
}

func visitsOf(events []Event, session string) []Event {
	seen := map[string]bool{}
	var visits []Event
	for _, event := range events {
		if event.SessionID != session || seen[event.VisitID] {
			continue
		}
		seen[event.VisitID] = true
		visits = append(visits, event)
	}
	return visits
}

func parentsOf(visits []Event) map[string]string {
	byQueryID := map[string]string{}
	for _, visit := range visits {
		byQueryID[visit.QueryID] = visit.VisitID
	}
	parents := map[string]string{}
	for _, visit := range visits {
		parents[visit.VisitID] = byQueryID[visit.From]
	}
	return parents
}

func pathOf(visits []Event, visitID string) string {
	for _, visit := range visits {
		if visit.VisitID == visitID {
			return visit.Path
		}
	}
	return ""
}

func (uc *recordVisit) put(ctx context.Context, prepare func(string) (string, error), raw string, path string, format pkg.Format) string {
	body, err := prepare(raw)
	if err != nil {
		slog.Warn("prepare content", "err", err, "path", path, "format", format)
		return ""
	}
	id, err := uc.blobs.Put(ctx, body)
	if err != nil {
		slog.Warn("store content", "err", err, "path", path, "format", format)
		return ""
	}
	return id
}

type getVisitContent struct {
	blobs BlobStore
}

func newGetVisitContent(blobs BlobStore) *getVisitContent {
	return &getVisitContent{blobs: blobs}
}

func (uc *getVisitContent) Exec(ctx context.Context, event Event) (string, error) {
	if event.JSONContentID == "" {
		return "", fmt.Errorf("%w: %s", pkg.ErrContentNotRecorded, event.Path)
	}
	body, err := uc.blobs.Get(ctx, event.JSONContentID)
	if err != nil {
		return "", err
	}
	return withQueryID(body, event.QueryID)
}

func (uc *recordVisit) resolveOrigin(ctx context.Context, origin pkg.Origin) (string, string) {
	from := origin.From
	fromSession := ""
	if from != "" {
		event, err := uc.courseRepo.Get(ctx, from)
		if err != nil {
			slog.Warn("from names no recorded query", "from", from)
			from = ""
		} else {
			fromSession = event.SessionID
		}
	}
	session := origin.Session
	if session == "" {
		session = fromSession
	}
	if session == "" {
		session = uc.defaultSession(ctx)
	}
	if from == "" && origin.FromPath != "" {
		from = uc.resolveFromPath(ctx, session, normalizeQueryPath(origin.FromPath))
	}
	return session, from
}

func (uc *recordVisit) resolveFromPath(ctx context.Context, session string, path string) string {
	events, err := uc.courseRepo.List(ctx)
	if err != nil {
		return ""
	}
	for i := len(events) - 1; i >= 0; i-- {
		if events[i].SessionID == session && events[i].Path == path {
			return events[i].QueryID
		}
	}
	return ""
}

func (uc *recordVisit) defaultSession(ctx context.Context) string {
	events, err := uc.courseRepo.List(ctx)
	if err == nil {
		for i := len(events) - 1; i >= 0; i-- {
			if !strings.HasPrefix(events[i].SessionID, defaultSessionPrefix) {
				continue
			}
			if time.Since(events[i].Timestamp) < defaultSessionIdleGap {
				return events[i].SessionID
			}
			break
		}
	}
	return defaultSessionPrefix + uuid.Must(uuid.NewV7()).String()
}

func verbatim(raw string) (string, error) {
	return raw, nil
}

func canonicalJSON(raw string) (string, error) {
	value, err := decodeJSONValue(raw)
	if err != nil {
		return "", err
	}
	object, ok := value.(map[string]any)
	if ok {
		delete(object, pkg.QueryIDField)
	}
	return marshalCanonical(value)
}

func withQueryID(raw string, queryID string) (string, error) {
	value, err := decodeJSONValue(raw)
	if err != nil {
		return "", err
	}
	object, ok := value.(map[string]any)
	if !ok {
		return raw, nil
	}
	object[pkg.QueryIDField] = queryID
	return marshalCanonical(object)
}

func decodeJSONValue(raw string) (any, error) {
	decoder := json.NewDecoder(strings.NewReader(raw))
	decoder.UseNumber()
	var value any
	err := decoder.Decode(&value)
	if err != nil {
		return nil, err
	}
	return value, nil
}

func marshalCanonical(value any) (string, error) {
	var buf bytes.Buffer
	encoder := json.NewEncoder(&buf)
	encoder.SetEscapeHTML(false)
	err := encoder.Encode(value)
	if err != nil {
		return "", err
	}
	return strings.TrimRight(buf.String(), "\n"), nil
}
