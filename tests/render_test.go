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
		path     string
		expected string
	}{
		{
			name:     "root node",
			graph:    `{ _view:: { html: "<p>hi</p>" } }`,
			path:     "root",
			expected: `<p>hi</p>`,
		},
		{
			name:     "nested child",
			graph:    `{ child: { _view:: { html: "<span>child</span>" } } }`,
			path:     "root/child",
			expected: `<span>child</span>`,
		},
		{
			name:     "deeply nested path",
			graph:    `{ a: { b: { _view:: { html: "<div>deep</div>" } } } }`,
			path:     "root/a/b",
			expected: `<div>deep</div>`,
		},
		{
			name:     "path segment with hyphen",
			graph:    `{ "my-node": { _view:: { html: "<p>hyphen</p>" } } }`,
			path:     "root/my-node",
			expected: `<p>hyphen</p>`,
		},
		{
			name:     "function field applied to next segment",
			graph:    `{ get: function(name) { _view:: { html: "<p>" + name + "</p>" } } }`,
			path:     "root/get/alice",
			expected: `<p>alice</p>`,
		},
		{
			name:     "chained function fields",
			graph:    `{ owner: function(o) { repo: function(r) { _view:: { html: "<p>" + o + "/" + r + "</p>" } } } }`,
			path:     "root/owner/marcbran/repo/arcourse",
			expected: `<p>marcbran/arcourse</p>`,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			given, when, then := scenario(t)

			given.
				a_graph_root(tc.graph)

			when.
				a_path_is_rendered(tc.path, pkg.FormatHTML)

			then.
				the_raw_output_is(tc.expected)
		})
	}
}

func TestRenderPathAsJsonnet(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root(`{ child: { _view:: { jsonnet: "local x = 1;\nx" } } }`)

	when.
		a_path_is_rendered("root/child", pkg.FormatJsonnet)

	then.
		the_raw_output_is("local x = 1;\nx")
}

func TestRenderNodeWithParams(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root(`{
			child: {
				local node = self,
				_params:: [{ name: 'name', type: 'string' }],
				_view:: { html: '<p>' + node.name + '</p>' },
			},
		}`)

	when.
		a_path_is_rendered_with_params("root/child", map[string]any{"name": "alice"}, pkg.FormatHTML)

	then.
		the_raw_output_is("<p>alice</p>")
}

func TestRenderInvalidParams(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root(`{
			child: {
				_params:: [{ name: 'page', type: 'number' }],
				_view:: { html: '<p>ok</p>' },
			},
		}`)

	when.
		a_path_is_rendered_with_params("root/child", map[string]any{"unknown": "1"}, pkg.FormatHTML)

	then.
		the_error_contains("undeclared parameter")
}

func TestRenderPathNotFound(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root(`{ child: { _view:: { html: "<p>hi</p>" } } }`)

	when.
		a_path_is_rendered("root/nonexistent", pkg.FormatHTML)

	then.
		the_error_contains("nonexistent")
}
