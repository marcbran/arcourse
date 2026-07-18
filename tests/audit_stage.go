//go:build e2e

package tests

import (
	"context"
	"os"
	"path/filepath"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func (s *Stage) audit_capture_is_disabled() *Stage {
	path := filepath.Join(s.tempDir, "config.yaml")
	data, err := os.ReadFile(path)
	require.NoError(s.t, err)
	data = append(data, []byte("audit:\n  formats: []\n")...)
	err = os.WriteFile(path, data, 0o600)
	require.NoError(s.t, err)
	return s
}

func (s *Stage) the_audit_is_listed() *Stage {
	entries, err := s.facade.ListAudit(context.Background())
	if err != nil {
		s.LastError = err.Error()
		s.auditEntries = nil
		return s
	}
	s.LastError = ""
	s.auditEntries = entries
	return s
}

func (s *Stage) the_audit_entry_at_index_is_fetched(index int) *Stage {
	require.Greater(s.t, len(s.auditEntries), index)
	entry, err := s.facade.GetAudit(context.Background(), s.auditEntries[index].ID)
	if err != nil {
		s.LastError = err.Error()
		return s
	}
	s.LastError = ""
	s.auditEntry = entry
	return s
}

func (s *Stage) the_audit_has_entry_count(expected int) *Stage {
	assert.Len(s.t, s.auditEntries, expected)
	return s
}

func (s *Stage) audit_entry_at_index_has_path(index int, expected string) *Stage {
	require.Greater(s.t, len(s.auditEntries), index)
	assert.Equal(s.t, expected, s.auditEntries[index].Path)
	return s
}

func (s *Stage) the_audit_entries_are_in_chronological_order() *Stage {
	for i := 1; i < len(s.auditEntries); i++ {
		assert.False(s.t, s.auditEntries[i].Timestamp.Before(s.auditEntries[i-1].Timestamp))
	}
	return s
}

func (s *Stage) the_fetched_audit_entry_path_is(expected string) *Stage {
	assert.Equal(s.t, expected, s.auditEntry.Path)
	return s
}

func (s *Stage) the_fetched_audit_entry_html_is(expected string) *Stage {
	assert.Equal(s.t, expected, s.auditEntry.Results[pkg.FormatHTML].Output)
	return s
}

func (s *Stage) the_fetched_audit_entry_json_is(expected string) *Stage {
	assert.JSONEq(s.t, expected, s.auditEntry.Results[pkg.FormatJSON].Output)
	return s
}
