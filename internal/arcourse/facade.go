package arcourse

import (
	"context"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type AuditConfig struct {
	Formats []pkg.Format `json:"formats"`
	Dir     string       `json:"dir"`
}

type Config struct {
	Root  RootConfig  `json:"root"`
	Audit AuditConfig `json:"audit"`
}

type facade struct {
	evaluate  *evaluate
	query     *query
	observe   *observe
	listAudit *listAudit
	getAudit  *getAudit
	compile   *compile
	warm      *warm
}

func NewFacade(cfg Config, evaluator Evaluator, lastQuery LastQuery, auditRepo AuditRepo) pkg.Facade {
	compile := newCompile(cfg.Root, evaluator)
	root := newRoot(cfg.Root, compile)
	evaluate := newEvaluate(evaluator, root)
	appendAudit := newAppendAudit(auditRepo)
	queryCfg := QueryConfig{AuditFormats: cfg.Audit.Formats}
	query := newQuery(queryCfg, evaluator, root, lastQuery, appendAudit)
	observe := newObserve(lastQuery)
	listAudit := newListAudit(auditRepo)
	getAudit := newGetAudit(auditRepo)
	warm := newWarm(root)
	return &facade{
		evaluate:  evaluate,
		query:     query,
		observe:   observe,
		listAudit: listAudit,
		getAudit:  getAudit,
		compile:   compile,
		warm:      warm,
	}
}

func (f *facade) Evaluate(ctx context.Context, expression string) (pkg.Result, error) {
	return f.evaluate.Exec(ctx, expression)
}

func (f *facade) Query(ctx context.Context, path string, params map[string]any, format pkg.Format) (pkg.Result, error) {
	return f.query.Exec(ctx, path, params, format)
}

func (f *facade) Observe(ctx context.Context, format pkg.Format) (<-chan pkg.Result, func()) {
	return f.observe.Exec(ctx, format)
}

func (f *facade) ListAudit(ctx context.Context) ([]pkg.AuditEntry, error) {
	return f.listAudit.Exec(ctx)
}

func (f *facade) GetAudit(ctx context.Context, id string) (pkg.AuditEntry, error) {
	return f.getAudit.Exec(ctx, id)
}

func (f *facade) Compile(ctx context.Context) (pkg.Result, error) {
	return f.compile.Exec(ctx)
}

func (f *facade) Warm(ctx context.Context) error {
	return f.warm.Exec(ctx)
}
