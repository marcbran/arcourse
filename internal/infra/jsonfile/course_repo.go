package jsonfile

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
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
	var events []arcourse.Event
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 0, 64*1024), 4*1024*1024)
	for scanner.Scan() {
		line := scanner.Bytes()
		if len(line) == 0 {
			continue
		}
		var event arcourse.Event
		err = json.Unmarshal(line, &event)
		if err != nil {
			return nil, err
		}
		events = append(events, event)
	}
	err = scanner.Err()
	if err != nil {
		return nil, err
	}
	return events, nil
}

func (r *CourseRepo) Get(ctx context.Context, queryID string) (arcourse.Event, error) {
	events, err := r.List(ctx)
	if err != nil {
		return arcourse.Event{}, err
	}
	for i := len(events) - 1; i >= 0; i-- {
		if events[i].QueryID == queryID {
			return events[i], nil
		}
	}
	return arcourse.Event{}, pkg.ErrQueryNotRecorded
}

func (r *CourseRepo) eventsPath() string {
	return filepath.Join(r.dir, "events.jsonl")
}
