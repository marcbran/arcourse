//go:build e2e

package tests

import (
	"testing"

	pkg "github.com/marcbran/arcourse/pkg/arcourse"
)

func TestQueryNodeByPath(t *testing.T) {
	cases := []struct {
		name     string
		graph    string
		path     string
		expected string
	}{
		{
			name:     "root node",
			graph:    `{ _node: "resource", title: "hello" }`,
			path:     "root",
			expected: `{"_node":"resource","title":"hello"}`,
		},
		{
			name:     "nested child",
			graph:    `{ child: { _node: "resource", value: 42 } }`,
			path:     "root/child",
			expected: `{"_node":"resource","value":42}`,
		},
		{
			name:     "descendant nodes truncated to references",
			graph:    `{ _node: "resource", child: { _node: "resource", _queryPath:: "child", data: "big" } }`,
			path:     "root",
			expected: `{"_node":"resource","child":{"_node":"resource","_queryPath":"child"}}`,
		},
		{
			name:     "reference includes _summary when present",
			graph:    `{ _node: "resource", child: { _node: "resource", _queryPath:: "c", _summary: "A child", data: 42 } }`,
			path:     "root",
			expected: `{"_node":"resource","child":{"_node":"resource","_queryPath":"c","_summary":"A child"}}`,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			given, when, then := scenario(t)

			given.
				a_graph_root(tc.graph)

			when.
				a_path_is_queried(tc.path)

			then.
				the_output_is(tc.expected)
		})
	}
}

func TestQueryNodeWithParams(t *testing.T) {
	cases := []struct {
		name     string
		graph    string
		path     string
		params   map[string]any
		expected string
	}{
		{
			name: "params applied as visible fields",
			graph: `{
				child: {
					_node: true,
					_params:: [
						{ name: 'page', type: 'number', default: 1 },
						{ name: 'pageSize', type: 'number' },
					],
					value: 42,
				},
			}`,
			path:     "root/child",
			params:   map[string]any{"pageSize": "100"},
			expected: `{"_node":true,"pageSize":100,"page":1,"value":42}`,
		},
		{
			name: "optional param falls back to default",
			graph: `{
				child: {
					_node: true,
					_params:: [{ name: 'page', type: 'number', default: 1 }],
					value: 42,
				},
			}`,
			path:     "root/child",
			params:   nil,
			expected: `{"_node":true,"page":1,"value":42}`,
		},
		{
			name: "array params applied from repeated values",
			graph: `{
				child: {
					_node: true,
					_params:: [{ name: 'tags', type: 'array', items: 'string' }],
				},
			}`,
			path:     "root/child",
			params:   map[string]any{"tags": []any{"a", "b"}},
			expected: `{"_node":true,"tags":["a","b"]}`,
		},
		{
			name: "number array params applied from repeated values",
			graph: `{
				child: {
					_node: true,
					_params:: [{ name: 'ids', type: 'array', items: 'number' }],
				},
			}`,
			path:     "root/child",
			params:   map[string]any{"ids": []any{1, 2}},
			expected: `{"_node":true,"ids":[1,2]}`,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			given, when, then := scenario(t)

			given.
				a_graph_root(tc.graph)

			when.
				a_path_is_queried_with_params(tc.path, tc.params)

			then.
				the_output_is(tc.expected)
		})
	}
}

func TestQueryInvalidParams(t *testing.T) {
	cases := []struct {
		name   string
		graph  string
		path   string
		params map[string]any
		err    string
	}{
		{
			name: "undeclared parameter",
			graph: `{
				child: {
					_node: true,
					_params:: [{ name: 'page', type: 'number', default: 1 }],
				},
			}`,
			path:   "root/child",
			params: map[string]any{"unknown": "1"},
			err:    "undeclared parameter",
		},
		{
			name: "required parameter missing",
			graph: `{
				child: {
					_node: true,
					_params:: [{ name: 'pageSize', type: 'number' }],
				},
			}`,
			path:   "root/child",
			params: nil,
			err:    "required parameter",
		},
		{
			name: "value cannot be coerced",
			graph: `{
				child: {
					_node: true,
					_params:: [{ name: 'page', type: 'number' }],
				},
			}`,
			path:   "root/child",
			params: map[string]any{"page": "true"},
			err:    "cannot be coerced to number",
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			given, when, then := scenario(t)

			given.
				a_graph_root(tc.graph)

			when.
				a_path_is_queried_with_params(tc.path, tc.params)

			then.
				the_error_contains(tc.err)
		})
	}
}

func TestQueryPathNotFound(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root(`{ child: { _node: "resource" } }`)

	when.
		a_path_is_queried("root/nonexistent")

	then.
		the_error_contains("nonexistent")
}

func TestQueryPathAsHTML(t *testing.T) {
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
				a_path_is_queried_with_format(tc.path, pkg.FormatHTML)

			then.
				the_raw_output_is(tc.expected)
		})
	}
}

func TestQueryPathAsJsonnet(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root(`{ child: { _view:: { jsonnet: "local x = 1;\nx" } } }`)

	when.
		a_path_is_queried_with_format("root/child", pkg.FormatJsonnet)

	then.
		the_raw_output_is("local x = 1;\nx")
}

func TestQueryNodeWithParamsAsHTML(t *testing.T) {
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
		a_path_is_queried_with_params_and_format("root/child", map[string]any{"name": "alice"}, pkg.FormatHTML)

	then.
		the_raw_output_is("<p>alice</p>")
}

func TestQueryInvalidParamsAsHTML(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root(`{
			child: {
				_params:: [{ name: 'page', type: 'number' }],
				_view:: { html: '<p>ok</p>' },
			},
		}`)

	when.
		a_path_is_queried_with_params_and_format("root/child", map[string]any{"unknown": "1"}, pkg.FormatHTML)

	then.
		the_error_contains("undeclared parameter")
}

func TestQueryPathNotFoundAsHTML(t *testing.T) {
	given, when, then := scenario(t)

	given.
		a_graph_root(`{ child: { _view:: { html: "<p>hi</p>" } } }`)

	when.
		a_path_is_queried_with_format("root/nonexistent", pkg.FormatHTML)

	then.
		the_error_contains("nonexistent")
}
