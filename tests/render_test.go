//go:build e2e

package tests

import (
	"testing"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

func TestRenderPathAsHTML(t *testing.T) {
	cases := []struct {
		name     string
		graph    string
		path     []string
		expected string
	}{
		{
			name:     "root node",
			graph:    `{ _view:: { html: "<p>hi</p>" } }`,
			path:     []string{"root"},
			expected: `<p>hi</p>`,
		},
		{
			name:     "nested child",
			graph:    `{ child: { _view:: { html: "<span>child</span>" } } }`,
			path:     []string{"root", "child"},
			expected: `<span>child</span>`,
		},
		{
			name:     "deeply nested path",
			graph:    `{ a: { b: { _view:: { html: "<div>deep</div>" } } } }`,
			path:     []string{"root", "a", "b"},
			expected: `<div>deep</div>`,
		},
		{
			name:     "path segment with hyphen",
			graph:    `{ "my-node": { _view:: { html: "<p>hyphen</p>" } } }`,
			path:     []string{"root", "my-node"},
			expected: `<p>hyphen</p>`,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			given, when, then := scenario(t)

			given.
				a_graph(tc.graph)

			when.
				a_path_is_rendered(tc.path, pkg.FormatHTML)

			then.
				the_raw_output_is(tc.expected)
		})
	}
}

func TestRenderPathNotFound(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph(`{ child: { _view:: { html: "<p>hi</p>" } } }`)

	when.
		a_path_is_rendered([]string{"root", "nonexistent"}, pkg.FormatHTML)

	then.
		the_error_contains("nonexistent")
}
