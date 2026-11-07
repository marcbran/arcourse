package jsonnet

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io/fs"
	"strings"
	"sync"

	"github.com/google/go-jsonnet"
	"github.com/marcbran/arcourse/internal/arcourse"
	pkg "github.com/marcbran/arcourse/pkg/arcourse"
	"github.com/marcbran/jpoet/pkg/jpoet"
	"github.com/marcbran/jpoet/pkg/watch"
	htmlplugin "github.com/marcbran/jsonnet-plugin-html/html"
	urlplugin "github.com/marcbran/jsonnet-plugin-url/url"
)

type Evaluator struct {
	lib     fs.FS
	jpaths  []string
	plugins []*jpoet.Plugin

	warmOnce sync.Once
	env      *watch.Environment
}

func NewEvaluator(lib fs.FS, jpaths []string, plugins []*jpoet.Plugin) *Evaluator {
	all := make([]*jpoet.Plugin, 0, len(plugins)+3)
	all = append(all, newPlugin())
	for _, p := range []*jpoet.Plugin{urlplugin.Plugin(), htmlplugin.Plugin()} {
		if !hasPlugin(plugins, p.Name()) {
			all = append(all, p)
		}
	}
	all = append(all, plugins...)
	return &Evaluator{lib: lib, jpaths: jpaths, plugins: all}
}

func hasPlugin(plugins []*jpoet.Plugin, name string) bool {
	for _, p := range plugins {
		if p.Name() == name {
			return true
		}
	}
	return false
}

func (e *Evaluator) Warm(rootPath string) error {
	var err error
	e.warmOnce.Do(func() {
		e.env, err = e.buildWatchedEnv(rootPath)
	})
	return err
}

func (e *Evaluator) Close() error {
	if e.env == nil {
		return nil
	}
	return e.env.Close()
}

func (e *Evaluator) Evaluate(ctx context.Context, snippet string) (string, error) {
	if e.env == nil {
		return "", fmt.Errorf("evaluator not warmed")
	}
	var out bytes.Buffer
	err := e.env.Eval(ctx,
		jpoet.EvalSnippetInput("arcourse.jsonnet", snippet),
		jpoet.EvalWriterOutput(&out),
	)
	if err != nil {
		return "", evaluationFailed(err)
	}
	return out.String(), nil
}

func (e *Evaluator) EvaluateOnceRaw(ctx context.Context, snippet string) (string, error) {
	we, err := e.buildOnceEnv()
	if err != nil {
		return "", err
	}
	defer func() { _ = we.Close() }()
	var out bytes.Buffer
	err = we.Eval(ctx,
		jpoet.EvalSnippetInput("arcourse.jsonnet", snippet),
		jpoet.EvalWriterOutput(&out),
		jpoet.EvalSerialize(false),
	)
	if err != nil {
		return "", evaluationFailed(err)
	}
	return out.String(), nil
}

func (e *Evaluator) Exec(ctx context.Context, plugin string, action string, data map[string]any) (string, error) {
	if e.env == nil {
		return "", fmt.Errorf("evaluator not warmed")
	}
	return e.env.Exec(ctx, plugin, action, data)
}

func (e *Evaluator) Watch(ctx context.Context, key string, snippet string) (arcourse.Evaluation, <-chan arcourse.Evaluation, func(), error) {
	if e.env == nil {
		return arcourse.Evaluation{}, nil, nil, fmt.Errorf("evaluator not warmed")
	}
	var initial watch.Result
	var updates <-chan watch.Result
	unregister, err := e.env.Watch(ctx,
		watch.WatchSnippetInput("arcourse.jsonnet", snippet),
		watch.WatchWithKey(watch.WatchKey(key)),
		watch.WatchWithIdentity(contentIdentity),
		watch.WatchValueOutput(&initial, &updates),
	)
	if err != nil && unregister == nil {
		return arcourse.Evaluation{}, nil, nil, err
	}
	ch := make(chan arcourse.Evaluation, 1)
	go func() {
		defer close(ch)
		for r := range updates {
			ch <- arcourse.Evaluation{Output: r.Output, Err: evaluationFailed(r.Err)}
		}
	}()
	return arcourse.Evaluation{Output: initial.Output, Err: evaluationFailed(initial.Err)}, ch, unregister, nil
}

func (e *Evaluator) WatchFile(ctx context.Context, key string, snippet string, path string) (func(), error) {
	if e.env == nil {
		return nil, fmt.Errorf("evaluator not warmed")
	}
	unregister, err := e.env.Watch(ctx,
		watch.WatchSnippetInput("arcourse.jsonnet", snippet),
		watch.WatchWithKey(watch.WatchKey(key)),
		watch.WatchFileOutput(path),
		watch.WatchSerialize(false),
	)
	if err != nil && unregister != nil {
		return unregister, evaluationFailed(err)
	}
	return unregister, err
}

func (e *Evaluator) buildWatchedEnv(rootPath string) (*watch.Environment, error) {
	fileImporter := &jpoet.FileImporter{JPaths: e.jpaths}
	opts := []jpoet.EnvOption{
		jpoet.EnvImporter(fileImporter),
		jpoet.EnvFSImport(e.lib),
		jpoet.EnvWithPluginSet(e.plugins...),
	}
	if rootPath != "" {
		opts = append(opts, jpoet.EnvImporter(&rootAliasImporter{target: rootPath, inner: fileImporter}))
	}
	env := jpoet.Env(opts...)
	return watch.New(env)
}

func (e *Evaluator) buildOnceEnv() (*watch.Environment, error) {
	opts := []jpoet.EnvOption{
		jpoet.EnvFileImport(e.jpaths),
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

func contentIdentity(output string) (string, bool) {
	var raw map[string]json.RawMessage
	err := json.Unmarshal([]byte(output), &raw)
	if err != nil {
		return "", false
	}
	rawID, ok := raw[pkg.EvaluationIDField]
	if !ok {
		return "", false
	}
	var id string
	err = json.Unmarshal(rawID, &id)
	if err != nil || id == "" {
		return "", false
	}
	sum := sha256.Sum256([]byte(strings.ReplaceAll(output, id, "")))
	return hex.EncodeToString(sum[:]), true
}

type evaluationError struct {
	err error
}

func (e evaluationError) Error() string {
	return e.err.Error()
}

func (e evaluationError) Unwrap() error {
	return e.err
}

func (e evaluationError) Is(target error) bool {
	return target == pkg.ErrEvaluation
}

func evaluationFailed(err error) error {
	if err == nil {
		return nil
	}
	return evaluationError{err: err}
}
