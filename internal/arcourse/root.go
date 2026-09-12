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

const compileWatchKey = "arcourse-compile-root"

type RootConfig struct {
	Dir  string `json:"dir"`
	Mode Mode   `json:"mode"`
}

type root struct {
	cfg       RootConfig
	evaluator Evaluator

	warmOnce sync.Once
	warmErr  error
}

func newRoot(cfg RootConfig, evaluator Evaluator) *root {
	return &root{
		cfg:       cfg,
		evaluator: evaluator,
	}
}

func (r *root) Warm(ctx context.Context) error {
	r.warmOnce.Do(func() {
		r.warmErr = r.warm(ctx)
	})
	return r.warmErr
}

func (r *root) warm(ctx context.Context) error {
	err := ctx.Err()
	if err != nil {
		return err
	}
	rootPath := r.rootFilePath()
	err = os.MkdirAll(filepath.Dir(rootPath), 0o755)
	if err != nil {
		return err
	}
	if r.cfg.Mode != ModeCompiledGraph {
		snippet, err := r.snippet(ctx)
		if err != nil {
			return err
		}
		err = os.WriteFile(rootPath, []byte(snippet), 0o644)
		if err != nil {
			return err
		}
	}
	err = r.evaluator.Warm(rootPath)
	if err != nil {
		return err
	}
	if r.cfg.Mode == ModeCompiledGraph {
		entryPath, err := r.entryPath()
		if err != nil {
			return err
		}
		_, err = r.evaluator.WatchFile(compileWatchKey, compileSnippet(entryPath), rootPath)
		if err != nil {
			return err
		}
	}
	return nil
}

func (r *root) snippet(ctx context.Context) (string, error) {
	err := ctx.Err()
	if err != nil {
		return "", err
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
		return fmt.Sprintf(`local construct_immediate_graph_root = import 'lib/construct_immediate_graph_root.libsonnet';
construct_immediate_graph_root(import %q)`, filepath.ToSlash(entryPath)), nil
	default:
		return "", fmt.Errorf("unknown root mode %q", r.cfg.Mode)
	}
}

func (r *root) rootFilePath() string {
	return filepath.Join(r.cfg.Dir, ".arcourse", "root.jsonnet")
}

func (r *root) entryPath() (string, error) {
	return resolveEntryPath(r.cfg.Dir)
}

func resolveEntryPath(dir string) (string, error) {
	if dir == "" {
		return "", pkg.ErrEvaluateDirNotSet
	}
	path := filepath.Join(dir, "root.jsonnet")
	fi, err := os.Stat(path)
	if err != nil {
		if os.IsNotExist(err) {
			return "", fmt.Errorf("%w: %s", pkg.ErrGraphEntryNotFound, dir)
		}
		return "", err
	}
	if !fi.Mode().IsRegular() {
		return "", fmt.Errorf("%w: %s", pkg.ErrGraphEntryNotFound, path)
	}
	return path, nil
}
