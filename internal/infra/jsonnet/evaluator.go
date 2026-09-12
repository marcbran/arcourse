package jsonnet

import (
	"bytes"
	"fmt"
	"io/fs"
	"sync"

	"github.com/google/go-jsonnet"
	"github.com/marcbran/jpoet/pkg/jpoet"
	"github.com/marcbran/jpoet/pkg/watch"
)

type Evaluator struct {
	lib     fs.FS
	jpaths  []string
	plugins []*jpoet.Plugin

	warmOnce sync.Once
	env      *watch.Environment
}

func NewEvaluator(lib fs.FS, jpaths []string, plugins []*jpoet.Plugin) *Evaluator {
	return &Evaluator{lib: lib, jpaths: jpaths, plugins: plugins}
}

func (e *Evaluator) Warm(rootPath string) error {
	var err error
	e.warmOnce.Do(func() {
		e.env, err = e.buildWatchedEnv(rootPath)
	})
	return err
}

func (e *Evaluator) Evaluate(snippet string) (string, error) {
	if e.env == nil {
		return "", fmt.Errorf("evaluator not warmed")
	}
	var out bytes.Buffer
	err := e.env.Eval(
		jpoet.EvalSnippetInput("arcourse.jsonnet", snippet),
		jpoet.EvalWriterOutput(&out),
	)
	if err != nil {
		return "", err
	}
	return out.String(), nil
}

func (e *Evaluator) EvaluateOnceRaw(snippet string) (string, error) {
	we, err := e.buildOnceEnv()
	if err != nil {
		return "", err
	}
	defer func() { _ = we.Close() }()
	var out bytes.Buffer
	err = we.Eval(
		jpoet.EvalSnippetInput("arcourse.jsonnet", snippet),
		jpoet.EvalWriterOutput(&out),
		jpoet.EvalSerialize(false),
	)
	if err != nil {
		return "", err
	}
	return out.String(), nil
}

func (e *Evaluator) Watch(key string, snippet string) (string, <-chan string, func(), error) {
	if e.env == nil {
		return "", nil, nil, fmt.Errorf("evaluator not warmed")
	}
	var initial watch.Result
	var updates <-chan watch.Result
	unregister, err := e.env.Watch(
		watch.WatchSnippetInput("arcourse.jsonnet", snippet),
		watch.WatchWithKey(watch.WatchKey(key)),
		watch.WatchValueOutput(&initial, &updates),
	)
	if err != nil {
		return "", nil, nil, err
	}
	if initial.Err != nil {
		return "", nil, nil, initial.Err
	}
	ch := make(chan string, 1)
	go func() {
		defer close(ch)
		for r := range updates {
			if r.Err != nil {
				continue
			}
			ch <- r.Output
		}
	}()
	return initial.Output, ch, unregister, nil
}

func (e *Evaluator) WatchFile(key string, snippet string, path string) (func(), error) {
	if e.env == nil {
		return nil, fmt.Errorf("evaluator not warmed")
	}
	return e.env.Watch(
		watch.WatchSnippetInput("arcourse.jsonnet", snippet),
		watch.WatchWithKey(watch.WatchKey(key)),
		watch.WatchFileOutput(path),
		watch.WatchSerialize(false),
	)
}

func (e *Evaluator) buildWatchedEnv(rootPath string) (*watch.Environment, error) {
	diskImporter := &watch.DiskImporter{JPaths: e.jpaths}
	opts := []jpoet.EnvOption{
		jpoet.EnvImporter(diskImporter),
		jpoet.EnvFSImport(e.lib),
		jpoet.EnvWithPluginSet(e.plugins...),
	}
	if rootPath != "" {
		opts = append(opts, jpoet.EnvImporter(&rootAliasImporter{target: rootPath, inner: diskImporter}))
	}
	env := jpoet.Env(opts...)
	return watch.New(env)
}

func (e *Evaluator) buildOnceEnv() (*watch.Environment, error) {
	opts := []jpoet.EnvOption{
		watch.FileImport(e.jpaths),
		jpoet.EnvFSImport(e.lib),
		jpoet.EnvWithPluginSet(e.plugins...),
	}
	env := jpoet.Env(opts...)
	return watch.New(env)
}

type rootAliasImporter struct {
	target string
	inner  jsonnet.Importer
}

func (a *rootAliasImporter) Import(importedFrom, importedPath string) (jsonnet.Contents, string, error) {
	if importedPath != "root" {
		return jsonnet.Contents{}, "", fmt.Errorf("import not available %q", importedPath)
	}
	return a.inner.Import(importedFrom, a.target)
}
