package arcourse

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sync"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type Mode string

const (
	ModeImmediateGraph Mode = "immediateGraph"
	ModeCompiledGraph  Mode = "compiledGraph"
	ModeImmediateRoot  Mode = "immediateRoot"
)

type RootConfig struct {
	Dir  string `json:"dir"`
	Mode Mode   `json:"mode"`
}

type root struct {
	cfg     RootConfig
	compile *compile

	mu     sync.RWMutex
	cached *string
}

func newRoot(cfg RootConfig, compile *compile) *root {
	return &root{
		cfg:     cfg,
		compile: compile,
	}
}

func (r *root) Snippet(ctx context.Context) (string, error) {
	if r.cfg.Dir == "" {
		return "", pkg.ErrEvaluateDirNotSet
	}
	r.mu.RLock()
	cached := r.cached
	r.mu.RUnlock()
	if cached != nil {
		return *cached, nil
	}

	switch r.cfg.Mode {
	case ModeImmediateRoot:
		entryPath, err := r.entryPath()
		if err != nil {
			return "", err
		}
		return fmt.Sprintf(`import %q`, filepath.ToSlash(entryPath)), nil
	case ModeImmediateGraph:
		entryPath, err := r.entryPath()
		if err != nil {
			return "", err
		}
		return immediateGraphSnippet(entryPath), nil
	case ModeCompiledGraph:
		result, err := r.compile.Exec(ctx)
		if err != nil {
			return "", err
		}
		r.mu.Lock()
		r.cached = &result.Output
		r.mu.Unlock()
		return result.Output, nil
	default:
		return "", fmt.Errorf("unknown root mode %q", r.cfg.Mode)
	}
}

func (r *root) entryPath() (string, error) {
	path := filepath.Join(r.cfg.Dir, "root.jsonnet")
	fi, err := os.Stat(path)
	if err != nil {
		if os.IsNotExist(err) {
			return "", fmt.Errorf("%w: %s", pkg.ErrGraphEntryNotFound, r.cfg.Dir)
		}
		return "", err
	}
	if !fi.Mode().IsRegular() {
		return "", fmt.Errorf("%w: %s", pkg.ErrGraphEntryNotFound, path)
	}
	return path, nil
}
