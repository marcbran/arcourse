package arcourse

import (
	"context"
	"log/slog"
	"sort"
	"time"

	"github.com/google/uuid"
	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type AuditRepo interface {
	Append(ctx context.Context, entry pkg.AuditEntry) error
	List(ctx context.Context) ([]pkg.AuditEntry, error)
	Get(ctx context.Context, id string) (pkg.AuditEntry, error)
}

type AppendAudit struct {
	auditRepo AuditRepo
}

func NewAppendAudit(auditRepo AuditRepo) *AppendAudit {
	return &AppendAudit{auditRepo: auditRepo}
}

func (uc *AppendAudit) Exec(ctx context.Context, path string, results map[pkg.Format]pkg.Result) {
	entry := pkg.AuditEntry{
		ID:        uuid.Must(uuid.NewV7()).String(),
		Path:      path,
		Timestamp: time.Now(),
		Results:   results,
	}
	err := uc.auditRepo.Append(ctx, entry)
	if err != nil {
		slog.Warn("append audit entry", "err", err, "path", path)
	}
}

type ListAudit struct {
	auditRepo AuditRepo
}

func NewListAudit(auditRepo AuditRepo) *ListAudit {
	return &ListAudit{auditRepo: auditRepo}
}

func (uc *ListAudit) Exec(ctx context.Context) ([]pkg.AuditEntry, error) {
	entries, err := uc.auditRepo.List(ctx)
	if err != nil {
		return nil, err
	}
	sort.Slice(entries, func(i, j int) bool {
		return entries[i].Timestamp.Before(entries[j].Timestamp)
	})
	return entries, nil
}

type GetAudit struct {
	auditRepo AuditRepo
}

func NewGetAudit(auditRepo AuditRepo) *GetAudit {
	return &GetAudit{auditRepo: auditRepo}
}

func (uc *GetAudit) Exec(ctx context.Context, id string) (pkg.AuditEntry, error) {
	return uc.auditRepo.Get(ctx, id)
}
