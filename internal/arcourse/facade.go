package arcourse

import (
	"context"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type CourseConfig struct {
	Dir string `json:"dir"`
}

type Config struct {
	Root   RootConfig   `json:"root"`
	Course CourseConfig `json:"course"`
}

type facade struct {
	evaluate    *evaluate
	exec        *exec
	query       *query
	watch       *watch
	compile     *compile
	warm        *warm
	environment *environment
}

func NewFacade(cfg Config, evaluator Evaluator, executor Executor, courseRepo CourseRepo, blobs BlobStore, observer CourseObserver) pkg.Facade {
	compile := newCompile(cfg.Root, evaluator)
	root := newRoot(cfg.Root, evaluator)
	environment := newEnvironment(root, evaluator, executor)
	evaluate := newEvaluate(environment)
	recordVisit := newRecordVisit(courseRepo, blobs, observer)
	getVisitContent := newGetVisitContent(blobs)
	query := newQuery(environment, recordVisit)
	watch := newWatch(environment, recordVisit)
	warm := newWarm(environment)
	exec := newExec(courseRepo, getVisitContent, environment)

	return &facade{
		evaluate:    evaluate,
		exec:        exec,
		query:       query,
		watch:       watch,
		compile:     compile,
		warm:        warm,
		environment: environment,
	}
}

func (f *facade) Evaluate(ctx context.Context, expression string) (pkg.Result, error) {
	return f.evaluate.Exec(ctx, expression)
}

func (f *facade) Query(ctx context.Context, path string, params map[string]any, format pkg.Format, origin pkg.Origin) (pkg.Result, error) {
	return f.query.Exec(ctx, path, params, format, origin)
}

func (f *facade) Watch(ctx context.Context, path string, params map[string]any, format pkg.Format, origin pkg.Origin) (<-chan pkg.Result, func(), error) {
	return f.watch.Exec(ctx, path, params, format, origin)
}

func (f *facade) Exec(ctx context.Context, id string) (pkg.ExecResult, error) {
	return f.exec.Exec(ctx, id)
}

func (f *facade) Compile(ctx context.Context) (pkg.Result, error) {
	return f.compile.Exec(ctx)
}

func (f *facade) Warm(ctx context.Context) error {
	return f.warm.Exec(ctx)
}

func (f *facade) Close() error {
	return f.environment.Close()
}
