package jsonfile

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"github.com/marcbran/arcourse/internal/arcourse"
	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type CourseRepo struct {
	dir string
	mu  sync.Mutex
}

func NewCourseRepo(dir string) *CourseRepo {
	return &CourseRepo{dir: dir}
}

func (r *CourseRepo) Append(ctx context.Context, event arcourse.Event) error {
	err := ctx.Err()
	if err != nil {
		return err
	}
	line, err := json.Marshal(event)
	if err != nil {
		return err
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	err = os.MkdirAll(r.dir, 0o755)
	if err != nil {
		return err
	}
	file, err := os.OpenFile(r.eventsPath(), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	defer func() {
		_ = file.Close()
	}()
	_, err = file.Write(append(line, '\n'))
	return err
}

func (r *CourseRepo) List(ctx context.Context) ([]arcourse.Event, error) {
	lines, err := r.readLines(ctx)
	if err != nil {
		return nil, err
	}
	events := make([]arcourse.Event, 0, len(lines))
	for _, line := range lines {
		var event arcourse.Event
		err = json.Unmarshal(line, &event)
		if err != nil {
			return nil, err
		}
		events = append(events, event)
	}
	return events, nil
}

func (r *CourseRepo) Get(ctx context.Context, evaluationID pkg.EvaluationID) (arcourse.Event, error) {
	event, found, err := r.findLast(ctx, func(candidate arcourse.Event) bool {
		return candidate.EvaluationID == evaluationID
	})
	if err != nil {
		return arcourse.Event{}, err
	}
	if !found {
		return arcourse.Event{}, pkg.ErrQueryNotRecorded
	}
	return event, nil
}

func (r *CourseRepo) LatestAtPath(ctx context.Context, session pkg.SessionID, path pkg.QueryPath) (arcourse.Event, bool, error) {
	return r.findLast(ctx, func(candidate arcourse.Event) bool {
		return candidate.SessionID == session && candidate.Path == path
	})
}

func (r *CourseRepo) LatestWithSessionPrefix(ctx context.Context, prefix string) (arcourse.Event, bool, error) {
	return r.findLast(ctx, func(candidate arcourse.Event) bool {
		return strings.HasPrefix(string(candidate.SessionID), prefix)
	})
}

func (r *CourseRepo) findLast(ctx context.Context, match func(arcourse.Event) bool) (arcourse.Event, bool, error) {
	lines, err := r.readLines(ctx)
	if err != nil {
		return arcourse.Event{}, false, err
	}
	for i := len(lines) - 1; i >= 0; i-- {
		var event arcourse.Event
		err = json.Unmarshal(lines[i], &event)
		if err != nil {
			return arcourse.Event{}, false, err
		}
		if match(event) {
			return event, true, nil
		}
	}
	return arcourse.Event{}, false, nil
}

func (r *CourseRepo) readLines(ctx context.Context) ([][]byte, error) {
	err := ctx.Err()
	if err != nil {
		return nil, err
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	file, err := os.Open(r.eventsPath())
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return nil, nil
		}
		return nil, err
	}
	defer func() {
		_ = file.Close()
	}()
	var lines [][]byte
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 0, 64*1024), 4*1024*1024)
	for scanner.Scan() {
		line := scanner.Bytes()
		if len(line) == 0 {
			continue
		}
		lines = append(lines, append([]byte(nil), line...))
	}
	err = scanner.Err()
	if err != nil {
		return nil, err
	}
	return lines, nil
}

func (r *CourseRepo) eventsPath() string {
	return filepath.Join(r.dir, "events.jsonl")
}
