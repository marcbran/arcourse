package jsonfile

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sort"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

type AuditRepo struct {
	dir string
}

func NewAuditRepo(dir string) *AuditRepo {
	return &AuditRepo{dir: dir}
}

func (r *AuditRepo) Append(ctx context.Context, entry pkg.AuditEntry) error {
	err := os.MkdirAll(r.dir, 0o755)
	if err != nil {
		return err
	}
	data, err := json.Marshal(entry)
	if err != nil {
		return err
	}
	return os.WriteFile(r.entryPath(entry.ID), data, 0o644)
}

func (r *AuditRepo) List(ctx context.Context) ([]pkg.AuditEntry, error) {
	names, err := readEntryNames(r.dir)
	if err != nil {
		return nil, err
	}
	entries := make([]pkg.AuditEntry, 0, len(names))
	for _, name := range names {
		data, err := os.ReadFile(filepath.Join(r.dir, name))
		if err != nil {
			return nil, err
		}
		var entry pkg.AuditEntry
		err = json.Unmarshal(data, &entry)
		if err != nil {
			return nil, err
		}
		entries = append(entries, entry)
	}
	return entries, nil
}

func (r *AuditRepo) Get(ctx context.Context, id string) (pkg.AuditEntry, error) {
	data, err := os.ReadFile(r.entryPath(id))
	if err != nil {
		if os.IsNotExist(err) {
			return pkg.AuditEntry{}, pkg.ErrAuditEntryNotFound
		}
		return pkg.AuditEntry{}, err
	}
	var entry pkg.AuditEntry
	err = json.Unmarshal(data, &entry)
	if err != nil {
		return pkg.AuditEntry{}, err
	}
	return entry, nil
}

func (r *AuditRepo) entryPath(id string) string {
	return filepath.Join(r.dir, id+".json")
}

func readEntryNames(dir string) ([]string, error) {
	dirEntries, err := os.ReadDir(dir)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return nil, nil
		}
		return nil, err
	}
	names := make([]string, 0, len(dirEntries))
	for _, dirEntry := range dirEntries {
		if dirEntry.IsDir() || filepath.Ext(dirEntry.Name()) != ".json" {
			continue
		}
		names = append(names, dirEntry.Name())
	}
	sort.Strings(names)
	return names, nil
}
