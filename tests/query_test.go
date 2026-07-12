//go:build e2e

package tests

import "testing"

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
