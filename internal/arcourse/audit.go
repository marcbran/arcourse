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

type appendAudit struct {
	auditRepo AuditRepo
}

func newAppendAudit(auditRepo AuditRepo) *appendAudit {
	return &appendAudit{auditRepo: auditRepo}
}

func (uc *appendAudit) Exec(ctx context.Context, path string, results map[pkg.Format]pkg.Result) {
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

type listAudit struct {
	auditRepo AuditRepo
}

func newListAudit(auditRepo AuditRepo) *listAudit {
	return &listAudit{auditRepo: auditRepo}
}

func (uc *listAudit) Exec(ctx context.Context) ([]pkg.AuditEntry, error) {
	entries, err := uc.auditRepo.List(ctx)
	if err != nil {
		return nil, err
	}
	sort.Slice(entries, func(i, j int) bool {
		return entries[i].Timestamp.Before(entries[j].Timestamp)
	})
	return entries, nil
}

type getAudit struct {
	auditRepo AuditRepo
}

func newGetAudit(auditRepo AuditRepo) *getAudit {
	return &getAudit{auditRepo: auditRepo}
}

func (uc *getAudit) Exec(ctx context.Context, id string) (pkg.AuditEntry, error) {
	return uc.auditRepo.Get(ctx, id)
}
