package arcourse

import (
	"context"

	"github.com/marcbran/arcourse/internal/course"
	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type Config struct {
	Root RootConfig `json:"root"`
}

type facade struct {
	evaluate    *evaluate
	exec        *exec
	remark      *remark
	query       *query
	watch       *watch
	compile     *compile
	warm        *warm
	environment *environment
}

func NewFacade(cfg Config, evaluator Evaluator, executor Executor, courseFacade *course.Facade) pkg.Facade {
	compile := newCompile(cfg.Root, evaluator)
	root := newRoot(cfg.Root, evaluator)
	environment := newEnvironment(root, evaluator, executor)
	evaluate := newEvaluate(environment)
	query := newQuery(environment, courseFacade)
	watch := newWatch(environment, courseFacade)
	warm := newWarm(environment)
	exec := newExec(courseFacade, environment)
	remark := newRemark(courseFacade)

	return &facade{
		evaluate:    evaluate,
		exec:        exec,
		remark:      remark,
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

func (f *facade) Query(ctx context.Context, path pkg.QueryPath, params map[string]any, format pkg.Format, origin pkg.Origin) (pkg.Result, error) {
	return f.query.Exec(ctx, path, params, format, origin)
}

func (f *facade) Watch(ctx context.Context, path pkg.QueryPath, params map[string]any, format pkg.Format, origin pkg.Origin) (<-chan pkg.Result, func(), error) {
	return f.watch.Exec(ctx, path, params, format, origin)
}

func (f *facade) Exec(ctx context.Context, id pkg.EvaluationID) (pkg.ExecResult, error) {
	return f.exec.Exec(ctx, id)
}

func (f *facade) Remark(ctx context.Context, id pkg.EvaluationID, text string) (pkg.RemarkID, error) {
	return f.remark.Exec(ctx, id, text)
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

func courseOrigin(origin pkg.Origin) course.Origin {
	return course.Origin{
		SessionID:   course.SessionID(origin.Session),
		From:        course.EntryID(origin.From),
		FromAddress: course.Address(pkg.NewQueryPath(origin.FromPath.String())),
	}
}
