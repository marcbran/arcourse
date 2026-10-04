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

	"github.com/marcbran/arcourse/internal/arcourse/course"
)

type CourseRepo struct {
	dir string
	mu  sync.Mutex
}

func NewCourseRepo(dir string) *CourseRepo {
	return &CourseRepo{dir: dir}
}

func (r *CourseRepo) Append(ctx context.Context, event course.Event) error {
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

func (r *CourseRepo) List(ctx context.Context) ([]course.Event, error) {
	lines, err := r.readLines(ctx)
	if err != nil {
		return nil, err
	}
	events := make([]course.Event, 0, len(lines))
	for _, line := range lines {
		var event course.Event
		err = json.Unmarshal(line, &event)
		if err != nil {
			return nil, err
		}
		events = append(events, event)
	}
	return events, nil
}

func (r *CourseRepo) Get(ctx context.Context, evaluationID course.EvaluationID) (course.Event, error) {
	event, found, err := r.findLast(ctx, func(candidate course.Event) bool {
		return candidate.EvaluationID == evaluationID
	})
	if err != nil {
		return course.Event{}, err
	}
	if !found {
		return course.Event{}, course.ErrEvaluationNotRecorded
	}
	return event, nil
}

func (r *CourseRepo) ListSession(ctx context.Context, sessionID course.SessionID) ([]course.Event, error) {
	return r.filter(ctx, func(candidate course.Event) bool {
		return candidate.SessionID == sessionID
	})
}

func (r *CourseRepo) ListVisit(ctx context.Context, visitID course.VisitID) ([]course.Event, error) {
	return r.filter(ctx, func(candidate course.Event) bool {
		return candidate.VisitID == visitID
	})
}

func (r *CourseRepo) LatestAtAddress(ctx context.Context, sessionID course.SessionID, address course.Address) (course.Event, bool, error) {
	return r.findLast(ctx, func(candidate course.Event) bool {
		return candidate.SessionID == sessionID && candidate.Address == address
	})
}

func (r *CourseRepo) LatestWithSessionPrefix(ctx context.Context, prefix string) (course.Event, bool, error) {
	return r.findLast(ctx, func(candidate course.Event) bool {
		return strings.HasPrefix(string(candidate.SessionID), prefix)
	})
}

func (r *CourseRepo) filter(ctx context.Context, match func(course.Event) bool) ([]course.Event, error) {
	lines, err := r.readLines(ctx)
	if err != nil {
		return nil, err
	}
	var events []course.Event
	for _, line := range lines {
		var event course.Event
		err = json.Unmarshal(line, &event)
		if err != nil {
			return nil, err
		}
		if match(event) {
			events = append(events, event)
		}
	}
	return events, nil
}

func (r *CourseRepo) findLast(ctx context.Context, match func(course.Event) bool) (course.Event, bool, error) {
	lines, err := r.readLines(ctx)
	if err != nil {
		return course.Event{}, false, err
	}
	for i := len(lines) - 1; i >= 0; i-- {
		var event course.Event
		err = json.Unmarshal(lines[i], &event)
		if err != nil {
			return course.Event{}, false, err
		}
		if match(event) {
			return event, true, nil
		}
	}
	return course.Event{}, false, nil
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
