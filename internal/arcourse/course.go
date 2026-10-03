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

type VisitID string

type ContentID string

type Event struct {
	EvaluationID  pkg.EvaluationID `json:"evaluationId"`
	VisitID       VisitID          `json:"visitId"`
	SessionID     pkg.SessionID    `json:"sessionId"`
	Path          pkg.QueryPath    `json:"path"`
	From          pkg.EvaluationID `json:"from,omitempty"`
	Timestamp     time.Time        `json:"timestamp"`
	JSONContentID ContentID        `json:"jsonContentId,omitempty"`
	HTMLContentID ContentID        `json:"htmlContentId,omitempty"`
}

type VisitRef struct {
	VisitID       VisitID
	SessionID     pkg.SessionID
	JSONContentID ContentID
	HTMLContentID ContentID
}

type CourseRepo interface {
	Append(ctx context.Context, event Event) error
	List(ctx context.Context) ([]Event, error)
	Get(ctx context.Context, evaluationID pkg.EvaluationID) (Event, error)
	LatestAtPath(ctx context.Context, session pkg.SessionID, path pkg.QueryPath) (Event, bool, error)
	LatestWithSessionPrefix(ctx context.Context, prefix string) (Event, bool, error)
}

type CourseObserver interface {
	Appended(event Event)
}

type BlobStore interface {
	Put(ctx context.Context, content string) (ContentID, error)
	Get(ctx context.Context, contentID ContentID) (string, error)
}

type recordVisit struct {
	courseRepo CourseRepo
	blobs      BlobStore
	observer   CourseObserver
}

func newRecordVisit(courseRepo CourseRepo, blobs BlobStore, observer CourseObserver) *recordVisit {
	return &recordVisit{courseRepo: courseRepo, blobs: blobs, observer: observer}
}

func (uc *recordVisit) Exec(ctx context.Context, ref VisitRef, evaluationID pkg.EvaluationID, path pkg.QueryPath, decoded map[pkg.Format]string, origin pkg.Origin) VisitRef {
	event := Event{EvaluationID: evaluationID, Path: path, Timestamp: time.Now()}
	first := ref.VisitID == ""
	if first {
		session, from := uc.resolveOrigin(ctx, origin)
		ref = VisitRef{VisitID: VisitID(uuid.Must(uuid.NewV7()).String()), SessionID: session}
		event.From = from
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
		return ref
	}
	if uc.observer != nil {
		uc.observer.Appended(event)
	}
	return ref
}

func (uc *recordVisit) put(ctx context.Context, prepare func(string) (string, error), raw string, path pkg.QueryPath, format pkg.Format) ContentID {
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
	return withEvaluationID(body, event.EvaluationID)
}

func (uc *recordVisit) resolveOrigin(ctx context.Context, origin pkg.Origin) (pkg.SessionID, pkg.EvaluationID) {
	from := origin.From
	fromSession := pkg.SessionID("")
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
		from = uc.resolveFromPath(ctx, session, pkg.NewQueryPath(origin.FromPath.String()))
	}
	return session, from
}

func (uc *recordVisit) resolveFromPath(ctx context.Context, session pkg.SessionID, path pkg.QueryPath) pkg.EvaluationID {
	event, found, err := uc.courseRepo.LatestAtPath(ctx, session, path)
	if err != nil || !found {
		return ""
	}
	return event.EvaluationID
}

func (uc *recordVisit) defaultSession(ctx context.Context) pkg.SessionID {
	event, found, err := uc.courseRepo.LatestWithSessionPrefix(ctx, defaultSessionPrefix)
	if err == nil && found && time.Since(event.Timestamp) < defaultSessionIdleGap {
		return event.SessionID
	}
	return pkg.SessionID(defaultSessionPrefix + uuid.Must(uuid.NewV7()).String())
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
		delete(object, pkg.EvaluationIDField)
	}
	return marshalCanonical(value)
}

func withEvaluationID(raw string, evaluationID pkg.EvaluationID) (string, error) {
	value, err := decodeJSONValue(raw)
	if err != nil {
		return "", err
	}
	object, ok := value.(map[string]any)
	if !ok {
		return raw, nil
	}
	object[pkg.EvaluationIDField] = string(evaluationID)
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
