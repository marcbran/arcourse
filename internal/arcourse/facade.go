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
	Evaluate EvaluateConfig `json:"evaluate"`
	Audit    AuditConfig    `json:"audit"`
}

type facade struct {
	evaluate  *Evaluate
	query     *Query
	observe   *Observe
	listAudit *ListAudit
	getAudit  *GetAudit
}

func NewFacade(cfg Config, evaluator Evaluator, lastQuery LastQuery, auditRepo AuditRepo) pkg.Facade {
	evaluate := NewEvaluate(cfg.Evaluate, evaluator)
	appendAudit := NewAppendAudit(auditRepo)
	queryCfg := QueryConfig{AuditFormats: cfg.Audit.Formats}
	query := NewQuery(queryCfg, evaluate, lastQuery, appendAudit)
	observe := NewObserve(lastQuery)
	listAudit := NewListAudit(auditRepo)
	getAudit := NewGetAudit(auditRepo)
	return &facade{evaluate: evaluate, query: query, observe: observe, listAudit: listAudit, getAudit: getAudit}
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
