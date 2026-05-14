//go:build e2e

package tests

import (
	"context"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

func (s *Stage) a_path_is_rendered(path string, format pkg.Format) *Stage {
	result, err := s.facade.Render(context.Background(), path, format)
	if err != nil {
		s.LastOutput = ""
		s.LastError = err.Error()
		return s
	}

	s.LastOutput = result.Output
	s.LastError = ""
	return s
}
